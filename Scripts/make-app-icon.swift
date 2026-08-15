#!/usr/bin/env swift
// Uygulama ikonunu üretir. Tasarım dosyasında ikon yok; marka renginden ve
// "kapalı defter" metaforundan türetildi.
// Çalıştırma: swift Scripts/make-app-icon.swift App/Assets.xcassets/AppIcon.appiconset

import AppKit
import CoreGraphics
import Foundation

let size = 1024.0
let outputDirectory = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "App/Assets.xcassets/AppIcon.appiconset"

func color(_ hex: UInt32) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1)
}

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(data: nil, width: Int(size), height: Int(size),
                              bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("bağlam oluşturulamadı")
}

// Zemin: marka teal'inden hafif koyuya dikey geçiş.
let gradient = CGGradient(colorsSpace: colorSpace,
                          colors: [color(0x0E8A7C), color(0x06564E)] as CFArray,
                          locations: [0, 1])!
context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size),
                           end: CGPoint(x: 0, y: 0), options: [])

// Defter gövdesi: yuvarlatılmış dikdörtgen, hafif içe kaçık.
let bookWidth = size * 0.46
let bookHeight = size * 0.56
let bookRect = CGRect(x: (size - bookWidth) / 2, y: (size - bookHeight) / 2,
                      width: bookWidth, height: bookHeight)
context.setFillColor(color(0xF6F8F8))
context.addPath(CGPath(roundedRect: bookRect, cornerWidth: size * 0.05,
                       cornerHeight: size * 0.05, transform: nil))
context.fillPath()

// Sırt: sol kenarda dikey şerit.
let spineWidth = bookWidth * 0.18
let spineRect = CGRect(x: bookRect.minX, y: bookRect.minY,
                       width: spineWidth, height: bookRect.height)
context.setFillColor(color(0x0A7C70))
context.addPath(CGPath(roundedRect: spineRect, cornerWidth: size * 0.05,
                       cornerHeight: size * 0.05, transform: nil))
context.fillPath()
context.fill(CGRect(x: spineRect.maxX - size * 0.05, y: spineRect.minY,
                    width: size * 0.05, height: spineRect.height))

// Sayfa çizgileri: üç kısa, biri kısa — defter satırları.
context.setFillColor(color(0xCDD5D4))
let lineHeight = size * 0.022
let lineX = spineRect.maxX + bookWidth * 0.14
let lineWidths = [bookWidth * 0.58, bookWidth * 0.58, bookWidth * 0.34]
for (index, width) in lineWidths.enumerated() {
    let y = bookRect.maxY - bookHeight * 0.30 - Double(index) * size * 0.075
    context.addPath(CGPath(roundedRect:
        CGRect(x: lineX, y: y, width: width, height: lineHeight),
        cornerWidth: lineHeight / 2, cornerHeight: lineHeight / 2, transform: nil))
    context.fillPath()
}

// Alt satır marka renginde: "işlenmiş kayıt".
context.setFillColor(color(0x0A7C70))
context.addPath(CGPath(roundedRect:
    CGRect(x: lineX, y: bookRect.minY + bookHeight * 0.18,
           width: bookWidth * 0.44, height: lineHeight),
    cornerWidth: lineHeight / 2, cornerHeight: lineHeight / 2, transform: nil))
context.fillPath()

guard let image = context.makeImage() else { fatalError("görüntü üretilemedi") }
let bitmap = NSBitmapImageRep(cgImage: image)
guard let data = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("PNG kodlanamadı")
}
let url = URL(fileURLWithPath: outputDirectory).appendingPathComponent("AppIcon-1024.png")
try data.write(to: url)
print("yazıldı: \(url.path) · \(data.count) bayt")
