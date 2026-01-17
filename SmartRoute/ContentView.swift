import SwiftUI
import WebKit
import UniformTypeIdentifiers
import MessageUI

// Global reference to webview for communication
var globalWebView: WKWebView?

// Shared process pool to maintain localStorage across app launches
let sharedProcessPool = WKProcessPool()

struct WebView: UIViewRepresentable {
    @Binding var showDocumentPicker: Bool
    @Binding var emailData: EmailData?
    @Binding var showLanding: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        configuration.processPool = sharedProcessPool

        // Add message handlers
        let contentController = configuration.userContentController
        contentController.add(context.coordinator, name: "openDocumentPicker")
        contentController.add(context.coordinator, name: "shareFile")
        contentController.add(context.coordinator, name: "sendEmail")
        contentController.add(context.coordinator, name: "persistSession")
        contentController.add(context.coordinator, name: "showLanding")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 10/255, green: 15/255, blue: 28/255, alpha: 1)
        webView.scrollView.backgroundColor = UIColor(red: 10/255, green: 15/255, blue: 28/255, alpha: 1)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator

        globalWebView = webView

        if let htmlPath = Bundle.main.path(forResource: "index", ofType: "html") {
            let htmlUrl = URL(fileURLWithPath: htmlPath)
            webView.loadFileURL(htmlUrl, allowingReadAccessTo: htmlUrl.deletingLastPathComponent())
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKUIDelegate, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: WebView

        init(parent: WebView) {
            self.parent = parent
        }

        // Handle messages from JavaScript
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "openDocumentPicker" {
                DispatchQueue.main.async {
                    self.parent.showDocumentPicker = true
                }
            } else if message.name == "shareFile" {
                guard let body = message.body as? [String: Any],
                      let content = body["content"] as? String,
                      let filename = body["filename"] as? String else {
                    return
                }

                DispatchQueue.main.async {
                    self.shareFileContent(content: content, filename: filename)
                }
            } else if message.name == "sendEmail" {
                guard let body = message.body as? [String: Any],
                      let subject = body["subject"] as? String,
                      let htmlContent = body["htmlContent"] as? String,
                      let filename = body["filename"] as? String else {
                    return
                }

                DispatchQueue.main.async {
                    self.parent.emailData = EmailData(
                        subject: subject,
                        htmlContent: htmlContent,
                        filename: filename
                    )
                }
            } else if message.name == "persistSession" {
                // Store session in UserDefaults for persistence
                if let sessionString = message.body as? String {
                    if sessionString == "null" || sessionString.isEmpty {
                        UserDefaults.standard.removeObject(forKey: "supabase_session")
                    } else {
                        UserDefaults.standard.set(sessionString, forKey: "supabase_session")
                    }
                }
            } else if message.name == "showLanding" {
                // Go back to landing page (logout)
                DispatchQueue.main.async {
                    self.parent.showLanding = true
                }
            }
        }

        // Inject stored session when page finishes loading
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Check for landing page action first
            if let action = UserDefaults.standard.string(forKey: "landing_action") {
                handleLandingAction(webView: webView, action: action)
                // Clear the action so it doesn't repeat
                UserDefaults.standard.removeObject(forKey: "landing_action")
                return
            }

            // Otherwise restore existing session
            if let sessionString = UserDefaults.standard.string(forKey: "supabase_session") {
                let escapedSession = sessionString
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "'", with: "\\'")
                    .replacingOccurrences(of: "\n", with: "\\n")
                let js = "if (typeof restoreNativeSession === 'function') { restoreNativeSession('\(escapedSession)'); }"
                webView.evaluateJavaScript(js, completionHandler: nil)
            }
        }

        // Handle login action from landing page
        func handleLandingAction(webView: WKWebView, action: String) {
            let email = UserDefaults.standard.string(forKey: "landing_email") ?? ""
            let password = UserDefaults.standard.string(forKey: "landing_password") ?? ""
            let company = UserDefaults.standard.string(forKey: "landing_company") ?? ""
            let username = UserDefaults.standard.string(forKey: "landing_username") ?? ""

            // Clear stored credentials
            UserDefaults.standard.removeObject(forKey: "landing_email")
            UserDefaults.standard.removeObject(forKey: "landing_password")
            UserDefaults.standard.removeObject(forKey: "landing_company")
            UserDefaults.standard.removeObject(forKey: "landing_username")

            // Escape for JavaScript
            let escapedEmail = email.replacingOccurrences(of: "'", with: "\\'")
            let escapedPassword = password.replacingOccurrences(of: "'", with: "\\'")
            let escapedCompany = company.replacingOccurrences(of: "'", with: "\\'")
            let escapedUsername = username.replacingOccurrences(of: "'", with: "\\'")

            var js = ""
            switch action {
            case "signIn":
                js = "if (typeof nativeSignIn === 'function') { nativeSignIn('\(escapedEmail)', '\(escapedPassword)'); }"
            case "createAccount":
                js = "if (typeof nativeCreateAccount === 'function') { nativeCreateAccount('\(escapedEmail)', '\(escapedPassword)'); }"
            case "joinTeam":
                js = "if (typeof nativeJoinTeam === 'function') { nativeJoinTeam('\(escapedCompany)', '\(escapedUsername)', '\(escapedPassword)'); }"
            case "appleSignIn":
                js = "if (typeof nativeAppleSignIn === 'function') { nativeAppleSignIn(); }"
            case "googleSignIn":
                js = "if (typeof nativeGoogleSignIn === 'function') { nativeGoogleSignIn(); }"
            default:
                break
            }

            if !js.isEmpty {
                webView.evaluateJavaScript(js, completionHandler: nil)
            }
        }

        func shareFileContent(content: String, filename: String) {
            // Create temporary file
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(filename)

            do {
                try content.write(to: fileURL, atomically: true, encoding: .utf8)

                // Present share sheet
                let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)

                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    // For iPad, set popover source
                    if let popover = activityVC.popoverPresentationController {
                        popover.sourceView = rootVC.view
                        popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                        popover.permittedArrowDirections = []
                    }
                    rootVC.present(activityVC, animated: true)
                }
            } catch {
                print("Error creating temp file: \(error)")
            }
        }

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completionHandler()
            })

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(alert, animated: true)
            } else {
                completionHandler()
            }
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                completionHandler(false)
            })
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completionHandler(true)
            })

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(alert, animated: true)
            } else {
                completionHandler(false)
            }
        }

        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
            let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
            alert.addTextField { textField in
                textField.text = defaultText
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                completionHandler(nil)
            })
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completionHandler(alert.textFields?.first?.text)
            })

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(alert, animated: true)
            } else {
                completionHandler(nil)
            }
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            UTType.plainText,
            UTType.utf8PlainText,
            UTType.text,
            UTType.commaSeparatedText,
            UTType(filenameExtension: "doc") ?? UTType.data,
            UTType(filenameExtension: "docx") ?? UTType.data
        ])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker

        init(parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let fileName = url.lastPathComponent

                // Send content back to JavaScript
                let escapedContent = content
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "'", with: "\\'")
                    .replacingOccurrences(of: "\n", with: "\\n")
                    .replacingOccurrences(of: "\r", with: "")

                let escapedFileName = fileName
                    .replacingOccurrences(of: "'", with: "\\'")

                let js = "receiveDocumentContent('\(escapedFileName)', '\(escapedContent)');"

                DispatchQueue.main.async {
                    globalWebView?.evaluateJavaScript(js) { _, error in
                        if let error = error {
                            print("JS Error: \(error)")
                        }
                    }
                }
            } catch {
                print("Error reading file: \(error)")
            }

            parent.isPresented = false
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.isPresented = false
        }
    }
}

// Email data structure
struct EmailData: Identifiable, Equatable {
    let id = UUID()
    let subject: String
    let htmlContent: String
    let filename: String

    static func == (lhs: EmailData, rhs: EmailData) -> Bool {
        return lhs.id == rhs.id
    }
}

// Email composer
struct MailView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let emailData: EmailData

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailVC = MFMailComposeViewController()
        mailVC.mailComposeDelegate = context.coordinator
        mailVC.setSubject(emailData.subject)

        // Set HTML body
        mailVC.setMessageBody(emailData.htmlContent, isHTML: true)

        // Also attach the HTML as a file
        if let data = emailData.htmlContent.data(using: .utf8) {
            mailVC.addAttachmentData(data, mimeType: "text/html", fileName: emailData.filename)
        }

        return mailVC
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: MailView

        init(parent: MailView) {
            self.parent = parent
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.isPresented = false
        }
    }
}

struct ContentView: View {
    @Binding var showLanding: Bool
    @State private var showDocumentPicker = false
    @State private var emailData: EmailData? = nil
    @State private var showMailComposer = false

    var body: some View {
        WebView(showDocumentPicker: $showDocumentPicker, emailData: $emailData, showLanding: $showLanding)
            .ignoresSafeArea(.all, edges: .all)
            .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker(isPresented: $showDocumentPicker)
        }
        .sheet(isPresented: $showMailComposer) {
            if let data = emailData {
                if MFMailComposeViewController.canSendMail() {
                    MailView(isPresented: $showMailComposer, emailData: data)
                }
            }
        }
        .onChange(of: emailData) { oldValue, newValue in
            if newValue != nil {
                if MFMailComposeViewController.canSendMail() {
                    showMailComposer = true
                } else {
                    // Fallback - show alert that mail is not configured
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootVC = windowScene.windows.first?.rootViewController {
                        let alert = UIAlertController(
                            title: "Mail Not Available",
                            message: "Please configure an email account in Settings to send emails.",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        rootVC.present(alert, animated: true)
                    }
                    emailData = nil
                }
            }
        }
    }
}

#Preview {
    ContentView(showLanding: .constant(false))
}
