import XCTest
@testable import MultiroomKit

@MainActor
final class IntegrationTests: XCTestCase {
    private func cloud(_ server: SonosSimulator, http: HTTPTransport = HTTPTransport(), householdID: String? = nil) -> ControlAPIClient {
        ControlAPIClient(householdID: householdID, credentials: { try ControlAPICredentials(accessToken: "synthetic-token", apiKey: "synthetic-key") },
                         endpoint: server.baseURL.appendingPathComponent("control/api/v1"), http: http)
    }

    private func upnp(_ server: SonosSimulator, http: HTTPTransport = HTTPTransport()) -> UPnPClient {
        let policy = SpeakerAddressPolicy(loopbackPort: Int(server.port))
        return UPnPClient(seed: server.baseURL, discovery: SSDPDiscovery(), addressPolicy: policy, http: http)
    }

    func testControlAPIUsesRealHTTPAndIndependentFixtures() async throws {
        let server = try SonosSimulator(); defer { server.stop() }
        let snapshot = try await cloud(server).snapshot()
        XCTAssertFalse(snapshot.isPartial)
        XCTAssertEqual(snapshot.speakers.map(\.deviceCount), [2, 1])
        XCTAssertEqual(snapshot.groups.first?.playbackState, .playing)
        XCTAssertEqual(snapshot.groups.first?.metadata.title, "Fixture song")
        XCTAssertEqual(server.requests.count, 4)
        XCTAssertTrue(server.requests.allSatisfy { $0.method == "GET" && $0.body.isEmpty })
        XCTAssertTrue(server.requests.allSatisfy { $0.headers["authorization"] == "Bearer synthetic-token" })
    }

    func testUDPDiscoveryThenSOAPOverRealSockets() async throws {
        let server = try SonosSimulator(); defer { server.stop() }
        let responder = try SSDPResponder(location: server.baseURL); defer { responder.stop() }
        let policy = SpeakerAddressPolicy(loopbackPort: Int(server.port))
        let discovery = SSDPDiscovery(timeout: 0.2, addressPolicy: policy,
                                      destinationHost: "127.0.0.1", destinationPort: responder.port, testInterface: "127.0.0.1")
        let client = UPnPClient(discovery: discovery, addressPolicy: policy)
        let snapshot = try await client.snapshot()
        XCTAssertGreaterThan(responder.receivedQueries, 0)
        XCTAssertFalse(snapshot.isPartial)
        XCTAssertEqual(snapshot.speakers.count, 3)
        XCTAssertEqual(snapshot.speakers.filter { $0.role == .satellite }.count, 1)
        XCTAssertEqual(snapshot.groups.first?.speakerIDs.count, 3)
        XCTAssertEqual(snapshot.groups.first?.metadata.title, "Fixture song")
        XCTAssertEqual(server.requests.count, 3, "Query the coordinator, not every bonded device")
    }

    func testBothTransportsObserveChangedStateWithoutEquatingPhysicalAndLogicalPlayers() async throws {
        let server = try SonosSimulator(); defer { server.stop() }
        server.setPlaying(false)
        let local = try await upnp(server).snapshot()
        let remote = try await cloud(server).snapshot()
        XCTAssertEqual(local.groups.first?.playbackState, .paused)
        XCTAssertEqual(remote.groups.first?.playbackState, .paused)
        XCTAssertEqual(local.speakers.count, remote.speakers.reduce(0) { $0 + $1.deviceCount })
    }

    func testAbsentMetadataIsNotAnError() async throws {
        let server = try SonosSimulator(scenario: .missingMetadata); defer { server.stop() }
        let snapshots = [try await cloud(server).snapshot(), try await upnp(server).snapshot()]
        for snapshot in snapshots {
            XCTAssertFalse(snapshot.isPartial)
            XCTAssertNil(snapshot.groups.first?.metadata.title)
        }
    }

    func testMetadataFailuresPreservePlaybackAndMarkPartialResults() async throws {
        let server = try SonosSimulator(scenario: .metadataFailure); defer { server.stop() }
        for snapshot in [try await cloud(server).snapshot(), try await upnp(server).snapshot()] {
            XCTAssertTrue(snapshot.isPartial)
            XCTAssertEqual(snapshot.groups.first?.playbackState, .playing)
            XCTAssertEqual(snapshot.groups.first?.issues.first?.error, .http(status: 503))
        }
    }

    func testHTTPFailuresAreTyped() async throws {
        let scenarios: [(SonosSimulator.Scenario, MultiroomError)] = [
            (.unauthorized, .unauthorized), (.forbidden, .forbidden), (.rateLimited, .rateLimited(retryAfter: 2)),
            (.malformedJSON, .invalidResponse), (.duplicatePlayer, .invalidResponse), (.redirect, .http(status: 302)),
            (.noHouseholds, .noHouseholds), (.multipleHouseholds, .householdSelectionRequired), (.groupUnauthorized, .unauthorized)
        ]
        for (scenario, expected) in scenarios {
            let server = try SonosSimulator(scenario: scenario); defer { server.stop() }
            do { _ = try await cloud(server).snapshot(); XCTFail("Expected a typed failure") }
            catch { XCTAssertEqual(error as? MultiroomError, expected) }
            if scenario == .redirect { XCTAssertEqual(server.requests.count, 1) }
        }
    }

    func testDisappearingGroupAndUnknownPlaybackArePartial() async throws {
        for scenario in [SonosSimulator.Scenario.groupGone, .unknownState] {
            let server = try SonosSimulator(scenario: scenario); defer { server.stop() }
            let snapshot = try await cloud(server).snapshot()
            XCTAssertTrue(snapshot.isPartial)
            XCTAssertEqual(snapshot.groups.first?.playbackState, .unknown)
        }
    }

    func testUnsafeTopologyNeverLeavesLoopback() async throws {
        let server = try SonosSimulator(scenario: .unsafeTopology); defer { server.stop() }
        let snapshot = try await upnp(server).snapshot()
        XCTAssertTrue(snapshot.isPartial)
        XCTAssertEqual(server.requests.count, 1)
    }

    func testResponseLimitAndTimeout() async throws {
        let oversized = try SonosSimulator(scenario: .oversized); defer { oversized.stop() }
        do { _ = try await cloud(oversized, http: HTTPTransport(maximumBytes: 128)).snapshot(); XCTFail("Expected size limit") }
        catch { XCTAssertEqual(error as? MultiroomError, .responseTooLarge) }
        let slow = try SonosSimulator(scenario: .slow); defer { slow.stop() }
        do { _ = try await cloud(slow, http: HTTPTransport(timeout: 0.2)).snapshot(); XCTFail("Expected timeout") }
        catch { XCTAssertEqual(error as? MultiroomError, .timedOut) }
        do { _ = try await upnp(slow, http: HTTPTransport(timeout: 0.2)).snapshot(); XCTFail("Expected UPnP timeout") }
        catch { XCTAssertEqual(error as? MultiroomError, .timedOut) }
    }

    func testCancellationIsNotConvertedToAPartialSnapshot() async throws {
        let server = try SonosSimulator(scenario: .slow); defer { server.stop() }
        let client = cloud(server)
        let task = Task { try await client.snapshot() }
        for _ in 0..<100 {
            if !server.requests.isEmpty { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertFalse(server.requests.isEmpty)
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
    }

    func testDiscoveryRejectsResponsesOutsideItsPolicyAndSupportsCancellation() async throws {
        let responder = try SSDPResponder(location: URL(string: "http://example.com:1400/")!)
        defer { responder.stop() }
        let discovery = SSDPDiscovery(timeout: 0.2, destinationHost: "127.0.0.1",
                                      destinationPort: responder.port, testInterface: "127.0.0.1")
        do { _ = try await discovery.discover(); XCTFail("Expected no eligible speakers") }
        catch { XCTAssertEqual(error as? MultiroomError, .noSpeakers) }
        var longDiscovery = discovery
        longDiscovery.timeout = 10
        let cancellationTarget = longDiscovery
        let task = Task { try await cancellationTarget.discover() }
        try await Task.sleep(for: .milliseconds(50))
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
    }

    func testExplicitHouseholdSelectionAndIncompleteTopologies() async throws {
        let multiple = try SonosSimulator(scenario: .multipleHouseholds); defer { multiple.stop() }
        let selected = try await cloud(multiple, householdID: "fixture-household").snapshot()
        XCTAssertFalse(selected.isPartial)
        do { _ = try await cloud(multiple, householdID: "unavailable").snapshot(); XCTFail("Expected selection failure") }
        catch { XCTAssertEqual(error as? MultiroomError, .householdUnavailable) }
        for (scenario, warning) in [(SonosSimulator.Scenario.ungroupedPlayer, SnapshotWarning.ungroupedPlayers), (.noPlayers, .noPlayers)] {
            let server = try SonosSimulator(scenario: scenario); defer { server.stop() }
            let snapshot = try await cloud(server).snapshot()
            XCTAssertTrue(snapshot.isPartial)
            XCTAssertTrue(snapshot.warnings.contains(warning))
        }
    }
}
