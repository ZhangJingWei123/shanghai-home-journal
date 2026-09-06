import AuthenticationServices
import Combine
import Foundation
import Security
import UIKit

enum LoginProvider: String, Codable, Equatable {
    case apple
    case weChat

    var title: String {
        switch self {
        case .apple: "苹果"
        case .weChat: "微信"
        }
    }
}

struct AuthenticatedUser: Codable, Equatable {
    let id: String
    let displayName: String
    let provider: LoginProvider
}

protocol AuthSessionPersisting {
    func load() -> AuthenticatedUser?
    func save(_ user: AuthenticatedUser) throws
    func remove() throws
}

enum AuthSessionPersistenceError: Error, Equatable {
    case keychain(OSStatus)
}

final class KeychainAuthSessionStore: AuthSessionPersisting {
    private let service = "\(Bundle.main.bundleIdentifier ?? "HuJu").authentication"
    private let account = "current-user"

    func load() -> AuthenticatedUser? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard
            SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data
        else {
            return nil
        }
        return try? JSONDecoder().decode(AuthenticatedUser.self, from: data)
    }

    func save(_ user: AuthenticatedUser) throws {
        let data = try JSONEncoder().encode(user)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw AuthSessionPersistenceError.keychain(updateStatus)
        }

        var addQuery = query
        attributes.forEach { addQuery[$0.key] = $0.value }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw AuthSessionPersistenceError.keychain(addStatus)
        }
    }

    func remove() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AuthSessionPersistenceError.keychain(status)
        }
    }
}

final class UserDefaultsAuthSessionStore: AuthSessionPersisting {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults, key: String = "huju.authenticated-user.v1") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> AuthenticatedUser? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(AuthenticatedUser.self, from: data)
    }

    func save(_ user: AuthenticatedUser) throws {
        let data = try JSONEncoder().encode(user)
        defaults.set(data, forKey: key)
    }

    func remove() throws {
        defaults.removeObject(forKey: key)
    }
}

enum AuthenticationError: LocalizedError, Equatable {
    case invalidAppleCredential
    case cancelled
    case weChatNotConfigured
    case invalidCallback
    case serverRejected
    case unavailable
    case sessionPersistenceFailed
    case signOutFailed

    var errorDescription: String? {
        switch self {
        case .invalidAppleCredential:
            "未能读取苹果账号信息，请重试。"
        case .cancelled:
            "登录已取消。"
        case .weChatNotConfigured:
            "微信登录尚未配置开放平台与服务端地址。"
        case .invalidCallback:
            "登录回调校验失败，请重新发起登录。"
        case .serverRejected:
            "登录服务暂时不可用，请稍后重试。"
        case .unavailable:
            "当前设备暂时无法完成登录。"
        case .sessionPersistenceFailed:
            "无法安全保存登录状态，请重试。"
        case .signOutFailed:
            "未能清除本机登录状态，请重试。"
        }
    }
}

protocol WeChatAuthenticating {
    @MainActor
    func authenticate() async throws -> AuthenticatedUser
}

protocol AppleCredentialStateChecking {
    @MainActor
    func credentialState(
        for userID: String
    ) async throws -> ASAuthorizationAppleIDProvider.CredentialState
}

struct SystemAppleCredentialStateChecker: AppleCredentialStateChecking {
    @MainActor
    func credentialState(
        for userID: String
    ) async throws -> ASAuthorizationAppleIDProvider.CredentialState {
        let provider = ASAuthorizationAppleIDProvider()
        return try await withCheckedThrowingContinuation { continuation in
            provider.getCredentialState(forUserID: userID) { state, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: state)
                }
            }
        }
    }
}

@MainActor
final class AuthenticationStore: NSObject, ObservableObject {
    @Published private(set) var currentUser: AuthenticatedUser?
    @Published private(set) var isWorking = false
    @Published private(set) var isLoginPresented: Bool
    @Published var errorMessage: String?

    private let storage: AuthSessionPersisting
    private let weChatAuthenticator: WeChatAuthenticating
    private let appleCredentialStateChecker: AppleCredentialStateChecking
    private let allowsSimulatorLogin: Bool

    init(
        storage: AuthSessionPersisting = KeychainAuthSessionStore(),
        weChatAuthenticator: WeChatAuthenticating = WeChatWebAuthenticator(),
        appleCredentialStateChecker: AppleCredentialStateChecking =
            SystemAppleCredentialStateChecker(),
        allowsSimulatorLogin: Bool = true
    ) {
        self.storage = storage
        self.weChatAuthenticator = weChatAuthenticator
        self.appleCredentialStateChecker = appleCredentialStateChecker
        self.isLoginPresented = ProcessInfo.processInfo.arguments.contains("-showLogin")
        #if targetEnvironment(simulator)
        self.allowsSimulatorLogin = allowsSimulatorLogin
        #else
        self.allowsSimulatorLogin = false
        #endif
        super.init()

        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTestAuthenticated") {
            currentUser = AuthenticatedUser(
                id: "界面验证用户",
                displayName: "看房人",
                provider: .apple
            )
        } else {
            currentUser = storage.load()
        }
    }

    var isAuthenticated: Bool {
        currentUser != nil
    }

    func presentLogin() {
        errorMessage = nil
        isLoginPresented = true
    }

    func continueWithoutAccount() {
        errorMessage = nil
        isLoginPresented = false
    }

    func completeAppleAuthorization(_ result: Result<ASAuthorization, Error>) {
        isWorking = false
        switch result {
        case let .success(authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = AuthenticationError.invalidAppleCredential.localizedDescription
                return
            }

            let components = credential.fullName
            let providedName = [components?.familyName, components?.givenName]
                .compactMap { $0 }
                .joined()
            let user = AuthenticatedUser(
                id: credential.user,
                displayName: providedName.isEmpty ? "选个家用户" : providedName,
                provider: .apple
            )
            finish(with: user)
        case let .failure(error):
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = AuthenticationError.unavailable.localizedDescription
            }
        }
    }

    func beginAppleAuthorization() {
        errorMessage = nil
        isWorking = true
    }

    func prepareAppleAuthorization(_ request: ASAuthorizationAppleIDRequest) {
        beginAppleAuthorization()
        request.requestedScopes = [.fullName, .email]
    }

    func signInWithApple() {
        if allowsSimulatorLogin {
            beginAppleAuthorization()
            finishWithSimulatorUser(provider: .apple)
            isWorking = false
            return
        }

        let request = ASAuthorizationAppleIDProvider().createRequest()
        prepareAppleAuthorization(request)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func signInWithWeChat() async {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }

        if allowsSimulatorLogin {
            finishWithSimulatorUser(provider: .weChat)
            return
        }

        do {
            finish(with: try await weChatAuthenticator.authenticate())
        } catch let error as AuthenticationError {
            if error != .cancelled {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = AuthenticationError.serverRejected.localizedDescription
        }
    }

    @discardableResult
    func signOut() -> Bool {
        do {
            try storage.remove()
            currentUser = nil
            isLoginPresented = false
            errorMessage = nil
            return true
        } catch {
            errorMessage = AuthenticationError.signOutFailed.localizedDescription
            return false
        }
    }

    func validateStoredSession() async {
        guard
            let currentUser,
            currentUser.provider == .apple,
            !currentUser.id.hasPrefix("simulator."),
            !ProcessInfo.processInfo.arguments.contains("-uiTestAuthenticated")
        else {
            return
        }

        do {
            let state = try await appleCredentialStateChecker.credentialState(
                for: currentUser.id
            )
            switch state {
            case .authorized:
                return
            case .revoked, .notFound, .transferred:
                signOut()
            @unknown default:
                signOut()
            }
        } catch {
            return
        }
    }

    private func finish(with user: AuthenticatedUser) {
        do {
            try storage.save(user)
            currentUser = user
            isLoginPresented = false
            errorMessage = nil
        } catch {
            currentUser = nil
            errorMessage = AuthenticationError.sessionPersistenceFailed.localizedDescription
        }
    }

    private func finishWithSimulatorUser(provider: LoginProvider) {
        finish(
            with: AuthenticatedUser(
                id: "simulator.\(provider.rawValue)",
                displayName: "看房体验账号",
                provider: provider
            )
        )
    }
}

extension AuthenticationStore:
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        completeAppleAuthorization(.success(authorization))
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        completeAppleAuthorization(.failure(error))
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}

private struct WeChatServerUser: Decodable {
    let id: String
    let displayName: String
}

final class WeChatWebAuthenticator: NSObject, WeChatAuthenticating {
    private var session: ASWebAuthenticationSession?

    @MainActor
    func authenticate() async throws -> AuthenticatedUser {
        guard
            let authorizationValue = Bundle.main.object(
                forInfoDictionaryKey: "HUJUWeChatAuthorizationURL"
            ) as? String,
            let exchangeValue = Bundle.main.object(
                forInfoDictionaryKey: "HUJUWeChatExchangeURL"
            ) as? String,
            !authorizationValue.isEmpty,
            !exchangeValue.isEmpty,
            var components = URLComponents(string: authorizationValue),
            let exchangeURL = URL(string: exchangeValue)
        else {
            throw AuthenticationError.weChatNotConfigured
        }

        let state = UUID().uuidString
        let callback = "huju://auth/wechat"
        components.queryItems = (components.queryItems ?? []) + [
            URLQueryItem(name: "callback_uri", value: callback),
            URLQueryItem(name: "state", value: state)
        ]
        guard let authorizationURL = components.url else {
            throw AuthenticationError.weChatNotConfigured
        }

        let callbackURL = try await startSession(at: authorizationURL)
        guard
            let callbackComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
            callbackComponents.scheme == "huju",
            callbackComponents.host == "auth",
            callbackComponents.path == "/wechat",
            callbackComponents.value(for: "state") == state,
            let code = callbackComponents.value(for: "code"),
            !code.isEmpty
        else {
            throw AuthenticationError.invalidCallback
        }

        var request = URLRequest(url: exchangeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([
            "code": code,
            "callback_uri": callback
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard
            let httpResponse = response as? HTTPURLResponse,
            (200 ..< 300).contains(httpResponse.statusCode),
            let serverUser = try? JSONDecoder().decode(WeChatServerUser.self, from: data)
        else {
            throw AuthenticationError.serverRejected
        }

        return AuthenticatedUser(
            id: serverUser.id,
            displayName: serverUser.displayName,
            provider: .weChat
        )
    }

    @MainActor
    private func startSession(at url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "huju"
            ) { [weak self] callbackURL, error in
                self?.session = nil
                if let error = error as? ASWebAuthenticationSessionError,
                   error.code == .canceledLogin {
                    continuation.resume(throwing: AuthenticationError.cancelled)
                } else if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: AuthenticationError.unavailable)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            self.session = session
            guard session.start() else {
                self.session = nil
                continuation.resume(throwing: AuthenticationError.unavailable)
                return
            }
        }
    }
}

extension WeChatWebAuthenticator: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}

private extension URLComponents {
    func value(for name: String) -> String? {
        queryItems?.first { $0.name == name }?.value
    }
}
