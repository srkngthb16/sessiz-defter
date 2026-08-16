import Core
import DesignSystem
import Domain
import ImportPipeline
import SwiftUI
import UniformTypeIdentifiers

public struct ImportFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: ImportModel
    @State private var isFilePickerPresented = false
    @State private var selection: Set<UUID> = []
    @State private var isBulkCategoryPresented = false

    let environment: AppEnvironment
    var onFinished: () -> Void

    public init(environment: AppEnvironment, onFinished: @escaping () -> Void = {}) {
        self.environment = environment
        self.onFinished = onFinished
        _model = State(initialValue: ImportModel(environment: environment))
    }

    public var body: some View {
        NavigationStack {
            content
                .background(Color.bg.canvas)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
                .task { await model.loadAccounts() }
                .fileImporter(isPresented: $isFilePickerPresented,
                              allowedContentTypes: [.pdf]) { result in
                    guard case .success(let url) = result else { return }
                    Task { await startImport(url) }
                }
                .sheet(isPresented: $isBulkCategoryPresented) {
                    BulkCategorySheet(model: model, selection: selection) {
                        selection.removeAll()
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.step {
        case .picking: pickingStep
        case .processing(let stage): ProcessingStep(stage: stage)
        case .review: reviewStep
        case .summary(let summary): summaryStep(summary)
        case .passwordRequired(let attemptsLeft):
            PasswordStep(model: model, attemptsLeft: attemptsLeft)
        case .unknownFormat(let preview):
            ColumnMappingStep(model: model, preview: preview)
        case .scannedDocument: ScannedStep(model: model)
        case .failed(let message): failureStep(message)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(cancelTitle) {
                model.cancel()
                dismiss()
            }
        }
        ToolbarItem(placement: .principal) {
            Text(title).font(.sd.titleSection).foregroundStyle(Color.text.primary)
        }
    }

    private var title: String {
        switch model.step {
        case .picking: "Ekstre yükle"
        case .processing: "Ayrıştırılıyor"
        case .review: "İşlemleri onayla"
        case .summary: "Sonuç"
        case .passwordRequired: "PDF parola korumalı"
        case .unknownFormat: "Format tanınmadı"
        case .scannedDocument: "Metin bulunamadı"
        case .failed: "Hata"
        }
    }

    private var cancelTitle: String {
        if case .summary = model.step { return "Kapat" }
        return "İptal"
    }

    // MARK: C1

    private var pickingStep: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                if model.accounts.count > 1 {
                    Card {
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            Text("Hangi hesaba aktarılacak?")
                                .font(.sd.titleSection)
                                .foregroundStyle(Color.text.primary)
                            Text("Ekstredeki işlemler seçtiğiniz hesaba yazılır.")
                                .font(.sd.meta)
                                .foregroundStyle(Color.text.muted)
                            Picker("Hesap", selection: $model.selectedAccountID) {
                                Text("Seçiniz").tag(UUID?.none)
                                ForEach(model.accounts) { account in
                                    Text(account.displayName).tag(UUID?.some(account.id))
                                }
                            }
                            .pickerStyle(.inline)
                            .labelsHidden()
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        PrimaryButton("Dosyalar'dan PDF seç", systemImage: "doc.badge.plus") {
                            isFilePickerPresented = true
                        }
                        .disabled(!model.canPickFile)
                        .opacity(model.canPickFile ? 1 : 0.5)
                        if !model.canPickFile {
                            Text("Önce hedef hesabı seçin.")
                                .font(.sd.meta)
                                .foregroundStyle(Color.finance.warning)
                        }
                        Text("Ekstre kopyası uygulama kasasına alınır, işlem bitince silinir.")
                            .font(.sd.meta)
                            .foregroundStyle(Color.text.muted)
                    }
                }
                Card {
                    HStack(alignment: .top, spacing: Spacing.s) {
                        Image(systemName: "checkmark.seal")
                            .foregroundStyle(Color.brand.primary)
                        Text("Bu işlem sırasında hiçbir ağ isteği yapılmaz. Uçak modunda da çalışır.")
                            .font(.sd.meta)
                            .foregroundStyle(Color.text.secondary)
                    }
                }
            }
            .padding(Spacing.l)
        }
    }

    // MARK: C3

    private var reviewStep: some View {
        Group {
            if let draft = model.draft {
                VStack(spacing: 0) {
                    ReviewCounters(draft: draft)

                    if let report = model.report {
                        Card {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(report.summaryLine)
                                    .font(.sd.meta)
                                    .foregroundStyle(Color.text.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                ForEach(ParseReport.SkipReason.allCases, id: \.rawValue) { reason in
                                    if let count = report.skippedRows[reason], count > 0 {
                                        Text("\(count) satır · \(reason.rawValue)")
                                            .font(.sd.caption)
                                            .foregroundStyle(Color.text.muted)
                                    }
                                }
                                if report.looksWrong {
                                    // Aday satırların yarısından çoğu okunamadı:
                                    // sessizce eksik içe aktarmaktansa uyarmak gerek.
                                    Text("Satırların çoğu okunamadı. Ekstre yanlış tanınmış olabilir — iptal edip sütunları elle eşleyebilirsiniz.")
                                        .font(.sd.meta)
                                        .foregroundStyle(Color.finance.warning)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    List {
                        section("Kontrol gerekiyor", kind: .needsReview, draft: draft)
                        section("Otomatik kategorilendi", kind: .automatic, draft: draft)
                        section("Mükerrer · varsayılan olarak eklenmez",
                                kind: .duplicate, draft: draft)
                    }
                    .listStyle(.insetGrouped)
                    reviewFooter(draft)
                }
            } else {
                ProgressView()
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, kind: ImportDraftRow.Kind,
                         draft: ImportDraft) -> some View {
        let rows = draft.rows.filter { $0.kind == kind }
        if !rows.isEmpty {
            Section("\(title) · \(rows.count)") {
                ForEach(rows) { row in
                    ImportRowView(row: row,
                                  categoryName: model.categories.name(row.categoryID),
                                  isChecked: row.isSelected,
                                  isSelectedForBulk: selection.contains(row.id))
                        .contentShape(Rectangle())
                        .onTapGesture { model.toggle(row.id) }
                        .onLongPressGesture {
                            if selection.contains(row.id) {
                                selection.remove(row.id)
                            } else {
                                selection.insert(row.id)
                            }
                        }
                }
            }
        }
    }

    private func reviewFooter(_ draft: ImportDraft) -> some View {
        VStack(spacing: Spacing.s) {
            HStack {
                Text("\(draft.selectedCount) işlem seçili")
                    .font(.sd.meta)
                    .foregroundStyle(Color.text.secondary)
                Spacer()
                if !selection.isEmpty {
                    Button("Toplu kategori") { isBulkCategoryPresented = true }
                        .font(.sd.meta)
                        .foregroundStyle(Color.brand.primary)
                }
            }
            PrimaryButton("Ekle") { Task { await model.confirm() } }
        }
        .padding(Spacing.l)
        .background(Color.bg.surface)
    }

    // MARK: C5

    private func summaryStep(_ summary: ImportModel.ImportSummary) -> some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                Card {
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        HStack(spacing: Spacing.s) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.finance.income)
                            Text("\(summary.addedCount) işlem eklendi")
                                .font(.sd.titleSection)
                                .foregroundStyle(Color.text.primary)
                        }
                        Text(summary.fileName)
                            .font(.sd.meta)
                            .foregroundStyle(Color.text.muted)
                        counter("Eklenen", "\(summary.addedCount)")
                        counter("Atlanan (mükerrer)", "\(summary.skippedDuplicateCount)")
                        counter("Elle düzeltilen kategori", "\(summary.recategorizedCount)")
                        HStack {
                            Text("Yeni net etki")
                                .font(.sd.meta)
                                .foregroundStyle(Color.text.secondary)
                            Spacer()
                            AmountText(amount: summary.netEffect.magnitude,
                                       direction: summary.netEffect.isNegative
                                           ? .expense : .income,
                                       style: .summary)
                        }
                    }
                }
                PrimaryButton("Özete dön") {
                    onFinished()
                    dismiss()
                }
            }
            .padding(Spacing.l)
        }
    }

    private func counter(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.sd.meta).foregroundStyle(Color.text.secondary)
            Spacer()
            Text(value).font(.sd.amountRow).foregroundStyle(Color.text.primary)
        }
    }

    private func failureStep(_ message: String) -> some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Color.finance.critical)
            Text(message)
                .font(.sd.meta)
                .foregroundStyle(Color.text.secondary)
                .multilineTextAlignment(.center)
            SecondaryButton("Baştan dene") { model.cancel() }
        }
        .padding(Spacing.xl)
    }

    private func startImport(_ url: URL) async {
        // Güvenlik kapsamı: seçilen dosya sandbox dışında; kopya kasaya alınır.
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        do {
            let vault = try ImportVault.copyIntoVault(url)
            await model.start(url: vault)
        } catch {
            await model.start(url: url)
        }
    }
}

/// Seçilen PDF uygulama kasasına kopyalanır ve FileProtection.complete ile yazılır.
enum ImportVault {
    static func directory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
            .appendingPathComponent("SessizDefter/Import", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true,
                                                attributes: [.protectionKey: FileProtectionType.complete])
        return base
    }

    static func copyIntoVault(_ url: URL) throws -> URL {
        let target = try directory().appendingPathComponent(url.lastPathComponent)
        if FileManager.default.fileExists(atPath: target.path) {
            try FileManager.default.removeItem(at: target)
        }
        try FileManager.default.copyItem(at: url, to: target)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete], ofItemAtPath: target.path)
        return target
    }
}
