import Foundation

enum Fixture {
    static func text(_ name: String) throws -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: "txt",
                                          subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: name, withExtension: "txt") else {
            throw NSError(domain: "Fixture", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "bulunamadı: \(name).txt"])
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
