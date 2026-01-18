import SwiftUI

@main
struct SmartRouteApp: App {
    @State private var showLoading: Bool = true
    @State private var showLanding: Bool = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showLanding {
                    LandingView(showLanding: $showLanding)
                        .ignoresSafeArea()
                        .statusBarHidden(true)
                        .transition(.opacity)
                } else if !showLoading {
                    ContentView(showLanding: $showLanding)
                        .ignoresSafeArea()
                        .statusBarHidden(true)
                        .transition(.opacity)
                }

                if showLoading {
                    LoadingView(showLoading: $showLoading, showLanding: $showLanding)
                        .ignoresSafeArea()
                        .statusBarHidden(true)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.75), value: showLoading)
            .animation(.easeInOut(duration: 0.3), value: showLanding)
        }
    }
}
