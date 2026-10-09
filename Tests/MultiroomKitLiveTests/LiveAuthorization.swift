import Foundation
import Darwin
import Security
import MultiroomKit

// Test-runner UI only. Credentials are neither arguments nor environment variables;
// The foreground launcher preserves terminal input. Never redirect its output.
enum TerminalInteractionError: Error, LocalizedError {
    case unavailable, readFailed, endOfInput, emptyInput, inputTooLong, invalidEncoding

    var errorDescription: String? {
        switch self {
        case .unavailable: "No interactive terminal is available. Run bash scripts/test-live.sh terminal-check from your terminal."
        case .readFailed: "The test runner cannot read terminal input. Use bash scripts/test-live.sh instead of swift test for interactive live tests."
        case .endOfInput: "Terminal input ended before a complete line was read."
        case .emptyInput: "No input was entered."
        case .inputTooLong: "Terminal input exceeds the length limit."
        case .invalidEncoding: "Terminal input is not valid UTF-8."
        }
    }
}

enum PrivateTerminal {
    static func write(_ value: String) throws {
        if let terminal = FileHandle(forWritingAtPath: "/dev/tty") {
            defer { try? terminal.close() }
            try terminal.write(contentsOf: Data(value.utf8))
        } else if isatty(STDERR_FILENO) == 1 {
            try FileHandle.standardError.write(contentsOf: Data(value.utf8))
        } else {
            throw TerminalInteractionError.unavailable
        }
    }

    static func hidden(_ prompt: String) throws -> String {
        // SwiftPM launchers can detach stdin or put XCTest outside the terminal's
        // foreground process group. The direct launcher keeps inherited stdin usable.
        let inherited = isatty(STDIN_FILENO) == 1
        let fd = inherited ? STDIN_FILENO : open("/dev/tty", O_RDWR)
        guard fd >= 0 else { throw TerminalInteractionError.unavailable }
        defer { if !inherited { close(fd) } }
        var original = termios()
        guard tcgetattr(fd, &original) == 0 else { throw TerminalInteractionError.unavailable }
        var hidden = original
        hidden.c_lflag &= ~tcflag_t(ECHO)
        // Discard queued command-paste newlines before displaying the prompt.
        guard tcsetattr(fd, TCSAFLUSH, &hidden) == 0 else { throw TerminalInteractionError.unavailable }
        defer { _ = tcsetattr(fd, TCSANOW, &original); try? write("\n") }
        try write(prompt)
        return try readLine {
            var byte: UInt8 = 0
            while true {
                let count = Darwin.read(fd, &byte, 1)
                if count == 1 { return byte }
                if count == 0 { return nil }
                if errno == EINTR { continue }
                throw TerminalInteractionError.readFailed
            }
        }
    }

    // Independently test line handling without opening a terminal or using secrets.
    static func readLine(nextByte: () throws -> UInt8?) throws -> String {
        var bytes: [UInt8] = []
        while true {
            guard let byte = try nextByte() else { throw TerminalInteractionError.endOfInput }
            if byte == 10 || byte == 13 { break }
            guard bytes.count < 4096 else { throw TerminalInteractionError.inputTooLong }
            bytes.append(byte)
        }
        guard !bytes.isEmpty else { throw TerminalInteractionError.emptyInput }
        guard let value = String(bytes: bytes, encoding: .utf8) else { throw TerminalInteractionError.invalidEncoding }
        return value
    }
}

private final class RefuseRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

enum LiveAuthorization {
    private static let redirect = "https://nbeadman.github.io/multiroomkit/sonos/callback/"
    private static func encode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"))!
    }

    static func client() async throws -> ControlAPIClient {
        let key = try PrivateTerminal.hidden("Sonos integration API key (hidden): ")
        let secret = try PrivateTerminal.hidden("Sonos client secret (hidden): ")
        _ = try ControlAPICredentials(accessToken: secret, apiKey: key)
        guard !key.contains(":") else { throw MultiroomError.authenticationFailed }
        var random = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, random.count, &random) == errSecSuccess else {
            throw MultiroomError.authenticationFailed
        }
        let state = random.map { String(format: "%02x", $0) }.joined()
        let url = "https://api.sonos.com/login/v3/oauth?client_id=\(encode(key))&response_type=code&state=\(state)&scope=playback-control-all&redirect_uri=\(encode(redirect))"
        try PrivateTerminal.write("Open this private authorization URL in your browser; do not share it:\n\(url)\n")
        let returnedState = try PrivateTerminal.hidden("Returned state (hidden): ")
        let code = try PrivateTerminal.hidden("Authorization code (hidden): ")
        guard returnedState == state else { throw MultiroomError.authenticationFailed }
        var request = URLRequest(url: URL(string: "https://api.sonos.com/login/v3/oauth/access")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded;charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("Basic " + Data("\(key):\(secret)".utf8).base64EncodedString(), forHTTPHeaderField: "Authorization")
        request.httpBody = Data("grant_type=authorization_code&code=\(encode(code))&redirect_uri=\(encode(redirect))".utf8)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration, delegate: RefuseRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let data: Data
        do {
            let (stream, response) = try await session.bytes(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw MultiroomError.authenticationFailed }
            var bounded = Data()
            for try await byte in stream {
                guard bounded.count < 65536 else { throw MultiroomError.authenticationFailed }
                bounded.append(byte)
            }
            data = bounded
        } catch { throw MultiroomError.authenticationFailed }
        struct Token: Decodable {
            let access_token: String
            let token_type: String
            let expires_in: Int
            let scope: String?
        }
        guard let token = try? JSONDecoder().decode(Token.self, from: data),
              token.token_type.lowercased() == "bearer", token.expires_in > 0,
              token.scope?.split(separator: " ").contains("playback-control-all") ?? true else {
            throw MultiroomError.authenticationFailed
        }
        let credentials = try ControlAPICredentials(accessToken: token.access_token, apiKey: key)
        let client = ControlAPIClient { credentials }
        let households = try await client.households()
        guard !households.isEmpty else { throw MultiroomError.noHouseholds }
        if households.count == 1 { return client }
        // Household identifiers stay on the private terminal, never in test logs.
        for (index, id) in households.enumerated() { try PrivateTerminal.write("\(index + 1): \(id)\n") }
        let choice = try PrivateTerminal.hidden("Household number (hidden): ")
        guard let index = Int(choice), households.indices.contains(index - 1) else { throw MultiroomError.householdUnavailable }
        return ControlAPIClient(householdID: households[index - 1]) { credentials }
    }
}
