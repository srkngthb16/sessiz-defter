import Core
import Testing
@testable import Features

@Suite("Manuel giriş tutar ayrıştırma")
struct AmountParsingTests {
    @Test("tr_TR yazımı kabul edilir")
    func gecerliGirisler() {
        #expect(TransactionEditorView.parseAmount("248,50")?.minorUnits == 24_850)
        #expect(TransactionEditorView.parseAmount("1.234,56")?.minorUnits == 123_456)
        #expect(TransactionEditorView.parseAmount("1234,5")?.minorUnits == 123_450)
        #expect(TransactionEditorView.parseAmount("100")?.minorUnits == 10_000)
        #expect(TransactionEditorView.parseAmount("₺ 48.320,75")?.minorUnits == 4_832_075)
    }

    @Test("Geçersiz giriş nil döner")
    func gecersizGirisler() {
        #expect(TransactionEditorView.parseAmount("") == nil)
        #expect(TransactionEditorView.parseAmount("abc") == nil)
        #expect(TransactionEditorView.parseAmount("1,2,3") == nil)
        #expect(TransactionEditorView.parseAmount("12,ab") == nil)
    }

    @Test("Kuruş iki hane ile sınırlı")
    func kurusSiniri() {
        #expect(TransactionEditorView.parseAmount("10,999")?.minorUnits == 1_099)
    }
}
