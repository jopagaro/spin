//
//  SymbolArt.swift
//  RoyalSpin
//
//  Loads symbol art from the asset catalog, and draws a decent-looking stand-in
//  when a file isn't there yet.
//
//  The placeholders exist so the game is fully playable before any art lands, and
//  so assets can be dropped in one at a time — see ASSETS.md. They are deliberately
//  *not* ugly magenta error squares: a placeholder you can stand to look at is a
//  placeholder you can playtest with.
//

import UIKit

enum SymbolArt {

    private static var cache: [Symbol: UIImage] = [:]
    private static let lock = NSLock()

    /// Real art if present, generated stand-in otherwise.
    static func image(for symbol: Symbol) -> UIImage {
        lock.lock(); defer { lock.unlock() }
        if let cached = cache[symbol] { return cached }

        let image = UIImage(named: "sym_\(symbol.assetName)") ?? placeholder(for: symbol)
        cache[symbol] = image
        return image
    }

    /// True when we're drawing a stand-in — the UI uses this to show a quiet
    /// "placeholder art" note rather than letting you wonder why the King is a disc.
    static func isPlaceholder(_ symbol: Symbol) -> Bool {
        UIImage(named: "sym_\(symbol.assetName)") == nil
    }

    static var anyPlaceholders: Bool {
        Symbol.allCases.contains(where: isPlaceholder)
    }

    /// Drop the cache so newly-added art appears without a rebuild.
    static func reload() {
        lock.lock(); defer { lock.unlock() }
        cache.removeAll()
    }

    // MARK: - Placeholder drawing

    /// Tier colouring, matching the guidance in ASSETS.md: cool and dull for low
    /// symbols, hot and rich for high ones, so value reads before you learn the
    /// paytable.
    private static func palette(for symbol: Symbol) -> (top: UIColor, bottom: UIColor, ink: UIColor) {
        switch symbol {
        case .shield:
            return (UIColor(red: 0.62, green: 0.66, blue: 0.72, alpha: 1),
                    UIColor(red: 0.33, green: 0.37, blue: 0.44, alpha: 1), .white)
        case .chalice:
            return (UIColor(red: 0.70, green: 0.62, blue: 0.52, alpha: 1),
                    UIColor(red: 0.40, green: 0.33, blue: 0.26, alpha: 1), .white)
        case .sceptre:
            return (UIColor(red: 0.55, green: 0.68, blue: 0.74, alpha: 1),
                    UIColor(red: 0.26, green: 0.38, blue: 0.46, alpha: 1), .white)
        case .joker:
            return (UIColor(red: 0.88, green: 0.42, blue: 0.55, alpha: 1),
                    UIColor(red: 0.48, green: 0.16, blue: 0.32, alpha: 1), .white)
        case .knight:
            return (UIColor(red: 0.52, green: 0.60, blue: 0.86, alpha: 1),
                    UIColor(red: 0.20, green: 0.26, blue: 0.52, alpha: 1), .white)
        case .princess:
            return (UIColor(red: 0.85, green: 0.66, blue: 0.90, alpha: 1),
                    UIColor(red: 0.45, green: 0.24, blue: 0.56, alpha: 1), .white)
        case .prince:
            return (UIColor(red: 0.60, green: 0.80, blue: 0.72, alpha: 1),
                    UIColor(red: 0.20, green: 0.44, blue: 0.38, alpha: 1), .white)
        case .queen:
            return (UIColor(red: 0.95, green: 0.72, blue: 0.42, alpha: 1),
                    UIColor(red: 0.60, green: 0.28, blue: 0.14, alpha: 1), .white)
        case .king:
            return (UIColor(red: 0.98, green: 0.82, blue: 0.36, alpha: 1),
                    UIColor(red: 0.66, green: 0.36, blue: 0.06, alpha: 1), .white)
        case .crown:
            return (UIColor(red: 1.00, green: 0.92, blue: 0.55, alpha: 1),
                    UIColor(red: 0.82, green: 0.52, blue: 0.05, alpha: 1),
                    UIColor(red: 0.28, green: 0.16, blue: 0.0, alpha: 1))
        case .royalSeal:
            return (UIColor(red: 0.92, green: 0.30, blue: 0.30, alpha: 1),
                    UIColor(red: 0.48, green: 0.06, blue: 0.10, alpha: 1), .white)
        }
    }

    /// One or two characters standing in for the character art.
    private static func glyph(for symbol: Symbol) -> String {
        switch symbol {
        case .shield:    return "SH"
        case .chalice:   return "CH"
        case .sceptre:   return "SC"
        case .joker:     return "J"
        case .knight:    return "KN"
        case .princess:  return "Ps"
        case .prince:    return "P"
        case .queen:     return "Q"
        case .king:      return "K"
        case .crown:     return "W"      // wild
        case .royalSeal: return "★"      // scatter
        }
    }

    private static func placeholder(for symbol: Symbol) -> UIImage {
        let size = CGSize(width: 512, height: 512)
        let (top, bottom, ink) = palette(for: symbol)

        let renderer = UIGraphicsImageRenderer(size: size, format: {
            let f = UIGraphicsImageRendererFormat.default()
            f.opaque = false
            f.scale = 1
            return f
        }())

        return renderer.image { ctx in
            let cg = ctx.cgContext
            let inset: CGFloat = 34
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)

            // Rounded-square medallion with a vertical gradient body.
            let body = UIBezierPath(roundedRect: rect, cornerRadius: rect.width * 0.22)
            cg.saveGState()
            body.addClip()
            let space = CGColorSpaceCreateDeviceRGB()
            if let grad = CGGradient(colorsSpace: space,
                                     colors: [top.cgColor, bottom.cgColor] as CFArray,
                                     locations: [0, 1]) {
                cg.drawLinearGradient(grad,
                                      start: CGPoint(x: rect.midX, y: rect.minY),
                                      end: CGPoint(x: rect.midX, y: rect.maxY),
                                      options: [])
            }

            // Specular sweep across the upper third, so it reads as a curved surface
            // under the scene's upper-left key light.
            let sheen = UIBezierPath(ovalIn: CGRect(x: rect.minX - rect.width * 0.25,
                                                    y: rect.minY - rect.height * 0.62,
                                                    width: rect.width * 1.5,
                                                    height: rect.height * 0.95))
            UIColor(white: 1, alpha: 0.18).setFill()
            sheen.fill()
            cg.restoreGState()

            // Gold bevel.
            UIColor(red: 0.92, green: 0.76, blue: 0.36, alpha: 0.95).setStroke()
            body.lineWidth = 10
            body.stroke()

            // Glyph.
            let text = glyph(for: symbol)
            let fontSize: CGFloat = text.count > 1 ? 168 : 232
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .heavy),
                .foregroundColor: ink,
            ]
            let bounds = (text as NSString).size(withAttributes: attrs)
            // Nudge up to leave room for the label underneath.
            let origin = CGPoint(x: rect.midX - bounds.width / 2,
                                 y: rect.midY - bounds.height / 2 - 26)
            // Soft drop so the glyph separates from the gradient.
            cg.setShadow(offset: CGSize(width: 0, height: 4), blur: 10,
                         color: UIColor(white: 0, alpha: 0.45).cgColor)
            (text as NSString).draw(at: origin, withAttributes: attrs)
            cg.setShadow(offset: .zero, blur: 0, color: nil)

            // Name, so a playtester can read the grid without decoding initials.
            let nameAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 40, weight: .semibold),
                .foregroundColor: ink.withAlphaComponent(0.85),
            ]
            let name = symbol.displayName.uppercased() as NSString
            let nameSize = name.size(withAttributes: nameAttrs)
            name.draw(at: CGPoint(x: rect.midX - nameSize.width / 2,
                                  y: rect.maxY - nameSize.height - 26),
                      withAttributes: nameAttrs)
        }
    }
}
