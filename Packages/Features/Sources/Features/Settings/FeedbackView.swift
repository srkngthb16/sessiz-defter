import DesignSystem
import SwiftUI
import UIKit

/// Ayarlar > Geri bildirim gönder.
///
/// Metin gönderilmeden önce tam hâliyle ekranda: özet değil, paylaşılacak
/// dizenin kendisi gösteriliyor. Kullanıcı ne gönderdiğini görmeden gönderemez.
public struct FeedbackView: View {
    let environment: AppEnvironment
    let appVersion: AppVersion
    let deviceModel: String
    let systemVersion: String

    @State private var note = ""
    @State private var counts = Counts()

    private struct Counts {
        var transactions = 0
        var accounts = 0
        var budgets = 0
    }

    public init(environment: AppEnvironment,
                appVersion: AppVersion = AppVersion(),
                deviceModel: String = DeviceModel.identifier(),
                systemVersion: String = UIDevice.current.systemVersion) {
        self.environment = environment
        self.appVersion = appVersion
        self.deviceModel = deviceModel
        self.systemVersion = systemVersion
    }

    private var report: FeedbackReport {
        FeedbackReport(
            appVersion: appVersion.displayString,
            deviceModel: deviceModel,
            systemVersion: systemVersion,
            transactionCount: counts.transactions,
            accountCount: counts.accounts,
            budgetCount: counts.budgets,
            failureCounts: Diagnostics.Failure.allCases.map {
                (name: $0.title, count: environment.diagnostics.count($0))
            },
            note: note)
    }

    public var body: some View {
        Form {
            Section {
                TextField("Ne oldu? (isteğe bağlı)", text: $note, axis: .vertical)
                    .lineLimit(3...8)
            } header: {
                Text("Mesajınız")
            } footer: {
                Text("Yazdığınız not aşağıdaki metnin sonuna eklenir.")
            }

            Section {
                Text(report.text)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .foregroundStyle(Color.text.secondary)
            } header: {
                Text("Gönderilecek metnin tamamı")
            } footer: {
                Text("Defterinizden yalnızca bu sayılar çıkar. İşlem detayı, tutar, işyeri adı ve hesap bilgisi rapora girmez.")
            }

            Section {
                ShareLink(item: report.text) {
                    Label("Geri bildirim gönder", systemImage: "square.and.arrow.up")
                }
            } footer: {
                Text("Sistem paylaşım sayfası açılır; metni hangi uygulamayla göndereceğinize siz karar verirsiniz. Uygulama kendi başına hiçbir yere bağlanmaz.")
            }
        }
        .navigationTitle("Geri bildirim")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadCounts() }
    }

    private func loadCounts() async {
        counts.transactions = (try? await environment.transactions.count(matching: .all)) ?? 0
        counts.accounts = (try? await environment.accounts.all(includeArchived: true).count) ?? 0
        counts.budgets = (try? await environment.budgets.all(includeArchived: true).count) ?? 0
    }
}
