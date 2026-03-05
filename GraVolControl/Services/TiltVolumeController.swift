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
    private let holdDuration: TimeInterval = 0.12
    private let maxRotationNoise: Double = 14.0

    private var lowPassPitch: Double = 0
    private var didInitializeLowPass = false
    private var towardHoldStart: Date?
    private var awayHoldStart: Date?
    private var lastStepAt = Date.distantPast
    private var lastTelemetryLogAt = Date.distantPast

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
        VolumeDiagnostics.log(
            "tilt.thresholds up=\(Int((self.towardPitchThreshold * 180 / .pi).rounded()))° down=\(Int((self.awayPitchThreshold * 180 / .pi).rounded()))° " +
            "hUp=\(Int((self.towardHysteresis * 180 / .pi).rounded()))° hDown=\(Int((self.awayHysteresis * 180 / .pi).rounded()))°"
        )
    }

    func start() {
        guard motionManager.isDeviceMotionAvailable else {
            VolumeDiagnostics.log("tilt.start blocked deviceMotionUnavailable")
            return
        }
        guard !motionManager.isDeviceMotionActive else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / 45.0
        VolumeDiagnostics.log("tilt.start intervalHz=45 hold=\(String(format: "%.2f", holdDuration))s step=\(String(format: "%.2f", stepInterval))s")
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
        didInitializeLowPass = false
        onTiltDeltaChanged?(0)
        VolumeDiagnostics.log("tilt.stop")
    }

    func recenterBaseline() {
        towardHoldStart = nil
        awayHoldStart = nil
    }

    private func process(_ motion: CMDeviceMotion) {
        let alpha = 0.2
        if !didInitializeLowPass {
            lowPassPitch = motion.attitude.pitch
            didInitializeLowPass = true
        }
        lowPassPitch = alpha * motion.attitude.pitch + (1.0 - alpha) * lowPassPitch
        let signedPitchFromHorizontal = lowPassPitch
        onTiltDeltaChanged?(signedPitchFromHorizontal)

        let rotationNoise = abs(motion.rotationRate.x) + abs(motion.rotationRate.y) + abs(motion.rotationRate.z)
        let now = Date()

        if now.timeIntervalSince(lastTelemetryLogAt) >= 0.35 {
            lastTelemetryLogAt = now
            let pitchDeg = signedPitchFromHorizontal * 180 / .pi
            let upDeg = towardPitchThreshold * 180 / .pi
            let downDeg = awayPitchThreshold * 180 / .pi
            VolumeDiagnostics.log(
                "tilt.sample pitch=\(String(format: "%+.1f", pitchDeg))° up>=\(String(format: "%.1f", upDeg))° down<=-\(String(format: "%.1f", downDeg))° " +
                "noise=\(String(format: "%.2f", rotationNoise)) holdU=\(towardHoldStart != nil) holdD=\(awayHoldStart != nil)"
            )
        }

        if rotationNoise > maxRotationNoise {
            if towardHoldStart != nil || awayHoldStart != nil {
                VolumeDiagnostics.log("tilt.noise reset noise=\(String(format: "%.2f", rotationNoise))")
            }
            towardHoldStart = nil
            awayHoldStart = nil
            return
        }

        guard now.timeIntervalSince(lastStepAt) >= stepInterval else { return }

        let towardEnter = towardPitchThreshold
        let towardExit = towardPitchThreshold - towardHysteresis
        let awayEnter = -awayPitchThreshold
        let awayExit = -awayPitchThreshold + awayHysteresis

        if signedPitchFromHorizontal >= towardEnter {
            if towardHoldStart == nil {
                towardHoldStart = now
                VolumeDiagnostics.log("tilt.hold start direction=up pitch=\(String(format: "%+.1f", signedPitchFromHorizontal * 180 / .pi))°")
            }
            awayHoldStart = nil
            if let towardHoldStart, now.timeIntervalSince(towardHoldStart) >= holdDuration {
                lastStepAt = now
                VolumeDiagnostics.log("tilt.step fire direction=up")
                onDirection?(.towardUser)
                self.towardHoldStart = nil
            }
            return
        }

        if signedPitchFromHorizontal <= awayEnter {
            if awayHoldStart == nil {
                awayHoldStart = now
                VolumeDiagnostics.log("tilt.hold start direction=down pitch=\(String(format: "%+.1f", signedPitchFromHorizontal * 180 / .pi))°")
            }
            towardHoldStart = nil
            if let awayHoldStart, now.timeIntervalSince(awayHoldStart) >= holdDuration {
                lastStepAt = now
                VolumeDiagnostics.log("tilt.step fire direction=down")
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
