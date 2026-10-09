import Foundation

/// Read-only local Sonos status. Production addresses must be private/link-local IPv4 on port 1400.
public struct UPnPClient: SpeakerStatusProvider {
    private let seed: URL?
    private let discovery: SSDPDiscovery
    private let addressPolicy: SpeakerAddressPolicy
    private let http: HTTPTransport

    public init(seed: URL? = nil, discoveryTimeout: TimeInterval = 3, interface: String? = nil) throws {
        guard discoveryTimeout.isFinite, (0.1...30).contains(discoveryTimeout) else {
            throw MultiroomError.invalidConfiguration
        }
        let policy = SpeakerAddressPolicy()
        if let seed { _ = try policy.validate(seed) }
        self.init(seed: seed, discovery: SSDPDiscovery(timeout: discoveryTimeout, interface: interface),
                  addressPolicy: policy, http: HTTPTransport())
    }

    init(seed: URL? = nil, discovery: SSDPDiscovery, addressPolicy: SpeakerAddressPolicy,
         http: HTTPTransport = HTTPTransport()) {
        self.seed = seed
        self.discovery = discovery
        self.addressPolicy = addressPolicy
        self.http = http
    }

    private func soap(_ host: URL, service: String, action: String) async throws -> XMLNode {
        var components = URLComponents(url: try addressPolicy.validate(host), resolvingAgainstBaseURL: false)!
        components.path = service == "ZoneGroupTopology" ? "/ZoneGroupTopology/Control" : "/MediaRenderer/AVTransport/Control"
        guard let url = components.url else { throw MultiroomError.invalidConfiguration }
        let type = "urn:schemas-upnp-org:service:\(service):1"
        let arguments = service == "AVTransport" ? "<InstanceID>0</InstanceID>" : ""
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        request.setValue("\"\(type)#\(action)\"", forHTTPHeaderField: "SOAPACTION")
        request.httpBody = Data("<?xml version=\"1.0\"?><s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\"><s:Body><u:\(action) xmlns:u=\"\(type)\">\(arguments)</u:\(action)></s:Body></s:Envelope>".utf8)
        return try parseXML(await http.data(for: request))
    }

    public func snapshot() async throws -> SystemSnapshot {
        let startedAt = Date()
        let seeds: [URL]
        if let seed { seeds = [seed] }
        else { seeds = try await discovery.discover() }
        var zones: [Zone]?
        var topologyFailure = MultiroomError.invalidResponse
        for seed in seeds {
            do {
                let response = try await soap(seed, service: "ZoneGroupTopology", action: "GetZoneGroupState")
                guard let topology = response.value("ZoneGroupState") else { throw MultiroomError.invalidResponse }
                zones = try parseZones(topology)
                break
            } catch {
                try checkCancellation(error)
                topologyFailure = sanitized(error)
            }
        }
        guard let zones else { throw topologyFailure }
        let members = zones.flatMap(\.members)
        guard Set(members.map(\.id)).count == members.count else { throw MultiroomError.invalidResponse }
        let speakers = members.map { Speaker(id: $0.id, name: $0.name, role: $0.role, deviceCount: 1) }
        var groups: [SpeakerGroup] = []
        for zone in zones {
            try Task.checkCancellation()
            let coordinator = zone.members.first { $0.id == zone.coordinator }
            var state = PlaybackState.unknown
            var title: String?
            var artist: String?
            var source: String?
            var issues: [StatusIssue] = []
            if let coordinator, let host = URL(string: coordinator.location), (try? addressPolicy.validate(host)) != nil {
                do {
                    let response = try await soap(host, service: "AVTransport", action: "GetTransportInfo")
                    state = PlaybackState(wireValue: response.value("CurrentTransportState"))
                    if state == .unknown { issues.append(StatusIssue(operation: .playback, error: .invalidResponse)) }
                } catch { try record(error, operation: .playback, in: &issues) }
                do {
                    let response = try await soap(host, service: "AVTransport", action: "GetPositionInfo")
                    source = sourceName(response.value("TrackURI"))
                    if let text = response.value("TrackMetaData") {
                        let metadata = try parseXML(text)
                        title = metadata.value("streamContent") ?? metadata.value("title")
                        artist = metadata.value("creator")
                    }
                } catch { try record(error, operation: .metadata, in: &issues) }
                if source == nil {
                    do {
                        let response = try await soap(host, service: "AVTransport", action: "GetMediaInfo")
                        source = sourceName(response.value("CurrentURI"))
                    } catch { try record(error, operation: .source, in: &issues) }
                }
            } else {
                issues.append(StatusIssue(operation: .playback, error: .invalidResponse))
            }
            groups.append(SpeakerGroup(id: zone.coordinator, name: coordinator?.name ?? "Unknown group",
                                       speakerIDs: zone.members.map(\.id), playbackState: state,
                                       metadata: PlaybackMetadata(title: title, artist: artist, source: source), issues: issues))
        }
        let hosts = Set(members.compactMap { URL(string: $0.location)?.host })
        let warnings: [SnapshotWarning] = seeds.contains { !hosts.contains($0.host ?? "") } ? [.discoveryOutsideSelectedTopology] : []
        return SystemSnapshot(transport: .upnp, startedAt: startedAt, capturedAt: Date(), speakers: speakers,
                              groups: groups, warnings: warnings)
    }

    private func record(_ error: Error, operation: StatusIssue.Operation, in issues: inout [StatusIssue]) throws {
        try checkCancellation(error)
        issues.append(StatusIssue(operation: operation, error: sanitized(error)))
    }
}

private struct Member {
    let id: String
    let name: String
    let location: String
    let role: SpeakerRole
}

private struct Zone {
    let coordinator: String
    let members: [Member]
}

private func parseZones(_ text: String) throws -> [Zone] {
    let root = try parseXML(text)
    let zones = root.all("ZoneGroup").map { group in
        let members = group.children.filter { $0.name == "ZoneGroupMember" }.flatMap { node -> [Member] in
            let member = Member(id: node.attributes["UUID"] ?? "", name: node.attributes["ZoneName"] ?? "Unnamed",
                                location: node.attributes["Location"] ?? "",
                                role: node.attributes["Invisible"] == "1" ? .bonded : .player)
            return [member] + node.all("Satellite").map {
                Member(id: $0.attributes["UUID"] ?? "", name: $0.attributes["ZoneName"] ?? member.name,
                       location: $0.attributes["Location"] ?? "", role: .satellite)
            }
        }
        return Zone(coordinator: group.attributes["Coordinator"] ?? "", members: members)
    }
    guard !zones.isEmpty, zones.allSatisfy({ !$0.coordinator.isEmpty && !$0.members.isEmpty && $0.members.allSatisfy { !$0.id.isEmpty } }),
          Set(zones.map(\.coordinator)).count == zones.count else { throw MultiroomError.invalidResponse }
    return zones
}

private func sourceName(_ uri: String?) -> String? {
    guard let uri, !uri.isEmpty else { return nil }
    if uri.hasPrefix("x-sonos-htastream:") { return "TV" }
    if uri.hasPrefix("x-rincon-stream:") { return "Line-in" }
    if uri.hasPrefix("x-sonos-vli:") { return "AirPlay or virtual input" }
    if uri.hasPrefix("x-rincon-mp3radio:") { return "Radio" }
    if uri.hasPrefix("x-rincon:") { return "Grouped playback" }
    return "Media"
}
