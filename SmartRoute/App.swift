import SwiftUI

@main
struct SmartRouteApp: App {
    @State private var showLanding: Bool = true

    var body: some Scene {
        WindowGroup {
            if showLanding {
                LandingView(showLanding: $showLanding)
                    .ignoresSafeArea()
                    .statusBarHidden(true)
            } else {
                ContentView(showLanding: $showLanding)
                    .ignoresSafeArea()
                    .statusBarHidden(true)
            }
        }
    }
}
