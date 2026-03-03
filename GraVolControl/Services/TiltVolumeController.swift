import CoreMotion
import Foundation

final class TiltVolumeController {
    enum Direction {
        case towardUser
        case awayFromUser
    }

    var onDirection: ((Direction) -> Void)?
    var onTiltDeltaChanged: ((Double) -> Void)?

    private let motionManager = CMMotionManager()
    private var pitchThreshold: Double
    private var hysteresis: Double
    private let stepInterval: TimeInterval
    private let holdDuration: TimeInterval = 0.15
    private let maxRotationNoise: Double = 2.8

    private var lowPassPitch: Double = 0
    private var towardHoldStart: Date?
    private var awayHoldStart: Date?
    private var lastStepAt = Date.distantPast

    init(pitchThreshold: Double, hysteresis: Double, stepInterval: TimeInterval) {
        self.pitchThreshold = pitchThreshold
        self.hysteresis = hysteresis
        self.stepInterval = stepInterval
    }

    func updateThresholds(pitchThreshold: Double, hysteresis: Double) {
        self.pitchThreshold = max(0.05, pitchThreshold)
        self.hysteresis = max(0.025, hysteresis)
    }

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        guard !motionManager.isDeviceMotionActive else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / 45.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.process(motion)
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        towardHoldStart = nil
        awayHoldStart = nil
        lowPassPitch = 0
        onTiltDeltaChanged?(0)
    }

    func recenterBaseline() {
        towardHoldStart = nil
        awayHoldStart = nil
    }

    private func process(_ motion: CMDeviceMotion) {
        let alpha = 0.2
        lowPassPitch = alpha * motion.attitude.pitch + (1.0 - alpha) * lowPassPitch
        let signedPitchFromHorizontal = lowPassPitch
        onTiltDeltaChanged?(signedPitchFromHorizontal)

        let rotationNoise = abs(motion.rotationRate.x) + abs(motion.rotationRate.y) + abs(motion.rotationRate.z)
        if rotationNoise > maxRotationNoise {
            towardHoldStart = nil
            awayHoldStart = nil
            return
        }

        let now = Date()
        guard now.timeIntervalSince(lastStepAt) >= stepInterval else { return }

        let towardEnter = pitchThreshold
        let towardExit = pitchThreshold - hysteresis
        let awayEnter = -pitchThreshold
        let awayExit = -pitchThreshold + hysteresis

        if signedPitchFromHorizontal >= towardEnter {
            towardHoldStart = towardHoldStart ?? now
            awayHoldStart = nil
            if let towardHoldStart, now.timeIntervalSince(towardHoldStart) >= holdDuration {
                lastStepAt = now
                onDirection?(.towardUser)
                self.towardHoldStart = nil
            }
            return
        }

        if signedPitchFromHorizontal <= awayEnter {
            awayHoldStart = awayHoldStart ?? now
            towardHoldStart = nil
            if let awayHoldStart, now.timeIntervalSince(awayHoldStart) >= holdDuration {
                lastStepAt = now
                onDirection?(.awayFromUser)
                self.awayHoldStart = nil
            }
            return
        }

        if signedPitchFromHorizontal < towardExit {
            towardHoldStart = nil
        }

        if signedPitchFromHorizontal > awayExit {
            awayHoldStart = nil
        }
    }
}
