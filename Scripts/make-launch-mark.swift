#!/usr/bin/env swift
// Açılış ekranındaki işareti üretir: ikondaki defter simgesi, zeminsiz.
// Açık ve koyu mod için iki ayrı PNG — marka rengi iki modda farklı.
// Çalıştırma: swift Scripts/make-launch-mark.swift App/Assets.xcassets/LaunchMark.imageset

import AppKit
import CoreGraphics
import Foundation

let outputDirectory = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "App/Assets.xcassets/LaunchMark.imageset"

func color(_ hex: UInt32) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

/// scale: 1x/2x/3x için aynı çizim farklı çözünürlükte.
func draw(tint: UInt32, page: UInt32, pointSize: CGFloat, scale: CGFloat) -> Data {
    let size = pointSize * scale
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(data: nil, width: Int(size), height: Int(size),
                                  bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fatalError("bağlam oluşturulamadı")
    }

    let bookWidth = size * 0.72
    let bookHeight = size * 0.88
    let bookRect = CGRect(x: (size - bookWidth) / 2, y: (size - bookHeight) / 2,
                          width: bookWidth, height: bookHeight)
    let radius = size * 0.08

    context.setFillColor(color(page))
    context.addPath(CGPath(roundedRect: bookRect, cornerWidth: radius,
                           cornerHeight: radius, transform: nil))
    context.fillPath()

    context.setStrokeColor(color(tint))
    context.setLineWidth(size * 0.035)
    context.addPath(CGPath(roundedRect: bookRect.insetBy(dx: size * 0.017, dy: size * 0.017),
                           cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.strokePath()

    // Sırt
    let spineWidth = bookWidth * 0.20
    context.setFillColor(color(tint))
    context.fill(CGRect(x: bookRect.minX + size * 0.017, y: bookRect.minY + size * 0.017,
                        width: spineWidth, height: bookRect.height - size * 0.034))
    context.addPath(CGPath(roundedRect:
        CGRect(x: bookRect.minX + size * 0.017, y: bookRect.minY + size * 0.017,
               width: spineWidth, height: bookRect.height - size * 0.034),
        cornerWidth: radius * 0.7, cornerHeight: radius * 0.7, transform: nil))
    context.fillPath()

    // Satırlar
    let lineHeight = size * 0.045
    let lineX = bookRect.minX + spineWidth + bookWidth * 0.16
    for (index, width) in [bookWidth * 0.48, bookWidth * 0.48, bookWidth * 0.28].enumerated() {
        let y = bookRect.maxY - bookHeight * 0.30 - CGFloat(index) * size * 0.14
        context.setFillColor(color(tint))
        context.addPath(CGPath(roundedRect:
            CGRect(x: lineX, y: y, width: width, height: lineHeight),
            cornerWidth: lineHeight / 2, cornerHeight: lineHeight / 2, transform: nil))
        context.fillPath()
    }

    guard let image = context.makeImage(),
          let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    else { fatalError("PNG kodlanamadı") }
    return data
}

let pointSize: CGFloat = 96
for scale in [1, 2, 3] {
    let light = draw(tint: 0x0A7C70, page: 0xFFFFFF,
                     pointSize: pointSize, scale: CGFloat(scale))
    let dark = draw(tint: 0x3FCFBC, page: 0x1B2122,
                    pointSize: pointSize, scale: CGFloat(scale))
    let suffix = scale == 1 ? "" : "@\(scale)x"
    try light.write(to: URL(fileURLWithPath: outputDirectory)
        .appendingPathComponent("LaunchMark\(suffix).png"))
    try dark.write(to: URL(fileURLWithPath: outputDirectory)
        .appendingPathComponent("LaunchMark-Dark\(suffix).png"))
}
print("yazıldı: \(outputDirectory)")
