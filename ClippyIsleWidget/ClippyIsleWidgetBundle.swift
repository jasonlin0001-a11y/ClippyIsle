import WidgetKit
import SwiftUI

@main
struct ClippyIsleWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClippyIsleWidget()
        #if os(iOS)
        if #available(iOS 16.1, *) {
            ClippyIsleLiveActivity()
        }
        #endif
    }
}
