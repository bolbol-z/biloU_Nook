#!/usr/bin/env swift
import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: swift make-placeholder-icon.swift <output.png>\n".utf8))
    exit(1)
}

let outputPath = arguments[1]
let side = 1024
let canvas = NSRect(x: 0, y: 0, width: side, height: side)

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: side,
    pixelsHigh: side,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    FileHandle.standardError.write(Data("unable to create bitmap\n".utf8))
    exit(2)
}
bitmap.size = canvas.size

guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    FileHandle.standardError.write(Data("unable to create graphics context\n".utf8))
    exit(3)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.cgContext.clear(canvas)
context.shouldAntialias = true

NSColor.black.setFill()
let square = NSBezierPath(roundedRect: canvas.insetBy(dx: 64, dy: 64), xRadius: 200, yRadius: 200)
square.fill()

let notchWidth: CGFloat = 380
let notchHeight: CGFloat = 110
let notchRadius: CGFloat = 36
let left = canvas.midX - notchWidth / 2
let right = canvas.midX + notchWidth / 2
let top = canvas.maxY - 64
let bottom = top - notchHeight

let notch = NSBezierPath()
notch.move(to: NSPoint(x: left, y: top))
notch.line(to: NSPoint(x: right, y: top))
notch.line(to: NSPoint(x: right, y: bottom + notchRadius))
notch.curve(
    to: NSPoint(x: right - notchRadius, y: bottom),
    controlPoint1: NSPoint(x: right, y: bottom),
    controlPoint2: NSPoint(x: right - notchRadius, y: bottom)
)
notch.line(to: NSPoint(x: left + notchRadius, y: bottom))
notch.curve(
    to: NSPoint(x: left, y: bottom + notchRadius),
    controlPoint1: NSPoint(x: left + notchRadius, y: bottom),
    controlPoint2: NSPoint(x: left, y: bottom)
)
notch.close()
NSColor.white.setFill()
notch.fill()

NSGraphicsContext.restoreGraphicsState()

guard let data = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("unable to encode PNG\n".utf8))
    exit(4)
}

do {
    try data.write(to: URL(fileURLWithPath: outputPath))
} catch {
    FileHandle.standardError.write(Data("write failed: \(error)\n".utf8))
    exit(5)
}
