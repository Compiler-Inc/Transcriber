//  Copyright © 2025 Compiler, Inc. All rights reserved.

import SwiftUI

@main
struct TranscriberDemoApp: App {
    var body: some Scene {
        WindowGroup {
            if #available(iOS 17.0, *) {
                ContentView()
            } else {
                LegacyContentView()
            }
        }
    }
}
