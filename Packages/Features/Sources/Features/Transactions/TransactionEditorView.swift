import Core
import DesignSystem
import Domain
import SwiftUI

/// E4 (yeni işlem) ve D5 (detay / düzenleme) aynı formu paylaşır: alanlar birebir aynı,
/// yalnızca başlık ve silme eylemi değişir.
public struct TransactionEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let environment: AppEnvironment
    let existing: TransactionEntity?
    let onSaved: () -> Void

    @State private var direction: TransactionDirection
    @State private var amountText: String
    @State private var detail: String
    @State private var categoryID: UUID?
    @State private var accountID: UUID?
    @State private var date: Date
    @State private var note: String
    @State private var categories = CategoryLookup()
    @State private var accounts = AccountLookup()
    @State private var showsDeleteConfirmation = false

    public init(
        environment: AppEnvironment,
        editing existing: TransactionEntity? = nil,
        onSaved: @escaping () -> Void = {}
    ) {
        self.environment = environment
        self.existing = existing
        self.onSaved = onSaved
        _direction = State(initialValue: existing?.direction ?? .expense)
        _amountText = State(initialValue: existing.map { Fmt.amount($0.amount) } ?? "")
        _detail = State(initialValue: existing?.detail ?? "")
        _categoryID = State(initialValue: existing?.categoryID)
        _accountID = State(initialValue: existing?.accountID)
        _date = State(initialValue: existing?.date ?? Date())
        _note = State(initialValue: existing?.note ?? "")
    }

    private var isEditing: Bool { existing != nil }

    private var parsedAmount: Money? {
        Self.parseAmount(amountText)
    }

    private var canSave: Bool {
        guard let parsedAmount, parsedAmount.minorUnits > 0 else { return false }
        return !detail.trimmingCharacters(in: .whitespaces).isEmpty && accountID != nil
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Yön", selection: $direction) {
                        Text("Gider").tag(TransactionDirection.expense)
                        Text("Gelir").tag(TransactionDirection.income)
                        Text("Transfer").tag(TransactionDirection.transfer)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Tutar") {
                    HStack {
                        TextField("0,00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.sd.amountRow)
                            .multilineTextAlignment(.trailing)
                        Text("₺").foregroundStyle(Color.text.muted)
                    }
                }

                Section("Açıklama") {
                    TextField("Örn. Migros Ataşehir", text: $detail)
                        .font(.sd.bodyItem)
                }

                Section {
                    Picker("Kategori", selection: $categoryID) {
                        Text("Kategorisiz").tag(UUID?.none)
                        ForEach(categoryOptions) { category in
                            Text(category.name).tag(UUID?.some(category.id))
                        }
                    }
                    Picker("Hesap", selection: $accountID) {
                        Text("Seçiniz").tag(UUID?.none)
                        ForEach(accounts.ordered) { account in
                            Text(account.displayName).tag(UUID?.some(account.id))
                        }
                    }
                    DatePicker("Tarih", selection: $date, displayedComponents: .date)
                        .environment(\.locale, TurkishLocale.locale)
                }

                Section("Not") {
                    TextField("İsteğe bağlı", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }

                if isEditing {
                    Section {
                        Button("İşlemi sil", role: .destructive) {
                            showsDeleteConfirmation = true
                        }
                        .frame(maxWidth: .infinity)
                    }
                    if let existing, existing.source == .statement {
                        Section("Kaynak") {
                            Text(existing.importBatchID == nil
                                 ? "İçe aktarıldı"
                                 : "İçe aktarıldı · satır \(existing.statementLineNumber ?? 0)")
                                .font(.sd.meta)
                                .foregroundStyle(Color.text.muted)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "İşlemi düzenle" : "Yeni işlem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Kaydet" : "Ekle") {
                        Task { await save() }
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .confirmationDialog("İşlemi sil", isPresented: $showsDeleteConfirmation,
                                titleVisibility: .visible) {
                Button("Sil", role: .destructive) { Task { await delete() } }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                Text("Bu işlem kalıcı olarak silinecek.")
            }
            .task { await loadReferences() }
        }
    }

    private var categoryOptions: [CategoryEntity] {
        direction == .income ? categories.incomeCategories : categories.expenseCategories
    }

    private func loadReferences() async {
        try? await TransactionService(
            transactions: environment.transactions,
            accounts: environment.accounts,
            categories: environment.categories).seedDefaultAccountIfNeeded()
        categories = CategoryLookup(
            (try? await environment.categories.all(includeArchived: false)) ?? [])
        accounts = AccountLookup(
            (try? await environment.accounts.all(includeArchived: false)) ?? [])
        if accountID == nil { accountID = accounts.ordered.first?.id }
    }

    private func save() async {
        guard let parsedAmount, let accountID else { return }
        let entity = TransactionEntity(
            id: existing?.id ?? UUID(),
            date: date,
            amount: parsedAmount,
            direction: direction,
            detail: detail.trimmingCharacters(in: .whitespaces),
            categoryID: categoryID,
            accountID: accountID,
            counterpartAccountID: existing?.counterpartAccountID,
            note: note.isEmpty ? nil : note,
            tags: existing?.tags ?? [],
            source: existing?.source ?? .manual,
            importBatchID: existing?.importBatchID,
            statementLineNumber: existing?.statementLineNumber,
            categoryConfidence: nil,
            needsReview: false,
            createdAt: existing?.createdAt ?? Date())
        try? await environment.transactions.save(entity)
        onSaved()
        dismiss()
    }

    private func delete() async {
        guard let existing else { return }
        try? await environment.transactions.delete(id: existing.id)
        onSaved()
        dismiss()
    }

    /// "1.234,56" ve "1234,56" kabul edilir; nokta binlik ayracıdır, virgül ondalık.
    static func parseAmount(_ text: String) -> Money? {
        let cleaned = text
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: "₺", with: "")
            .replacingOccurrences(of: ".", with: "")
        let parts = cleaned.split(separator: ",", omittingEmptySubsequences: false)
        guard !cleaned.isEmpty, parts.count <= 2,
              let whole = Int(parts.first ?? "0") ?? (parts.first?.isEmpty == true ? 0 : nil)
        else { return nil }

        var kurus = 0
        if parts.count == 2 {
            let fraction = parts[1].prefix(2)
            let padded = fraction.count == 1 ? "\(fraction)0" : String(fraction)
            guard fraction.allSatisfy(\.isNumber), let value = Int(padded) else { return nil }
            kurus = value
        }
        return Money(minorUnits: whole * 100 + kurus)
    }
}
