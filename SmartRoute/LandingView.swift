import SwiftUI
import AVKit
import LocalAuthentication

struct VideoPlayerView: UIViewRepresentable {
    let videoName: String
    let videoExtension: String

    func makeUIView(context: Context) -> UIView {
        let view = PlayerUIView(videoName: videoName, videoExtension: videoExtension)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

class PlayerUIView: UIView {
    private var playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?

    init(videoName: String, videoExtension: String) {
        super.init(frame: .zero)

        guard let path = Bundle.main.path(forResource: videoName, ofType: videoExtension) else {
            print("Video file not found: \(videoName).\(videoExtension)")
            return
        }

        let url = URL(fileURLWithPath: path)
        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)

        let player = AVQueuePlayer(playerItem: item)
        playerLooper = AVPlayerLooper(player: player, templateItem: item)

        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)

        player.isMuted = true
        player.play()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

enum LandingMode {
    case buttons
    case signIn
    case createAccount
    case joinTeam
}

struct LandingView: View {
    @Binding var showLanding: Bool
    @State private var logoOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var mode: LandingMode = .buttons
    @State private var formOpacity: Double = 0

    // Form fields
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var companyCode: String = ""
    @State private var username: String = ""
    @State private var errorMessage: String = ""
    @State private var isLoading: Bool = false
    @State private var rememberMe: Bool = true

    // Biometric
    @State private var deviceSupportsBiometrics: Bool = false
    @State private var biometricType: LABiometryType = .none
    @State private var showBiometricPrompt: Bool = false
    @State private var pendingCredentials: (email: String, password: String)? = nil

    var body: some View {
        ZStack {
            // Video background
            VideoPlayerView(videoName: "smartroute_video", videoExtension: "mp4")
                .ignoresSafeArea()

            // Dark overlay for better text visibility
            Color.black.opacity(mode == .buttons ? 0.4 : 0.7)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: mode)

            // Content
            ScrollView {
                VStack(spacing: 30) {
                    Spacer().frame(height: 60)

                    // Logo/Title area - smaller when form is shown
                    VStack(spacing: mode == .buttons ? 16 : 8) {
                        Text("SmartRoute")
                            .font(.custom("DM Sans", size: mode == .buttons ? 42 : 28).weight(.bold))
                            .foregroundColor(.white)

                        if mode == .buttons {
                            Text("Optimize your routes. Save time.")
                                .font(.custom("DM Sans", size: 18).weight(.medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .opacity(logoOpacity)
                    .animation(.easeInOut(duration: 0.3), value: mode)

                    if mode == .buttons {
                        Spacer().frame(height: 100)
                    }

                    // Form or Buttons
                    if mode == .buttons {
                        // Main buttons
                        buttonsView
                            .opacity(buttonOpacity)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        // Form overlay
                        formView
                            .opacity(formOpacity)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    Spacer().frame(height: 50)
                }
            }
        }
        .onAppear {
            checkBiometricAvailability()
            withAnimation(.easeIn(duration: 0.8).delay(0.3)) {
                logoOpacity = 1
            }
            withAnimation(.easeIn(duration: 0.8).delay(0.8)) {
                buttonOpacity = 1
            }
        }
        .alert(
            biometricType == .faceID ? "Enable Face ID?" : "Enable Touch ID?",
            isPresented: $showBiometricPrompt
        ) {
            Button("Enable") {
                enableBiometricLogin()
            }
            Button("Not Now", role: .cancel) {
                proceedWithoutBiometric()
            }
        } message: {
            Text(biometricType == .faceID
                 ? "Would you like to use Face ID to sign in next time?"
                 : "Would you like to use Touch ID to sign in next time?")
        }
    }

    // MARK: - Buttons View
    var buttonsView: some View {
        VStack(spacing: 16) {
            // Sign In button (primary)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    mode = .signIn
                    formOpacity = 1
                }
            }) {
                Text("Sign In")
                    .font(.custom("DM Sans", size: 18).weight(.semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .cornerRadius(28)
            }
            .padding(.horizontal, 32)

            // Create Account button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    mode = .createAccount
                    formOpacity = 1
                }
            }) {
                Text("Create Account")
                    .font(.custom("DM Sans", size: 18).weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(28)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )
            }
            .padding(.horizontal, 32)

            // Joining a team link
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    mode = .joinTeam
                    formOpacity = 1
                }
            }) {
                Text("Joining a team?")
                    .font(.custom("DM Sans", size: 15).weight(.medium))
                    .foregroundColor(.white.opacity(0.7))
                    .underline()
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Form View
    var formView: some View {
        VStack(spacing: 20) {
            // Form title
            Text(formTitle)
                .font(.custom("DM Sans", size: 24).weight(.bold))
                .foregroundColor(.white)
                .padding(.bottom, 5)

            // Form fields
            VStack(spacing: 16) {
                if mode == .joinTeam {
                    // Company code field
                    FormTextField(
                        placeholder: "Company Code",
                        text: $companyCode,
                        isSecure: false,
                        autocapitalization: .characters
                    )

                    // Username field
                    FormTextField(
                        placeholder: "Username",
                        text: $username,
                        isSecure: false,
                        autocapitalization: .never
                    )
                } else {
                    // Email field
                    FormTextField(
                        placeholder: "Email",
                        text: $email,
                        isSecure: false,
                        autocapitalization: .never,
                        keyboardType: .emailAddress
                    )
                }

                // Password field
                FormTextField(
                    placeholder: "Password",
                    text: $password,
                    isSecure: true
                )

                if mode == .createAccount {
                    // Confirm password field
                    FormTextField(
                        placeholder: "Confirm Password",
                        text: $confirmPassword,
                        isSecure: true
                    )
                }
            }

            // Remember me toggle (only for sign in)
            if mode == .signIn {
                HStack {
                    Toggle(isOn: $rememberMe) {
                        Text("Remember me")
                            .font(.custom("DM Sans", size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .toggleStyle(CheckboxToggleStyle())

                    Spacer()

                    Button(action: {
                        // Forgot password action
                    }) {
                        Text("Forgot Password?")
                            .font(.custom("DM Sans", size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 4)
            }

            // Error message
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.custom("DM Sans", size: 14))
                    .foregroundColor(Color(red: 239/255, green: 68/255, blue: 68/255))
                    .multilineTextAlignment(.center)
            }

            // Submit button
            Button(action: handleSubmit) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: mode == .joinTeam ? .white : .black))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                } else {
                    Text(submitButtonText)
                        .font(.custom("DM Sans", size: 18).weight(.semibold))
                        .foregroundColor(mode == .joinTeam ? .white : .black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
            }
            .background(submitButtonBackground)
            .cornerRadius(28)
            .disabled(isLoading)

            // Social login options (only for sign in and create account)
            if mode == .signIn || mode == .createAccount {
                VStack(spacing: 12) {
                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 1)
                        Text("or")
                            .font(.custom("DM Sans", size: 14))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 10)
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.vertical, 10)

                    // Sign in with Apple
                    Button(action: handleAppleSignIn) {
                        HStack(spacing: 12) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 20))
                            Text(mode == .signIn ? "Sign in with Apple" : "Sign up with Apple")
                                .font(.custom("DM Sans", size: 16).weight(.semibold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.white)
                        .cornerRadius(26)
                    }

                    // Sign in with Google
                    Button(action: handleGoogleSignIn) {
                        HStack(spacing: 12) {
                            // Google logo (simplified)
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 22, height: 22)
                                Text("G")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(red: 66/255, green: 133/255, blue: 244/255))
                            }
                            Text(mode == .signIn ? "Sign in with Google" : "Sign up with Google")
                                .font(.custom("DM Sans", size: 16).weight(.semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(red: 66/255, green: 133/255, blue: 244/255))
                        .cornerRadius(26)
                    }
                }
            }

            // Back button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    mode = .buttons
                    formOpacity = 0
                    clearForm()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                    Text("Back")
                        .font(.custom("DM Sans", size: 15).weight(.medium))
                }
                .foregroundColor(.white.opacity(0.7))
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Computed Properties
    var formTitle: String {
        switch mode {
        case .signIn: return "Welcome Back"
        case .createAccount: return "Create Account"
        case .joinTeam: return "Join Your Team"
        default: return ""
        }
    }

    var submitButtonText: String {
        switch mode {
        case .signIn: return "Sign In"
        case .createAccount: return "Create Account"
        case .joinTeam: return "Join Team"
        default: return ""
        }
    }

    var submitButtonBackground: Color {
        switch mode {
        case .joinTeam:
            return Color(red: 245/255, green: 158/255, blue: 11/255) // Orange for team
        default:
            return .white
        }
    }

    // MARK: - Biometric Authentication
    func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            deviceSupportsBiometrics = true
            biometricType = context.biometryType
        } else {
            deviceSupportsBiometrics = false
            biometricType = .none
        }
    }

    func enableBiometricLogin() {
        guard let credentials = pendingCredentials else {
            proceedWithoutBiometric()
            return
        }

        // Store credentials in Keychain with Face ID protection
        let keychainSuccess = KeychainManager.shared.saveCredentials(
            email: credentials.email,
            password: credentials.password
        )

        if keychainSuccess {
            print("DEBUG: Credentials saved to Keychain with Face ID protection")
        } else {
            print("DEBUG: Failed to save to Keychain, falling back to UserDefaults")
        }

        // Also store in UserDefaults as backup
        UserDefaults.standard.set(credentials.email, forKey: "biometric_email")
        UserDefaults.standard.set(credentials.password, forKey: "biometric_password")
        UserDefaults.standard.set(true, forKey: "biometric_enabled")

        // Store action for WebView and proceed
        UserDefaults.standard.set("signIn", forKey: "landing_action")
        UserDefaults.standard.set(credentials.email, forKey: "landing_email")
        UserDefaults.standard.set(credentials.password, forKey: "landing_password")

        pendingCredentials = nil
        showLanding = false
    }

    func proceedWithoutBiometric() {
        guard let credentials = pendingCredentials else {
            return
        }

        // Store action for WebView and proceed
        UserDefaults.standard.set("signIn", forKey: "landing_action")
        UserDefaults.standard.set(credentials.email, forKey: "landing_email")
        UserDefaults.standard.set(credentials.password, forKey: "landing_password")

        pendingCredentials = nil
        showLanding = false
    }

    // MARK: - Social Sign In
    func handleAppleSignIn() {
        // Store action for WebView to handle
        UserDefaults.standard.set("appleSignIn", forKey: "landing_action")
        showLanding = false
    }

    func handleGoogleSignIn() {
        // Store action for WebView to handle
        UserDefaults.standard.set("googleSignIn", forKey: "landing_action")
        showLanding = false
    }

    // MARK: - Actions
    func handleSubmit() {
        errorMessage = ""

        // Validation
        if mode == .joinTeam {
            if companyCode.isEmpty || username.isEmpty || password.isEmpty {
                errorMessage = "Please fill in all fields"
                return
            }
        } else {
            if email.isEmpty || password.isEmpty {
                errorMessage = "Please fill in all fields"
                return
            }
            if mode == .createAccount && password != confirmPassword {
                errorMessage = "Passwords don't match"
                return
            }
        }

        // Handle sign in with Remember Me - show biometric prompt if device supports it
        if mode == .signIn && rememberMe && deviceSupportsBiometrics {
            // Check if biometric is not already enabled
            let biometricAlreadyEnabled = UserDefaults.standard.bool(forKey: "biometric_enabled")
            if !biometricAlreadyEnabled {
                // Store credentials temporarily and show prompt
                pendingCredentials = (email: email, password: password)
                showBiometricPrompt = true
                return
            }
        }

        // Store form data for WebView to use
        if mode == .signIn {
            UserDefaults.standard.set("signIn", forKey: "landing_action")
            UserDefaults.standard.set(email, forKey: "landing_email")
            UserDefaults.standard.set(password, forKey: "landing_password")
        } else if mode == .createAccount {
            UserDefaults.standard.set("createAccount", forKey: "landing_action")
            UserDefaults.standard.set(email, forKey: "landing_email")
            UserDefaults.standard.set(password, forKey: "landing_password")
        } else if mode == .joinTeam {
            UserDefaults.standard.set("joinTeam", forKey: "landing_action")
            UserDefaults.standard.set(companyCode, forKey: "landing_company")
            UserDefaults.standard.set(username, forKey: "landing_username")
            UserDefaults.standard.set(password, forKey: "landing_password")
        }

        // Transition to main app
        withAnimation(.easeInOut(duration: 0.3)) {
            showLanding = false
        }
    }

    func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        companyCode = ""
        username = ""
        errorMessage = ""
    }
}

// MARK: - Checkbox Toggle Style
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isOn ? Color.white : Color.clear)
                    .frame(width: 22, height: 22)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                    )

                if configuration.isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            .onTapGesture {
                configuration.isOn.toggle()
            }

            configuration.label
        }
    }
}

// MARK: - Form Text Field Component
struct FormTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var autocapitalization: TextInputAutocapitalization = .never
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(autocapitalization)
                    .keyboardType(keyboardType)
                    .autocorrectionDisabled()
            }
        }
        .font(.custom("DM Sans", size: 16))
        .foregroundColor(.white)
        .padding(18)
        .background(Color.white.opacity(0.15))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    LandingView(showLanding: .constant(true))
}
