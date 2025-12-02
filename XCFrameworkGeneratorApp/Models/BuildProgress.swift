import Foundation

struct BuildProgress {
    let currentStep: Int
    let totalSteps: Int
    let label: String

    static let idle = BuildProgress(currentStep: 0, totalSteps: 0, label: "")
}
