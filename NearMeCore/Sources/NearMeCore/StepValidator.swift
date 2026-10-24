import CoreGraphics
import Foundation

public enum StepValidator {
    /// Actions describe guidance only; they must never be executed against the target app.
    public static func isValid(elementIndex: Int, action: String, in list: ElementList) -> Bool {
        guard list.elements.indices.contains(elementIndex),
              list.elements[elementIndex].isEnabled else { return false }
        return ["click", "scroll", "none"].contains(action)
    }
}
