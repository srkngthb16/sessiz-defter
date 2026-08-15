import Core
import DesignSystem
import SnapshotSupport
import SwiftUI
import Testing
@testable import Features

@Suite(.serialized)
struct SecuritySnapshotTests {
    init() { Fonts.register() }
    static let suiteName = "SecuritySnapshotTests"

    @MainActor
    @Test("A4 — kilit ekranı")
    func kilitEkrani() throws {
        try Snapshot.verify(
            LockView(appLock: StubAppLock(succeeds: false)) {},
            name: "a4-kilit", suite: Self.suiteName)
    }

    @MainActor
    @Test("F2 — mahremiyet raporu")
    func mahremiyetRaporu() throws {
        var counts = SettingsView.Counts()
        counts.transactions = 218
        counts.accounts = 3
        counts.budgets = 5
        counts.rules = 7
        counts.profiles = 2
        try Snapshot.verify(
            NavigationStack { PrivacyReportView(counts: counts) },
            name: "f2-mahremiyet", suite: Self.suiteName)
    }
}
