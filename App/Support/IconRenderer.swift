import UIKit

enum IconRenderer {

    static func makeFiles(image: UIImage, plan: IPAIconPlan) -> IconRenderResult {
        var files: [String: Data] = [:]
        var problems: [String] = []

        for slot in plan.slots {
            guard let data = pngData(
                image: image,
                width: slot.pixelWidth,
                height: slot.pixelHeight
            ) else {
                problems.append("Could not render \(slot.path).")
                continue
            }

            files[slot.path] = data
        }

        if image.size.width < 512 || image.size.height < 512 {
            problems.append("A larger source image (1024×1024 or more) gives sharper results.")
        }

        return IconRenderResult(files: files, problems: problems)
    }

    static func pngData(image: UIImage, width: Int, height: Int) -> Data? {
        guard width > 0, height > 0 else {
            return nil
        }

        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let rendered = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

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
}

struct IconRenderResult {
    let files: [String: Data]
    let problems: [String]
}
