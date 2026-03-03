import SwiftUI
import WidgetKit

@main
struct GraVolControlWidgetBundle: WidgetBundle {
    var body: some Widget {
        GraVolControlHomeWidget()
        if #available(iOSApplicationExtension 16.1, *) {
            GraVolControlLiveActivityWidget()
        }
    }
}
