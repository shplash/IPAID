import CoreGraphics
import XCTest
@testable import IPAIDCore

final class IconFittingTests: XCTestCase {

    private let canvas = CGSize(width: 1024, height: 1024)

    func testSquareSourceFillsTheCanvas() {
        let rect = IPAIconFitting.rect(for: CGSize(width: 1024, height: 1024), in: canvas)

        XCTAssertEqual(rect.origin.x, 0, accuracy: 0.5)
        XCTAssertEqual(rect.origin.y, 0, accuracy: 0.5)
        XCTAssertEqual(rect.size.width, 1024, accuracy: 0.5)
        XCTAssertEqual(rect.size.height, 1024, accuracy: 0.5)
    }

    func testSmallSquareSourceIsUpscaledToFill() {
        let rect = IPAIconFitting.rect(for: CGSize(width: 128, height: 128), in: canvas)

        XCTAssertEqual(rect.size.width, 1024, accuracy: 0.5)
        XCTAssertEqual(rect.size.height, 1024, accuracy: 0.5)
        XCTAssertEqual(rect.origin.x, 0, accuracy: 0.5)
        XCTAssertTrue(IPAIconFitting.isUpscaling(source: CGSize(width: 128, height: 128), canvas: canvas))
    }

    func testLargeSourceIsNotReportedAsUpscaled() {
        XCTAssertFalse(
            IPAIconFitting.isUpscaling(source: CGSize(width: 2048, height: 2048), canvas: canvas)
        )
    }

    func testNonSquareSourceKeepsAspectRatioAndOverflows() {
        let source = CGSize(width: 512, height: 256)
        let rect = IPAIconFitting.rect(for: source, in: canvas)

        XCTAssertEqual(rect.size.height, 1024, accuracy: 0.5)
        XCTAssertEqual(rect.size.width, 2048, accuracy: 0.5)
        XCTAssertEqual(rect.size.width / rect.size.height, source.width / source.height, accuracy: 0.001)
        XCTAssertLessThan(rect.origin.x, 0)
        XCTAssertEqual(rect.origin.y, 0, accuracy: 0.5)
    }

    func testTallSourceIsCentredHorizontally() {
        let rect = IPAIconFitting.rect(for: CGSize(width: 256, height: 1024), in: canvas)

        XCTAssertEqual(rect.size.width, 256, accuracy: 0.5)
        XCTAssertEqual(rect.origin.x, (1024 - 256) / 2, accuracy: 0.5)
    }

    func testCanvasIsAlwaysCovered() {
        let sources = [
            CGSize(width: 1, height: 1),
            CGSize(width: 64, height: 64),
            CGSize(width: 4096, height: 1024),
            CGSize(width: 300, height: 900)
        ]

        for source in sources {
            let rect = IPAIconFitting.rect(for: source, in: canvas)

            XCTAssertLessThanOrEqual(rect.minX, 0.5, "\(source)")
            XCTAssertLessThanOrEqual(rect.minY, 0.5, "\(source)")
            XCTAssertGreaterThanOrEqual(rect.maxX, canvas.width - 0.5, "\(source)")
            XCTAssertGreaterThanOrEqual(rect.maxY, canvas.height - 0.5, "\(source)")
        }
    }

    func testDegenerateSourcesAreHandled() {
        let rect = IPAIconFitting.rect(for: .zero, in: canvas)
        XCTAssertEqual(IPAIconFitting.scale(for: .zero, in: canvas), 1, accuracy: 0.001)
        XCTAssertFalse(rect.isInfinite)
        XCTAssertFalse(rect.isNull)
    }
}
