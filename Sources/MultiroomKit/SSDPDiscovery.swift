import Foundation
import Darwin

struct SSDPDiscovery: Sendable {
    var timeout: TimeInterval = 3
    var interface: String?
    var addressPolicy = SpeakerAddressPolicy()
    // Internal socket settings let integration tests use an isolated UDP responder.
    var destinationHost = "239.255.255.250"
    var destinationPort: UInt16 = 1900
    var testInterface: String?

    static func location(_ response: String, sender: String, policy: SpeakerAddressPolicy) -> URL? {
        guard response.hasPrefix("HTTP/1.1 200 ") else { return nil }
        let fields = response.components(separatedBy: "\r\n").compactMap { line -> (String, String)? in
            guard let colon = line.firstIndex(of: ":") else { return nil }
            return (line[..<colon].lowercased(), line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces))
        }
        guard fields.contains(where: { $0.0 == "st" && $0.1 == "urn:schemas-upnp-org:device:ZonePlayer:1" }),
              let text = fields.first(where: { $0.0 == "location" })?.1, let url = URL(string: text),
              (try? policy.validate(url)) != nil, url.host == sender else { return nil }
        return url
    }

    func discover() async throws -> [URL] {
        let task = Task.detached { try blockingDiscover() }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private func interfaces() throws -> [in_addr] {
        if let testInterface {
            var address = in_addr()
            guard inet_pton(AF_INET, testInterface, &address) == 1 else { throw MultiroomError.invalidConfiguration }
            return [address]
        }
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0 else { throw MultiroomError.networkUnavailable }
        defer { if let list { freeifaddrs(list) } }
        var result: [in_addr] = []
        var cursor = list
        while let entry = cursor {
            defer { cursor = entry.pointee.ifa_next }
            let flags = entry.pointee.ifa_flags
            guard flags & UInt32(IFF_UP | IFF_MULTICAST) == UInt32(IFF_UP | IFF_MULTICAST),
                  flags & UInt32(IFF_LOOPBACK | IFF_POINTOPOINT) == 0,
                  interface == nil || String(cString: entry.pointee.ifa_name) == interface,
                  let address = entry.pointee.ifa_addr, address.pointee.sa_family == sa_family_t(AF_INET) else { continue }
            let ipv4 = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
            if SpeakerAddressPolicy.isPrivateIPv4(Self.string(ipv4)) { result.append(ipv4) }
        }
        guard !result.isEmpty else { throw MultiroomError.noSpeakers }
        return result
    }

    private static func string(_ address: in_addr) -> String {
        var address = address
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        _ = inet_ntop(AF_INET, &address, &buffer, socklen_t(INET_ADDRSTRLEN))
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    private func blockingDiscover() throws -> [URL] {
        let addresses = try interfaces()
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { throw MultiroomError.networkUnavailable }
        defer { close(fd) }
        var receiveTimeout = timeval(tv_sec: 0, tv_usec: 100_000)
        guard setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &receiveTimeout,
                         socklen_t(MemoryLayout.size(ofValue: receiveTimeout))) == 0 else {
            throw MultiroomError.networkUnavailable
        }
        var ttl: UInt8 = 2
        _ = setsockopt(fd, IPPROTO_IP, IP_MULTICAST_TTL, &ttl, socklen_t(MemoryLayout.size(ofValue: ttl)))
        var destination = sockaddr_in()
        destination.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        destination.sin_family = sa_family_t(AF_INET)
        destination.sin_port = destinationPort.bigEndian
        guard inet_pton(AF_INET, destinationHost, &destination.sin_addr) == 1 else {
            throw MultiroomError.invalidConfiguration
        }
        let query = Data("M-SEARCH * HTTP/1.1\r\nHOST: \(destinationHost):\(destinationPort)\r\nMAN: \"ssdp:discover\"\r\nMX: 1\r\nST: urn:schemas-upnp-org:device:ZonePlayer:1\r\n\r\n".utf8)
        let start = ProcessInfo.processInfo.systemUptime
        var nextSend = start
        var found: Set<URL> = []
        while ProcessInfo.processInfo.systemUptime - start < timeout {
            try Task.checkCancellation()
            let now = ProcessInfo.processInfo.systemUptime
            if now >= nextSend {
                for var address in addresses {
                    if testInterface == nil {
                        guard setsockopt(fd, IPPROTO_IP, IP_MULTICAST_IF, &address,
                                         socklen_t(MemoryLayout<in_addr>.size)) == 0 else {
                            throw MultiroomError.networkUnavailable
                        }
                    }
                    let sent = withUnsafePointer(to: &destination) { pointer in
                        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { target in
                            query.withUnsafeBytes { sendto(fd, $0.baseAddress, $0.count, 0, target, socklen_t(MemoryLayout<sockaddr_in>.size)) }
                        }
                    }
                    guard sent == query.count else { throw MultiroomError.networkUnavailable }
                }
                nextSend = now + 1
            }
            var buffer = [UInt8](repeating: 0, count: 8192)
            var sender = sockaddr_in()
            var size = socklen_t(MemoryLayout<sockaddr_in>.size)
            let count = withUnsafeMutablePointer(to: &sender) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { source in
                    buffer.withUnsafeMutableBytes { recvfrom(fd, $0.baseAddress, $0.count, 0, source, &size) }
                }
            }
            if count < 0 {
                if errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR { continue }
                throw MultiroomError.networkUnavailable
            }
            if let url = Self.location(String(decoding: buffer.prefix(count), as: UTF8.self),
                                       sender: Self.string(sender.sin_addr), policy: addressPolicy) {
                found.insert(url)
            }
        }
        try Task.checkCancellation()
        guard !found.isEmpty else { throw MultiroomError.noSpeakers }
        return found.sorted { $0.absoluteString < $1.absoluteString }
    }
}
