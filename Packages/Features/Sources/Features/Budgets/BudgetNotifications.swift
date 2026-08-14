import Core
import Domain
import Foundation
import UserNotifications

/// Bütçe eşiği aşıldığında yerel bildirim. Ağ kullanılmaz, arka planda iş çalışmaz:
/// eşik uygulama açıkken hesaplanır, bildirim sistem tarafından zamanlanır.
///
/// Bildirim gövdesinde tutar yazılmaz — kilit ekranında görünen metin bakiye
/// sızdırmamalı. Yalnızca kategori adı ve yüzde geçer.
public protocol BudgetNotifying: Sendable {
    func requestAuthorizationIfNeeded() async -> Bool
    func schedule(_ requests: [BudgetNotificationRequest]) async
    func pendingIdentifiers() async -> Set<String>
}

public struct BudgetNotificationRequest: Hashable, Sendable {
    public let identifier: String
    public let title: String
    public let body: String

    public init(identifier: String, title: String, body: String) {
        self.identifier = identifier
        self.title = title
        self.body = body
    }
}

public struct BudgetNotificationPlanner: Sendable {
    public init() {}

    /// Aynı bütçe, dönem ve eşik için tek bildirim: kimlik bu üçlüden türer.
    public static func identifier(budgetID: UUID, periodStart: Date,
                                  state: BudgetStatus.State,
                                  calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month], from: periodStart)
        let stamp = String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
        return "budget.\(budgetID.uuidString).\(stamp).\(state == .exceeded ? "exceeded" : "warning")"
    }

    public func requests(
        for statuses: [BudgetStatus],
        categories: CategoryLookup,
        periodStart: Date,
        alreadyScheduled: Set<String>
    ) -> [BudgetNotificationRequest] {
        statuses.compactMap { status in
            guard status.budget.warnsAtEightyPercent || status.state == .exceeded,
                  status.state != .onTrack else { return nil }
            let identifier = Self.identifier(budgetID: status.budget.id,
                                             periodStart: periodStart, state: status.state)
            guard !alreadyScheduled.contains(identifier) else { return nil }

            let name = categories.name(status.budget.categoryID)
            let percent = Fmt.percent(status.ratio)
            return BudgetNotificationRequest(
                identifier: identifier,
                title: status.state == .exceeded ? "Bütçe aşıldı" : "Bütçe limitine yaklaştınız",
                body: status.state == .exceeded
                    ? "\(name) bütçesi \(percent) seviyesinde."
                    : "\(name) bütçesinin \(percent)'ini kullandınız.")
        }
    }
}

public struct SystemBudgetNotifier: BudgetNotifying {
    public init() {}

    public func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional: return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default: return false
        }
    }

    public func schedule(_ requests: [BudgetNotificationRequest]) async {
        let center = UNUserNotificationCenter.current()
        for request in requests {
            let content = UNMutableNotificationContent()
            content.title = request.title
            content.body = request.body
            content.sound = .default
            // Anında tetiklenen bildirim yerine kısa gecikme: kullanıcı hâlâ
            // uygulamadayken banner göstermek gürültü olur.
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            try? await center.add(UNNotificationRequest(
                identifier: request.identifier, content: content, trigger: trigger))
        }
    }

    public func pendingIdentifiers() async -> Set<String> {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let delivered = await center.deliveredNotifications()
        return Set(pending.map(\.identifier)).union(delivered.map(\.request.identifier))
    }
}
