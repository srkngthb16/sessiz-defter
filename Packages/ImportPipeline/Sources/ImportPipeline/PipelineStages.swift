import Core
import Domain
import Foundation

/// Hattın adımları Faz 4'te doldurulur. Protokoller şimdiden burada duruyor ki
/// parser'lar saf Swift olarak, PDFKit'e bağlanmadan TDD ile yazılabilsin.
public protocol TextExtracting: Sendable {
    func extractText(fromFileAt url: URL) throws -> String
}

public protocol BankFormatDetecting: Sendable {
    func detectFormat(in text: String) -> String?
}

public protocol StatementParsing: Sendable {
    var formatIdentifier: String { get }
    func canParse(_ text: String) -> Bool
}

public enum ImportPipelineModule {
    public static let layer = "Import Pipeline · on-device"
}
