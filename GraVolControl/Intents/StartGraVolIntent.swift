import AppIntents

struct StartGraVolIntent: AppIntent {
    static var title: LocalizedStringResource = "Start GraVol"
    static var description = IntentDescription("Open GraVol Control so tilt-based volume control can start.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}
