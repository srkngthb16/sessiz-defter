import Foundation
import Testing
@testable import ImportPipeline

@Suite("Hat iskeleti")
struct PlaceholderTests {
    @Test("Modül derleniyor")
    func moduleLoads() {
        #expect(ImportPipelineModule.layer.isEmpty == false)
    }
}
