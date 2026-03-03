import AppIntents

struct GraVolShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartGraVolIntent(),
            phrases: [
                "Start GraVol in \(.applicationName)",
                "Open GraVol in \(.applicationName)"
            ],
            shortTitle: "Start GraVol",
            systemImageName: "speaker.wave.2.fill"
        )
        AppShortcut(
            intent: IncreaseTriggerAngleIntent(),
            phrases: ["Increase trigger angle in \(.applicationName)"],
            shortTitle: "Angle +",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: DecreaseTriggerAngleIntent(),
            phrases: ["Decrease trigger angle in \(.applicationName)"],
            shortTitle: "Angle -",
            systemImageName: "minus.circle.fill"
        )
        AppShortcut(
            intent: RecenterTiltIntent(),
            phrases: ["Recenter tilt in \(.applicationName)"],
            shortTitle: "Recenter",
            systemImageName: "dot.scope"
        )
    }
}
