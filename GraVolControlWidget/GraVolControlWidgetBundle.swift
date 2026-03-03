import SwiftUI
import WidgetKit

@main
struct GraVolControlWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOSApplicationExtension 16.1, *) {
            GraVolControlLiveActivityWidget()
        }
    }
}
