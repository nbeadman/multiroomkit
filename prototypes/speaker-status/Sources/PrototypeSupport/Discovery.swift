import Foundation
import Darwin

public enum Discovery {
    public static func location(_ response: String, sender: String) -> URL? {
        guard response.hasPrefix("HTTP/1.1 200") else { return nil }
        let fields = response.components(separatedBy: "\r\n").compactMap { line -> (String, String)? in
            guard let colon = line.firstIndex(of: ":") else { return nil }
            return (line[..<colon].lowercased(), line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces))
        }
        guard fields.contains(where: { $0.0 == "st" && $0.1 == "urn:schemas-upnp-org:device:ZonePlayer:1" }),
              let location = fields.first(where: { $0.0 == "location" })?.1,
              let url = try? speakerURL(location), url.host == sender else { return nil }
        return url
    }

    public static func discover(seconds: Double, interface: String? = nil) throws -> [URL] {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0 else { throw StatusError("Cannot enumerate network interfaces.") }
        defer { if let list { freeifaddrs(list) } }
        var addresses: [in_addr] = []
        var cursor = list
        while let entry = cursor {
            defer { cursor = entry.pointee.ifa_next }
            let flags = entry.pointee.ifa_flags
            guard flags & UInt32(IFF_UP) != 0, flags & UInt32(IFF_MULTICAST) != 0,
                  flags & UInt32(IFF_LOOPBACK | IFF_POINTOPOINT) == 0,
                  interface == nil || String(cString: entry.pointee.ifa_name) == interface,
                  let address = entry.pointee.ifa_addr, address.pointee.sa_family == sa_family_t(AF_INET) else { continue }
            var ipv4 = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
            var text = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            _ = inet_ntop(AF_INET, &ipv4, &text, socklen_t(INET_ADDRSTRLEN))
            let host = String(decoding: text.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
            if privateIPv4(host) { addresses.append(ipv4) }
        }
        guard !addresses.isEmpty else { throw StatusError("No eligible private IPv4 multicast interface. Check LAN connectivity or --interface selection.") }
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { throw StatusError("Cannot create discovery socket.") }
        defer { close(fd) }
        var timeout = timeval(tv_sec: 0, tv_usec: 200_000)
        guard setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout))) == 0 else {
            throw StatusError("Cannot configure discovery timeout.")
        }
        var ttl: UInt8 = 2
        _ = setsockopt(fd, IPPROTO_IP, IP_MULTICAST_TTL, &ttl, socklen_t(MemoryLayout.size(ofValue: ttl)))
        var destination = sockaddr_in()
        destination.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        destination.sin_family = sa_family_t(AF_INET)
        destination.sin_port = UInt16(1900).bigEndian
        inet_pton(AF_INET, "239.255.255.250", &destination.sin_addr)
        let query = "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nMX: 1\r\nST: urn:schemas-upnp-org:device:ZonePlayer:1\r\n\r\n"
        let data = Data(query.utf8)
        let start = ProcessInfo.processInfo.systemUptime
        var nextSend = start
        var found: Set<URL> = []
        var received = 0
        while ProcessInfo.processInfo.systemUptime - start < seconds {
            let now = ProcessInfo.processInfo.systemUptime
            if now >= nextSend {
                for var localAddress in addresses {
                    guard setsockopt(fd, IPPROTO_IP, IP_MULTICAST_IF, &localAddress, socklen_t(MemoryLayout<in_addr>.size)) == 0 else {
                        throw StatusError("Cannot select multicast interface.")
                    }
                    let sent = withUnsafePointer(to: &destination) { pointer in
                        pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
                            data.withUnsafeBytes { sendto(fd, $0.baseAddress, $0.count, 0, address, socklen_t(MemoryLayout<sockaddr_in>.size)) }
                        }
                    }
                    guard sent == data.count else { throw StatusError("Discovery send failed. Check local network permission and interface.") }
                }
                nextSend = now + 1
            }
            var buffer = [UInt8](repeating: 0, count: 8192)
            var sender = sockaddr_in()
            var size = socklen_t(MemoryLayout<sockaddr_in>.size)
            let count = withUnsafeMutablePointer(to: &sender) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
                    buffer.withUnsafeMutableBytes { recvfrom(fd, $0.baseAddress, $0.count, 0, address, &size) }
                }
            }
            if count < 0 {
                if errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR { continue }
                throw StatusError("Discovery receive failed. Check local network permission.")
            }
            received += 1
            var ip = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            _ = inet_ntop(AF_INET, &sender.sin_addr, &ip, socklen_t(INET_ADDRSTRLEN))
            let senderIP = String(decoding: ip.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
            if let url = location(String(decoding: buffer.prefix(count), as: UTF8.self), sender: senderIP) {
                found.insert(url)
            }
        }
        guard !found.isEmpty else {
            throw StatusError("No usable Sonos discovery responses (\(received) datagrams, \(addresses.count) LAN interfaces). Check macOS Local Network permission, VPN/firewall, and Sonos UPnP access; try --host to bypass multicast.")
        }
        return found.sorted { $0.absoluteString < $1.absoluteString }
    }
}
