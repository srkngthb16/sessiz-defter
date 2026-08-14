import Core
import DesignSystem
import Domain
import ImportPipeline
import SwiftUI

/// C2 — cihaz üzerinde işleniyor.
struct ProcessingStep: View {
    let stage: ImportPipeline.Stage

    var body: some View {
        VStack(spacing: Spacing.l) {
            Card {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    ForEach(ImportPipeline.Stage.allCases, id: \.rawValue) { item in
                        HStack(spacing: Spacing.s) {
                            Image(systemName: icon(for: item))
                                .foregroundStyle(tint(for: item))
                                .frame(width: 20)
                            Text(item.title)
                                .font(.sd.bodyItem)
                                .foregroundStyle(item.rawValue <= stage.rawValue
                                                 ? Color.text.primary : Color.text.muted)
                            Spacer()
                        }
                    }
                }
            }
            Card {
                HStack(alignment: .top, spacing: Spacing.s) {
                    Image(systemName: "iphone").foregroundStyle(Color.brand.primary)
                    Text("Her şey bu cihazda. Ağ göstergesi yanmaz; işlem uygulama açıkken çalışır, arka planda devam etmez.")
                        .font(.sd.meta)
                        .foregroundStyle(Color.text.secondary)
                }
            }
            Spacer()
        }
        .padding(Spacing.l)
    }

    private func icon(for item: ImportPipeline.Stage) -> String {
        if item.rawValue < stage.rawValue { return "checkmark.circle.fill" }
        if item.rawValue == stage.rawValue { return "circle.dotted" }
        return "circle"
    }

    private func tint(for item: ImportPipeline.Stage) -> Color {
        item.rawValue < stage.rawValue ? .finance.income
            : item.rawValue == stage.rawValue ? .brand.primary : .text.disabled
    }
}

/// C6 — parola korumalı PDF. Parola hiçbir yere kaydedilmez.
struct PasswordStep: View {
    let model: ImportModel
    let attemptsLeft: Int
    @State private var password = ""

    var body: some View {
        VStack(spacing: Spacing.l) {
            Card {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    Text("Parola yalnızca dosyayı açmak için kullanılır, hiçbir yere kaydedilmez.")
                        .font(.sd.meta)
                        .foregroundStyle(Color.text.secondary)
                    SecureField("Parola", text: $password)
                        .textFieldStyle(.roundedBorder)
                    if attemptsLeft < 2 {
                        Text("Parola hatalı · \(attemptsLeft) deneme daha")
                            .font(.sd.meta)
                            .foregroundStyle(Color.finance.critical)
                    }
                    PrimaryButton("Aç") {
                        model.password = password
                        Task { await model.retryWithPassword() }
                    }
                }
            }
            Spacer()
        }
        .padding(Spacing.l)
    }
}

/// C8 — taranmış PDF. OCR cihazda çalışır, doğruluk düşebilir.
struct ScannedStep: View {
    let model: ImportModel

    var body: some View {
        VStack(spacing: Spacing.l) {
            Card {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    Text("Bu PDF taranmış görüntü")
                        .font(.sd.titleSection)
                        .foregroundStyle(Color.text.primary)
                    Text("Dosyada seçilebilir metin yok. Cihaz üzerinde OCR ile okunabilir; bu işlem yaklaşık 20 saniye sürer ve bataryayı biraz daha kullanır.")
                        .font(.sd.meta)
                        .foregroundStyle(Color.text.secondary)
                    bullet("checkmark.seal", "Vision framework · görüntü dışarı çıkmaz",
                           Color.brand.primary)
                    bullet("exclamationmark.triangle",
                           "Doğruluk düşebilir: tüm satırlar “kontrol gerekiyor” işaretiyle gelir",
                           Color.finance.warning)
                    PrimaryButton("OCR ile oku") { Task { await model.retryWithOCR() } }
                    SecondaryButton("Vazgeç ve dosyayı sil") { model.cancel() }
                }
            }
            Spacer()
        }
        .padding(Spacing.l)
    }

    private func bullet(_ symbol: String, _ text: String, _ tint: Color) -> some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Image(systemName: symbol).foregroundStyle(tint)
            Text(text).font(.sd.meta).foregroundStyle(Color.text.secondary)
        }
    }
}

/// C7 — tanınmayan format. Sütunlar bir kez eşlenir, şablon cihazda saklanır.
struct ColumnMappingStep: View {
    let model: ImportModel
    let preview: [String]
    @State private var roles: [ColumnRole] = [.date, .detail, .amount, .balance]
    @State private var separator = "Boşluk"

    private static let separators = ["Boşluk", "|", ";", ","]

    var body: some View {
        Form {
            Section("Ham satır önizlemesi") {
                ForEach(preview, id: \.self) { line in
                    Text(line)
                        .font(.custom(TypeFace.data, size: 12, relativeTo: .footnote))
                        .foregroundStyle(Color.text.secondary)
                }
            }
            Section("Sütun ayracı") {
                Picker("Ayraç", selection: $separator) {
                    ForEach(Self.separators, id: \.self) { Text($0) }
                }
                .pickerStyle(.segmented)
            }
            Section("Sütun eşleme") {
                ForEach(roles.indices, id: \.self) { index in
                    Picker("\(index + 1). sütun", selection: $roles[index]) {
                        ForEach(ColumnRole.allCases, id: \.rawValue) { role in
                            Text(Self.title(for: role)).tag(role)
                        }
                    }
                }
                Button("Sütun ekle") { roles.append(.ignored) }
                    .disabled(roles.count >= 8)
            }
            Section {
                Button("Eşlemeyi dene") {
                    Task {
                        await model.retryWithColumns(
                            roles, separator: separator == "Boşluk" ? nil : Character(separator))
                    }
                }
                .fontWeight(.semibold)
            }
        }
    }

    static func title(for role: ColumnRole) -> String {
        switch role {
        case .date: "Tarih"
        case .detail: "Açıklama"
        case .amount: "Tutar"
        case .balance: "Bakiye"
        case .ignored: "Yok say"
        }
    }
}

struct ReviewCounters: View {
    let draft: ImportDraft

    var body: some View {
        HStack(spacing: Spacing.s) {
            counter("otomatik", draft.automaticCount, Color.finance.income)
            counter("kontrol", draft.reviewCount, Color.finance.warning)
            counter("mükerrer", draft.duplicateCount, Color.text.muted)
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
    }

    private func counter(_ title: String, _ value: Int, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.sd.amountRow)
                .foregroundStyle(tint)
            Text(title)
                .font(.sd.caption)
                .foregroundStyle(Color.text.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.s)
        .background(Color.bg.subtle, in: RoundedRectangle(cornerRadius: Radius.control,
                                                          style: .continuous))
    }
}

struct ImportRowView: View {
    let row: ImportDraftRow
    let categoryName: String
    let isChecked: Bool
    let isSelectedForBulk: Bool

    var body: some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                .foregroundStyle(isChecked ? Color.brand.primary : Color.text.disabled)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.detail)
                    .font(.sd.bodyItem)
                    .foregroundStyle(Color.text.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(meta)
                    .font(.sd.meta)
                    .foregroundStyle(row.kind == .needsReview
                                     ? Color.finance.warning : Color.text.secondary)
            }
            Spacer(minLength: Spacing.s)
            if row.amount.minorUnits > 0 {
                AmountText(amount: row.amount, direction: row.direction.style, style: .row)
            }
        }
        .padding(.vertical, 2)
        .listRowBackground(isSelectedForBulk ? Color.brand.surface : Color.bg.surface)
    }

    private var meta: String {
        var parts: [String] = []
        if row.kind == .duplicate {
            parts.append("Zaten kayıtlı")
        } else if row.confidence > 0 {
            parts.append(row.kind == .needsReview
                         ? "\(categoryName)? · güven \(Fmt.percent(row.confidence))"
                         : categoryName)
        } else {
            parts.append("Okunamadı")
        }
        parts.append(Fmt.date(row.date))
        return parts.joined(separator: " · ")
    }
}

/// C4 — toplu kategori atama, isteğe bağlı kural kaydı.
struct BulkCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let model: ImportModel
    let selection: Set<UUID>
    let onApplied: () -> Void

    @State private var categoryID: UUID?
    @State private var savesRule = false

    private var keyword: String {
        guard let row = model.draft?.rows.first(where: { selection.contains($0.id) })
        else { return "" }
        return row.detail.split(separator: " ").first.map(String.init) ?? row.detail
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("\(selection.count) seçili satır") {
                    ForEach(model.categories.expenseCategories
                            + model.categories.incomeCategories) { category in
                        Button {
                            categoryID = category.id
                        } label: {
                            HStack {
                                Text(category.name).foregroundStyle(Color.text.primary)
                                Spacer()
                                if categoryID == category.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.brand.primary)
                                }
                            }
                        }
                    }
                }
                if !keyword.isEmpty {
                    Section {
                        Toggle("Kural olarak kaydet", isOn: $savesRule)
                        if savesRule {
                            Text("“\(keyword)” içeren satırlar bu kategoriye atanır.")
                                .font(.sd.meta)
                                .foregroundStyle(Color.text.muted)
                        }
                    }
                }
            }
            .navigationTitle("Kategori ata")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("\(selection.count) satıra uygula") {
                        guard let categoryID else { return }
                        model.assign(categoryID: categoryID, to: selection)
                        if savesRule {
                            Task { await model.saveRule(keyword: keyword,
                                                        categoryID: categoryID) }
                        }
                        onApplied()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(categoryID == nil)
                }
            }
        }
    }
}
