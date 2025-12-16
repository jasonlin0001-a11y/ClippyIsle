import WidgetKit
import SwiftUI

@main
struct ClippyIsleWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClippyIsleWidget()
        if #available(iOS 16.0, *) {
            ClippyIsleLockScreenWidget()
        }
        if #available(iOS 16.1, *) {
            ClippyIsleLiveActivity()
        }
    }
}
