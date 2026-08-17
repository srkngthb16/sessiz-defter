import Domain
import Foundation

/// Ekstredeki hesap/kart numarasının son dört hanesi. İşlemlerin doğru bankaya
/// yazılması için gerekiyor: banka adı tek başına yetmiyor, aynı bankada iki kart
/// olabiliyor.
///
/// Tam numara hiçbir yere yazılmıyor; yalnız son dört hane tutuluyor, o da
/// ekranlarda maske olarak görünüyor (`AccountEntity.maskedNumber`).
public enum AccountHint {
    /// Etiket satırları bankadan bankaya değişiyor ama hepsi bu üç kalıptan biri.
    private static let labels = ["KART NUMARASI", "HESAP NUMARASI", "HESAP NO"]

    /// "••9764" ya da nil. Bulunamaması hata değil: kullanıcı hesabı elle seçer.
    public static func maskedNumber(in text: String) -> String? {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }

        for (index, line) in lines.enumerated() {
            let folded = TextNormalizer.fold(line)
            guard labels.contains(where: folded.contains) else { continue }
            // Numara alt satıra taşabiliyor ("5430-81##-" / "####-3682"), o yüzden
            // sonraki satır da aramaya katılıyor.
            let candidate = index + 1 < lines.count ? line + " " + lines[index + 1] : line
            if let digits = lastFourDigits(in: candidate) { return "••" + digits }
        }
        return nil
    }

    private static func lastFourDigits(in text: String) -> String? {
        // Maskeli numarada yıldız ve kare işaretleri var; yalnız rakam öbekleri
        // ilgilendiriyor ve son öbeğin sonu son dört haneyi veriyor.
        let groups = text.split(whereSeparator: { !$0.isNumber })
            .map(String.init)
            .filter { $0.count >= 2 }
        guard let last = groups.last, last.count >= 4 else { return nil }
        return String(last.suffix(4))
    }
}
