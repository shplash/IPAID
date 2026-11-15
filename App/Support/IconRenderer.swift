import UIKit

enum IconRenderer {

    private static let analysisLimit: CGFloat = 2048

    static func makeFiles(image: UIImage, plan: IPAIconPlan) -> IconRenderResult {
        var files: [String: Data] = [:]
        var problems: [String] = []
        let canvas = canvasImage(from: image)

        if IPAIconFitting.isUpscaling(
            source: canvasSize(of: image),
            canvas: CGSize(
                width: IPAIconFitting.canvasSize,
                height: IPAIconFitting.canvasSize
            )
        ) {
            problems.append("This image is smaller than 1024×1024, so it is scaled up.")
        }

        for slot in plan.slots {
            guard let data = pngData(
                image: canvas,
                width: slot.pixelWidth,
                height: slot.pixelHeight
            ) else {
                problems.append("Could not render \(slot.path).")
                continue
            }

            files[slot.path] = data
        }

        return IconRenderResult(files: files, problems: problems)
    }

    static func canvasImage(from image: UIImage) -> UIImage {
        let side = IPAIconFitting.canvasSize
        let prepared = trimmed(normalized(image, limit: analysisLimit))
        let size = CGSize(width: side, height: side)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.interpolationQuality = .high
            prepared.draw(in: IPAIconFitting.rect(for: prepared.size, in: size))
        }
    }

    static func canvasSize(of image: UIImage) -> CGSize {
        CGSize(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale
        )
    }

    static func normalized(_ image: UIImage, limit: CGFloat) -> UIImage {
        let pixels = CGSize(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale
        )

        guard pixels.width > 0, pixels.height > 0 else {
            return image
        }

        let factor = min(1, limit / max(pixels.width, pixels.height))
        let target = CGSize(
            width: max(1, (pixels.width * factor).rounded()),
            height: max(1, (pixels.height * factor).rounded())
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1

        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    static func pngData(image: UIImage, width: Int, height: Int) -> Data? {
        guard width > 0, height > 0,
              image.size.width > 0, image.size.height > 0 else {
            return nil
        }

        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1

        let rect = IPAIconFitting.rect(for: image.size, in: size)

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let rendered = renderer.image { context in
            context.cgContext.interpolationQuality = .high
            image.draw(in: rect)
        }

        return rendered.pngData()
    }

    static func canvasData(image: UIImage, size: CGFloat = IPAIconFitting.canvasSize) -> Data? {
        pngData(image: canvasImage(from: image), width: Int(size), height: Int(size))
    }

    static func trimmed(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else {
            return image
        }

        let width = cgImage.width
        let height = cgImage.height

        guard width > 1, height > 1 else {
            return image
        }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let base = buffer.baseAddress,
                  let context = CGContext(
                    data: base,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo
                  ) else {
                return false
            }

            context.draw(
                cgImage,
                in: CGRect(x: 0, y: 0, width: width, height: height)
            )

            return true
        }

        guard drawn else {
            return image
        }

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 8 {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }

        guard maxX >= minX, maxY >= minY else {
            return image
        }

        let bounds = CGRect(
            x: minX,
            y: minY,
            width: maxX - minX + 1,
            height: maxY - minY + 1
        )

        guard bounds.width < CGFloat(width) || bounds.height < CGFloat(height) else {
            return image
        }

        guard let cropped = cgImage.cropping(to: bounds) else {
            return image
        }

        return UIImage(
            cgImage: cropped,
            scale: image.scale,
            orientation: .up
        )
    }
}

struct IconRenderResult {
    let files: [String: Data]
    let problems: [String]
}
