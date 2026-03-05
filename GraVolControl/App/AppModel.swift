import Foundation
import os
import SwiftUI
import UIKit
import WidgetKit

enum VolumeDiagnostics {
    private static let logger = Logger(subsystem: "com.sarsiz.GraVolControl", category: "Volume")
    private static let storeKey = "gravol_volume_diagnostics_log"
    private static let fileName = "simulator-volume-log-iphone.txt"
    private static let maxEntries = 300
    #if targetEnvironment(simulator)
    private static let isSimulator = true
    #else
    private static let isSimulator = false
    #endif
    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: GraVolControlRemoteStore.appGroupID) ?? UserDefaults.standard
    }

    static func log(_ message: String) {
        let line = "\(dateFormatter.string(from: Date())) | \(message)"
        logger.debug("\(line, privacy: .public)")
        if isSimulator {
            print("[GraVol][Volume] \(line)")
        }
        append(line)
        appendToFile(line)
    }

    static func recent() -> [String] {
        defaults.stringArray(forKey: storeKey) ?? []
    }

    static func logFilePath() -> String? {
        fileURL()?.path
    }

    private static func append(_ line: String) {
        var items = defaults.stringArray(forKey: storeKey) ?? []
        items.append(line)
        if items.count > maxEntries {
            items.removeFirst(items.count - maxEntries)
        }
        defaults.set(items, forKey: storeKey)
    }

    private static func appendToFile(_ line: String) {
        let urls = [localFileURL(), iCloudFileURL()].compactMap { $0 }
        guard !urls.isEmpty else { return }
        let payload = (line + "\n").data(using: .utf8) ?? Data()
        for url in urls {
            if FileManager.default.fileExists(atPath: url.path) {
                if let handle = try? FileHandle(forWritingTo: url) {
                    defer { try? handle.close() }
                    do {
                        try handle.seekToEnd()
                        try handle.write(contentsOf: payload)
                    } catch { }
                }
            } else {
                try? payload.write(to: url, options: .atomic)
            }
        }
    }

    private static func localFileURL() -> URL? {
        let fm = FileManager.default
        guard let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let logsDir = documents
            .appendingPathComponent("GraVolControl", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
        try? fm.createDirectory(at: logsDir, withIntermediateDirectories: true)
        return logsDir.appendingPathComponent(fileName)
    }

    private static func iCloudFileURL() -> URL? {
        let fm = FileManager.default
        guard let ubiquityURL = fm.url(forUbiquityContainerIdentifier: nil) else {
            return nil
        }
        let logsDir = ubiquityURL
            .appendingPathComponent("Documents/GraVolControl/Logs", isDirectory: true)
        try? fm.createDirectory(at: logsDir, withIntermediateDirectories: true)
        return logsDir.appendingPathComponent(fileName)
    }

    private static func fileURL() -> URL? {
        localFileURL()
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var isArmed = true
    @Published var lastAction: String = ""
    @Published var currentVolume: Float = 0
    @Published var triggerAngleDegrees: Double = 30
    @Published var defaultTriggerAngleDegrees: Double = 30
    @Published var downTriggerAngleDegrees: Double = 15
    @Published var defaultDownTriggerAngleDegrees: Double = 15
    @Published var currentTiltDegrees: Double = 0
    @Published var stepSize: Double = 0.2
    @Published var isTiltLearnMode = false
    @Published var didLaunchAnimate = false
    @Published var isVolumeControlReady = false
    @Published var tiltStatus: String = "Tilt Ready"

    private let volumeManager = VolumeManager()
    private var volumeRefreshTimer: Timer?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var lastSeenRecenterCommandID = 0
    private var lastSeenSetArmedCommandID = 0
    private var lastSeenVolumePresetCommandID = 0
    private var lastWidgetArmedState: Bool?
    private var lastWidgetMutedState: Bool?
    private var lastWidgetUpAngle: Double?
    private var lastWidgetDownAngle: Double?
    private let triggerAngleRange: ClosedRange<Double> = 0...60
    private let muteThreshold: Float = 0.001
    private let firstLaunchFlagKey = "gravol_has_launched_once"
    private let tiltLearnModeKey = "gravol_tilt_learn_mode"
    private let tiltLearnSmoothingFactor = 0.22
    private let tiltLearnMinimumDelta = 0.12
    private let volumeRefreshInterval: TimeInterval = 0.12
    private var lastLoggedReadyState = false
    private var lastActionClearWorkItem: DispatchWorkItem?

    private lazy var tiltController: TiltVolumeController = {
        let upThreshold = Self.degreesToRadians(triggerAngleDegrees)
        let downThreshold = Self.degreesToRadians(downTriggerAngleDegrees)
        return TiltVolumeController(
            towardPitchThreshold: upThreshold,
            awayPitchThreshold: downThreshold,
            towardHysteresis: max(abs(upThreshold) * 0.45, Self.degreesToRadians(1)),
            awayHysteresis: max(abs(downThreshold) * 0.45, Self.degreesToRadians(1)),
            stepInterval: 0.15
        )
    }()

    init() {
        VolumeDiagnostics.log("app.previousLogCount=\(VolumeDiagnostics.recent().count)")
        if let path = VolumeDiagnostics.logFilePath() {
            VolumeDiagnostics.log("app.logFile=\(path)")
        }
        volumeManager.configureAudioSession()
        volumeManager.prepareBridge()
        VolumeDiagnostics.log("app.init started")

        if !UserDefaults.standard.bool(forKey: firstLaunchFlagKey) {
            UserDefaults.standard.set(true, forKey: firstLaunchFlagKey)
            defaultTriggerAngleDegrees = 15
            triggerAngleDegrees = 15
            defaultDownTriggerAngleDegrees = 15
            downTriggerAngleDegrees = 15
            stepSize = 0.2
            isArmed = true
            GraVolControlRemoteStore.setDefaultTriggerAngleDegrees(defaultTriggerAngleDegrees)
            GraVolControlRemoteStore.setTriggerAngleDegrees(triggerAngleDegrees)
            GraVolControlRemoteStore.setDefaultDownTriggerAngleDegrees(defaultDownTriggerAngleDegrees)
            GraVolControlRemoteStore.setDownTriggerAngleDegrees(downTriggerAngleDegrees)
            GraVolControlRemoteStore.setStepSize(stepSize)
            GraVolControlRemoteStore.setArmedState(isArmed)
        } else {
            defaultTriggerAngleDegrees = min(max(abs(GraVolControlRemoteStore.defaultTriggerAngleDegrees(defaultValue: defaultTriggerAngleDegrees)), triggerAngleRange.lowerBound), triggerAngleRange.upperBound)
            triggerAngleDegrees = min(max(abs(GraVolControlRemoteStore.triggerAngleDegrees(defaultValue: defaultTriggerAngleDegrees)), triggerAngleRange.lowerBound), triggerAngleRange.upperBound)
            defaultDownTriggerAngleDegrees = min(max(abs(GraVolControlRemoteStore.defaultDownTriggerAngleDegrees(defaultValue: defaultDownTriggerAngleDegrees)), triggerAngleRange.lowerBound), triggerAngleRange.upperBound)
            downTriggerAngleDegrees = min(max(abs(GraVolControlRemoteStore.downTriggerAngleDegrees(defaultValue: defaultDownTriggerAngleDegrees)), triggerAngleRange.lowerBound), triggerAngleRange.upperBound)
            stepSize = min(max(GraVolControlRemoteStore.stepSize(defaultValue: stepSize), 0.01), 5.0)
            isArmed = GraVolControlRemoteStore.armedState(defaultValue: true)
        }

        lastSeenRecenterCommandID = GraVolControlRemoteStore.currentRecenterCommandID()
        lastSeenSetArmedCommandID = GraVolControlRemoteStore.currentSetArmedCommandID()
        lastSeenVolumePresetCommandID = GraVolControlRemoteStore.currentVolumePresetCommandID()
        isTiltLearnMode = false
        UserDefaults.standard.set(false, forKey: tiltLearnModeKey)
        refreshCurrentVolume()
        startVolumeRefreshTimer()
        VolumeDiagnostics.log("app.init complete ready=\(isVolumeControlReady) volume=\(Int(currentVolume * 100))%")

        tiltController.onDirection = { [weak self] direction in
            guard let self else { return }
            switch direction {
            case .towardUser:
                self.applyVolumeChange(delta: Float(self.stepSize / 100.0), action: "Tilt Up")
            case .awayFromUser:
                self.applyVolumeChange(delta: -Float(self.stepSize / 100.0), action: "Tilt Down")
            }
        }

        tiltController.onTiltDeltaChanged = { [weak self] deltaPitch in
            guard let self else { return }
            let tilt = Self.radiansToDegrees(deltaPitch)
            self.currentTiltDegrees = tilt
            if self.isTiltLearnMode {
                self.applyTiltAsTrigger(tilt)
            }
            self.syncLiveActivity(force: true)
        }
    }

    func setArmed(_ value: Bool) {
        isArmed = value
        GraVolControlRemoteStore.setArmedState(value)
        notifyWidgetsIfNeeded(force: true)
        if value {
            tiltController.start()
            tiltController.recenterBaseline()
            setPersistentAction("Tilt Ready")
            tiltStatus = "Tilt Ready"
            syncLiveActivity(force: true)
        } else {
            tiltController.stop()
            setPersistentAction("Paused")
            tiltStatus = "Paused"
            endLiveActivity()
        }
    }

    func updateTriggerAngleDegrees(_ value: Double) {
        triggerAngleDegrees = min(max(abs(value), triggerAngleRange.lowerBound), triggerAngleRange.upperBound)
        GraVolControlRemoteStore.setTriggerAngleDegrees(triggerAngleDegrees)
        notifyWidgetsIfNeeded(force: true)
        updateTiltThresholds()
        syncLiveActivity(force: true)
    }

    func updateDefaultTriggerAngleDegrees(_ value: Double) {
        defaultTriggerAngleDegrees = min(max(abs(value), triggerAngleRange.lowerBound), triggerAngleRange.upperBound)
        GraVolControlRemoteStore.setDefaultTriggerAngleDegrees(defaultTriggerAngleDegrees)
        notifyWidgetsIfNeeded(force: true)
    }

    func resetTriggerToDefault() {
        updateTriggerAngleDegrees(defaultTriggerAngleDegrees)
    }

    func updateDownTriggerAngleDegrees(_ value: Double) {
        downTriggerAngleDegrees = min(max(abs(value), triggerAngleRange.lowerBound), triggerAngleRange.upperBound)
        GraVolControlRemoteStore.setDownTriggerAngleDegrees(downTriggerAngleDegrees)
        notifyWidgetsIfNeeded(force: true)
        updateTiltThresholds()
        syncLiveActivity(force: true)
    }

    func updateDefaultDownTriggerAngleDegrees(_ value: Double) {
        defaultDownTriggerAngleDegrees = min(max(abs(value), triggerAngleRange.lowerBound), triggerAngleRange.upperBound)
        GraVolControlRemoteStore.setDefaultDownTriggerAngleDegrees(defaultDownTriggerAngleDegrees)
        notifyWidgetsIfNeeded(force: true)
    }

    func resetDownTriggerToDefault() {
        updateDownTriggerAngleDegrees(defaultDownTriggerAngleDegrees)
    }

    func resetBothTriggersToFortyFive() {
        let defaultAngle = 45.0
        defaultTriggerAngleDegrees = defaultAngle
        defaultDownTriggerAngleDegrees = defaultAngle
        triggerAngleDegrees = defaultAngle
        downTriggerAngleDegrees = defaultAngle
        GraVolControlRemoteStore.setDefaultTriggerAngleDegrees(defaultAngle)
        GraVolControlRemoteStore.setDefaultDownTriggerAngleDegrees(defaultAngle)
        GraVolControlRemoteStore.setTriggerAngleDegrees(defaultAngle)
        GraVolControlRemoteStore.setDownTriggerAngleDegrees(defaultAngle)
        updateTiltThresholds()
        notifyWidgetsIfNeeded(force: true)
        syncLiveActivity(force: true)
    }

    func updateStepSize(_ value: Double) {
        stepSize = min(max(value, 0.01), 5.0)
        GraVolControlRemoteStore.setStepSize(stepSize)
    }

    func setTiltLearnMode(_ enabled: Bool) {
        isTiltLearnMode = enabled
        UserDefaults.standard.set(enabled, forKey: tiltLearnModeKey)
        if !enabled {
            GraVolControlRemoteStore.setTriggerAngleDegrees(triggerAngleDegrees)
            GraVolControlRemoteStore.setDownTriggerAngleDegrees(downTriggerAngleDegrees)
            notifyWidgetsIfNeeded(force: true)
            syncLiveActivity(force: true)
        }
    }

    func attachSystemVolumeSlider(_ slider: UISlider) {
        volumeManager.attachSystemSlider(slider)
        isVolumeControlReady = true
        VolumeDiagnostics.log("ui.bridge sliderAttached")
    }

    func nudgeUp() {
        VolumeDiagnostics.log("ui.tap up")
        applyVolumeChange(delta: 0.05, action: "Manual Up")
    }

    func nudgeDown() {
        VolumeDiagnostics.log("ui.tap down")
        applyVolumeChange(delta: -0.05, action: "Manual Down")
    }

    func setVolumeDirect(_ value: Float) {
        VolumeDiagnostics.log("ui.dial set target=\(Int(value * 100))%")
        guard ensureVolumeBridgeReady(context: "ui.dial") else {
            isVolumeControlReady = false
            setPersistentAction("Volume Bridge Loading")
            return
        }
        _ = volumeManager.setVolume(value)
        currentVolume = volumeManager.currentOutputVolume()
        setTransientAction("Dial \(Int(currentVolume * 100))%")
        syncMuteState(for: currentVolume)
        VolumeDiagnostics.log("ui.dial done current=\(Int(currentVolume * 100))%")
    }

    func setVolumePreset(_ value: Float) {
        VolumeDiagnostics.log("ui.preset set target=\(Int(value * 100))%")
        guard ensureVolumeBridgeReady(context: "ui.preset") else {
            isVolumeControlReady = false
            setPersistentAction("Volume Bridge Loading")
            return
        }
        _ = volumeManager.setVolume(value)
        currentVolume = volumeManager.currentOutputVolume()
        setTransientAction("Set \(Int(value * 100))%")
        syncMuteState(for: currentVolume)
        VolumeDiagnostics.log("ui.preset done current=\(Int(currentVolume * 100))%")
    }

    func toggleMute() {
        VolumeDiagnostics.log("ui.tap muteToggle current=\(Int(currentVolume * 100))%")
        if currentVolume <= muteThreshold {
            let restore = max(0.01, GraVolControlRemoteStore.lastAudibleVolume(defaultValue: 0.5))
            setVolumePreset(restore)
            setTransientAction("Unmuted")
            VolumeDiagnostics.log("ui.mute unmuted restore=\(Int(restore * 100))%")
        } else {
            GraVolControlRemoteStore.setLastAudibleVolume(max(currentVolume, 0.05))
            setVolumePreset(0.0)
            setTransientAction("Muted")
            VolumeDiagnostics.log("ui.mute muted")
        }
    }

    func triggerLaunchAnimationIfNeeded() {
        guard !didLaunchAnimate else { return }
        didLaunchAnimate = true
    }

    func recenterTiltReference() {
        let baselineDefault = 45.0
        defaultTriggerAngleDegrees = baselineDefault
        defaultDownTriggerAngleDegrees = baselineDefault
        triggerAngleDegrees = baselineDefault
        downTriggerAngleDegrees = baselineDefault
        GraVolControlRemoteStore.setDefaultTriggerAngleDegrees(baselineDefault)
        GraVolControlRemoteStore.setDefaultDownTriggerAngleDegrees(baselineDefault)
        GraVolControlRemoteStore.setTriggerAngleDegrees(baselineDefault)
        GraVolControlRemoteStore.setDownTriggerAngleDegrees(baselineDefault)
        updateTiltThresholds()
        notifyWidgetsIfNeeded(force: true)
        tiltController.recenterBaseline()
        tiltStatus = "Recentered"
        syncLiveActivity(force: true)
    }

    func handleScenePhase(_ phase: ScenePhase) {
        VolumeDiagnostics.log("scene.phase \(String(describing: phase))")
        switch phase {
        case .active:
            endBackgroundTaskIfNeeded()
            startVolumeRefreshTimer()
            refreshCurrentVolume()
            if isArmed { tiltController.start() }
            syncLiveActivity(force: true)
        case .inactive:
            if isArmed {
                tiltController.start()
                startVolumeRefreshTimer()
            }
        case .background:
            // Best effort: keep updates alive briefly while app transitions.
            beginBackgroundTaskIfNeeded()
            if isArmed {
                tiltController.start()
                startVolumeRefreshTimer()
                syncLiveActivity(force: true)
            } else {
                tiltController.stop()
                stopVolumeRefreshTimer()
            }
        @unknown default:
            tiltController.stop()
            stopVolumeRefreshTimer()
        }
    }

    private func applyVolumeChange(delta: Float, action: String) {
        VolumeDiagnostics.log("ui.change action=\(action) delta=\(String(format: "%.2f", delta))")
        guard ensureVolumeBridgeReady(context: "ui.change") else {
            isVolumeControlReady = false
            setPersistentAction("Volume Bridge Loading")
            return
        }
        isVolumeControlReady = true
        let before = volumeManager.currentOutputVolume()
        let after = volumeManager.changeVolume(by: delta)
        currentVolume = after
        syncMuteState(for: after)
        if abs(after - before) > 0.0001 {
            setTransientAction(action)
        } else if after <= 0.001 {
            setTransientAction("Already at Min")
        } else if after >= 0.999 {
            setTransientAction("Already at Max")
        }
        VolumeDiagnostics.log("ui.change done action=\(action) before=\(Int(before * 100))% after=\(Int(after * 100))%")
        syncLiveActivity()
    }

    private func refreshCurrentVolume() {
        volumeManager.prepareBridge()
        isVolumeControlReady = volumeManager.isReady()
        let read = volumeManager.currentOutputVolume()
        if abs(read - currentVolume) > 0.009 {
            VolumeDiagnostics.log("refresh.volume old=\(Int(currentVolume * 100))% new=\(Int(read * 100))%")
        }
        currentVolume = read
        volumeManager.logSystemVolumeIfChanged(source: "timer")
        if isVolumeControlReady != lastLoggedReadyState {
            lastLoggedReadyState = isVolumeControlReady
            VolumeDiagnostics.log("refresh.ready \(isVolumeControlReady ? "ready" : "notReady")")
        }
        syncMuteState(for: currentVolume)
    }

    private func startVolumeRefreshTimer() {
        guard volumeRefreshTimer == nil else { return }
        volumeRefreshTimer = Timer.scheduledTimer(withTimeInterval: volumeRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshCurrentVolume()
                self?.applyRemoteCommands()
                self?.syncLiveActivity()
            }
        }
        if let volumeRefreshTimer {
            RunLoop.main.add(volumeRefreshTimer, forMode: .common)
        }
    }

    private func stopVolumeRefreshTimer() {
        volumeRefreshTimer?.invalidate()
        volumeRefreshTimer = nil
    }

    deinit {
        volumeRefreshTimer?.invalidate()
    }

    private func applyRemoteCommands() {
        var shouldRefreshWidgets = false

        // Do not overwrite local live-learning values from stale shared store.
        if !isTiltLearnMode {
            let sharedAngle = GraVolControlRemoteStore.triggerAngleDegrees(defaultValue: triggerAngleDegrees)
            if abs(sharedAngle - triggerAngleDegrees) > 0.001 {
                triggerAngleDegrees = min(max(abs(sharedAngle), triggerAngleRange.lowerBound), triggerAngleRange.upperBound)
                updateTiltThresholds()
                shouldRefreshWidgets = true
            }

            let sharedDownAngle = GraVolControlRemoteStore.downTriggerAngleDegrees(defaultValue: downTriggerAngleDegrees)
            if abs(sharedDownAngle - downTriggerAngleDegrees) > 0.001 {
                downTriggerAngleDegrees = min(max(abs(sharedDownAngle), triggerAngleRange.lowerBound), triggerAngleRange.upperBound)
                updateTiltThresholds()
                shouldRefreshWidgets = true
            }
        }

        if GraVolControlRemoteStore.consumeRecenterCommand(lastSeenID: &lastSeenRecenterCommandID) {
            recenterTiltReference()
        }

        if let remoteArmed = GraVolControlRemoteStore.consumeSetArmedCommand(lastSeenID: &lastSeenSetArmedCommandID),
           remoteArmed != isArmed {
            setArmed(remoteArmed)
            shouldRefreshWidgets = true
        }

        if let volumePreset = GraVolControlRemoteStore.consumeVolumePresetCommand(lastSeenID: &lastSeenVolumePresetCommandID) {
            setVolumePreset(volumePreset)
            shouldRefreshWidgets = true
        }
        if shouldRefreshWidgets {
            notifyWidgetsIfNeeded(force: true)
        }
    }

    private func syncLiveActivity(force: Bool = false) {
        guard #available(iOS 16.1, *) else { return }
        guard isArmed else { return }

        let content = GraVolLiveActivityAttributes.ContentState(
            tiltDegrees: currentTiltDegrees,
            upTriggerDegrees: triggerAngleDegrees,
            downTriggerDegrees: downTriggerAngleDegrees,
            isArmed: isArmed
        )
        Task {
            await GraVolLiveActivityController.shared.startOrUpdate(content)
        }
    }

    private func endLiveActivity() {
        guard #available(iOS 16.1, *) else { return }
        Task {
            await GraVolLiveActivityController.shared.endAll()
        }
    }

    private static func degreesToRadians(_ value: Double) -> Double {
        value * .pi / 180
    }

    private static func radiansToDegrees(_ value: Double) -> Double {
        value * 180 / .pi
    }

    private func syncMuteState(for volume: Float) {
        let isMutedNow = volume <= muteThreshold
        let previous = GraVolControlRemoteStore.mutedState(defaultValue: false)
        if isMutedNow {
            GraVolControlRemoteStore.setMutedState(true)
        } else {
            GraVolControlRemoteStore.setMutedState(false)
            GraVolControlRemoteStore.setLastAudibleVolume(volume)
        }
        if previous != isMutedNow {
            notifyWidgetsIfNeeded(force: true)
        }
    }

    private func updateTiltThresholds() {
        let upThreshold = Self.degreesToRadians(triggerAngleDegrees)
        let downThreshold = Self.degreesToRadians(downTriggerAngleDegrees)
        tiltController.updateThresholds(
            towardPitchThreshold: upThreshold,
            awayPitchThreshold: downThreshold,
            towardHysteresis: max(abs(upThreshold) * 0.45, Self.degreesToRadians(1)),
            awayHysteresis: max(abs(downThreshold) * 0.45, Self.degreesToRadians(1))
        )
    }

    private func applyTiltAsTrigger(_ tiltDegrees: Double) {
        let minLearnAngle = 1.0
        guard abs(tiltDegrees) >= minLearnAngle else { return }

        let mapped = min(max(abs(tiltDegrees), triggerAngleRange.lowerBound), triggerAngleRange.upperBound)
        if tiltDegrees >= 0 {
            let smoothed = triggerAngleDegrees + ((mapped - triggerAngleDegrees) * tiltLearnSmoothingFactor)
            guard abs(smoothed - triggerAngleDegrees) >= tiltLearnMinimumDelta else { return }
            triggerAngleDegrees = smoothed
            GraVolControlRemoteStore.setTriggerAngleDegrees(triggerAngleDegrees)
        } else {
            let smoothed = downTriggerAngleDegrees + ((mapped - downTriggerAngleDegrees) * tiltLearnSmoothingFactor)
            guard abs(smoothed - downTriggerAngleDegrees) >= tiltLearnMinimumDelta else { return }
            downTriggerAngleDegrees = smoothed
            GraVolControlRemoteStore.setDownTriggerAngleDegrees(downTriggerAngleDegrees)
        }
        notifyWidgetsIfNeeded()
        updateTiltThresholds()
    }

    private func notifyWidgetsIfNeeded(force: Bool = false) {
        let muted = GraVolControlRemoteStore.mutedState(defaultValue: false)
        let changed = lastWidgetArmedState != isArmed ||
            lastWidgetMutedState != muted ||
            lastWidgetUpAngle != triggerAngleDegrees ||
            lastWidgetDownAngle != downTriggerAngleDegrees

        guard force || changed else { return }
        lastWidgetArmedState = isArmed
        lastWidgetMutedState = muted
        lastWidgetUpAngle = triggerAngleDegrees
        lastWidgetDownAngle = downTriggerAngleDegrees
        WidgetCenter.shared.reloadTimelines(ofKind: "GraVolControlHomeWidget")
    }

    private func beginBackgroundTaskIfNeeded() {
        guard backgroundTaskID == .invalid else { return }
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "GraVolTiltLiveActivity") { [weak self] in
            Task { @MainActor in
                self?.endBackgroundTaskIfNeeded()
                self?.tiltController.stop()
                self?.stopVolumeRefreshTimer()
            }
        }
    }

    private func endBackgroundTaskIfNeeded() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }

    private func ensureVolumeBridgeReady(context: String) -> Bool {
        if volumeManager.isReady() {
            isVolumeControlReady = true
            return true
        }
        isVolumeControlReady = false
        VolumeDiagnostics.log("\(context) blocked bridgeNotReady")
        return false
    }

    private func setTransientAction(_ value: String, duration: TimeInterval = 2.2) {
        lastActionClearWorkItem?.cancel()
        withAnimation(.easeInOut(duration: 0.22)) {
            lastAction = value
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.lastAction == value {
                withAnimation(.easeInOut(duration: 0.35)) {
                    self.lastAction = ""
                }
            }
        }
        lastActionClearWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private func setPersistentAction(_ value: String) {
        lastActionClearWorkItem?.cancel()
        lastAction = value
    }
}
