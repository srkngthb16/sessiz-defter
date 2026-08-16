import Core
import DesignSystem
import Domain
import SwiftUI

public struct TransactionsView: View {
    @State private var model: TransactionsModel
    @State private var isFilterPresented = false
    @State private var editing: TransactionEntity?
    @State private var pendingDeletion: TransactionEntity?

    let environment: AppEnvironment
    let reloadToken: Int

    public init(environment: AppEnvironment, reloadToken: Int = 0) {
        self.environment = environment
        self.reloadToken = reloadToken
        _model = State(initialValue: TransactionsModel(environment: environment))
    }

    public var body: some View {
        NavigationStack {
            Group {
                if model.isLoading {
                    loadingSkeleton
                } else if model.groups.isEmpty {
                    emptyResults
                } else {
                    list
                }
            }
            .background(Color.bg.canvas)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: RootTabView.composerClearance)
            }
            .navigationTitle("İşlemler")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isFilterPresented = true
                    } label: {
                        Label("Filtrele", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .searchable(text: $model.searchText,
                        prompt: "İşlem, hesap veya tutar ara")
            .task(id: reloadToken) { await model.load() }
            .task(id: model.searchText) { await model.load() }
            .task(id: model.query) { await model.load() }
            .sheet(isPresented: $isFilterPresented) {
                FilterSheet(model: model)
            }
            .sheet(item: $editing) { transaction in
                TransactionEditorView(environment: environment, editing: transaction) {
                    Task { await model.load() }
                }
            }
            .confirmationDialog(
                "İşlemi sil",
                isPresented: Binding(get: { pendingDeletion != nil },
                                     set: { if !$0 { pendingDeletion = nil } }),
                titleVisibility: .visible
            ) {
                Button("Sil", role: .destructive) {
                    // Tam kaydırma silmez, onay ister: geri alınamaz eylem tek dokunuşla olmamalı.
                    if let target = pendingDeletion {
                        Task { await model.delete(target) }
                    }
                    pendingDeletion = nil
                }
                Button("Vazgeç", role: .cancel) { pendingDeletion = nil }
            } message: {
                Text(pendingDeletion.map { "\($0.detail) kalıcı olarak silinecek." } ?? "")
            }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                header
                ForEach(model.groups) { group in
                    Section {
                        ForEach(group.transactions) { transaction in
                            row(transaction)
                                // Sona yaklaşınca sonraki sayfa: liste 200'er
                                // satır yükleniyor, hepsini birden okumak
                                // 10.000 kayıtta kaydırmayı takıyordu.
                                .onAppear {
                                    guard transaction.id == model.lastLoadedTransactionID
                                    else { return }
                                    Task { await model.loadMore() }
                                }
                            Divider().overlay(Color.border.divider)
                        }
                    } header: {
                        dayHeader(group)
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("\(model.totalCount) kayıt")
                .font(.sd.meta)
                .foregroundStyle(Color.text.muted)
            if !model.chips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.s) {
                        ForEach(model.chips) { chip in
                            Button {
                                model.removeChip(chip)
                            } label: {
                                HStack(spacing: Spacing.xs) {
                                    Text(chip.title)
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .font(.sd.meta)
                                .foregroundStyle(Color.text.primary)
                                .padding(.horizontal, Spacing.m)
                                .frame(minHeight: 32)
                                .background(Color.bg.subtle,
                                            in: Capsule())
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dayHeader(_ group: TransactionDayGroup) -> some View {
        HStack {
            Text(Fmt.dayHeader(group.date, calendar: environment.calendar))
                .font(.sd.caption)
                .foregroundStyle(Color.text.muted)
            Spacer(minLength: Spacing.s)
            Text(signedTotal(group))
                .font(.sd.amountRow)
                .foregroundStyle(Color.text.secondary)
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
        .background(Color.bg.canvas)
        // Gün başlığı listede gezinme durağı: tarih ile gün toplamı ayrı okununca
        // "12 Ağustos 2026 · Çarşamba" ile "−487,25 ₺" ilişkisiz duyuluyordu.
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel("\(Fmt.dayHeader(group.date, calendar: environment.calendar)), "
                            + "gün toplamı "
                            + Fmt.spoken(group.total,
                                         sign: group.total.isNegative ? .expense : .income))
    }

    private func signedTotal(_ group: TransactionDayGroup) -> String {
        let total = group.total
        let sign = total.isNegative ? "\u{2212}" : "+"
        return "\(sign)\(Fmt.amount(total)) ₺"
    }

    private func row(_ transaction: TransactionEntity) -> some View {
        TransactionRow(model: transaction.rowModel(
            categories: model.categories, accounts: model.accounts))
            .contentShape(Rectangle())
            .onTapGesture { editing = transaction }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    pendingDeletion = transaction
                } label: {
                    Label("Sil", systemImage: "trash")
                }
                Button {
                    editing = transaction
                } label: {
                    Label("Kategori", systemImage: "tag")
                }
                .tint(Color.brand.primary)
            }
            .contextMenu {
                Button("Kategori değiştir", systemImage: "tag") { editing = transaction }
                Button("Düzenle", systemImage: "pencil") { editing = transaction }
                Button("Sil", systemImage: "trash", role: .destructive) {
                    pendingDeletion = transaction
                }
            }
    }

    private var loadingSkeleton: some View {
        VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { _ in
                TransactionRowSkeleton()
                Divider().overlay(Color.border.divider)
            }
        }
    }

    /// D6 — filtre sonucu boş.
    private var emptyResults: some View {
        ScrollView {
            if model.hasActiveFilters {
                EmptyState(
                    kind: .noResults,
                    title: "Bu filtreyle eşleşen işlem yok",
                    message: "Aramanızı ve seçtiğiniz filtreleri birlikte denediniz. Filtrelerden birini kaldırmayı deneyin."
                ) {
                    PrimaryButton("Filtreleri temizle") { model.clearFilters() }
                }
            } else {
                EmptyState(
                    kind: .firstRun,
                    title: "Henüz işlem yok",
                    message: "Manuel işlem ekleyerek ya da PDF ekstre yükleyerek başlayabilirsiniz.",
                    footnote: "Veriler yalnızca bu telefonda saklanır"
                ) { EmptyView() }
            }
        }
    }
}
