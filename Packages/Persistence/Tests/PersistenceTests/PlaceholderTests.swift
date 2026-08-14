import Foundation
import Testing
@testable import Persistence

@Suite("Kalıcılık iskeleti")
struct PlaceholderTests {
    @Test("Modül derleniyor")
    func moduleLoads() {
        #expect(PersistenceModule.layer.isEmpty == false)
    }
}
