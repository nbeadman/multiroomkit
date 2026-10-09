import Foundation
import XCTest
@testable import MultiroomKit

// These tests use invented observations only and do not opt into live networking.
final class HouseholdExpectationTests: XCTestCase {
    private func expected(state: PlaybackState = .playing, title: String? = nil) -> ExpectedSystem {
        ExpectedSystem(rooms: ["Example Lounge", "Example Study"], physicalDeviceCount: 3, groups: [
            .init(rooms: ["Example Lounge", "Example Study"], playbackState: ExpectedSystem.Playback(rawValue: state.rawValue)!, title: title, artist: nil, source: nil)
        ])
    }

    private func snapshot(transport: SonosTransport = .upnp, state: PlaybackState = .playing,
                          title: String? = nil, splitGroups: Bool = false) -> SystemSnapshot {
        var speakers = [
            Speaker(id: "synthetic-a", name: "Example Lounge", role: .player, deviceCount: transport == .upnp ? 1 : 2),
            Speaker(id: "synthetic-b", name: "Example Study", role: .player, deviceCount: 1)
        ]
        if transport == .upnp {
            speakers.append(Speaker(id: "synthetic-sub", name: "Example satellite", role: .satellite, deviceCount: 1))
        }
        let metadata = PlaybackMetadata(title: title, artist: nil, source: nil)
        let memberships = splitGroups ? [["synthetic-a"], ["synthetic-b"]] : [speakers.map(\.id)]
        let groups = memberships.enumerated().map { index, members in
            SpeakerGroup(id: "synthetic-group-\(index)", name: "Synthetic group", speakerIDs: members,
                         playbackState: state, metadata: metadata, issues: [])
        }
        return SystemSnapshot(transport: transport, startedAt: Date(), capturedAt: Date(),
                              speakers: speakers, groups: groups, warnings: [])
    }

    func testIndependentObservationMatchesBothPlayerModels() {
        for transport in [SonosTransport.upnp, .controlAPI] {
            XCTAssertTrue(expected().mismatches(in: snapshot(transport: transport)).isEmpty)
        }
    }

    func testPlaybackAndMembershipMismatchesAreDetectedWithoutLeakingValues() {
        let failures = expected(state: .paused).mismatches(in: snapshot()) + expected().mismatches(in: snapshot(splitGroups: true))
        XCTAssertTrue(failures.contains("Playback differs from the Sonos-app observation"))
        XCTAssertTrue(failures.contains("Group membership differs from the Sonos-app observation"))
        XCTAssertFalse(failures.joined().contains("Example"))
        XCTAssertFalse(failures.joined().contains("synthetic"))
    }

    func testMetadataIsOnlyAssertedWhenSpecified() {
        XCTAssertTrue(expected().mismatches(in: snapshot(title: "Synthetic song")).isEmpty)
        XCTAssertFalse(expected(title: "Synthetic song").mismatches(in: snapshot()).isEmpty)
        XCTAssertTrue(expected(title: "Synthetic song").mismatches(in: snapshot(title: "Synthetic song")).isEmpty)
    }

    func testInvalidObservationDoesNotSilentlyPass() {
        let invalid = ExpectedSystem(rooms: ["Example Lounge", "Example Lounge"], physicalDeviceCount: nil, groups: [])
        XCTAssertFalse(invalid.isValid)
        XCTAssertFalse(invalid.mismatches(in: snapshot()).isEmpty)
    }

    func testInventoryAndPartialFailuresAreDetected() {
        let value = snapshot()
        let incomplete = SystemSnapshot(transport: .upnp, startedAt: Date(), capturedAt: Date(),
                                        speakers: Array(value.speakers.dropLast()), groups: value.groups,
                                        warnings: [.discoveryOutsideSelectedTopology])
        let failures = expected().mismatches(in: incomplete)
        XCTAssertTrue(failures.contains("Live snapshot is incomplete"))
        XCTAssertTrue(failures.contains("Physical device inventory differs from the Sonos-app observation"))
    }

    func testPlayButtonObservationDoesNotPretendToDistinguishPausedFromIdle() {
        XCTAssertTrue(ExpectedSystem.Playback.notPlaying.matches(.paused))
        XCTAssertTrue(ExpectedSystem.Playback.notPlaying.matches(.idle))
        XCTAssertFalse(ExpectedSystem.Playback.notPlaying.matches(.playing))
        XCTAssertFalse(ExpectedSystem.Playback.notPlaying.matches(.unknown))
        XCTAssertFalse(ExpectedSystem.Playback.notPlaying.matches(.buffering))
    }
}
