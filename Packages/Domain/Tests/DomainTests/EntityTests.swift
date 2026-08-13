import Core
import Domain
import Foundation
import Testing

@Suite("Varlık değişmezleri")
struct EntityTests {
    @Test("Tutar daima pozitif saklanır, yön ayrı alanda")
    func tutarPozitif() {
        let entity = TransactionEntity(
            date: Date(), amount: Money(minorUnits: -84260),
            direction: .expense, detail: "Migros", accountID: UUID())
        #expect(entity.amount.minorUnits == 84260)
        #expect(entity.signedAmount.minorUnits == -84260)
    }

    @Test("Transfer bakiyeye etki etmez")
    func transferNotr() {
        let entity = TransactionEntity(
            date: Date(), amount: Money(minorUnits: 125000),
            direction: .transfer, detail: "Papara → Ziraat", accountID: UUID())
        #expect(entity.signedAmount == .zero)
    }

    @Test("Yön işaretleri ve ikonları tasarımla aynı")
    func yonKodlamasi() {
        #expect(TransactionDirection.income.signPrefix == "+")
        #expect(TransactionDirection.expense.signPrefix == "\u{2212}")
        #expect(TransactionDirection.transfer.signPrefix == "")
        #expect(TransactionDirection.income.symbolName == "arrow.down.left")
        #expect(TransactionDirection.expense.symbolName == "arrow.up.right")
        #expect(TransactionDirection.transfer.symbolName == "arrow.left.arrow.right")
    }

    @Test("Kategori renk indeksi 0..<12 aralığına kelepçelenir")
    func renkIndeksi() {
        #expect(CategoryEntity(name: "X", colorIndex: 99, symbolName: "a").colorIndex == 11)
        #expect(CategoryEntity(name: "X", colorIndex: -5, symbolName: "a").colorIndex == 0)
    }

    @Test("Hesap görünen adı maskeyi ekler")
    func hesapAdi() {
        let account = AccountEntity(name: "Ziraat", kind: .checking, maskedNumber: "••3412")
        #expect(account.displayName == "Ziraat ••3412")
        #expect(AccountEntity(name: "Nakit", kind: .cash).displayName == "Nakit")
    }
}
