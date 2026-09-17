import CoreMotion
import Combine

/// A source of attitude samples. `CoreMotionAttitude` is the production one;
/// tests inject a scripted fake so the start/stop lifecycle can be pinned
/// without hardware (roadmap M4: "CoreMotion starts/stops with card state").
protocol AttitudeProviding: AnyObject {
    /// `true` when a real motion sensor can supply attitude samples.
    var hasSensor: Bool { get }
    /// Begin delivering attitude samples, on the main queue.
    func begin(_ onSample: @escaping (CGVector) -> Void)
    /// Stop delivering samples.
    func end()
}

/// Device attitude via CoreMotion — **attitude only** (roll + pitch).
/// Deliberately not a health-adjacent API, so no `NSMotionUsageDescription`
/// / permission is required (roadmap: "CoreMotion attitude needs no
/// permission").
final class CoreMotionAttitude: AttitudeProviding {
    private let manager = CMMotionManager()

    var hasSensor: Bool { manager.isDeviceMotionAvailable }

    func begin(_ onSample: @escaping (CGVector) -> Void) {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { motion, _ in
            guard let motion else { return }
            onSample(CGVector(dx: motion.attitude.roll, dy: motion.attitude.pitch))
        }
    }

    func end() {
        manager.stopDeviceMotionUpdates()
    }
}

/// Smoothly tracks device attitude to drive the holo finish's view angle.
///
/// Tracking starts and stops with the card's face-up state, so there is
/// **no idle draw** when no card is revealed (roadmap M4: no idle battery
/// drain). When no sensor data exists (simulator, or a sensor-less device)
/// `isLive` stays false and the holo layer switches to a smooth time-based
/// shimmer instead of a dead sheen.
final class MotionTilt: ObservableObject {

    /// The smoothed view angle — `(roll, pitch)` in radians.
    @Published private(set) var angle = CGVector.zero

    /// `true` while real device-motion data is driving `angle`.
    @Published private(set) var isLive = false

    private let source: AttitudeProviding
    private var smoothed = CGVector.zero
    private var isTracking = false

    init(source: AttitudeProviding = CoreMotionAttitude()) {
        self.source = source
    }

    /// Begin/stop attitude tracking as the card's face-up state changes.
    /// Idempotent in both directions — safe to call on every state change.
    func setFaceUp(_ faceUp: Bool) {
        if faceUp && !isTracking {
            start()
        } else if !faceUp && isTracking {
            stop()
        }
    }

    private func start() {
        isTracking = true
        smoothed = .zero
        angle = .zero
        guard source.hasSensor else {
            // Simulator / sensor-less device: the holo layer reads `isLive`
            // each frame and falls back to a time-based shimmer.
            isLive = false
            return
        }
        isLive = true
        // The CoreMotion callback already runs on the main queue (`.main`
        // above), so ingest directly — no extra hop.
        source.begin { [weak self] sample in
            self?.ingest(sample)
        }
    }

    private func stop() {
        isTracking = false
        isLive = false
        source.end()
    }

    private func ingest(_ sample: CGVector) {
        guard isTracking else { return }   // ignore in-flight samples after stop
        smoothed = Self.smooth(prev: smoothed, target: sample)
        angle = smoothed
    }

    /// Exponential smoothing — the tilt reads immediately but never jitters.
    /// `k` is the fraction of the previous value kept per sample (0.8 keeps
    /// 80%, i.e. moves 20% toward the target each sample).
    static func smooth(prev: CGVector, target: CGVector, k: Double = 0.8) -> CGVector {
        CGVector(dx: prev.dx * k + target.dx * (1 - k),
                 dy: prev.dy * k + target.dy * (1 - k))
    }
}
