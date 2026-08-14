import Core
import DesignSystem
import Domain
import SwiftUI

/// E2 — bütçe ekle / düzenle.
public struct BudgetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: BudgetEditorModel
    let onSaved: () -> Void

    public init(environment: AppEnvironment, editing existing: BudgetEntity? = nil,
                onSaved: @escaping () -> Void = {}) {
        self.onSaved = onSaved
        _model = State(initialValue: BudgetEditorModel(environment: environment,
                                                       editing: existing))
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Aylık limit") {
                    HStack {
                        TextField("0,00", text: $model.limitText)
                            .keyboardType(.decimalPad)
                            .font(.sd.amountRow)
                            .multilineTextAlignment(.trailing)
                        Text("₺").foregroundStyle(Color.text.muted)
                    }
                    if !model.suggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.s) {
                                ForEach(model.suggestions, id: \.minorUnits) { amount in
                                    Button(Fmt.amount(amount)) {
                                        model.limitText = Fmt.amount(amount)
                                        Task { await model.refreshHint() }
                                    }
                                    .font(.sd.meta)
                                    .padding(.horizontal, Spacing.m)
                                    .frame(minHeight: 32)
                                    .background(Color.bg.subtle, in: Capsule())
                                }
                            }
                        }
                    }
                }

                Section {
                    Picker("Kategori", selection: $model.categoryID) {
                        ForEach(model.categories.expenseCategories) { category in
                            Text(category.name).tag(UUID?.some(category.id))
                        }
                    }
                    .onChange(of: model.categoryID) { Task { await model.refreshHint() } }
                    LabeledContent("Dönem", value: "Aylık")
                }

                Section {
                    Toggle("%80'de uyar", isOn: $model.warnsAtEightyPercent)
                    Toggle("Devreden bakiye", isOn: $model.rollsOver)
                } footer: {
                    Text("Artan tutar sonraki aya eklenir. Uyarı cihazda üretilir, ağ kullanmaz.")
                }

                if let hint = model.averageHint {
                    Section {
                        Text(hint)
                            .font(.sd.meta)
                            .foregroundStyle(Color.text.secondary)
                    }
                }
            }
            .navigationTitle(model.existing == nil ? "Bütçe ekle" : "Bütçeyi düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kaydet") {
                        Task {
                            await model.save()
                            onSaved()
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!model.canSave)
                }
            }
            .task { await model.load() }
        }
    }
}
