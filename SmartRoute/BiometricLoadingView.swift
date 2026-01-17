import SwiftUI
import LocalAuthentication

struct BiometricLoadingView: View {
    @Binding var showLanding: Bool
    @Binding var showBiometricLoading: Bool
    @Binding var isAuthenticated: Bool

    @State private var faceIDCompleted: Bool = false

    var body: some View {
        ZStack {
            // White background
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // App Logo from Assets
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 27))

                Spacer()

                // Loading spinner
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.gray))
                    .scaleEffect(1.5)

                Spacer()
                    .frame(height: 100)
            }
        }
        .onAppear {
            // Start the loading/auth flow
            startAuthFlow()
        }
    }

    func startAuthFlow() {
        let biometricEnabled = UserDefaults.standard.bool(forKey: "biometric_enabled")
        let hasSession = UserDefaults.standard.string(forKey: "supabase_session") != nil

        // Always set a timeout - go to landing after 2 seconds no matter what
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if !self.faceIDCompleted {
                self.faceIDCompleted = true
                self.goToLanding()
            }
        }

        // Brief delay then check auth
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if biometricEnabled && self.deviceSupportsBiometrics() {
                // Try Face ID
                self.triggerFaceID()
            } else if hasSession {
                // Has session, go straight to app
                self.faceIDCompleted = true
                self.isAuthenticated = true
                self.showBiometricLoading = false
            } else {
                // No session - go to landing
                self.faceIDCompleted = true
                self.goToLanding()
            }
        }
    }

    func triggerFaceID() {
        let context = LAContext()
        context.localizedFallbackTitle = ""

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Can't use Face ID - go to landing
            self.faceIDCompleted = true
            self.goToLanding()
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Unlock SmartRoute"
        ) { success, error in
            DispatchQueue.main.async {
                self.faceIDCompleted = true
                if success {
                    self.handleSuccess()
                } else {
                    // Face ID failed or cancelled - go to landing
                    self.goToLanding()
                }
            }
        }
    }

    func handleSuccess() {
        // Face ID verified successfully
        let hasSession = UserDefaults.standard.string(forKey: "supabase_session") != nil

        if hasSession {
            // Already have a session, just unlock the app
            withAnimation(.easeInOut(duration: 0.3)) {
                isAuthenticated = true
                showBiometricLoading = false
            }
        } else {
            // No session, need to sign in with stored credentials
            if let storedEmail = UserDefaults.standard.string(forKey: "biometric_email"),
               let storedPassword = UserDefaults.standard.string(forKey: "biometric_password"),
               !storedEmail.isEmpty,
               !storedPassword.isEmpty {
                UserDefaults.standard.set("signIn", forKey: "landing_action")
                UserDefaults.standard.set(storedEmail, forKey: "landing_email")
                UserDefaults.standard.set(storedPassword, forKey: "landing_password")

                withAnimation(.easeInOut(duration: 0.3)) {
                    isAuthenticated = true
                    showBiometricLoading = false
                }
            } else {
                goToLanding()
            }
        }
    }

    func goToLanding() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showBiometricLoading = false
            showLanding = true
        }
    }

    func deviceSupportsBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
}

#Preview {
    BiometricLoadingView(
        showLanding: .constant(false),
        showBiometricLoading: .constant(true),
        isAuthenticated: .constant(false)
    )
}
