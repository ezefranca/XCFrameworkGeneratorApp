import Foundation
import XcodeProj

class XcodeProjService {
    private(set) var project: XcodeProj?
    private(set) var projectPath: String?

    func loadProject(at path: String) -> Bool {
        do {
            project = try XcodeProj(pathString: path)
            projectPath = path                  
            return true
        } catch {
            print("Error loading project: \(error)")
            return false
        }
    }

    func fetchSchemes() -> [String] {
        guard let project = project else { return [] }

        var allSchemes: [XCScheme] = []

        if let shared = project.sharedData {
            allSchemes.append(contentsOf: shared.schemes)
        }

        for userData in project.userData {
            allSchemes.append(contentsOf: userData.schemes)
        }

        return Array(Set(allSchemes.map { $0.name })).sorted()
    }
}
