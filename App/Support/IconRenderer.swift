import UIKit

enum IconRenderer {

    static func makeFiles(image: UIImage, plan: IPAIconPlan) -> IconRenderResult {
        var files: [String: Data] = [:]
        var problems: [String] = []
        let source = trimmed(image)

        for slot in plan.slots {
            guard let data = pngData(
                image: source,
                width: slot.pixelWidth,
                height: slot.pixelHeight
            ) else {
                problems.append("Could not render \(slot.path).")
                continue
            }

            files[slot.path] = data
        }

        if source.size.width < 512 || source.size.height < 512 {
            problems.append("A larger source image (1024×1024 or more) gives sharper results.")
        }

        return IconRenderResult(files: files, problems: problems)
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

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let rendered = renderer.image { _ in
            let scale = max(
                size.width / image.size.width,
                size.height / image.size.height
            )
            let drawSize = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )
            let origin = CGPoint(
                x: (size.width - drawSize.width) / 2,
                y: (size.height - drawSize.height) / 2
            )

            image.draw(in: CGRect(origin: origin, size: drawSize))
        }

        return rendered.pngData()
    }

    static func trimmed(_ image: UIImage) -> UIImage {
        guard image.imageOrientation == .up, let cgImage = image.cgImage else {
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
