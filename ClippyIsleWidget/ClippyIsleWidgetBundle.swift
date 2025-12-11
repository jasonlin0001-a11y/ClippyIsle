import WidgetKit
import SwiftUI

@main
struct ClippyIsleWidgetBundle: WidgetBundle {
    #if os(iOS)
    @WidgetBundleBuilder
    var body: some Widget {
        ClippyIsleWidget()
        if #available(iOS 16.1, *) {
            ClippyIsleLiveActivity()
        }
    }
    #else
    var body: some Widget {
        ClippyIsleWidget()
    }
    #endif
}
