import Foundation

private final class NoRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

struct HTTPTransport: Sendable {
    var timeout: TimeInterval = 8
    var maximumBytes = 2_000_000

    func data(for request: URLRequest) async throws -> Data {
        try Task.checkCancellation()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration, delegate: NoRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let response = response as? HTTPURLResponse else { throw MultiroomError.invalidResponse }
            switch response.statusCode {
            case 200..<300: break
            case 401: throw MultiroomError.unauthorized
            case 403: throw MultiroomError.forbidden
            case 410: throw MultiroomError.resourceGone
            case 429:
                let seconds = response.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init)
                throw MultiroomError.rateLimited(retryAfter: seconds.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil })
            default: throw MultiroomError.http(status: response.statusCode)
            }
            var data = Data()
            for try await byte in bytes {
                try Task.checkCancellation()
                guard data.count < maximumBytes else { throw MultiroomError.responseTooLarge }
                data.append(byte)
            }
            return data
        } catch {
            try checkCancellation(error)
            if let error = error as? MultiroomError { throw error }
            if (error as? URLError)?.code == .timedOut { throw MultiroomError.timedOut }
            throw MultiroomError.networkUnavailable
        }
    }
}

struct SpeakerAddressPolicy: Sendable {
    // Only internal test initializers can permit a loopback server on an ephemeral port.
    var loopbackPort: Int?

    func validate(_ url: URL) throws -> URL {
        guard url.scheme == "http", let host = url.host, url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil else { throw MultiroomError.invalidConfiguration }
        if let loopbackPort {
            guard host == "127.0.0.1", url.port == loopbackPort else { throw MultiroomError.invalidConfiguration }
        } else {
            guard Self.isPrivateIPv4(host), url.port == 1400 else { throw MultiroomError.invalidConfiguration }
        }
        return url
    }

    static func isPrivateIPv4(_ host: String) -> Bool {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              parts.allSatisfy({ UInt8($0) != nil }) else { return false }
        let values = parts.map { Int($0)! }
        return values[0] == 10 || (values[0] == 172 && (16...31).contains(values[1])) ||
            (values[0] == 192 && values[1] == 168) || (values[0] == 169 && values[1] == 254)
    }
}
