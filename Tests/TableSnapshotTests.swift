import ImageIO
import SpriteKit
import XCTest
@testable import iPinball

/// Renders the built table off screen. It proves the scene assembles and draws
/// without a display, and — with `IPINBALL_SNAPSHOT_DIR` set — writes a PNG,
/// which is the only way to look at the table when the Mac is locked.
final class TableSnapshotTests: XCTestCase {

    @MainActor
    func testTheTableRendersOffScreen() throws {
        let size = CGSize(width: 560, height: 940)
        let scene = PinballScene()
        scene.size = size
        scene.scaleMode = .resizeFill

        let view = SKView(frame: CGRect(origin: .zero, size: size))
        view.presentScene(scene)

        guard let texture = view.texture(from: scene),
              let image = texture.cgImage() as CGImage? else {
            throw XCTSkip("no renderer available in this environment")
        }

        XCTAssertGreaterThan(image.width, 0)
        XCTAssertGreaterThan(image.height, 0)
        XCTAssertFalse(scene.children.isEmpty, "the table built no nodes")

        guard let directory = ProcessInfo.processInfo
            .environment["IPINBALL_SNAPSHOT_DIR"] else { return }

        let url = URL(fileURLWithPath: directory)
            .appendingPathComponent("table.png")
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, "public.png" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }
}
