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
    }
}
