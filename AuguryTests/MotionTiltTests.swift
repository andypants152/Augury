import XCTest
@testable import Augury

/// A scripted attitude source standing in for CoreMotion in tests — the real
/// one is hardware-dependent and reports no sensor in the simulator.
private final class FakeAttitude: AttitudeProviding {
    var hasSensor = true
    private(set) var onSample: ((CGVector) -> Void)?
    var beginCount = 0
    var endCount = 0

    func begin(_ onSample: @escaping (CGVector) -> Void) {
        self.onSample = onSample
        beginCount += 1
    }

    func end() {
        // CoreMotion can deliver in-flight callbacks after a stop, so keep the
        // callback registered — the production code's `isTracking` guard must
        // be what makes late samples harmless.
        endCount += 1
    }

    func send(roll: Double, pitch: Double) {
        onSample?(CGVector(dx: roll, dy: pitch))
    }
}

/// Roadmap M4: "CoreMotion starts/stops with card state (no idle draw)".
final class MotionTiltTests: XCTestCase {

    func testFaceUpStartsTrackingAndFaceDownStopsIt() {
        let source = FakeAttitude()
        let tilt = MotionTilt(source: source)

        tilt.setFaceUp(true)
        XCTAssertEqual(source.beginCount, 1)
        XCTAssertTrue(tilt.isLive)

        tilt.setFaceUp(true)              // idempotent
        XCTAssertEqual(source.beginCount, 1)

        tilt.setFaceUp(false)
        XCTAssertEqual(source.endCount, 1)
        XCTAssertFalse(tilt.isLive)

        tilt.setFaceUp(false)             // idempotent
        XCTAssertEqual(source.endCount, 1)
    }

    func testNoSensorNeverBeginsAndStaysInShimmerMode() {
        let source = FakeAttitude()
        source.hasSensor = false
        let tilt = MotionTilt(source: source)

        tilt.setFaceUp(true)
        XCTAssertEqual(source.beginCount, 0)
        XCTAssertFalse(tilt.isLive)      // the holo layer falls back to a time-based shimmer
    }

    func testSamplesSmoothIntoTheAngle() {
        let source = FakeAttitude()
        let tilt = MotionTilt(source: source)
        tilt.setFaceUp(true)

        // A constant attitude: the exponential smoothing converges onto it.
        for _ in 0..<200 { source.send(roll: 0.5, pitch: -0.25) }
        XCTAssertEqual(tilt.angle.dx, 0.5, accuracy: 0.001)
        XCTAssertEqual(tilt.angle.dy, -0.25, accuracy: 0.001)
        XCTAssertTrue(tilt.isLive)
    }

    func testLateSamplesAreIgnoredAfterStop() {
        let source = FakeAttitude()
        let tilt = MotionTilt(source: source)

        tilt.setFaceUp(true)
        source.send(roll: 0.5, pitch: 0)
        tilt.setFaceUp(false)

        let frozen = tilt.angle
        source.send(roll: 1.0, pitch: 1.0)   // an in-flight sample after stop
        XCTAssertEqual(tilt.angle.dx, frozen.dx)
        XCTAssertEqual(tilt.angle.dy, frozen.dy)
        XCTAssertFalse(tilt.isLive)
    }
}
