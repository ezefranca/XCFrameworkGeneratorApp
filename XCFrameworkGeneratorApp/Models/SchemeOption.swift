import Foundation

struct SchemeOption: Identifiable, Hashable {
    let id: String
    let name: String

    init(name: String, id: String) {
        self.name = name
        self.id = id
    }
}
