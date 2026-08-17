#!/usr/bin/env swift
// Ham simülatör ekran görüntülerine başlık bandı ekler, App Store ölçüsünde PNG üretir.
// Çalıştırma: swift Scripts/make-screenshots.swift <ham dizin> <çıktı dizin>
//
// Ham dosyalar `docs/SCREENSHOTS.md` bölüm 3'teki adlarla beklenir; başlık metni
// dosya adına göre aşağıdaki tablodan seçilir. Böylece görüntü yeniden çekildiğinde
// metin katmanı elle hizalanmıyor: betik tekrar koşar, çıktı aynı olur.
//
// Ölçü kontrolü betikte: girdi 1320x2868 değilse durur. App Store 6.9 inç yuvasına
// başka ölçü kabul etmiyor; sessizce yanlış boyut üretmek en pahalı hata olurdu.

import AppKit
import CoreGraphics
import Foundation

let rawDirectory = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1] : "build/screenshots/raw"
let outputDirectory = CommandLine.arguments.count > 2
    ? CommandLine.arguments[2] : "build/screenshots/appstore"

/// Tasarım tokenları (DesignTokens+Color.swift, açık tema).
let canvasColor = NSColor(srgbRed: 0xF6 / 255, green: 0xF8 / 255, blue: 0xF8 / 255, alpha: 1)
let textPrimary = NSColor(srgbRed: 0x16 / 255, green: 0x1D / 255, blue: 0x1C / 255, alpha: 1)
let brandPrimary = NSColor(srgbRed: 0x0A / 255, green: 0x7C / 255, blue: 0x70 / 255, alpha: 1)

/// Başlıklar mağaza sırasına göre. İlk görüntü tek satırda ürünün ne olduğunu
/// söylemeli: arama sonuçlarında yalnız ilk ikisi görünüyor.
let captions: [String: (title: String, note: String)] = [
    "01-dashboard": ("Defteriniz tek ekranda", "Net varlık, bütçe ve kategori dağılımı"),
    "02-islemler": ("İşlemler otomatik kategorilenir", "Arama, filtre ve elle düzeltme her zaman açık"),
    "03-butce": ("Bütçe gün gün takip eder", "Kalan gün başına harcanabilir payı gösterir"),
    "04-raporlar": ("Dönemleri karşılaştırın", "Gelir · gider trendi ve kategori değişimi"),
    // Başlık ekrandaki cümleyi tekrarlamıyor: aynı sözü iki kez okumak bandı
    // gereksiz kılıyordu.
    "05-onboarding": ("Uçak modunda da çalışır", "Ağ katmanı hiç yazılmadı; kapatılabilir bir ayar değil"),
    "06-mahremiyet": ("İddia değil, rapor", "Hangi izin kullanılıyor, hangisi kullanılmıyor")
]

let canvasSize = CGSize(width: 1320, height: 2868)
let shotWidth: CGFloat = 1080
let shotTop: CGFloat = 470

func font(named name: String, size: CGFloat, fallbackBold: Bool) -> NSFont {
    let path = "Scripts/font-src/\(name).ttf"
    if let data = FileManager.default.contents(atPath: path),
       let provider = CGDataProvider(data: data as CFData),
       let cgFont = CGFont(provider) {
        CTFontManagerRegisterGraphicsFont(cgFont, nil)
        if let registered = cgFont.postScriptName as String?,
           let font = NSFont(name: registered, size: size) {
            return font
        }
    }
    // Font bulunamazsa üretim durmaz; yalnız tipografi sistem fontuna düşer.
    return fallbackBold ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size)
}

let titleFont = font(named: "Archivo-Bold", size: 76, fallbackBold: true)
let noteFont = font(named: "Archivo-Medium", size: 42, fallbackBold: false)

func paragraph() -> NSMutableParagraphStyle {
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    style.lineSpacing = 8
    return style
}

func compose(rawPath: String, key: String, outputPath: String) throws {
    guard let source = NSImage(contentsOfFile: rawPath),
          let tiff = source.tiffRepresentation,
          let sourceRep = NSBitmapImageRep(data: tiff) else {
        throw NSError(domain: "screenshot", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "okunamadı: \(rawPath)"])
    }
    guard sourceRep.pixelsWide == 1320, sourceRep.pixelsHigh == 2868 else {
        throw NSError(domain: "screenshot", code: 2, userInfo: [
            NSLocalizedDescriptionKey:
                "\(rawPath): \(sourceRep.pixelsWide)x\(sourceRep.pixelsHigh) — 1320x2868 bekleniyordu"
        ])
    }
    guard let caption = captions[key] else {
        throw NSError(domain: "screenshot", code: 3,
                      userInfo: [NSLocalizedDescriptionKey: "başlık tanımsız: \(key)"])
    }

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(data: nil, width: Int(canvasSize.width),
                                  height: Int(canvasSize.height), bitsPerComponent: 8,
                                  bytesPerRow: 0, space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
        throw NSError(domain: "screenshot", code: 4,
                      userInfo: [NSLocalizedDescriptionKey: "bağlam kurulamadı"])
    }

    context.setFillColor(canvasColor.cgColor)
    context.fill(CGRect(origin: .zero, size: canvasSize))

    let previous = NSGraphicsContext.current
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

    // CGContext'in başlangıcı sol *alt* köşe; başlıklar üstten ölçülüyor, o yüzden
    // dikey konum tuvalin yüksekliğinden düşülerek yazılıyor.
    let textWidth = canvasSize.width - 160
    func fromTop(_ top: CGFloat, height: CGFloat) -> CGRect {
        CGRect(x: 80, y: canvasSize.height - top - height, width: textWidth, height: height)
    }

    NSAttributedString(string: caption.title, attributes: [
        .font: titleFont, .foregroundColor: textPrimary, .paragraphStyle: paragraph()
    ]).draw(in: fromTop(150, height: 220))

    NSAttributedString(string: caption.note, attributes: [
        .font: noteFont, .foregroundColor: brandPrimary, .paragraphStyle: paragraph()
    ]).draw(in: fromTop(368, height: 120))

    NSGraphicsContext.current = previous

    // Ekran görüntüsü köşeleri yuvarlatılıp altta taşırılıyor: tam sığdırmak
    // görüntüyü küçültüp içindeki tutarları okunmaz yapıyordu.
    let scale = shotWidth / canvasSize.width
    let shotHeight = canvasSize.height * scale
    let shotRect = CGRect(x: (canvasSize.width - shotWidth) / 2,
                          y: canvasSize.height - shotTop - shotHeight,
                          width: shotWidth, height: shotHeight)
    context.saveGState()
    let radius: CGFloat = 56
    context.beginPath()
    context.addPath(CGPath(roundedRect: shotRect, cornerWidth: radius,
                           cornerHeight: radius, transform: nil))
    context.clip()
    guard let cgSource = sourceRep.cgImage else {
        throw NSError(domain: "screenshot", code: 5,
                      userInfo: [NSLocalizedDescriptionKey: "kaynak görüntü dönüştürülemedi"])
    }
    context.draw(cgSource, in: shotRect)
    context.restoreGState()

    guard let output = context.makeImage() else {
        throw NSError(domain: "screenshot", code: 6,
                      userInfo: [NSLocalizedDescriptionKey: "çıktı üretilemedi"])
    }
    let rep = NSBitmapImageRep(cgImage: output)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "screenshot", code: 7,
                      userInfo: [NSLocalizedDescriptionKey: "PNG kodlanamadı"])
    }
    try data.write(to: URL(fileURLWithPath: outputPath))
}

let fileManager = FileManager.default
try? fileManager.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)

let files = ((try? fileManager.contentsOfDirectory(atPath: rawDirectory)) ?? [])
    .filter { $0.hasSuffix(".png") }
    .sorted()

guard !files.isEmpty else {
    FileHandle.standardError.write(Data("FAIL · ham görüntü yok: \(rawDirectory)\n".utf8))
    exit(1)
}

var failed = false
for file in files {
    let key = (file as NSString).deletingPathExtension
    do {
        try compose(rawPath: "\(rawDirectory)/\(file)", key: key,
                    outputPath: "\(outputDirectory)/\(file)")
        print("OK · \(file)")
    } catch {
        FileHandle.standardError.write(Data("FAIL · \(error.localizedDescription)\n".utf8))
        failed = true
    }
}
exit(failed ? 1 : 0)
