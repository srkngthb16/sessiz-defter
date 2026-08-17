import DesignSystem
import SwiftUI

/// İlk kullanım turu: dört adım, tek seferlik. Onboarding "veriniz çıkmaz" der,
/// tur "şuraya dokun" der — ikisi ayrı iş, o yüzden ayrı bayrakla saklanıyor.
///
/// Bilerek sade: hedef arayüz öğelerinin üstünü işaretleyen bir kaplama, ekran
/// yerleşimini ölçmek zorunda kalır ve her tasarım değişikliğinde kayardı.
/// Burada simge, başlık ve tek satır açıklama var; nereye dokunulacağı simgeyle
/// anlatılıyor.
public struct TourView: View {
    public struct Step: Identifiable, Sendable {
        public let symbol: String
        public let title: String
        public let message: String
        public var id: String { title }
    }

    /// Sıra kullanım sırası: önce veri girer, sonra bakar, sonra denetler.
    public static let steps: [Step] = [
        Step(symbol: "doc.badge.plus",
             title: "Ekstrenizi yükleyin",
             message: "Özet ekranının sağ üstündeki simge PDF ekstre yükler. Birden fazla dosyayı aynı anda seçebilirsiniz."),
        Step(symbol: "plus",
             title: "Elle işlem ekleyin",
             message: "Alttaki yuvarlak düğme nakit harcamalar ve desteklenmeyen bankalar için."),
        Step(symbol: "chart.pie",
             title: "Bütçenizi kurun",
             message: "Bütçe sekmesinde aylık limit koyun; kalan gün başına ne harcayabileceğinizi uygulama hesaplar."),
        Step(symbol: "lock.shield",
             title: "Mahremiyet raporu",
             message: "Ayarlar'da hangi iznin kullanıldığını, hangisinin hiç istenmediğini tek ekranda görürsünüz.")
    ]

    @State private var index = 0
    var onFinished: () -> Void

    public init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
    }

    public var body: some View {
        VStack(spacing: Spacing.l) {
            HStack {
                Text("\(index + 1) / \(Self.steps.count)")
                    .font(.sd.caption)
                    .foregroundStyle(Color.brand.primary)
                Spacer()
                Button("Atla") { onFinished() }
                    .font(.sd.meta)
                    .foregroundStyle(Color.text.muted)
            }

            Spacer(minLength: 0)

            let step = Self.steps[index]
            Image(systemName: step.symbol)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.brand.primary)
                .frame(width: 96, height: 96)
                .background(Color.brand.surface, in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: Spacing.s) {
                Text(LocalizedStringKey(step.title))
                    .font(.sd.titleScreen)
                    .foregroundStyle(Color.text.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(LocalizedStringKey(step.message))
                    .font(.sd.meta)
                    .foregroundStyle(Color.text.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            // Adım göstergesi TabView'a bırakılmadı: sayfa kaydırma jesti "Atla"
            // düğmesiyle birlikte kazayla geçmeye yol açıyordu.
            HStack(spacing: Spacing.xs) {
                ForEach(Self.steps.indices, id: \.self) { position in
                    Circle()
                        .fill(position == index ? Color.brand.primary : Color.border.default)
                        .frame(width: 7, height: 7)
                }
            }
            .accessibilityHidden(true)

            PrimaryButton(index == Self.steps.count - 1 ? "Başla" : "İleri") {
                if index == Self.steps.count - 1 {
                    onFinished()
                } else {
                    index += 1
                }
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg.canvas)
        .accessibilityElement(children: .contain)
    }
}
