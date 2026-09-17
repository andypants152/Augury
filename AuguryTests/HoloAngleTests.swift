import XCTest
@testable import Augury

/// The holo's drive-source priority (roadmap M4: Reduce Motion → fixed angle,
/// no shimmer; live tilt; else time-based shimmer). Pure logic in `HoloLayer`,
/// so it is testable without a view hierarchy or a GPU.
final class HoloAngleTests: XCTestCase {

    func testReduceMotionWinsOverEverything() {
        let a = HoloLayer.angle(reduceMotion: true, isLive: true,
                                liveAngle: CGVector(dx: 1.0, dy: 1.0), t: 99)
        XCTAssertEqual(a.dx, HoloLayer.fixedAngle.dx)
        XCTAssertEqual(a.dy, HoloLayer.fixedAngle.dy)
    }

    func testLiveTiltWinsOverShimmer() {
        let live = CGVector(dx: 0.3, dy: -0.4)
        let a = HoloLayer.angle(reduceMotion: false, isLive: true,
                                liveAngle: live, t: 99)
        XCTAssertEqual(a.dx, live.dx)
        XCTAssertEqual(a.dy, live.dy)
    }

    func testNoSensorFallsBackToShimmer() {
        let a = HoloLayer.angle(reduceMotion: false, isLive: false,
                                liveAngle: CGVector(dx: 0.9, dy: 0.9), t: 1.0)
        let expected = HoloLayer.shimmer(1.0)
        XCTAssertEqual(a.dx, expected.dx, accuracy: 0.0001)
        XCTAssertEqual(a.dy, expected.dy, accuracy: 0.0001)
    }

    func testShimmerIsAlive() {
        // Two well-separated times must give different angles — a frozen time
        // would mean a dead sheen (the no-sensor fallback must still feel alive).
        let a = HoloLayer.shimmer(1.0)
        let b = HoloLayer.shimmer(30.0)
        XCTAssertNotEqual(a.dx, b.dx, accuracy: 0.0001)
        XCTAssertNotEqual(a.dy, b.dy, accuracy: 0.0001)
    }

    func testShimmerStaysBounded() {
        for t in stride(from: 0.0, through: 200.0, by: 0.37) {
            let a = HoloLayer.shimmer(t)
            XCTAssertEqual(abs(a.dx), abs(a.dx), accuracy: 0)   // sanity: finite
            XCTAssertLessThan(abs(a.dx), 0.41)
            XCTAssertLessThan(abs(a.dy), 0.41)
        }
    }
}
