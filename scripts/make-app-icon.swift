#!/usr/bin/env swift
// Renders the app icon into Clipboard/Resources/Assets.xcassets/AppIcon.appiconset.
// Usage: swift scripts/make-app-icon.swift
//
// Follows the macOS icon grid: an 824pt squircle body centred on a 1024pt
// canvas, with a soft drop shadow in the margin.
import AppKit
import SwiftUI

struct AppIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.36, green: 0.69, blue: 1.0), Color(red: 0.0, green: 0.40, blue: 0.96)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .overlay {
                    RoundedRectangle(cornerRadius: 185, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 3)
                }
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.28), radius: 14, y: 10)

            // Board
            RoundedRectangle(cornerRadius: 58, style: .continuous)
                .fill(Color.white)
                .frame(width: 440, height: 540)
                .shadow(color: Color(red: 0, green: 0.2, blue: 0.5).opacity(0.35), radius: 24, y: 14)
                .offset(y: 40)

            // Text lines
            VStack(alignment: .leading, spacing: 44) {
                Capsule().frame(width: 280, height: 38)
                Capsule().frame(width: 280, height: 38)
                Capsule().frame(width: 180, height: 38)
            }
            .foregroundStyle(Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.28))
            .frame(width: 280, alignment: .leading)
            .offset(y: 62)

            // Clip
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color(red: 0.05, green: 0.22, blue: 0.55))
                .frame(width: 230, height: 96)
                .overlay(alignment: .top) {
                    Capsule().fill(Color.white.opacity(0.22)).frame(width: 120, height: 14).padding(.top, 16)
                }
                .offset(y: -222)
        }
        .frame(width: 1024, height: 1024)
    }
}

let output = URL(fileURLWithPath: "Clipboard/Resources/Assets.xcassets/AppIcon.appiconset")
let sizes: [(points: Int, scale: Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]

MainActor.assumeIsolated {
    var images: [String] = []
    for (points, scale) in sizes {
        let pixels = points * scale
        let renderer = ImageRenderer(content: AppIcon())
        renderer.scale = CGFloat(pixels) / 1024
        guard let cgImage = renderer.cgImage else { fatalError("render failed") }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try! rep.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
        images.append("""
            { "filename" : "\(name)", "idiom" : "mac", "scale" : "\(scale)x", "size" : "\(points)x\(points)" }
        """)
    }
    let contents = "{\n  \"images\" : [\n" + images.joined(separator: ",\n") + "\n  ],\n  \"info\" : { \"author\" : \"xcode\", \"version\" : 1 }\n}\n"
    try! contents.write(to: output.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
    print("Wrote \(sizes.count) icon sizes to \(output.path)")
}
