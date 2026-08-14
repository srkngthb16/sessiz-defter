import DesignSystem
import Domain
import SnapshotSupport
import SwiftUI
import Testing
@testable import Features

@Suite(.serialized)
struct ScreenSnapshotTests {
    init() { Fonts.register() }
    static let suiteName = "ScreenSnapshotTests"

    @MainActor
    @Test("B1 — dashboard boş durum")
    func bosDurum() throws {
        try Snapshot.verify(
            NavigationStack { DashboardScreen(state: .empty).navigationTitle("Özet") },
            name: "dashboard-bos", suite: Self.suiteName)
    }

    @MainActor
    @Test("B2 — dashboard yükleme iskeleti")
    func iskelet() throws {
        try Snapshot.verify(
            NavigationStack { DashboardScreen(state: .loading).navigationTitle("Özet") },
            name: "dashboard-iskelet", suite: Self.suiteName)
    }

    @MainActor
    @Test("D1 — dashboard dolu")
    func dolu() async throws {
        let state = await Fixtures.loadedDashboard()
        try Snapshot.verify(
            NavigationStack {
                DashboardScreen(state: state, calendar: Fixtures.calendar)
                    .navigationTitle("Özet")
            },
            name: "dashboard-dolu", suite: Self.suiteName)
    }
}
