import Foundation
import XCTest
import MultiroomKit

@MainActor
final class LiveTests: XCTestCase {
    private func optIn(_ flag: String) throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment[flag] == "1", environment["CI"] == nil else {
            throw XCTSkip("Live testing requires explicit local opt-in; disabled in CI.")
        }
    }

    private func validate(_ snapshot: SystemSnapshot) {
        // Generic assertions deliberately avoid printing household values on failure.
        XCTAssertTrue(!snapshot.speakers.isEmpty, "Expected a nonempty system")
        XCTAssertTrue(Set(snapshot.speakers.map(\.id)).count == snapshot.speakers.count, "Expected unique speakers")
        XCTAssertTrue(!snapshot.groups.isEmpty, "Expected groups")
        let ids = Set(snapshot.speakers.map(\.id))
        XCTAssertTrue(snapshot.groups.allSatisfy { !$0.speakerIDs.isEmpty && Set($0.speakerIDs).isSubset(of: ids) },
                      "Expected consistent group membership")
        XCTAssertTrue(!snapshot.isPartial, "Snapshot was incomplete; inspect privately before relying on it")
    }

    private func showPrivately(_ snapshots: [SystemSnapshot]) throws {
        guard ProcessInfo.processInfo.environment["MULTIROOMKIT_LIVE_SHOW_SNAPSHOT"] == "1" else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try PrivateTerminal.write(String(decoding: encoder.encode(snapshots), as: UTF8.self) + "\n")
    }

    func testUPnP() async throws {
        try optIn("MULTIROOMKIT_LIVE_UPNP")
        let snapshot = try await UPnPClient().snapshot()
        validate(snapshot)
        try showPrivately([snapshot])
    }

    func testControlAPI() async throws {
        try optIn("MULTIROOMKIT_LIVE_CLOUD")
        let snapshot = try await LiveAuthorization.client().snapshot()
        validate(snapshot)
        try showPrivately([snapshot])
    }

    func testPairedSnapshotsForManualAppComparison() async throws {
        try optIn("MULTIROOMKIT_LIVE_COMPARE")
        let cloud = try await LiveAuthorization.client()
        let local = try await UPnPClient().snapshot()
        let remote = try await cloud.snapshot()
        validate(local)
        validate(remote)
        // Not a parity assertion: snapshots are non-atomic and player models differ.
        try showPrivately([local, remote])
    }
}
