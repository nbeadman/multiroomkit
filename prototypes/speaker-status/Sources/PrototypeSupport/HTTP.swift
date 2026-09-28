import Foundation

public typealias Fetch = @Sendable (URLRequest) async throws -> Data

private final class NoRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        // A redirect must not forward credentials or turn discovery into arbitrary network access.
        completionHandler(nil)
    }
}

public enum HTTP {
    public static func fetch(_ request: URLRequest) async throws -> Data {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 12
        config.httpCookieStorage = nil
        config.urlCache = nil
        let session = URLSession(configuration: config, delegate: NoRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse else { throw StatusError("Invalid HTTP response.") }
            guard (200..<300).contains(http.statusCode) else {
                throw StatusError("HTTP \(http.statusCode). Check access, availability, or authentication.")
            }
            var data = Data()
            for try await byte in bytes {
                guard data.count < 2_000_000 else { throw StatusError("Response exceeds the prototype size limit.") }
                data.append(byte)
            }
            return data
        } catch let error as StatusError { throw error }
        catch { throw StatusError("Network request failed or timed out. Check connectivity and permissions.") }
    }
}

public func privateIPv4(_ host: String) -> Bool {
    let pieces = host.split(separator: ".", omittingEmptySubsequences: false)
    guard pieces.count == 4, pieces.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
          pieces.allSatisfy({ UInt8($0) != nil }) else { return false }
    let octets = pieces.map { Int($0)! }
    return octets[0] == 10 || (octets[0] == 172 && (16...31).contains(octets[1])) ||
        (octets[0] == 192 && octets[1] == 168) || (octets[0] == 169 && octets[1] == 254)
}

public func speakerURL(_ value: String) throws -> URL {
    guard let url = URL(string: value), url.scheme == "http", let host = url.host,
          privateIPv4(host), url.port == 1400, url.user == nil, url.password == nil,
          url.query == nil, url.fragment == nil else {
        throw StatusError("Unsupported speaker URL. This prototype accepts private IPv4 HTTP on port 1400 only.")
    }
    return url
}
