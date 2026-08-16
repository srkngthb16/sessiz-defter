import Core
import DesignSystem
import Domain
import SwiftUI

/// Kategori yönetimi. Silme yerine arşivleme: geçmiş işlemlerin kategorisi
/// boşa düşmemeli.
public struct CategoryManagementView: View {
    let environment: AppEnvironment

    @State private var categories: [CategoryEntity] = []
    @State private var editing: CategoryEntity?
    @State private var isCreating = false

    public var body: some View {
        List {
            Section("Gider") { rows(for: .expense) }
            Section("Gelir") { rows(for: .income) }
        }
        .navigationTitle("Kategoriler")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Ekle") { isCreating = true }
            }
        }
        .task { await load() }
        .sheet(isPresented: $isCreating) {
            CategoryEditorView(environment: environment) { Task { await load() } }
        }
        .sheet(item: $editing) { category in
            CategoryEditorView(environment: environment, editing: category) {
                Task { await load() }
            }
        }
    }

    @ViewBuilder
    private func rows(for direction: TransactionDirection) -> some View {
        ForEach(categories.filter { $0.direction == direction }) { category in
            Button {
                editing = category
            } label: {
                HStack(spacing: Spacing.s) {
                    CategoryBadge(symbolName: category.symbolName,
                                  colorIndex: category.colorIndex, size: 28)
                    Text(category.name)
                        .foregroundStyle(Color.text.primary)
                    if category.isArchived {
                        Text("arşivli")
                            .font(.sd.caption)
                            .foregroundStyle(Color.text.muted)
                    }
                    Spacer()
                }
            }
            .swipeActions(edge: .trailing) {
                Button(category.isArchived ? "Geri al" : "Arşivle") {
                    Task { await toggleArchive(category) }
                }
                .tint(Color.finance.warning)
            }
        }
    }

    private func load() async {
        categories = ((try? await environment.categories.all(includeArchived: true)) ?? [])
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    private func toggleArchive(_ category: CategoryEntity) async {
        var updated = category
        updated.isArchived.toggle()
        try? await environment.categories.save(updated)
        await load()
    }
}

struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let environment: AppEnvironment
    let existing: CategoryEntity?
    let onSaved: () -> Void

    @State private var name: String
    @State private var colorIndex: Int
    @State private var symbolName: String
    @State private var direction: TransactionDirection

    init(environment: AppEnvironment, editing existing: CategoryEntity? = nil,
         onSaved: @escaping () -> Void = {}) {
        self.environment = environment
        self.existing = existing
        self.onSaved = onSaved
        _name = State(initialValue: existing?.name ?? "")
        _colorIndex = State(initialValue: existing?.colorIndex ?? 0)
        _symbolName = State(initialValue: existing?.symbolName
                            ?? DefaultCategories.fallbackSymbol)
        _direction = State(initialValue: existing?.direction ?? .expense)
    }

    /// Liste Domain'den gelir: varsayılan kategorilerin simgeleri burada elle
    /// tekrarlanınca eşleme değiştiğinde seçici geride kalıyordu.
    private static let symbolChoices = DefaultCategories.symbolChoices()

    var body: some View {
        NavigationStack {
            Form {
                Section("Ad") {
                    TextField("Kategori adı", text: $name)
                }
                Section("Yön") {
                    Picker("Yön", selection: $direction) {
                        Text("Gider").tag(TransactionDirection.expense)
                        Text("Gelir").tag(TransactionDirection.income)
                    }
                    .pickerStyle(.segmented)
                }
                Section("Renk") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6),
                              spacing: Spacing.s) {
                        ForEach(0..<CategoryEntity.colorSlotCount, id: \.self) { index in
                            Button {
                                colorIndex = index
                            } label: {
                                Circle()
                                    .fill(Color.category.all[index])
                                    .frame(height: 32)
                                    .overlay {
                                        if colorIndex == index {
                                            Circle().strokeBorder(Color.text.primary,
                                                                  lineWidth: 2)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, Spacing.xs)
                }
                Section("Simge") {
                    Picker("Simge", selection: $symbolName) {
                        ForEach(Self.symbolChoices, id: \.self) { symbol in
                            Label(symbol, systemImage: symbol).tag(symbol)
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "Kategori ekle" : "Kategoriyi düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kaydet") {
                        Task {
                            let entity = CategoryEntity(
                                id: existing?.id ?? UUID(),
                                name: name.trimmingCharacters(in: .whitespaces),
                                colorIndex: colorIndex, symbolName: symbolName,
                                direction: direction,
                                isArchived: existing?.isArchived ?? false,
                                sortIndex: existing?.sortIndex ?? 100)
                            try? await environment.categories.save(entity)
                            onSaved()
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

extension CategoryEntity: @retroactive Identifiable {}
