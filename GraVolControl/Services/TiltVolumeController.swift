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
    private var towardPitchThreshold: Double
    private var awayPitchThreshold: Double
    private var towardHysteresis: Double
    private var awayHysteresis: Double
    private let stepInterval: TimeInterval
    private let holdDuration: TimeInterval = 0.22
    private let maxRotationNoise: Double = 2.8

    private var lowPassPitch: Double = 0
    private var towardHoldStart: Date?
    private var awayHoldStart: Date?
    private var lastStepAt = Date.distantPast

    init(
        towardPitchThreshold: Double,
        awayPitchThreshold: Double,
        towardHysteresis: Double,
        awayHysteresis: Double,
        stepInterval: TimeInterval
    ) {
        self.towardPitchThreshold = towardPitchThreshold
        self.awayPitchThreshold = awayPitchThreshold
        self.towardHysteresis = towardHysteresis
        self.awayHysteresis = awayHysteresis
        self.stepInterval = stepInterval
    }

    func updateThresholds(
        towardPitchThreshold: Double,
        awayPitchThreshold: Double,
        towardHysteresis: Double,
        awayHysteresis: Double
    ) {
        self.towardPitchThreshold = max(0.01, abs(towardPitchThreshold))
        self.awayPitchThreshold = max(0.01, abs(awayPitchThreshold))
        self.towardHysteresis = max(0.008, abs(towardHysteresis))
        self.awayHysteresis = max(0.008, abs(awayHysteresis))
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

        let towardEnter = towardPitchThreshold
        let towardExit = towardPitchThreshold - towardHysteresis
        let awayEnter = -awayPitchThreshold
        let awayExit = -awayPitchThreshold + awayHysteresis

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
