import CoreGraphics
import Foundation
import PDFKit

/// PDF'ten **konumlu** metin çıkarır: hangi sözcük hangi satırda, hangi sütunda.
///
/// Neden gerekli: `PDFPage.string` sütun bilgisini atıyor. Ekstre tablosu düz
/// metne dönünce iki işlem tek satıra yapışıyor, tutar sütunuyla bakiye sütunu
/// karışıyor ve her banka için elle parser yazmak zorunda kalıyoruz. Konum
/// korunursa "hangi banka" sorusu ortadan kalkıyor: tarih sütunu tarih gibi
/// görünen sütundur.
/// **Durum: yarım.** Konumlu çıkarım metni doğru okuyor ama satır gruplaması
/// henüz güvenilir değil: bazı PDF'lerde farklı satırların parçaları aynı satırda
/// toplanıyor. Bu yüzden boru hattına **bağlanmadı** — bağlanırsa çalışan banka
/// ayrıştırıcılarını da bozar. Sıradaki iş: sözcük dikdörtgenlerini dökerek
/// dikey kümeleme eşiğini gerçek ekstrelerle kalibre etmek.

public struct LayoutCell: Hashable, Sendable {
    public let text: String
    public let minX: CGFloat
    public let maxX: CGFloat

    public init(text: String, minX: CGFloat, maxX: CGFloat) {
        self.text = text
        self.minX = minX
        self.maxX = maxX
    }

    public var midX: CGFloat { (minX + maxX) / 2 }
}

public struct LayoutLine: Hashable, Sendable {
    public let cells: [LayoutCell]
    /// Sayfadaki dikey konum; satır sırası buna göre.
    public let y: CGFloat
    public let pageIndex: Int

    public init(cells: [LayoutCell], y: CGFloat, pageIndex: Int) {
        self.cells = cells
        self.y = y
        self.pageIndex = pageIndex
    }

    public var text: String { cells.map(\.text).joined(separator: " ") }
}

public struct LayoutDocument: Sendable {
    public let lines: [LayoutLine]

    public init(lines: [LayoutLine]) {
        self.lines = lines
    }
}

public enum LayoutExtractor {
    /// Aynı satır sayılmak için dikey merkez farkı bu oranı geçmemeli. Ekstrelerde
    /// satır yüksekliği ~10 punto; yarısı, üst simge ve alt simgeyi aynı satırda
    /// tutmaya yetiyor, iki ayrı satırı birleştirmeye yetmiyor.
    static let lineTolerance: CGFloat = 5

    /// Sözcükler arası bu boşluktan geniş aralık sütun ayracı sayılıyor. Kelime
    /// arası tek boşluk ~3 punto; sütun aralığı ekstrelerde en az 8.
    static let columnGap: CGFloat = 8

    public static func extract(document: PDFDocument) -> LayoutDocument {
        var lines: [LayoutLine] = []
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            lines.append(contentsOf: self.lines(of: page, pageIndex: pageIndex))
        }
        return LayoutDocument(lines: lines)
    }

    /// Sayfadaki karakterleri sözcüklere, sözcükleri satırlara, satırları
    /// sütunlara ayırır.
    static func lines(of page: PDFPage, pageIndex: Int) -> [LayoutLine] {
        guard let text = page.string, !text.isEmpty else { return [] }

        struct Word {
            var text: String
            var minX: CGFloat
            var maxX: CGFloat
            var midY: CGFloat
        }

        var words: [Word] = []
        var current: Word?

        // Konum sorgusu UTF-16 sırasına göre çalışıyor; `Character` sırasıyla
        // gezmek Türkçe metinde kaymaya ve sözcüklerin ortadan bölünmesine yol
        // açıyordu ("esap Bakiyesi").
        let units = Array(text.utf16)
        for offset in 0..<min(units.count, page.numberOfCharacters) {
            guard let scalar = Unicode.Scalar(units[offset]) else { continue }
            let character = Character(scalar)
            let bounds = page.characterBounds(at: offset)
            // Kimi glif için konum boş dönüyor (bitişik harfler, aksan). Karakteri
            // atmak sözcüğü bozuyordu ("Limiti" yerine "Lmiti"); konumu olmayan
            // karakter içinde bulunduğu sözcüğe yazılıyor, sınır değiştirilmiyor.
            if bounds.isNull || bounds.isEmpty {
                if !character.isWhitespace, current != nil { current?.text.append(character) }
                continue
            }
            if character.isWhitespace || character.isNewline {
                if let word = current { words.append(word) }
                current = nil
                continue
            }
            // Sözcük yalnız dikey yakınlıkla kurulamıyor: PDFKit karakterleri her
            // zaman görsel sırada vermiyor, akış satırlar arasında zıplayabiliyor.
            // Yatay süreklilik de aranıyor — yeni karakter, öncekinin bittiği
            // yerden başlamalı.
            let continuesWord = current.map { word in
                abs(word.midY - bounds.midY) <= lineTolerance
                    && bounds.minX >= word.minX - 1
                    && bounds.minX - word.maxX <= 2.5
            } ?? false

            if continuesWord, var word = current {
                word.text.append(character)
                word.minX = min(word.minX, bounds.minX)
                word.maxX = max(word.maxX, bounds.maxX)
                current = word
            } else {
                if let word = current { words.append(word) }
                current = Word(text: String(character), minX: bounds.minX,
                               maxX: bounds.maxX, midY: bounds.midY)
            }
        }
        if let word = current { words.append(word) }
        guard !words.isEmpty else { return [] }

        // Satırlar: dikey merkezi yakın sözcükler bir arada. PDF'in başlangıcı sol
        // alt köşe olduğu için büyük y üstte; sıralama azalan.
        var grouped: [[Word]] = []
        for word in words.sorted(by: { $0.midY > $1.midY }) {
            if var last = grouped.last, let reference = last.first,
               abs(reference.midY - word.midY) <= lineTolerance {
                last.append(word)
                grouped[grouped.count - 1] = last
            } else {
                grouped.append([word])
            }
        }

        return grouped.compactMap { group in
            let ordered = group.sorted { $0.minX < $1.minX }
            guard let first = ordered.first else { return nil }

            // Sütunlar: aralarında geniş boşluk olan sözcük öbekleri.
            var cells: [LayoutCell] = []
            var buffer = first
            for word in ordered.dropFirst() {
                if word.minX - buffer.maxX > columnGap {
                    cells.append(LayoutCell(text: buffer.text, minX: buffer.minX,
                                            maxX: buffer.maxX))
                    buffer = word
                } else {
                    buffer.text += " " + word.text
                    buffer.maxX = max(buffer.maxX, word.maxX)
                }
            }
            cells.append(LayoutCell(text: buffer.text, minX: buffer.minX, maxX: buffer.maxX))
            return LayoutLine(cells: cells, y: first.midY, pageIndex: pageIndex)
        }
    }
}
