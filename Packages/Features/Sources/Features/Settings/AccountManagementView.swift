import Core
import DesignSystem
import Domain
import SwiftUI

/// Hesap listesi. Silme yalnızca üzerinde işlem yoksa mümkün; arşivleme her zaman
/// açık — geçmiş işlemlerin hesabı boşa düşmemeli.
public struct AccountManagementView: View {
    let environment: AppEnvironment

    @State private var accounts: [AccountEntity] = []
    @State private var transactionCounts: [UUID: Int] = [:]
    @State private var editing: AccountEntity?
    @State private var isCreating = false
    @State private var blockedDeletion: AccountEntity?

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public var body: some View {
        List {
            Section("Etkin") { rows(archived: false) }
            Section("Arşivli") { rows(archived: true) }
            Section {
                Text("Arşivlenen hesap yeni işlem seçiminde görünmez ama geçmiş işlemleri korunur. Silme yalnızca üzerinde hiç işlem olmayan hesaplar için mümkündür.")
                    .font(.sd.meta)
                    .foregroundStyle(Color.text.muted)
            }
        }
        .navigationTitle("Hesaplar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Ekle") { isCreating = true }
            }
        }
        .task { await load() }
        .sheet(isPresented: $isCreating) {
            AccountEditorView(environment: environment) { Task { await load() } }
        }
        .sheet(item: $editing) { account in
            AccountEditorView(environment: environment, editing: account) {
                Task { await load() }
            }
        }
        .alert("Hesap silinemiyor",
               isPresented: Binding(get: { blockedDeletion != nil },
                                    set: { if !$0 { blockedDeletion = nil } })) {
            Button("Anladım", role: .cancel) { blockedDeletion = nil }
        } message: {
            if let blockedDeletion {
                let count = transactionCounts[blockedDeletion.id] ?? 0
                Text("\(blockedDeletion.displayName) üzerinde \(count) işlem var. Önce bu işlemleri başka bir hesaba taşıyın ya da silin. Hesabı kullanım dışı bırakmak için arşivleyebilirsiniz.")
            }
        }
    }

    @ViewBuilder
    private func rows(archived: Bool) -> some View {
        let filtered = accounts.filter { $0.isArchived == archived }
        if filtered.isEmpty {
            Text(archived ? "Arşivli hesap yok" : "Hesap yok")
                .font(.sd.meta)
                .foregroundStyle(Color.text.muted)
        }
        ForEach(filtered) { account in
            Button {
                editing = account
            } label: {
                HStack(spacing: Spacing.s) {
                    Image(systemName: account.kind.symbolName)
                        .foregroundStyle(Color.brand.primary)
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(account.displayName)
                            .foregroundStyle(Color.text.primary)
                        Text("\(account.kind.title) · \(transactionCounts[account.id] ?? 0) işlem")
                            .font(.sd.meta)
                            .foregroundStyle(Color.text.muted)
                    }
                    Spacer()
                }
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    Task { await delete(account) }
                } label: {
                    Label("Sil", systemImage: "trash")
                }
                Button(account.isArchived ? "Geri al" : "Arşivle") {
                    Task { await toggleArchive(account) }
                }
                .tint(Color.finance.warning)
            }
        }
    }

    private func load() async {
        accounts = ((try? await environment.accounts.all(includeArchived: true)) ?? [])
            .sorted { $0.sortIndex < $1.sortIndex }
        var counts: [UUID: Int] = [:]
        for account in accounts {
            counts[account.id] = (try? await environment.transactions.count(
                matching: TransactionQuery(accountIDs: [account.id]))) ?? 0
        }
        transactionCounts = counts
    }

    private func toggleArchive(_ account: AccountEntity) async {
        var updated = account
        updated.isArchived.toggle()
        try? await environment.accounts.save(updated)
        await load()
    }

    private func delete(_ account: AccountEntity) async {
        let count = (try? await environment.transactions.count(
            matching: TransactionQuery(accountIDs: [account.id]))) ?? 0
        guard count == 0 else {
            blockedDeletion = account
            return
        }
        try? await environment.accounts.delete(id: account.id)
        await load()
    }
}

struct AccountEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let environment: AppEnvironment
    let existing: AccountEntity?
    let onSaved: () -> Void

    @State private var name: String
    @State private var kind: AccountKind
    @State private var lastFour: String
    @State private var openingBalanceText: String

    init(environment: AppEnvironment, editing existing: AccountEntity? = nil,
         onSaved: @escaping () -> Void = {}) {
        self.environment = environment
        self.existing = existing
        self.onSaved = onSaved
        _name = State(initialValue: existing?.name ?? "")
        _kind = State(initialValue: existing?.kind ?? .checking)
        // Maske "••3412" biçiminde saklanıyor; alana yalnızca rakamlar girilir.
        _lastFour = State(initialValue: existing?.maskedNumber?.filter(\.isNumber) ?? "")
        _openingBalanceText = State(initialValue: existing.map {
            $0.openingBalance.minorUnits == 0 ? "" : Fmt.amount($0.openingBalance)
        } ?? "")
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    /// Son 4 hane ya boş ya tam dört rakam; yarım maske hesabı ayırt etmiyor.
    private var canSave: Bool {
        !trimmedName.isEmpty && (lastFour.isEmpty || lastFour.count == 4)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Hesap adı") {
                    TextField("Örn. Ziraat", text: $name)
                }
                Section("Tür") {
                    Picker("Tür", selection: $kind) {
                        ForEach(AccountKind.allCases, id: \.self) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    TextField("3412", text: $lastFour)
                        .keyboardType(.numberPad)
                        .onChange(of: lastFour) { _, value in
                            lastFour = String(value.filter(\.isNumber).prefix(4))
                        }
                } header: {
                    Text("Son 4 hane")
                } footer: {
                    Text("Yalnızca listede hesabı ayırt etmek için. Tam kart ya da IBAN numarası saklanmaz.")
                }
                Section {
                    HStack {
                        TextField("0,00", text: $openingBalanceText)
                            .keyboardType(.decimalPad)
                            .font(.sd.amountRow)
                            .multilineTextAlignment(.trailing)
                        Text("₺").foregroundStyle(Color.text.muted)
                    }
                } header: {
                    Text("Açılış bakiyesi")
                } footer: {
                    Text("Defteri kurduğunuz andaki bakiye. Sonraki işlemler bunun üzerine eklenir.")
                }
            }
            .navigationTitle(existing == nil ? "Hesap ekle" : "Hesabı düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kaydet") { Task { await save() } }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() async {
        let entity = AccountEntity(
            id: existing?.id ?? UUID(),
            name: trimmedName,
            kind: kind,
            openingBalance: TransactionEditorView.parseAmount(openingBalanceText) ?? .zero,
            maskedNumber: lastFour.count == 4 ? "••\(lastFour)" : nil,
            isArchived: existing?.isArchived ?? false,
            sortIndex: existing?.sortIndex ?? 100,
            createdAt: existing?.createdAt ?? Date())
        try? await environment.accounts.save(entity)
        onSaved()
        dismiss()
    }
}

extension AccountKind {
    public var title: String {
        switch self {
        case .cash: "Nakit"
        case .checking: "Vadesiz"
        case .creditCard: "Kredi kartı"
        }
    }

    public var symbolName: String {
        switch self {
        case .cash: "banknote"
        case .checking: "building.columns"
        case .creditCard: "creditcard"
        }
    }
}

extension AccountEntity: @retroactive Identifiable {}
