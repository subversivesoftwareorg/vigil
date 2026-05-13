#!/usr/bin/env swift
//
// Generates a 1024x1024 app icon PNG for Vigil.
//
// Design: deep blue-to-teal gradient background in a macOS super-ellipse shape,
// with a white stylized eye symbol — representing observation/monitoring.
//
// Usage: swift Scripts/generate-icon.swift [output-path]
//        Default output: .build/vigil-icon-1024.png

import AppKit
import CoreGraphics

let size: CGFloat = 1024
let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : ".build/vigil-icon-1024.png"

// Ensure output directory exists
let outputURL = URL(fileURLWithPath: outputPath)
try? FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(),
                                         withIntermediateDirectories: true)

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else {
    print("Error: Could not get graphics context")
    exit(1)
}

// MARK: - Background: macOS super-ellipse with gradient

// macOS icon shape: continuous curvature rounded rect (squircle)
// Approximated with a large corner radius
let iconInset: CGFloat = 10
let iconRect = CGRect(x: iconInset, y: iconInset,
                      width: size - iconInset * 2, height: size - iconInset * 2)
let cornerRadius: CGFloat = size * 0.225
let iconPath = NSBezierPath(roundedRect: iconRect, xRadius: cornerRadius, yRadius: cornerRadius)

// Clip to icon shape
ctx.saveGState()
iconPath.addClip()

// Gradient: deep navy (#0f1b3d) → rich blue (#1a5ab8) → teal (#18a5a7)
let colorSpace = CGColorSpaceCreateDeviceRGB()
let gradientColors = [
    CGColor(red: 0.06, green: 0.11, blue: 0.24, alpha: 1.0),  // deep navy
    CGColor(red: 0.10, green: 0.27, blue: 0.58, alpha: 1.0),  // rich blue
    CGColor(red: 0.09, green: 0.55, blue: 0.58, alpha: 1.0),  // teal
] as CFArray
let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors,
                          locations: [0.0, 0.5, 1.0])!

// Draw gradient from top-left to bottom-right for depth
ctx.drawLinearGradient(gradient,
                       start: CGPoint(x: 0, y: size),
                       end: CGPoint(x: size, y: 0),
                       options: [])

// Subtle inner glow at the top
let glowColor = CGColor(red: 1, green: 1, blue: 1, alpha: 0.08)
ctx.setFillColor(glowColor)
let glowRect = CGRect(x: 0, y: size * 0.5, width: size, height: size * 0.5)
ctx.fillEllipse(in: glowRect.insetBy(dx: -size * 0.2, dy: -size * 0.1))

ctx.restoreGState()

// Redraw the icon shape border for crispness
ctx.saveGState()
iconPath.addClip()

// MARK: - Eye symbol

let centerX = size / 2
let centerY = size / 2

// Eye almond shape — constructed from two arcs
let eyeWidth: CGFloat = size * 0.52
let eyeHeight: CGFloat = size * 0.22

let eyePath = NSBezierPath()

// Top arc
eyePath.move(to: NSPoint(x: centerX - eyeWidth / 2, y: centerY))
eyePath.curve(to: NSPoint(x: centerX + eyeWidth / 2, y: centerY),
              controlPoint1: NSPoint(x: centerX - eyeWidth * 0.2, y: centerY + eyeHeight),
              controlPoint2: NSPoint(x: centerX + eyeWidth * 0.2, y: centerY + eyeHeight))
// Bottom arc
eyePath.curve(to: NSPoint(x: centerX - eyeWidth / 2, y: centerY),
              controlPoint1: NSPoint(x: centerX + eyeWidth * 0.2, y: centerY - eyeHeight),
              controlPoint2: NSPoint(x: centerX - eyeWidth * 0.2, y: centerY - eyeHeight))
eyePath.close()

// White fill for the eye shape
NSColor(white: 1.0, alpha: 0.95).setFill()
eyePath.fill()

// Iris: solid circle
let irisRadius: CGFloat = size * 0.095
let irisRect = CGRect(x: centerX - irisRadius, y: centerY - irisRadius,
                      width: irisRadius * 2, height: irisRadius * 2)

// Iris gradient: deep blue center fading to teal edge
ctx.saveGState()
let irisPath = NSBezierPath(ovalIn: irisRect)
irisPath.addClip()

let irisGradientColors = [
    CGColor(red: 0.06, green: 0.12, blue: 0.30, alpha: 1.0),  // deep navy center
    CGColor(red: 0.10, green: 0.35, blue: 0.65, alpha: 1.0),  // blue mid
    CGColor(red: 0.12, green: 0.50, blue: 0.55, alpha: 1.0),  // teal edge
] as CFArray
let irisGradient = CGGradient(colorsSpace: colorSpace, colors: irisGradientColors,
                               locations: [0.0, 0.5, 1.0])!
ctx.drawRadialGradient(irisGradient,
                       startCenter: CGPoint(x: centerX, y: centerY),
                       startRadius: 0,
                       endCenter: CGPoint(x: centerX, y: centerY),
                       endRadius: irisRadius,
                       options: [])
ctx.restoreGState()

// Pupil: dark circle in the center
let pupilRadius: CGFloat = size * 0.045
let pupilRect = CGRect(x: centerX - pupilRadius, y: centerY - pupilRadius,
                       width: pupilRadius * 2, height: pupilRadius * 2)
NSColor(red: 0.04, green: 0.06, blue: 0.15, alpha: 1.0).setFill()
NSBezierPath(ovalIn: pupilRect).fill()

// Specular highlight on the iris
let highlightRadius: CGFloat = size * 0.02
let highlightX = centerX + irisRadius * 0.3
let highlightY = centerY + irisRadius * 0.3
let highlightRect = CGRect(x: highlightX - highlightRadius, y: highlightY - highlightRadius,
                           width: highlightRadius * 2, height: highlightRadius * 2)
NSColor(white: 1.0, alpha: 0.85).setFill()
NSBezierPath(ovalIn: highlightRect).fill()

// Outer ring around the iris for definition
NSColor(red: 0.08, green: 0.15, blue: 0.35, alpha: 0.6).setStroke()
let irisStrokePath = NSBezierPath(ovalIn: irisRect)
irisStrokePath.lineWidth = size * 0.005
irisStrokePath.stroke()

// Eye outline for definition against the gradient
NSColor(white: 1.0, alpha: 0.3).setStroke()
eyePath.lineWidth = size * 0.006
eyePath.stroke()

ctx.restoreGState()

image.unlockFocus()

// MARK: - Save as PNG

guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    print("Error: Could not create PNG data")
    exit(1)
}

do {
    try pngData.write(to: outputURL)
    print("Icon generated at: \(outputPath)")
} catch {
    print("Error writing file: \(error)")
    exit(1)
}
