import Core
import DesignSystem
import SwiftUI

/// F2 — mahremiyet raporu. Uygulamanın hangi izinleri kullandığı ve kullanmadığı.
public struct PrivacyReportView: View {
    let counts: SettingsView.Counts

    public var body: some View {
        List {
            Section {
                Text("Uygulamanın hangi izinleri kullandığı ve kullanmadığı — tek sayfada.")
                    .font(.sd.meta)
                    .foregroundStyle(Color.text.secondary)
            }

            Section("Kullanılmayan") {
                row("Ağ erişimi", "kod tabanında yok", isUsed: false)
                row("Konum", "izin hiç istenmedi", isUsed: false)
                row("Analitik / çökme raporu", "üçüncü taraf SDK yok", isUsed: false)
            }

            Section("Kullanılan") {
                row("Dosyalar (okuma)", "yalnızca seçtiğiniz PDF", isUsed: true)
                row("Face ID", "yalnızca kilit açma", isUsed: true)
                row("Yerel bildirim", "bütçe uyarıları · cihazda üretilir", isUsed: true)
            }

            Section("Yerel depolama") {
                LabeledContent("İşlem", value: "\(counts.transactions)")
                LabeledContent("Hesap", value: "\(counts.accounts)")
                LabeledContent("Bütçe", value: "\(counts.budgets)")
                LabeledContent("Kural · banka şablonu",
                               value: "\(counts.rules) · \(counts.profiles)")
                LabeledContent("Saklanan ekstre kopyası", value: "0")
            }

            Section {
                Text("Son 30 günde gerçekleşen ağ isteği: 0")
                    .font(.sd.meta)
                    .foregroundStyle(Color.text.muted)
            }
        }
        .navigationTitle("Mahremiyet raporu")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ title: String, _ detail: String, isUsed: Bool) -> some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: isUsed ? "checkmark" : "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isUsed ? Color.finance.income : Color.finance.critical)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.sd.bodyItem)
                    .foregroundStyle(Color.text.primary)
                Text(detail)
                    .font(.sd.meta)
                    .foregroundStyle(Color.text.muted)
            }
        }
    }
}
