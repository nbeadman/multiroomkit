import Foundation
import XCTest
@testable import MultiroomKit

final class ModelTests: XCTestCase {
    func testWirePlaybackStates() {
        XCTAssertEqual(PlaybackState(wireValue: "PAUSED_PLAYBACK"), .paused)
        XCTAssertEqual(PlaybackState(wireValue: "PLAYBACK_STATE_PLAYING"), .playing)
        XCTAssertEqual(PlaybackState(wireValue: "TRANSITIONING"), .buffering)
        XCTAssertEqual(PlaybackState(wireValue: "NO_MEDIA_PRESENT"), .idle)
        XCTAssertEqual(PlaybackState(wireValue: "FUTURE_STATE"), .unknown)
    }

    func testProductionAddressPolicyDoesNotAcceptTestEndpoints() throws {
        let policy = SpeakerAddressPolicy()
        XCTAssertNoThrow(try policy.validate(URL(string: "http://10.0.0.1:1400/xml/device_description.xml")!))
        for text in ["http://127.0.0.1:1400/", "http://10.0.0.1:8080/", "http://example.com:1400/",
                     "http://user:password@10.0.0.1:1400/", "http://10.0.0.1:1400/?token=synthetic"] {
            XCTAssertThrowsError(try policy.validate(URL(string: text)!))
            XCTAssertThrowsError(try UPnPClient(seed: URL(string: text)!))
        }
    }

    func testTestPolicyCannotRouteTopologyOutsideItsServer() throws {
        let policy = SpeakerAddressPolicy(loopbackPort: 12345)
        XCTAssertNoThrow(try policy.validate(URL(string: "http://127.0.0.1:12345/xml/device_description.xml")!))
        XCTAssertThrowsError(try policy.validate(URL(string: "http://10.0.0.1:1400/")!))
        XCTAssertThrowsError(try policy.validate(URL(string: "http://127.0.0.1:54321/")!))
    }

    func testInvalidDiscoveryWindowsAndCredentialsFailBeforeNetworkAccess() {
        for timeout in [Double.nan, .infinity, 0, 31] {
            XCTAssertThrowsError(try UPnPClient(discoveryTimeout: timeout))
        }
        XCTAssertThrowsError(try ControlAPICredentials(accessToken: "bad\ntoken", apiKey: "synthetic"))
        XCTAssertThrowsError(try ControlAPICredentials(accessToken: "synthetic", apiKey: ""))
    }

    func testXMLRejectsEntitiesMalformedAndExcessivelyNestedDocuments() {
        XCTAssertThrowsError(try parseXML("<!DOCTYPE x [<!ENTITY y 'bad'>]><x>&y;</x>"))
        XCTAssertThrowsError(try parseXML("<broken>"))
        XCTAssertThrowsError(try parseXML(String(repeating: "<x>", count: 65) + String(repeating: "</x>", count: 65)))
        XCTAssertThrowsError(try parseXML("<Envelope><Fault><detail>synthetic-private</detail></Fault></Envelope>"))
    }

    func testDiscoveryRejectsSpoofedSenderAndWrongService() {
        let reply = "HTTP/1.1 200 OK\r\nST: urn:schemas-upnp-org:device:ZonePlayer:1\r\nLOCATION: http://10.0.0.1:1400/xml/device_description.xml\r\n\r\n"
        XCTAssertNotNil(SSDPDiscovery.location(reply, sender: "10.0.0.1", policy: SpeakerAddressPolicy()))
        XCTAssertNil(SSDPDiscovery.location(reply, sender: "10.0.0.2", policy: SpeakerAddressPolicy()))
        XCTAssertNil(SSDPDiscovery.location(reply.replacingOccurrences(of: "ZonePlayer", with: "OtherDevice"),
                                            sender: "10.0.0.1", policy: SpeakerAddressPolicy()))
    }

    func testPartialSnapshotReflectsGroupFailuresAndWarnings() {
        let group = SpeakerGroup(id: "synthetic", name: "Example", speakerIDs: ["a"], playbackState: .unknown,
                                 metadata: PlaybackMetadata(title: nil, artist: nil, source: nil),
                                 issues: [StatusIssue(operation: .playback, error: .resourceGone)])
        let snapshot = SystemSnapshot(transport: .controlAPI, startedAt: Date(), capturedAt: Date(), speakers: [],
                                      groups: [group], warnings: [])
        XCTAssertTrue(snapshot.isPartial)
    }
}
