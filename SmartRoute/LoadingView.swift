import SwiftUI
import LocalAuthentication

struct LoadingView: View {
    @Binding var showLoading: Bool
    @Binding var showLanding: Bool

    @State private var authCompleted = false

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 27))

                Spacer()

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                    .scaleEffect(1.3)

                Spacer()
                    .frame(height: 80)
            }
        }
        .onAppear {
            startAuthFlow()
        }
    }

    func startAuthFlow() {
        let biometricEnabled = UserDefaults.standard.bool(forKey: "biometric_enabled")
        let hasSession = UserDefaults.standard.string(forKey: "supabase_session") != nil

        // Timeout - never get stuck
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
            if !self.authCompleted {
                self.authCompleted = true
                self.navigateToLanding()
            }
        }

        if biometricEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.doPasscodeAuth()
            }
        } else if hasSession {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if !self.authCompleted {
                    self.authCompleted = true
                    self.navigateToApp()
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if !self.authCompleted {
                    self.authCompleted = true
                    self.navigateToLanding()
                }
            }
        }
    }

    func doPasscodeAuth() {
        guard !authCompleted else { return }

        let context = LAContext()

        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Unlock SmartRoute"
        ) { success, error in
            DispatchQueue.main.async {
                guard !self.authCompleted else { return }
                self.authCompleted = true

                if success {
                    self.handleAuthSuccess()
                } else {
                    self.navigateToLanding()
                }
            }
        }
    }

    func handleAuthSuccess() {
        let hasSession = UserDefaults.standard.string(forKey: "supabase_session") != nil

        if hasSession {
            navigateToApp()
        } else if let email = UserDefaults.standard.string(forKey: "biometric_email"),
                  let password = UserDefaults.standard.string(forKey: "biometric_password") {
            UserDefaults.standard.set("signIn", forKey: "landing_action")
            UserDefaults.standard.set(email, forKey: "landing_email")
            UserDefaults.standard.set(password, forKey: "landing_password")
            navigateToApp()
        } else {
            navigateToLanding()
        }
    }

    func navigateToApp() {
        withAnimation(.easeInOut(duration: 0.75)) {
            showLanding = false
            showLoading = false
        }
    }

    func navigateToLanding() {
        withAnimation(.easeInOut(duration: 0.75)) {
            showLanding = true
            showLoading = false
        }
    }
}

#Preview {
    LoadingView(showLoading: .constant(true), showLanding: .constant(false))
}
