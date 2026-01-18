import Foundation
import Security
import LocalAuthentication

class KeychainManager {
    static let shared = KeychainManager()

    private let service = "com.smartroute.credentials"
    private let emailKey = "user_email"
    private let passwordKey = "user_password"

    private init() {}

    // Save credentials with Face ID protection
    func saveCredentials(email: String, password: String) -> Bool {
        // First delete any existing credentials
        deleteCredentials()

        // Create access control requiring user presence (Face ID first, passcode fallback)
        var error: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            .userPresence, // Shows Face ID first, falls back to passcode
            &error
        ) else {
            print("DEBUG Keychain: Failed to create access control: \(error?.takeRetainedValue().localizedDescription ?? "unknown")")
            return false
        }

        print("DEBUG Keychain: Access control created with .userPresence")

        // Save email
        let emailData = email.data(using: .utf8)!
        let emailQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: emailKey,
            kSecValueData as String: emailData,
            kSecAttrAccessControl as String: accessControl
        ]

        var status = SecItemAdd(emailQuery as CFDictionary, nil)
        if status != errSecSuccess {
            print("DEBUG Keychain: Failed to save email: \(status)")
            return false
        }

        // Save password
        let passwordData = password.data(using: .utf8)!
        let passwordQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: passwordKey,
            kSecValueData as String: passwordData,
            kSecAttrAccessControl as String: accessControl
        ]

        status = SecItemAdd(passwordQuery as CFDictionary, nil)
        if status != errSecSuccess {
            print("DEBUG Keychain: Failed to save password: \(status)")
            // Clean up email if password failed
            deleteCredentials()
            return false
        }

        print("DEBUG Keychain: Credentials saved successfully with Face ID protection")
        return true
    }

    // Read credentials - this will trigger Face ID
    func readCredentials(completion: @escaping (String?, String?, Error?) -> Void) {
        print("DEBUG Keychain: Starting readCredentials on background thread")

        // Keychain operations with user interaction should be on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            // Query for email - let system handle Face ID prompt automatically
            let emailQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: self.service,
                kSecAttrAccount as String: self.emailKey,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
                kSecUseOperationPrompt as String: "Unlock SmartRoute with Face ID"
            ]

            var emailResult: AnyObject?
            let emailStatus = SecItemCopyMatching(emailQuery as CFDictionary, &emailResult)

            print("DEBUG Keychain: Email read status: \(emailStatus)")

            if emailStatus != errSecSuccess {
                DispatchQueue.main.async {
                    let error = NSError(domain: "KeychainManager", code: Int(emailStatus), userInfo: [
                        NSLocalizedDescriptionKey: "Failed to read email: status \(emailStatus)"
                    ])
                    completion(nil, nil, error)
                }
                return
            }

            // Now get password - auth already done for this session
            let passwordQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: self.service,
                kSecAttrAccount as String: self.passwordKey,
                kSecReturnData as String: true
            ]

            var passwordResult: AnyObject?
            let passwordStatus = SecItemCopyMatching(passwordQuery as CFDictionary, &passwordResult)

            print("DEBUG Keychain: Password read status: \(passwordStatus)")

            DispatchQueue.main.async {
                if passwordStatus == errSecSuccess,
                   let emailData = emailResult as? Data,
                   let passwordData = passwordResult as? Data,
                   let email = String(data: emailData, encoding: .utf8),
                   let password = String(data: passwordData, encoding: .utf8) {
                    print("DEBUG Keychain: Credentials read successfully")
                    completion(email, password, nil)
                } else {
                    let error = NSError(domain: "KeychainManager", code: Int(passwordStatus), userInfo: [
                        NSLocalizedDescriptionKey: "Failed to read password: status \(passwordStatus)"
                    ])
                    completion(nil, nil, error)
                }
            }
        }
    }

    // Check if credentials exist (without triggering Face ID)
    func hasStoredCredentials() -> Bool {
        let context = LAContext()
        context.interactionNotAllowed = true // Don't prompt, just check

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: emailKey,
            kSecUseAuthenticationContext as String: context
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        // errSecInteractionNotAllowed means item exists but needs auth
        // errSecSuccess means item exists and was readable
        let exists = (status == errSecSuccess || status == errSecInteractionNotAllowed)
        print("DEBUG Keychain: hasStoredCredentials = \(exists), status = \(status)")
        return exists
    }

    // Delete all stored credentials
    func deleteCredentials() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        let status = SecItemDelete(query as CFDictionary)
        print("DEBUG Keychain: Deleted credentials, status = \(status)")
    }
}
