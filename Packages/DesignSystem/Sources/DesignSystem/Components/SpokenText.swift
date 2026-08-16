import Foundation

/// Ekranda kısa olsun diye seçilen işaretlerin okunabilir karşılıkları.
/// Görsel dize ile okunan dize aynı olmak zorunda değil; ikisini ayırmak
/// ekranı kalabalıklaştırmadan seslendirmeyi anlaşılır kılıyor.
public enum SpokenText {
    /// "Market · Ziraat ••3412" → "Market, Ziraat son dört hane 3412".
    ///
    /// Maske noktaları VoiceOver'da ya hiç okunmuyor ya da tek tek okunuyor;
    /// ikisi de bunun hesap numarasının son hanesi olduğunu anlatmıyor. Orta
    /// nokta da ayraç olarak okunmuyor, virgüle çevriliyor.
    public static func expandingAccountMask(_ text: String) -> String {
        text.replacingOccurrences(of: " · ", with: ", ")
            .replacingOccurrences(of: "••", with: "son dört hane ")
    }
}
