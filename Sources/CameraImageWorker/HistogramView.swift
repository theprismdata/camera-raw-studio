import AppKit
import SwiftUI

struct HistogramData: Equatable, Sendable {
    let red: [Double]
    let green: [Double]
    let blue: [Double]

    static let empty = HistogramData(
        red: Array(repeating: 0, count: 128),
        green: Array(repeating: 0, count: 128),
        blue: Array(repeating: 0, count: 128)
    )

    static func make(from image: NSImage) -> HistogramData {
        guard
            let data = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: data),
            let pixels = bitmap.bitmapData
        else { return .empty }

        let bins = 128
        var red = [Double](repeating: 0, count: bins)
        var green = [Double](repeating: 0, count: bins)
        var blue = [Double](repeating: 0, count: bins)
        let samplesTarget = 120_000
        let step = max(1, Int(sqrt(Double(bitmap.pixelsWide * bitmap.pixelsHigh) / Double(samplesTarget))))
        let samplesPerPixel = bitmap.samplesPerPixel

        for y in stride(from: 0, to: bitmap.pixelsHigh, by: step) {
            let row = pixels + y * bitmap.bytesPerRow
            for x in stride(from: 0, to: bitmap.pixelsWide, by: step) {
                let pixel = row + x * samplesPerPixel
                red[min(bins - 1, Int(pixel[0]) * bins / 256)] += 1
                green[min(bins - 1, Int(pixel[1]) * bins / 256)] += 1
                blue[min(bins - 1, Int(pixel[2]) * bins / 256)] += 1
            }
        }
        let maximum = max(1, red.max() ?? 1, green.max() ?? 1, blue.max() ?? 1)
        return HistogramData(
            red: red.map { $0 / maximum },
            green: green.map { $0 / maximum },
            blue: blue.map { $0 / maximum }
        )
    }
}

struct HistogramView: View {
    let data: HistogramData

    var body: some View {
        Canvas { context, size in
            draw(data.red, color: .red, in: context, size: size)
            draw(data.green, color: .green, in: context, size: size)
            draw(data.blue, color: .blue, in: context, size: size)
        }
        .background(Color.black.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(.white.opacity(0.12))
        }
        .frame(height: 92)
    }

    private func draw(
        _ values: [Double],
        color: Color,
        in context: GraphicsContext,
        size: CGSize
    ) {
        guard values.count > 1 else { return }
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height))
        for (index, value) in values.enumerated() {
            let x = CGFloat(index) / CGFloat(values.count - 1) * size.width
            let y = size.height - CGFloat(value) * size.height
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()
        context.fill(path, with: .color(color.opacity(0.38)))
        context.stroke(path, with: .color(color.opacity(0.85)), lineWidth: 0.7)
    }
}
