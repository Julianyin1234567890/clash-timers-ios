import SwiftUI
import UIKit
import CoreText
import ClashTimersCore

/// Colours, gradients, font and artwork from the Android widget resources.
enum OriginalTheme {
    static let gold = color(0xFFD24A)
    static let cream = color(0xE9DCC8)
    static let idle = color(0xFFB35C)
    static let green = color(0x6FD36A)
    static let ink = color(0x5A3500)
    static let outline = color(0x2A1D13)
    static let panel = LinearGradient(stops: [
        .init(color: color(0x7A5639), location: 0),
        .init(color: color(0x5A3F2B), location: 0.3),
        .init(color: color(0x3D2A1C), location: 1)
    ], startPoint: .top, endPoint: .bottom)
    static let progress = LinearGradient(stops: [
        .init(color: color(0xB9EC7A).opacity(0.92), location: 0),
        .init(color: color(0x8FD14F).opacity(0.92), location: 0.45),
        .init(color: color(0x5F9A2C).opacity(0.92), location: 1)
    ], startPoint: .top, endPoint: .bottom)
    static let done = gradient(0x6B7A8A, 0x4A5563)
    static let goldButton = gradient(0xFFD768, 0xE9A92A)
    static let greenButton = gradient(0x8EE05A, 0x62B534)

    private static let registeredFont: String = {
        if let url = GameData.resourceBundle.url(forResource: "lilita_one", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        return "LilitaOne"
    }()
    private static let images = NSCache<NSString, UIImage>()

    static func font(_ size: CGFloat) -> Font { .custom(registeredFont, fixedSize: size) }
    static func color(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 255) / 255,
              green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
    static func gradient(_ top: UInt32, _ bottom: UInt32) -> LinearGradient {
        LinearGradient(colors: [color(top), color(bottom)], startPoint: .top, endPoint: .bottom)
    }
    static func image(_ candidates: [String]) -> UIImage? {
        for name in candidates {
            if let cached = images.object(forKey: name as NSString) { return cached }
            if let url = GameData.resourceBundle.url(forResource: name, withExtension: "png"),
               let image = UIImage(contentsOfFile: url.path) {
                images.setObject(image, forKey: name as NSString)
                return image
            }
        }
        return nil
    }
}

struct VillageArtwork: View {
    let names: [String]
    var fallback = ""
    var body: some View {
        Group {
            if let image = OriginalTheme.image(names) {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Text(fallback).font(.system(size: 9, weight: .bold)).foregroundStyle(OriginalTheme.cream)
            }
        }.accessibilityHidden(true)
    }
}

struct WoodenPanel: View {
    var radius: CGFloat = 18
    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(OriginalTheme.panel)
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(OriginalTheme.outline, lineWidth: 2)
            }
            .overlay(alignment: .top) {
                Rectangle().fill(.white.opacity(0.18)).frame(height: 1)
                    .padding(.horizontal, 14).padding(.top, 2)
            }
    }
}

struct OriginalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension View {
    func villageText(_ size: CGFloat, color: Color = .white, shadow: Bool = true) -> some View {
        font(OriginalTheme.font(size)).foregroundStyle(color)
            .shadow(color: .black.opacity(shadow ? 0.75 : 0), radius: 0.8, x: 0, y: 1)
    }
}
