import Foundation
import Security
import Darwin

public enum TerminalInput {
    public static func hidden(_ prompt: String) throws -> String {
        guard isatty(STDIN_FILENO) == 1 else {
            throw StatusError("Sonos authorization requires an interactive terminal. Do not pass credentials as arguments or through a pipe.")
        }
        var original = termios()
        guard tcgetattr(STDIN_FILENO, &original) == 0 else {
            throw StatusError("Could not secure terminal input.")
        }
        var hidden = original
        hidden.c_lflag &= ~tcflag_t(ECHO)
        guard tcsetattr(STDIN_FILENO, TCSANOW, &hidden) == 0 else {
            throw StatusError("Could not disable terminal echo.")
        }
        defer {
            _ = tcsetattr(STDIN_FILENO, TCSANOW, &original)
            FileHandle.standardError.write(Data("\n".utf8))
        }
        FileHandle.standardError.write(Data(prompt.utf8))
        guard let value = readLine(strippingNewline: true), !value.isEmpty else {
            throw StatusError("Sonos authorization cancelled or an input was empty.")
        }
        return value
    }
}

private struct TokenResponse: Decodable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case scope
    }
}

public struct SonosOAuth: Sendable {
    public static let redirectURI = "https://nbeadman.github.io/multiroomkit/sonos/callback/"
    private static let loginURL = URL(string: "https://api.sonos.com/login/v3/oauth")!
    private static let tokenURL = URL(string: "https://api.sonos.com/login/v3/oauth/access")!

    private let apiKey: String
    private let clientSecret: String
    private let fetch: Fetch

    public init(apiKey: String, clientSecret: String, fetch: @escaping Fetch = HTTP.fetch) throws {
        guard Self.validCredential(apiKey), !apiKey.contains(":"), Self.validCredential(clientSecret) else {
            throw StatusError("The Sonos API key and client secret must be non-empty with no whitespace or control characters; the key cannot contain a colon.")
        }
        self.apiKey = apiKey
        self.clientSecret = clientSecret
        self.fetch = fetch
    }

    private static func validCredential(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 4096 && !value.unicodeScalars.contains {
            CharacterSet.whitespacesAndNewlines.contains($0) || CharacterSet.controlCharacters.contains($0)
        }
    }

    public static func randomState() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw StatusError("Could not create a secure authorization state.")
        }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    public func authorizationURL(state: String) throws -> URL {
        guard !state.isEmpty, state.count <= 256,
              state.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }) else {
            throw StatusError("Invalid authorization state.")
        }
        var components = URLComponents(url: Self.loginURL, resolvingAgainstBaseURL: false)!
        // Sonos requires the redirect URI to be percent-encoded, including its
        // slashes; URLComponents.queryItems otherwise leaves those characters raw.
        components.percentEncodedQuery = [
            "client_id=\(Self.formEncode(apiKey))",
            "response_type=code",
            "state=\(state)",
            "scope=playback-control-all",
            "redirect_uri=\(Self.formEncode(Self.redirectURI))",
        ].joined(separator: "&")
        guard let url = components.url else { throw StatusError("Could not create the Sonos authorization URL.") }
        return url
    }

    public func exchange(code: String, returnedState: String, expectedState: String) async throws -> CloudCredentials {
        guard returnedState == expectedState else {
            throw StatusError("Authorization state did not match. Start a new login; no token request was sent.")
        }
        guard !code.isEmpty, code.count <= 4096,
              !code.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw StatusError("Invalid Sonos authorization code.")
        }
        var request = URLRequest(url: Self.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded;charset=utf-8", forHTTPHeaderField: "Content-Type")
        let basic = Data("\(apiKey):\(clientSecret)".utf8).base64EncodedString()
        request.setValue("Basic " + basic, forHTTPHeaderField: "Authorization")
        let body = "grant_type=authorization_code&code=\(Self.formEncode(code))&redirect_uri=\(Self.formEncode(Self.redirectURI))"
        request.httpBody = Data(body.utf8)
        let response = try await fetch(request)
        let token: TokenResponse
        do { token = try JSONDecoder().decode(TokenResponse.self, from: response) }
        catch { throw StatusError("Unexpected Sonos token response format.") }
        guard token.tokenType.caseInsensitiveCompare("Bearer") == .orderedSame,
              token.expiresIn > 0,
              token.scope?.split(separator: " ").contains("playback-control-all") ?? true else {
            throw StatusError("Sonos returned an unsupported token type or scope.")
        }
        return try CloudCredentials(token: token.accessToken, apiKey: apiKey)
    }

    private static func formEncode(_ value: String) -> String {
        let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return value.addingPercentEncoding(withAllowedCharacters: unreserved)!
    }
}
