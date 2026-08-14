import Core
import DesignSystem
import Domain
import SwiftUI

/// D4 — filtre sheet'i. Değişiklikler "Uygula"ya basılana kadar taslakta kalır;
/// yarım bırakılan filtre listeyi değiştirmemeli.
public struct FilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    let model: TransactionsModel
    @State private var draft: TransactionQuery
    @State private var preset: DatePreset = .none

    public enum DatePreset: String, CaseIterable, Identifiable {
        case none = "Tümü"
        case thisMonth = "Bu ay"
        case lastMonth = "Geçen ay"
        case quarter = "Çeyrek"

        public var id: String { rawValue }
    }

    public init(model: TransactionsModel) {
        self.model = model
        _draft = State(initialValue: model.query)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Tarih aralığı") {
                    Picker("Dönem", selection: $preset) {
                        ForEach(DatePreset.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Kategori") {
                    ForEach(model.categories.expenseCategories) { category in
                        toggleRow(category.name, isOn: draft.categoryIDs.contains(category.id)) {
                            toggle(category.id, in: \.categoryIDs)
                        }
                    }
                }

                Section("Hesap") {
                    ForEach(model.accounts.ordered) { account in
                        toggleRow(account.displayName,
                                  isOn: draft.accountIDs.contains(account.id)) {
                            toggle(account.id, in: \.accountIDs)
                        }
                    }
                }

                Section {
                    Toggle("Yalnızca kontrol gerekenler", isOn: $draft.onlyNeedsReview)
                }
            }
            .navigationTitle("Filtrele")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Temizle") {
                        draft = .all
                        preset = .none
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Uygula") {
                        model.query = applyingPreset(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func toggleRow(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).foregroundStyle(Color.text.primary)
                Spacer()
                if isOn {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.brand.primary)
                        .fontWeight(.semibold)
                }
            }
        }
        .frame(minHeight: Metrics.minimumTapTarget)
    }

    private func toggle(_ id: UUID, in keyPath: WritableKeyPath<TransactionQuery, Set<UUID>>) {
        if draft[keyPath: keyPath].contains(id) {
            draft[keyPath: keyPath].remove(id)
        } else {
            draft[keyPath: keyPath].insert(id)
        }
    }

    private func applyingPreset(_ query: TransactionQuery) -> TransactionQuery {
        var result = query
        let calendar = Calendar.current
        let today = Date()
        switch preset {
        case .none:
            result.dateRange = nil
        case .thisMonth:
            let interval = Period.month(containing: today, calendar: calendar)
            result.dateRange = interval.start...interval.end
        case .lastMonth:
            let interval = Period.previousMonth(before: today, calendar: calendar)
            result.dateRange = interval.start...interval.end
        case .quarter:
            let start = calendar.date(byAdding: .month, value: -3, to: today) ?? today
            result.dateRange = start...today
        }
        return result
    }
}
