import Foundation
import MultiroomKit

enum HouseholdConfigurationError: Error {
    case privateExpectedStateRequired
    case invalidExpectedState
    case appConfirmationRequired
}

/// An independently checked Sonos UI observation, never a recorded SDK response.
struct HouseholdExpectations: Decodable {
    let confirmedInSonosApp: Bool
    let upnp: ExpectedSystem?
    let controlAPI: ExpectedSystem?

    static func load() throws -> HouseholdExpectations {
        // Use the checkout location, not the test runner's potentially different cwd.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent(".local/live-household.json")
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw HouseholdConfigurationError.privateExpectedStateRequired
        }
        guard let data = try? Data(contentsOf: file), data.count <= 65536,
              let expectations = try? JSONDecoder().decode(Self.self, from: data) else {
            throw HouseholdConfigurationError.invalidExpectedState
        }
        guard expectations.confirmedInSonosApp else { throw HouseholdConfigurationError.appConfirmationRequired }
        return expectations
    }

    func expected(for transport: SonosTransport) throws -> ExpectedSystem {
        let value = transport == .upnp ? upnp : controlAPI
        guard let value, value.isValid else { throw HouseholdConfigurationError.invalidExpectedState }
        return value
    }
}

struct ExpectedSystem: Decodable {
    enum Playback: String, Decodable {
        case playing, paused, idle, buffering, notPlaying

        func matches(_ state: PlaybackState) -> Bool {
            if self == .notPlaying { return state == .paused || state == .idle }
            return rawValue == state.rawValue
        }
    }

    struct Group: Decodable {
        let rooms: [String]
        let playbackState: Playback
        // An omitted field is not asserted. Specified metadata must match exactly.
        let title: String?
        let artist: String?
        let source: String?
    }

    let rooms: [String]
    let physicalDeviceCount: Int?
    let groups: [Group]

    var isValid: Bool {
        let grouped = groups.flatMap(\.rooms)
        return !rooms.isEmpty && rooms.allSatisfy { !$0.isEmpty } && Set(rooms).count == rooms.count &&
            !groups.isEmpty && groups.allSatisfy { !$0.rooms.isEmpty } &&
            Set(grouped).count == grouped.count && Set(grouped) == Set(rooms) &&
            (physicalDeviceCount.map { $0 >= rooms.count } ?? true)
    }

    /// Failures are intentionally generic: no names, IDs, counts, or listening details.
    func mismatches(in snapshot: SystemSnapshot) -> [String] {
        guard isValid else { return ["Invalid private expected-state configuration"] }
        var failures: [String] = []
        if snapshot.isPartial { failures.append("Live snapshot is incomplete") }
        guard Set(snapshot.speakers.map(\.id)).count == snapshot.speakers.count else {
            return failures + ["Live speaker identifiers are not unique"]
        }
        // UPnP invisible bonded members and satellites are not separate logical rooms.
        let players = snapshot.speakers.filter { $0.role == .player }
        let names = players.map(\.name)
        guard Set(names).count == names.count else {
            return failures + ["Room names are ambiguous; expected-state matching requires unique room names"]
        }
        if Set(names) != Set(rooms) { failures.append("Room inventory differs from the Sonos-app observation") }
        if let physicalDeviceCount, snapshot.speakers.reduce(0, { $0 + $1.deviceCount }) != physicalDeviceCount {
            failures.append("Physical device inventory differs from the Sonos-app observation")
        }
        let byID = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0.name) })
        let actual = snapshot.groups.map { group in
            (group, Set(group.speakerIDs.compactMap { byID[$0] }))
        }
        if actual.count != groups.count { failures.append("Group inventory differs from the Sonos-app observation") }
        for expected in groups {
            let matches = actual.filter { $0.1 == Set(expected.rooms) }
            guard matches.count == 1, let group = matches.first?.0 else {
                failures.append("Group membership differs from the Sonos-app observation")
                continue
            }
            if !expected.playbackState.matches(group.playbackState) { failures.append("Playback differs from the Sonos-app observation") }
            if let title = expected.title, group.metadata.title != title { failures.append("Title differs from the expected transport metadata") }
            if let artist = expected.artist, group.metadata.artist != artist { failures.append("Artist differs from the expected transport metadata") }
            if let source = expected.source, group.metadata.source != source { failures.append("Source differs from the expected transport metadata") }
        }
        return Array(Set(failures)).sorted()
    }
}
