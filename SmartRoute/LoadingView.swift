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
        var hasKeychainCredentials = KeychainManager.shared.hasStoredCredentials()

        // Migrate credentials from UserDefaults to Keychain if needed
        if biometricEnabled && !hasKeychainCredentials {
            if let email = UserDefaults.standard.string(forKey: "biometric_email"),
               let password = UserDefaults.standard.string(forKey: "biometric_password"),
               !email.isEmpty, !password.isEmpty {
                let migrated = KeychainManager.shared.saveCredentials(email: email, password: password)
                hasKeychainCredentials = migrated
            }
        }

        // Timeout - never get stuck
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
            if !self.authCompleted {
                self.authCompleted = true
                self.navigateToLanding()
            }
        }

        // If biometric enabled and we have Keychain credentials, authenticate
        if biometricEnabled && hasKeychainCredentials {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.doKeychainAuth()
            }
        } else if hasSession {
            // Has session but no biometric - go straight to app
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if !self.authCompleted {
                    self.authCompleted = true
                    self.navigateToApp()
                }
            }
        } else {
            // No session - go to landing
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if !self.authCompleted {
                    self.authCompleted = true
                    self.navigateToLanding()
                }
            }
        }
    }

    func doKeychainAuth() {
        guard !authCompleted else { return }

        // Read from Keychain - triggers passcode/Face ID
        KeychainManager.shared.readCredentials { email, password, error in
            guard !self.authCompleted else { return }
            self.authCompleted = true

            if let email = email, let password = password {
                // Store credentials for auto-login
                UserDefaults.standard.set("signIn", forKey: "landing_action")
                UserDefaults.standard.set(email, forKey: "landing_email")
                UserDefaults.standard.set(password, forKey: "landing_password")
                self.navigateToApp()
            } else {
                // Auth failed or cancelled - go to landing
                self.navigateToLanding()
            }
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
