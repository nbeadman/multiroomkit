import Foundation

public struct CloudCredentials: Sendable {
    public let token: String
    public let apiKey: String
    public init(token: String, apiKey: String) throws {
        guard !token.isEmpty, !apiKey.isEmpty,
              !token.contains(where: { $0.isWhitespace }), !apiKey.contains(where: { $0.isWhitespace }) else {
            throw StatusError("Both an access token and integration API key are required, without whitespace.")
        }
        self.token = token; self.apiKey = apiKey
    }
}

private struct Households: Decodable { struct Household: Decodable { let id: String }; let households: [Household] }
private struct Groups: Decodable {
    struct Group: Decodable { let id: String; let name: String; let playerIds: [String] }
    struct Player: Decodable { let id: String; let name: String; let deviceIds: [String]? }
    let groups: [Group]
    let players: [Player]
}
private struct Playback: Decodable { let playbackState: String }
private struct Metadata: Decodable {
    struct Named: Decodable { let name: String? }
    struct Track: Decodable { let name: String?; let artist: Named? }
    struct Item: Decodable { let track: Track? }
    struct Container: Decodable { let name: String?; let service: Named? }
    let currentItem: Item?
    let container: Container?
}

public struct CloudClient: Sendable {
    private let credentials: CloudCredentials
    private let fetch: Fetch
    public init(credentials: CloudCredentials, fetch: @escaping Fetch = HTTP.fetch) {
        self.credentials = credentials; self.fetch = fetch
    }

    private func get<T: Decodable>(_ path: [String], as type: T.Type) async throws -> T {
        var url = URL(string: "https://api.ws.sonos.com/control/api/v1")!
        for component in path {
            // IDs are opaque; prevent a returned ID from changing request routing.
            guard !component.isEmpty, component != ".", component != "..",
                  !component.contains("/"), !component.contains("\\"),
                  !component.contains("?"), !component.contains("#"), !component.contains("%") else {
                throw StatusError("Invalid resource identifier in cloud response or selection.")
            }
            url.appendPathComponent(component)
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer " + credentials.token, forHTTPHeaderField: "Authorization")
        request.setValue(credentials.apiKey, forHTTPHeaderField: "X-Sonos-Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data = try await fetch(request)
        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw StatusError("Unexpected cloud response format.") }
    }

    public func householdIDs() async throws -> [String] {
        try await get(["households"], as: Households.self).households.map(\.id)
    }

    public func snapshot(household selected: String? = nil) async throws -> Snapshot {
        let households = try await householdIDs()
        guard !households.isEmpty else { throw StatusError("No households available to this account.") }
        let household: String
        if let selected {
            guard households.contains(selected) else { throw StatusError("Selected household is not available to this account.") }
            household = selected
        } else {
            guard households.count == 1 else { throw StatusError("Multiple households found. Use --list-households, then --household to select the current system.") }
            household = households[0]
        }
        let topology = try await get(["households", household, "groups"], as: Groups.self)
        var rows: [SpeakerStatus] = []
        for player in topology.players {
            rows.append(SpeakerStatus(room: player.name,
                group: topology.groups.first { $0.playerIds.contains(player.id) }?.name ?? "Unknown group",
                deviceCount: max(1, player.deviceIds?.count ?? 1), issue: "Player has no readable group status."))
        }
        for group in topology.groups {
            var state = "unknown"
            var metadata: Metadata?
            var issues: [String] = []
            do {
                let result = try await get(["groups", group.id, "playback"], as: Playback.self)
                state = playbackState(result.playbackState)
                if state == "unknown" { issues.append("Unrecognized playback state.") }
            } catch { issues.append("Playback state unavailable: " + safeMessage(error)) }
            do { metadata = try await get(["groups", group.id, "playbackMetadata"], as: Metadata.self) }
            catch { issues.append("Track metadata unavailable: " + safeMessage(error)) }
            for (index, player) in topology.players.enumerated() where group.playerIds.contains(player.id) {
                rows[index].state = state
                rows[index].title = metadata?.currentItem?.track?.name
                rows[index].artist = metadata?.currentItem?.track?.artist?.name
                rows[index].source = metadata?.container?.service?.name ?? metadata?.container?.name
                rows[index].issue = issues.isEmpty ? nil : issues.joined(separator: " ")
            }
        }
        let warnings = rows.isEmpty ? ["Cloud returned no players for this household."] : []
        return Snapshot(transport: "Sonos Control API", speakers: rows.sorted { $0.room < $1.room }, warnings: warnings)
    }
}
