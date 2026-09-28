import Foundation

public struct Member: Sendable {
    public let id: String
    public let name: String
    public let location: String
    public let role: String
}

public struct Zone: Sendable {
    public let coordinator: String
    public let members: [Member]
}

public func zones(from data: Data) throws -> [Zone] {
    let response = try parseXML(data)
    let root: XMLNode
    if let nested = response.value("ZoneGroupState") { root = try parseXML(nested) }
    else { root = response }
    let result = root.all("ZoneGroup").map { group in
        let members = group.children.filter { $0.name == "ZoneGroupMember" }.flatMap { node -> [Member] in
            let primary = Member(id: node.attributes["UUID"] ?? "", name: node.attributes["ZoneName"] ?? "Unnamed",
                location: node.attributes["Location"] ?? "", role: node.attributes["Invisible"] == "1" ? "bonded/hidden" : "player")
            return [primary] + node.all("Satellite").map {
                Member(id: $0.attributes["UUID"] ?? "", name: $0.attributes["ZoneName"] ?? primary.name,
                       location: $0.attributes["Location"] ?? "", role: "satellite")
            }
        }
        return Zone(coordinator: group.attributes["Coordinator"] ?? "", members: members)
    }
    guard !result.isEmpty, result.allSatisfy({ !$0.coordinator.isEmpty && !$0.members.isEmpty && $0.members.allSatisfy { !$0.id.isEmpty } }) else {
        throw StatusError("No usable topology in speaker response.")
    }
    return result
}

public struct UPnPClient: Sendable {
    private let fetch: Fetch
    public init(fetch: @escaping Fetch = HTTP.fetch) { self.fetch = fetch }

    private func soap(host: URL, service: String, action: String, arguments: String = "") async throws -> XMLNode {
        let path = service == "ZoneGroupTopology" ? "/ZoneGroupTopology/Control" : "/MediaRenderer/AVTransport/Control"
        var components = URLComponents(url: host, resolvingAgainstBaseURL: false)!
        components.path = path
        let url = try speakerURL(components.url!.absoluteString)
        let type = "urn:schemas-upnp-org:service:\(service):1"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        request.setValue("\"\(type)#\(action)\"", forHTTPHeaderField: "SOAPACTION")
        request.httpBody = Data("<?xml version=\"1.0\"?><s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\"><s:Body><u:\(action) xmlns:u=\"\(type)\">\(arguments)</u:\(action)></s:Body></s:Envelope>".utf8)
        return try parseXML(await fetch(request))
    }

    public func snapshot(seeds: [URL]) async throws -> Snapshot {
        guard !seeds.isEmpty else { throw StatusError("No UPnP speakers discovered. Check same LAN, Sonos UPnP setting, VPN, firewall, and macOS Local Network permission; try --host with a known speaker IPv4 address.") }
        var topology: [Zone]?
        for seed in seeds {
            do {
                let response = try await soap(host: seed, service: "ZoneGroupTopology", action: "GetZoneGroupState")
                guard let value = response.value("ZoneGroupState") else { throw StatusError("Missing topology.") }
                topology = try zones(from: Data(value.utf8))
                break
            } catch { continue }
        }
        guard let topology else { throw StatusError("Discovered speakers did not return readable UPnP topology. Check UPnP access and connectivity.") }
        var rows: [SpeakerStatus] = []
        var seen: Set<String> = []
        for zone in topology {
            let coordinator = zone.members.first { $0.id == zone.coordinator }
            let groupName = coordinator?.name ?? "Unknown group"
            var state = "unknown"
            var title: String?
            var artist: String?
            var source: String?
            var issues: [String] = []
            if let coordinator, let host = try? speakerURL(coordinator.location) {
                do {
                    let response = try await soap(host: host, service: "AVTransport", action: "GetTransportInfo", arguments: "<InstanceID>0</InstanceID>")
                    state = playbackState(response.value("CurrentTransportState"))
                    if state == "unknown" { issues.append("Unrecognized playback state.") }
                } catch { issues.append("Playback state unavailable: " + safeMessage(error)) }
                do {
                    let response = try await soap(host: host, service: "AVTransport", action: "GetPositionInfo", arguments: "<InstanceID>0</InstanceID>")
                    source = sourceName(response.value("TrackURI"))
                    if let metadata = response.value("TrackMetaData") {
                        let track = try parseXML(metadata)
                        title = track.value("title")
                        artist = track.value("creator")
                        // Radio metadata often uses streamContent for the current programme.
                        if let stream = track.value("streamContent") { title = stream }
                    }
                } catch { issues.append("Track metadata unavailable: " + safeMessage(error)) }
                if source == nil {
                    do {
                        let response = try await soap(host: host, service: "AVTransport", action: "GetMediaInfo", arguments: "<InstanceID>0</InstanceID>")
                        source = sourceName(response.value("CurrentURI"))
                    } catch { issues.append("Source unavailable: " + safeMessage(error)) }
                }
            } else { issues.append("Group coordinator unavailable or uses an unsupported address.") }
            for member in zone.members where seen.insert(member.id).inserted {
                rows.append(SpeakerStatus(room: member.name, group: groupName, role: member.role,
                    state: state, title: title, artist: artist, source: source,
                    issue: issues.isEmpty ? nil : issues.joined(separator: " ")))
            }
        }
        let topologyHosts = Set(topology.flatMap(\.members).compactMap { URL(string: $0.location)?.host })
        let outsideTopology = seeds.contains { !topologyHosts.contains($0.host ?? "") }
        let warnings = outsideTopology ? ["Some discovered speakers are outside the selected topology. Multiple households or a changing topology may exist; use --host to select a system explicitly."] : []
        return Snapshot(transport: "UPnP", speakers: rows.sorted { $0.room < $1.room }, warnings: warnings)
    }
}

public func sourceName(_ uri: String?) -> String? {
    guard let uri, !uri.isEmpty else { return nil }
    if uri.hasPrefix("x-sonos-htastream:") { return "TV" }
    if uri.hasPrefix("x-rincon-stream:") { return "Line-in" }
    if uri.hasPrefix("x-sonos-vli:") { return "AirPlay or virtual input" }
    if uri.hasPrefix("x-rincon-mp3radio:") { return "Radio" }
    if uri.hasPrefix("x-rincon:") { return "Grouped playback" }
    return "Media" // Do not expose URIs, which may embed signed credentials.
}
