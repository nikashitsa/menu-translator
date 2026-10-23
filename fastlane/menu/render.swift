// Renders the fictional Mexican menu used for App Store screenshots:
//   swift fastlane/menu/render.swift fastlane/screenshot-menu.jpg
// Also prints each dish's rect (normalized, top-left origin) for `ScreenshotMode`.
import AppKit
import Foundation

let size = CGSize(width: 1400, height: 2400)
let marginX: CGFloat = 200
let paper = NSColor(red: 0.965, green: 0.93, blue: 0.86, alpha: 1)
let ink = NSColor(red: 0.16, green: 0.12, blue: 0.1, alpha: 1)
let accent = NSColor(red: 0.62, green: 0.16, blue: 0.1, alpha: 1)

let sections: [(String, [(String, String?, Int)])] = [
    ("ANTOJITOS", [
        ("Guacamole con totopos", nil, 95),
        ("Quesadillas de flor de calabaza", nil, 85),
        ("Elote asado con mayonesa y chile", nil, 55),
    ]),
    ("TACOS (orden de 3)", [
        ("Tacos al pastor con piña", nil, 75),
        ("Tacos de carnitas", nil, 80),
        ("Tacos de pescado estilo Baja", nil, 95),
    ]),
    ("PLATOS FUERTES", [
        ("Enchiladas verdes de pollo", "con crema, queso fresco y arroz", 145),
        ("Mole poblano", "pierna de pollo, arroz y tortillas", 165),
        ("Chiles rellenos de queso", nil, 150),
        ("Cochinita pibil", "con cebolla morada y tortillas", 155),
    ]),
    ("POSTRES Y BEBIDAS", [
        ("Churros con chocolate", nil, 70),
        ("Flan napolitano", nil, 65),
        ("Agua de horchata", nil, 40),
        ("Agua de jamaica", nil, 40),
    ]),
]

func font(_ name: String, _ size: CGFloat) -> NSFont { NSFont(name: name, size: size) ?? .systemFont(ofSize: size) }
let titleFont = font("Georgia-Bold", 96), subtitleFont = font("Georgia-Italic", 40)
let sectionFont = font("Georgia-Bold", 46), dishFont = font("Georgia", 42), noteFont = font("Georgia-Italic", 32)

let image = NSImage(size: size)
var rects: [(String, CGRect)] = []
image.lockFocusFlipped(true)
paper.setFill()
CGRect(origin: .zero, size: size).fill()
// Paper grain.
var generator = SystemRandomNumberGenerator()
for _ in 0..<60_000 {
    let shade = CGFloat.random(in: 0...1, using: &generator)
    NSColor(white: shade, alpha: 0.035).setFill()
    CGRect(x: .random(in: 0..<size.width), y: .random(in: 0..<size.height), width: 2, height: 2).fill()
}
accent.setStroke()
let border = NSBezierPath(rect: CGRect(x: marginX - 50, y: 250, width: size.width - 2 * (marginX - 50), height: size.height - 500))
border.lineWidth = 4
border.stroke()

func draw(_ text: String, _ font: NSFont, _ color: NSColor, x: CGFloat, y: CGFloat, alignRight: Bool = false) -> CGRect {
    let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
    let width = string.size().width
    let origin = CGPoint(x: alignRight ? x - width : x, y: y)
    string.draw(at: origin)
    return CGRect(origin: origin, size: string.size())
}
func centered(_ text: String, _ font: NSFont, _ color: NSColor, y: CGFloat) {
    let width = NSAttributedString(string: text, attributes: [.font: font]).size().width
    _ = draw(text, font, color, x: (size.width - width) / 2, y: y)
}

centered("COCINA MEXICANA", titleFont, accent, y: 320)
centered("Menú del día · comida casera", subtitleFont, ink, y: 440)
var y: CGFloat = 560
for (title, dishes) in sections {
    _ = draw(title, sectionFont, accent, x: marginX, y: y)
    y += 78
    for (name, note, price) in dishes {
        let nameRect = draw(name, dishFont, ink, x: marginX, y: y)
        let priceRect = draw("$\(price)", dishFont, ink, x: size.width - marginX, y: y, alignRight: true)
        // Dot leaders between the name and the price.
        var dotX = nameRect.maxX + 14
        while dotX < priceRect.minX - 14 {
            _ = draw(".", dishFont, ink.withAlphaComponent(0.6), x: dotX, y: y)
            dotX += 16
        }
        var rect = nameRect.union(priceRect)
        y += 58
        if let note {
            rect = rect.union(draw(note, noteFont, ink.withAlphaComponent(0.8), x: marginX + 20, y: y - 4))
            y += 46
        }
        rects.append((name, rect))
        y += 8
    }
    y += 40
}
image.unlockFocus()

let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85])!
try! jpeg.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
for (name, rect) in rects {
    let n = [rect.minX / size.width, rect.minY / size.height, rect.width / size.width, rect.height / size.height]
        .map { String(format: "%.4f", $0) }
    print("\(name): \(n.joined(separator: ", "))")
}
