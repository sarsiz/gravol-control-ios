import CoreMotion
import Foundation

final class TiltVolumeController {
    enum Direction {
        case towardUser
        case awayFromUser
    }

    var onDirection: ((Direction) -> Void)?

    private let motionManager = CMMotionManager()
    private var pitchThreshold: Double
    private var hysteresis: Double
    private let stepInterval: TimeInterval

    private var lowPassPitch: Double = 0
    private var isInsideTowardBand = false
    private var isInsideAwayBand = false
    private var lastStepAt = Date.distantPast

    init(pitchThreshold: Double, hysteresis: Double, stepInterval: TimeInterval) {
        self.pitchThreshold = pitchThreshold
        self.hysteresis = hysteresis
        self.stepInterval = stepInterval
    }

    func updateThresholds(pitchThreshold: Double, hysteresis: Double) {
        self.pitchThreshold = max(0.08, pitchThreshold)
        self.hysteresis = max(0.04, hysteresis)
    }

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        guard !motionManager.isDeviceMotionActive else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.process(pitch: motion.attitude.pitch)
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        isInsideTowardBand = false
        isInsideAwayBand = false
        lowPassPitch = 0
    }

    private func process(pitch: Double) {
        // Low-pass filter to smooth hand jitter.
        let alpha = 0.2
        lowPassPitch = alpha * pitch + (1.0 - alpha) * lowPassPitch

        let now = Date()
        guard now.timeIntervalSince(lastStepAt) >= stepInterval else { return }

        let towardEnter = pitchThreshold
        let towardExit = pitchThreshold - hysteresis
        let awayEnter = -pitchThreshold
        let awayExit = -pitchThreshold + hysteresis

        if lowPassPitch >= towardEnter {
            isInsideTowardBand = true
            isInsideAwayBand = false
            lastStepAt = now
            onDirection?(.towardUser)
            return
        }

        if lowPassPitch <= awayEnter {
            isInsideAwayBand = true
            isInsideTowardBand = false
            lastStepAt = now
            onDirection?(.awayFromUser)
            return
        }

        if isInsideTowardBand, lowPassPitch < towardExit {
            isInsideTowardBand = false
        }

        if isInsideAwayBand, lowPassPitch > awayExit {
            isInsideAwayBand = false
        }
    }
}
