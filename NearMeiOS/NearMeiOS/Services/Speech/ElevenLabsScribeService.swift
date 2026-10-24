// Adapted from a prior prototype, used with permission.

import Foundation

@MainActor
final class ElevenLabsScribeService: VoiceInputService {
    private let recorder = AudioFileRecorder()
    private let session: URLSession
    private(set) var isListening = false

    /// Backstop for `recordAudio()` — see that method's header comment.
    private static let hardRecordingTimeout: TimeInterval = 25

    private let modelID = "scribe_v1"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func startListening(onPartialTranscript: @escaping (String) -> Void) async throws -> String {
        guard APIKeys.hasElevenLabsKey else {
            throw VoiceInputError.transcriptionFailed("No ElevenLabs API key configured (see APIKeys.swift).")
        }

        isListening = true
        defer { isListening = false }

        let fileURL = try await recordAudio()

        defer { try? FileManager.default.removeItem(at: fileURL) }

        return try await transcribe(fileURL: fileURL)
    }

    private func recordAudio() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let resume = ResumeOnce(continuation)

            do {
                try recorder.start { result in
                    switch result {
                    case .success(let url): resume.fulfill(returning: url)
                    case .failure(let error): resume.fulfill(throwing: error)
                    }
                }
            } catch {
                resume.fulfill(throwing: VoiceInputError.microphoneUnavailable)
                return
            }

            Task { [recorder] in
                try? await Task.sleep(nanoseconds: UInt64(Self.hardRecordingTimeout * 1_000_000_000))
                recorder.stop() // resolves the completion itself if still pending
                resume.fulfill(throwing: VoiceInputError.noSpeechDetected) // no-op if already resolved
            }
        }
    }

    func stopListening() {
        recorder.stop()
        isListening = false
    }

    // MARK: - Upload
    private func transcribe(fileURL: URL) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.elevenlabs.io/v1/speech-to-text")!)
        request.httpMethod = "POST"
        request.setValue(APIKeys.elevenLabsAPIKey, forHTTPHeaderField: "xi-api-key")

        let boundary = "NearMe-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let audioData = try Data(contentsOf: fileURL)
        var body = Data()

        func appendField(name: String, value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        appendField(name: "model_id", value: modelID)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"speech.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw VoiceInputError.network(error)
        }

        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw VoiceInputError.transcriptionFailed("ElevenLabs returned status \(statusCode): \(bodyText)")
        }

        let decoded = try JSONDecoder().decode(ScribeResponse.self, from: data)
        let text = decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw VoiceInputError.noSpeechDetected
        }
        return text
    }

    private struct ScribeResponse: Decodable {
        let text: String
        let languageCode: String?

        enum CodingKeys: String, CodingKey {
            case text
            case languageCode = "language_code"
        }
    }
}
