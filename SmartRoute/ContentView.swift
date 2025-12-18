import SwiftUI
import WebKit
import UniformTypeIdentifiers

// Global reference to webview for communication
var globalWebView: WKWebView?

struct WebView: UIViewRepresentable {
    @Binding var showDocumentPicker: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.websiteDataStore = WKWebsiteDataStore.default()

        // Add message handler for document picker
        let contentController = configuration.userContentController
        contentController.add(context.coordinator, name: "openDocumentPicker")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 10/255, green: 15/255, blue: 28/255, alpha: 1)
        webView.scrollView.backgroundColor = UIColor(red: 10/255, green: 15/255, blue: 28/255, alpha: 1)
        webView.uiDelegate = context.coordinator

        globalWebView = webView

        if let htmlPath = Bundle.main.path(forResource: "index", ofType: "html") {
            let htmlUrl = URL(fileURLWithPath: htmlPath)
            webView.loadFileURL(htmlUrl, allowingReadAccessTo: htmlUrl.deletingLastPathComponent())
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKUIDelegate, WKScriptMessageHandler {
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

struct ContentView: View {
    @State private var showDocumentPicker = false

    var body: some View {
        ZStack {
            WebView(showDocumentPicker: $showDocumentPicker)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker(isPresented: $showDocumentPicker)
        }
    }
}

#Preview {
    ContentView()
}
