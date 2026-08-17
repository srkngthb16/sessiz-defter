#!/usr/bin/env swift
// App Review'a eklenecek örnek ekstre PDF'ini üretir.
// Çalıştırma: swift Scripts/make-sample-statement.swift [çıktı yolu]
//
// Belge kurgusal bir bankaya ait ve "ÖRNEK BELGE" damgası taşıyor: gerçek bir
// bankanın adına düzenlenmiş sahte ekstre, uygulamanın dışında da kullanılabilecek
// bir belge olurdu. Bedeli, kurgusal bankanın yerleşik format imzası olmaması —
// reviewer otomatik tanıma yerine elle sütun eşleme akışını görür.
//
// Metin katmanı gerçek: PDF'e çizilen yazı seçilebilir durumda, yani metin
// çıkarma görüntüden okuma yoluna düşmeden çalışır.

import AppKit
import CoreGraphics
import Foundation

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "build/ornek-ekstre.pdf"

// A4, 72 dpi punto sisteminde.
let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
let margin: CGFloat = 48

/// Satırlar sentetik. Tutarlar ve işyeri adları uydurma; hiçbiri gerçek bir
/// hesaba ya da kişiye ait değil.
let rows: [(date: String, detail: String, amount: String, balance: String)] = [
    ("12.08.2026", "MARKET ALISVERISI", "842,60-", "18.402,15"),
    ("11.08.2026", "AKARYAKIT", "1.180,00-", "19.244,75"),
    ("09.08.2026", "KIRA ODEMESI", "12.500,00-", "20.424,75"),
    ("07.08.2026", "SU FATURASI", "318,40-", "32.924,75"),
    ("06.08.2026", "KAHVE DUKKANI", "185,00-", "33.243,15"),
    ("05.08.2026", "MAAS ODEMESI", "52.400,00+", "33.428,15"),
    ("04.08.2026", "MUZIK ABONELIGI", "59,99-", "-18.971,85"),
    ("03.08.2026", "ECZANE", "437,25-", "-18.911,86"),
    ("02.08.2026", "TOPLU TASIMA", "120,00-", "-18.474,61"),
    ("01.08.2026", "INTERNET FATURASI", "749,90-", "-18.354,61")
]

func attributes(size: CGFloat, bold: Bool = false,
                gray: CGFloat = 0) -> [NSAttributedString.Key: Any] {
    [.font: bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size),
     .foregroundColor: NSColor(white: gray, alpha: 1)]
}

/// Tutar ve bakiye sütunu sağa dayalı: ekstrelerde sayılar sağa hizalı gelir,
/// ayrıştırma da satırın son iki alanını sayı olarak okuyor.
func draw(_ text: String, at point: CGPoint, _ attrs: [NSAttributedString.Key: Any],
          rightAlignedTo right: CGFloat? = nil) {
    let string = NSAttributedString(string: text, attributes: attrs)
    var origin = point
    if let right { origin.x = right - string.size().width }
    string.draw(at: origin)
}

let outputURL = URL(fileURLWithPath: outputPath)
try? FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(),
                                         withIntermediateDirectories: true)

guard let consumer = CGDataConsumer(url: outputURL as CFURL) else {
    FileHandle.standardError.write(Data("FAIL · çıktı yolu açılamadı: \(outputPath)\n".utf8))
    exit(1)
}
var mediaBox = pageRect
guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
    FileHandle.standardError.write(Data("FAIL · PDF bağlamı oluşturulamadı\n".utf8))
    exit(1)
}

context.beginPDFPage(nil)
let previous = NSGraphicsContext.current
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

var y = pageRect.height - margin - 24
let rightEdge = pageRect.width - margin

draw("ÖRNEK BANKASI A.Ş.", at: CGPoint(x: margin, y: y), attributes(size: 16, bold: true))
// Damga ilk sayfada ve göz hizasında: belgenin ne olduğu okunmadan önce görünsün.
draw("ÖRNEK BELGE", at: CGPoint(x: 0, y: y), attributes(size: 12, bold: true, gray: 0.45),
     rightAlignedTo: rightEdge)

y -= 22
draw("HESAP ÖZETİ", at: CGPoint(x: margin, y: y), attributes(size: 13, bold: true))
y -= 18
draw("Gerçek bir hesaba ait değildir · uygulama testi için üretilmiştir",
     at: CGPoint(x: margin, y: y), attributes(size: 9, gray: 0.45))

y -= 26
for line in ["Hesap No: ****3412        Şube: 1234",
             "Dönem: 01.08.2026 - 12.08.2026",
             "Para Birimi: TRY"] {
    draw(line, at: CGPoint(x: margin, y: y), attributes(size: 10, gray: 0.2))
    y -= 15
}

y -= 12
draw("TARİH", at: CGPoint(x: margin, y: y), attributes(size: 10, bold: true))
draw("AÇIKLAMA", at: CGPoint(x: margin + 90, y: y), attributes(size: 10, bold: true))
draw("TUTAR", at: CGPoint(x: 0, y: y), attributes(size: 10, bold: true),
     rightAlignedTo: rightEdge - 90)
draw("BAKİYE", at: CGPoint(x: 0, y: y), attributes(size: 10, bold: true),
     rightAlignedTo: rightEdge)

y -= 8
context.setStrokeColor(CGColor(gray: 0.7, alpha: 1))
context.setLineWidth(0.5)
context.move(to: CGPoint(x: margin, y: y))
context.addLine(to: CGPoint(x: rightEdge, y: y))
context.strokePath()

y -= 20
for row in rows {
    draw(row.date, at: CGPoint(x: margin, y: y), attributes(size: 10))
    draw(row.detail, at: CGPoint(x: margin + 90, y: y), attributes(size: 10))
    draw(row.amount, at: CGPoint(x: 0, y: y), attributes(size: 10),
         rightAlignedTo: rightEdge - 90)
    draw(row.balance, at: CGPoint(x: 0, y: y), attributes(size: 10), rightAlignedTo: rightEdge)
    y -= 18
}

y -= 16
draw("Toplam Borç: 16.393,14", at: CGPoint(x: margin, y: y), attributes(size: 10, gray: 0.2))
y -= 15
draw("Toplam Alacak: 52.400,00", at: CGPoint(x: margin, y: y), attributes(size: 10, gray: 0.2))
y -= 24
draw("Bu belge Sessiz Defter uygulamasının içe aktarma akışını denemek için üretilmiş",
     at: CGPoint(x: margin, y: y), attributes(size: 9, gray: 0.45))
y -= 13
draw("sentetik bir örnektir. Hiçbir banka ile ilişkisi yoktur.",
     at: CGPoint(x: margin, y: y), attributes(size: 9, gray: 0.45))

NSGraphicsContext.current = previous
context.endPDFPage()
context.closePDF()

print("OK · örnek ekstre: \(outputPath)")
