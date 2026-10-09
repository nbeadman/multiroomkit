import Foundation

/// Obtain these through your application's authorization flow. Never embed a client secret in an app.
public struct ControlAPICredentials: Sendable {
    let accessToken: String
    let apiKey: String

    public init(accessToken: String, apiKey: String) throws {
        guard [accessToken, apiKey].allSatisfy({
            !$0.isEmpty && $0.count <= 4096 && !$0.unicodeScalars.contains {
                CharacterSet.whitespacesAndNewlines.contains($0) || CharacterSet.controlCharacters.contains($0)
            }
        }) else { throw MultiroomError.invalidConfiguration }
        self.accessToken = accessToken
        self.apiKey = apiKey
    }
}

public typealias ControlAPICredentialProvider = @Sendable () async throws -> ControlAPICredentials

/// Read-only Sonos Control API queries. Authorization UI and token persistence belong to the caller.
public struct ControlAPIClient: SpeakerStatusProvider {
    private let credentials: ControlAPICredentialProvider
    private let householdID: String?
    private let endpoint: URL
    private let http: HTTPTransport

    public init(householdID: String? = nil, credentials: @escaping ControlAPICredentialProvider) {
        self.init(householdID: householdID, credentials: credentials,
                  endpoint: URL(string: "https://api.ws.sonos.com/control/api/v1")!, http: HTTPTransport())
    }

    init(householdID: String? = nil, credentials: @escaping ControlAPICredentialProvider,
         endpoint: URL, http: HTTPTransport = HTTPTransport()) {
        self.householdID = householdID
        self.credentials = credentials
        self.endpoint = endpoint
        self.http = http
    }

    private func authorizedCredentials() async throws -> ControlAPICredentials {
        do { return try await credentials() }
        catch {
            try checkCancellation(error)
            throw MultiroomError.authenticationFailed
        }
    }

    private func get<Value: Decodable>(_ path: [String], credentials: ControlAPICredentials,
                                       as type: Value.Type) async throws -> Value {
        var url = endpoint
        for component in path {
            guard !component.isEmpty, component != ".", component != "..",
                  !component.contains(where: { "/\\?#%".contains($0) || $0.isNewline }) else {
                throw MultiroomError.invalidResponse
            }
            url.appendPathComponent(component)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer " + credentials.accessToken, forHTTPHeaderField: "Authorization")
        request.setValue(credentials.apiKey, forHTTPHeaderField: "X-Sonos-Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("MultiroomKit/0.1", forHTTPHeaderField: "User-Agent")
        let data = try await http.data(for: request)
        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw MultiroomError.invalidResponse }
    }

    public func households() async throws -> [String] {
        try await get(["households"], credentials: authorizedCredentials(), as: Households.self).households.map(\.id)
    }

    public func snapshot() async throws -> SystemSnapshot {
        let startedAt = Date()
        let credentials = try await authorizedCredentials()
        let households = try await get(["households"], credentials: credentials, as: Households.self).households.map(\.id)
        guard !households.isEmpty else { throw MultiroomError.noHouseholds }
        let selected: String
        if let householdID {
            guard households.contains(householdID) else { throw MultiroomError.householdUnavailable }
            selected = householdID
        } else {
            guard households.count == 1 else { throw MultiroomError.householdSelectionRequired }
            selected = households[0]
        }
        let topology = try await get(["households", selected, "groups"], credentials: credentials, as: Groups.self)
        let playerIDs = topology.players.map(\.id)
        let groupIDs = topology.groups.map(\.id)
        let groupedIDs = topology.groups.flatMap(\.playerIds)
        guard playerIDs.allSatisfy({ !$0.isEmpty }), Set(playerIDs).count == playerIDs.count,
              groupIDs.allSatisfy({ !$0.isEmpty }), Set(groupIDs).count == groupIDs.count,
              topology.groups.allSatisfy({ !$0.playerIds.isEmpty }),
              Set(groupedIDs).count == groupedIDs.count, Set(groupedIDs).isSubset(of: Set(playerIDs)) else {
            throw MultiroomError.invalidResponse
        }
        let speakers = topology.players.map {
            Speaker(id: $0.id, name: $0.name, role: .player, deviceCount: max(1, $0.deviceIds?.count ?? 1))
        }
        var groups: [SpeakerGroup] = []
        for group in topology.groups {
            try Task.checkCancellation()
            var state = PlaybackState.unknown
            var metadata = PlaybackMetadata(title: nil, artist: nil, source: nil)
            var issues: [StatusIssue] = []
            do {
                let result = try await get(["groups", group.id, "playback"], credentials: credentials, as: Playback.self)
                state = PlaybackState(wireValue: result.playbackState)
                if state == .unknown { issues.append(StatusIssue(operation: .playback, error: .invalidResponse)) }
            } catch { try record(error, operation: .playback, in: &issues) }
            do {
                let result = try await get(["groups", group.id, "playbackMetadata"], credentials: credentials, as: Metadata.self)
                metadata = PlaybackMetadata(title: result.currentItem?.track?.name,
                                            artist: result.currentItem?.track?.artist?.name,
                                            source: result.container?.service?.name ?? result.container?.name)
            } catch { try record(error, operation: .metadata, in: &issues) }
            groups.append(SpeakerGroup(id: group.id, name: group.name, speakerIDs: group.playerIds,
                                       playbackState: state, metadata: metadata, issues: issues))
        }
        var warnings: [SnapshotWarning] = []
        if speakers.isEmpty { warnings.append(.noPlayers) }
        if Set(groupedIDs) != Set(playerIDs) { warnings.append(.ungroupedPlayers) }
        return SystemSnapshot(transport: .controlAPI, startedAt: startedAt, capturedAt: Date(),
                              speakers: speakers, groups: groups, warnings: warnings)
    }

    private func record(_ error: Error, operation: StatusIssue.Operation, in issues: inout [StatusIssue]) throws {
        try checkCancellation(error)
        let failure = sanitized(error)
        switch failure {
        case .unauthorized, .forbidden, .rateLimited: throw failure
        default: issues.append(StatusIssue(operation: operation, error: failure))
        }
    }
}

private struct Households: Decodable {
    struct Household: Decodable { let id: String }
    let households: [Household]
}

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
