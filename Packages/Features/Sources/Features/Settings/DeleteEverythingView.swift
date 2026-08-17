import Core
import DesignSystem
import Domain
import SwiftUI

/// F3 — tüm verileri sil. Yıkıcı eylem: yazarak onay ister ve geri alınamaz.
public struct DeleteEverythingView: View {
    @Environment(\.dismiss) private var dismiss
    let environment: AppEnvironment
    let counts: SettingsView.Counts

    @State private var confirmation = ""
    @State private var isDeleting = false
    @State private var isDone = false

    static let requiredWord = "SİL"

    /// Onay metni Türkçe harf katlamasıyla karşılaştırılıyor.
    ///
    /// Klavye "sil" yazınca otomatik büyük harf kuralı cihaza göre "SIL" (noktasız)
    /// ya da "SİL" üretiyor; tam eşleşme arandığında buton hiç açılmıyor ve
    /// kullanıcı doğru sözcüğü yazsa bile veriyi silemiyordu. Katlama sonrası
    /// dördü de "SIL" oluyor.
    static func matchesConfirmation(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).trFoldedUpper
            == requiredWord.trFoldedUpper
    }

    private var canDelete: Bool {
        Self.matchesConfirmation(confirmation) && !isDeleting
    }

    public var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    HStack(spacing: Spacing.s) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.finance.critical)
                        Text("Tüm verileri kalıcı olarak sil")
                            .font(.sd.titleSection)
                            .foregroundStyle(Color.text.primary)
                    }
                    Text("Bulutta kopya yok — bu işlem geri alınamaz. Silmeden önce yedek almanız önerilir.")
                        .font(.sd.meta)
                        .foregroundStyle(Color.text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section("Silinecek") {
                LabeledContent("İşlemler", value: "\(counts.transactions)")
                LabeledContent("Hesaplar", value: "\(counts.accounts)")
                LabeledContent("Bütçeler · kurallar",
                               value: "\(counts.budgets) · \(counts.rules)")
            }

            Section {
                TextField("SİL", text: $confirmation)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
            } header: {
                Text("Onaylamak için \(Self.requiredWord) yazın")
            }

            Section {
                Button(role: .destructive) {
                    Task { await deleteEverything() }
                } label: {
                    Text(isDeleting ? "Siliniyor…" : "Kalıcı olarak sil")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!canDelete)
            }

            if isDone {
                Section {
                    Text("Defter boşaltıldı.")
                        .font(.sd.meta)
                        .foregroundStyle(Color.text.secondary)
                }
            }
        }
        .navigationTitle("Tüm verileri sil")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func deleteEverything() async {
        isDeleting = true
        defer { isDeleting = false }
        try? await environment.transactions.deleteAll()
        for account in (try? await environment.accounts.all(includeArchived: true)) ?? [] {
            try? await environment.accounts.delete(id: account.id)
        }
        for category in (try? await environment.categories.all(includeArchived: true)) ?? [] {
            try? await environment.categories.delete(id: category.id)
        }
        for budget in (try? await environment.budgets.all(includeArchived: true)) ?? [] {
            try? await environment.budgets.delete(id: budget.id)
        }
        for rule in (try? await environment.categoryRules.all()) ?? [] {
            try? await environment.categoryRules.delete(id: rule.id)
        }
        for profile in (try? await environment.parserProfiles?.all()) ?? [] {
            try? await environment.parserProfiles?.delete(id: profile.id)
        }
        // Sayaç da defterin parçası: silinen defterin hataları geri bildirimde
        // görünmeye devam etmemeli.
        environment.diagnostics.reset()
        isDone = true
    }
}
