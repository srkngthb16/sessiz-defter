import Core
import Domain
import Testing
@testable import Features

@Suite("Ekran modelleri")
struct ModelBehaviourTests {
    @MainActor
    @Test("Veri yokken dashboard boş duruma düşer ve kategoriler yazılır")
    func bosDashboard() async {
        let environment = await Fixtures.environment(seeded: false)
        let model = DashboardModel(environment: environment)
        await model.load()

        guard case .empty = model.state else {
            Issue.record("boş durum bekleniyordu")
            return
        }
        let categories = try? await environment.categories.all(includeArchived: true)
        #expect(categories?.isEmpty == false)
    }

    @MainActor
    @Test("Dolu dashboard net varlık ve ay özetini hesaplar")
    func doluDashboard() async throws {
        let model = DashboardModel(environment: await Fixtures.environment())
        await model.load()

        guard case .loaded(let content) = model.state else {
            Issue.record("dolu durum bekleniyordu")
            return
        }
        // 150.000,00 açılış + 52.400,00 maaş − 842,60 − 1.180,00
        #expect(content.netWorth.minorUnits == 20_037_740)
        #expect(content.summary.income.minorUnits == 5_240_000)
        #expect(content.summary.expense.minorUnits == 202_260)
        #expect(content.periodTitle == "Ağustos 2026")
        #expect(content.accountCount == 2)
        #expect(content.recent.count == 3)
    }

    @MainActor
    @Test("İşlem listesi güne göre gruplanır, arama süzer")
    func islemListesi() async {
        let model = TransactionsModel(environment: await Fixtures.environment())
        await model.load()
        #expect(model.groups.count == 3)
        #expect(model.totalCount == 3)

        model.searchText = "migros"
        await model.load()
        #expect(model.groups.count == 1)
        #expect(model.groups.first?.transactions.first?.detail == "Migros Ataşehir")
    }

    @MainActor
    @Test("Filtre rozeti kaldırılınca ilgili filtre temizlenir")
    func filtreRozetleri() async {
        let model = TransactionsModel(environment: await Fixtures.environment())
        await model.load()
        model.query.accountIDs = [Fixtures.garanti.id]
        model.query.onlyNeedsReview = true

        #expect(model.chips.count == 2)
        for chip in model.chips { model.removeChip(chip) }
        #expect(model.chips.isEmpty)
        #expect(model.query.accountIDs.isEmpty)
        #expect(model.query.onlyNeedsReview == false)
    }
}
