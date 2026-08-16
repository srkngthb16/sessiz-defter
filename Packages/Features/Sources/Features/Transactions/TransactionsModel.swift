import Core
import Domain
import Foundation

@Observable
@MainActor
public final class TransactionsModel {
    public private(set) var groups: [TransactionDayGroup] = []
    public private(set) var totalCount: Int = 0
    public private(set) var categories = CategoryLookup()
    public private(set) var accounts = AccountLookup()
    public private(set) var isLoading = true

    public var searchText: String = "" { didSet { scheduleReload(oldValue) } }
    public var query = TransactionQuery.all {
        didSet { visibleLimit = Self.pageSize }
    }

    /// Liste sayfa sayfa yükleniyor: 10.000 kayıtlık defterde tümünü tek seferde
    /// okumak 494 ms sürüyordu. Ekranda en çok birkaç düzine satır var, gerisi
    /// kullanıcı sona yaklaşınca geliyor.
    static let pageSize = 200

    private(set) var visibleLimit = pageSize

    /// Yüklenmiş satır sayısı.
    public var loadedCount: Int { groups.reduce(0) { $0 + $1.transactions.count } }

    /// Sayfa dolduysa devamı vardır.
    public var canLoadMore: Bool { loadedCount >= visibleLimit }

    /// Listenin son satırı — görünürlüğü sonraki sayfayı tetikler.
    public var lastLoadedTransactionID: UUID? { groups.last?.transactions.last?.id }

    private let environment: AppEnvironment

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    /// Filtre rozetleri (D2 üst şerit): kaldırıldığında ilgili filtre temizlenir.
    public struct Chip: Identifiable, Hashable {
        public let id: String
        public let title: String
    }

    public var chips: [Chip] {
        var result: [Chip] = []
        if let range = query.dateRange {
            result.append(Chip(id: "date",
                               title: DashboardModel.monthTitle(range.lowerBound,
                                                                calendar: environment.calendar)))
        }
        for id in query.accountIDs {
            result.append(Chip(id: "account-\(id)", title: accounts.displayName(id)))
        }
        for id in query.categoryIDs {
            result.append(Chip(id: "category-\(id)", title: categories.name(id)))
        }
        if query.minimumAmount != nil || query.maximumAmount != nil {
            let low = query.minimumAmount.map(Fmt.amount) ?? "0"
            let high = query.maximumAmount.map(Fmt.amount) ?? "∞"
            result.append(Chip(id: "amount", title: "\(low) – \(high) ₺"))
        }
        if query.onlyNeedsReview {
            result.append(Chip(id: "review", title: "Yalnızca kontrol gerekenler"))
        }
        return result
    }

    public var hasActiveFilters: Bool { !chips.isEmpty || !searchText.isEmpty }

    public func removeChip(_ chip: Chip) {
        switch chip.id {
        case "date": query.dateRange = nil
        case "amount":
            query.minimumAmount = nil
            query.maximumAmount = nil
        case "review": query.onlyNeedsReview = false
        default:
            if let raw = chip.id.split(separator: "-", maxSplits: 1).last,
               let uuid = UUID(uuidString: String(raw)) {
                query.accountIDs.remove(uuid)
                query.categoryIDs.remove(uuid)
            }
        }
    }

    public func clearFilters() {
        query = .all
        searchText = ""
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            categories = CategoryLookup(try await environment.categories.all(includeArchived: true))
            accounts = AccountLookup(try await environment.accounts.all(includeArchived: true))
            var effective = query
            effective.searchText = searchText.isEmpty ? nil : searchText
            effective.limit = visibleLimit
            let rows = try await environment.transactions.transactions(matching: effective)
            groups = TransactionService.group(rows, calendar: environment.calendar)
            totalCount = try await environment.transactions.count(matching: .all)
        } catch {
            environment.diagnostics.record(.dataRead)
            groups = []
            totalCount = 0
        }
    }

    /// Liste sonuna gelindiğinde çağrılır. Zaten yükleniyorsa ya da devamı yoksa
    /// hiçbir şey yapmaz — kaydırma sırasında üst üste sorgu atılmasın.
    public func loadMore() async {
        guard !isLoading, canLoadMore else { return }
        visibleLimit += Self.pageSize
        await load()
    }

    public func delete(_ transaction: TransactionEntity) async {
        try? await environment.transactions.delete(id: transaction.id)
        await load()
    }

    private func scheduleReload(_ oldValue: String) {
        guard oldValue != searchText else { return }
    }
}
