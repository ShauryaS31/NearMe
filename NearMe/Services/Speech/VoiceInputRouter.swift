// Adapted from a prior prototype, used with permission.

import Foundation
import Speech
import OSLog

@MainActor
protocol OnDeviceSpeechCapabilityChecking {
    func service(for locale: Locale) async throws -> VoiceInputService?
}

@MainActor
struct OnDeviceSpeechCapabilities: OnDeviceSpeechCapabilityChecking {
    func service(for locale: Locale) async throws -> VoiceInputService? {
        var assetFailure = false
        if #available(iOS 26.0, *), SpeechTranscriber.isAvailable,
           let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) {
            let transcriber = SpeechTranscriber(locale: supported, transcriptionOptions: [],
                                              reportingOptions: [.volatileResults], attributeOptions: [])
            do {
                let installation = try await AssetInventory.assetInstallationRequest(supporting: [transcriber])
                if let installation {
                    try await installation.downloadAndInstall()
                }
                let installed = await SpeechTranscriber.installedLocales
                if installed.contains(where: { $0.identifier(.bcp47) == supported.identifier(.bcp47) }) {
                    return AnalyzerVoiceInputService(transcriber: transcriber)
                }
                assetFailure = true
            } catch {
                assetFailure = true
                VoiceDiagnostics.logger.notice("On-device speech assets unavailable; checking local recognizer")
            }
        }
        if let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable,
           recognizer.supportsOnDeviceRecognition == true {
            return AppleSpeechFallbackService(locale: locale)
        }
        if assetFailure { throw VoiceInputError.recognizerUnavailable }
        return nil
    }
}

@MainActor
final class VoiceInputRouter: VoiceInputService {
    private let capabilities: OnDeviceSpeechCapabilityChecking
    private let locales: [Locale]
    private var activeService: VoiceInputService?
    private var generation = 0

    init(capabilities: OnDeviceSpeechCapabilityChecking = OnDeviceSpeechCapabilities(),
         locales: [Locale] = [Locale(identifier: "en-AU"), .current]) {
        self.capabilities = capabilities
        self.locales = locales
    }

    var isListening: Bool { activeService?.isListening ?? false }

    func prepareForListening() async throws {
        stopListening()
        let token = generation
        var temporarilyUnavailable = false
        for locale in locales {
            let service: VoiceInputService?
            do { service = try await capabilities.service(for: locale) }
            catch { temporarilyUnavailable = true; service = nil }
            guard token == generation, !Task.isCancelled else { throw CancellationError() }
            if let service {
                activeService = service
                VoiceDiagnostics.logger.info("On-device speech ready locale=\(locale.identifier, privacy: .public)")
                return
            }
        }
        let error: VoiceInputError = temporarilyUnavailable ? .recognizerUnavailable : .unsupportedOnDeviceLocale
        VoiceDiagnostics.logger.notice("On-device speech unavailable reason=\(temporarilyUnavailable ? "assets unavailable" : "unsupported locale or device", privacy: .public)")
        throw error
    }

    func startListening(onPartialTranscript: @escaping (String) -> Void) async throws -> String {
        if activeService == nil { try await prepareForListening() }
        guard let activeService else { throw VoiceInputError.recognizerUnavailable }
        return try await activeService.startListening(onPartialTranscript: onPartialTranscript)
    }

    func stopListening() {
        generation += 1
        activeService?.stopListening()
        activeService = nil
    }
}
