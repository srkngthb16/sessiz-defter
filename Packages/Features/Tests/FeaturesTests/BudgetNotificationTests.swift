import Core
import Domain
import Foundation
import Testing
@testable import Features

@Suite("Bütçe bildirimleri")
struct BudgetNotificationTests {
    static let calendar = Fixtures.calendar
    static let categoryID = UUID()

    static func status(ratio: Double, warns: Bool = true) -> BudgetStatus {
        let budget = BudgetEntity(categoryID: categoryID, limit: Money(minorUnits: 100_000),
                                  warnsAtEightyPercent: warns, startDate: Fixtures.date(1))
        return BudgetStatus(budget: budget,
                            spent: Money(minorUnits: Int(100_000 * ratio)),
                            effectiveLimit: Money(minorUnits: 100_000),
                            daysRemaining: 18)
    }

    static var categories: CategoryLookup {
        CategoryLookup([CategoryEntity(id: categoryID, name: "Market", colorIndex: 0,
                                       symbolName: "cart")])
    }

    let planner = BudgetNotificationPlanner()

    @Test("Yolunda bütçe için bildirim üretilmez")
    func yolunda() {
        let requests = planner.requests(for: [Self.status(ratio: 0.5)],
                                        categories: Self.categories,
                                        periodStart: Fixtures.date(1), alreadyScheduled: [])
        #expect(requests.isEmpty)
    }

    @Test("Uyarı ve aşım için ayrı bildirim")
    func esikler() {
        let warning = planner.requests(for: [Self.status(ratio: 0.85)],
                                       categories: Self.categories,
                                       periodStart: Fixtures.date(1), alreadyScheduled: [])
        #expect(warning.count == 1)
        #expect(warning.first?.title == "Bütçe limitine yaklaştınız")
        #expect(warning.first?.body == "Market bütçesinin %85'ini kullandınız.")

        let exceeded = planner.requests(for: [Self.status(ratio: 1.2)],
                                        categories: Self.categories,
                                        periodStart: Fixtures.date(1), alreadyScheduled: [])
        #expect(exceeded.first?.title == "Bütçe aşıldı")
        #expect(exceeded.first?.body == "Market bütçesi %120 seviyesinde.")
    }

    @Test("Bildirim gövdesinde tutar geçmez — kilit ekranı bakiye sızdırmamalı")
    func tutarSizmaz() {
        let requests = planner.requests(for: [Self.status(ratio: 1.2)],
                                        categories: Self.categories,
                                        periodStart: Fixtures.date(1), alreadyScheduled: [])
        for request in requests {
            #expect(!request.body.contains("₺"))
            #expect(!request.body.contains(","))
        }
    }

    @Test("Aynı eşik iki kez planlanmaz")
    func tekrarYok() {
        let status = Self.status(ratio: 0.85)
        let identifier = BudgetNotificationPlanner.identifier(
            budgetID: status.budget.id, periodStart: Fixtures.date(1),
            state: .warning, calendar: Self.calendar)
        let requests = planner.requests(for: [status], categories: Self.categories,
                                        periodStart: Fixtures.date(1),
                                        alreadyScheduled: [identifier])
        #expect(requests.isEmpty)
    }

    @Test("%80 uyarısı kapalıysa uyarı gelmez ama aşım yine gelir")
    func uyariKapali() {
        let warning = planner.requests(for: [Self.status(ratio: 0.85, warns: false)],
                                       categories: Self.categories,
                                       periodStart: Fixtures.date(1), alreadyScheduled: [])
        #expect(warning.isEmpty)

        let exceeded = planner.requests(for: [Self.status(ratio: 1.2, warns: false)],
                                        categories: Self.categories,
                                        periodStart: Fixtures.date(1), alreadyScheduled: [])
        #expect(exceeded.count == 1)
    }

    @Test("Kimlik bütçe, dönem ve eşikten türer")
    func kimlik() {
        let budgetID = UUID()
        let warning = BudgetNotificationPlanner.identifier(
            budgetID: budgetID, periodStart: Fixtures.date(1), state: .warning,
            calendar: Self.calendar)
        let exceeded = BudgetNotificationPlanner.identifier(
            budgetID: budgetID, periodStart: Fixtures.date(1), state: .exceeded,
            calendar: Self.calendar)
        #expect(warning != exceeded)
        #expect(warning.contains("2026-08"))
        #expect(warning.hasSuffix("warning"))
    }
}
