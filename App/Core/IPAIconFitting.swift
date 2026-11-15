import CoreGraphics
import Foundation

enum IPAIconFitting {

    static let canvasSize: CGFloat = 1024

    static func scale(for source: CGSize, in canvas: CGSize) -> CGFloat {
        guard source.width > 0, source.height > 0,
              canvas.width > 0, canvas.height > 0 else {
            return 1
        }

        return max(canvas.width / source.width, canvas.height / source.height)
    }

    static func rect(for source: CGSize, in canvas: CGSize) -> CGRect {
        let factor = scale(for: source, in: canvas)
        let size = CGSize(
            width: source.width * factor,
            height: source.height * factor
        )

        return CGRect(
            x: (canvas.width - size.width) / 2,
            y: (canvas.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    static func isUpscaling(source: CGSize, canvas: CGSize) -> Bool {
        source.width < canvas.width || source.height < canvas.height
    }
}
