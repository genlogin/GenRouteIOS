import MapKit

extension MKRoute {
    /// Heuristic: phát hiện bước gợi ý phà / tuyến thủy theo ngôn ngữ phổ biến.
    var likelyContainsFerryManeuver: Bool {
        steps.contains { step in
            let text = step.instructions.lowercased()
            if text.isEmpty { return false }
            return text.contains("ferry")
                || text.contains("phà")
                || text.contains("boat ")
                || text.contains(" đò ")
                || text.contains("cruise")
        }
    }
}
