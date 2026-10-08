import XCTest
import Foundation
@testable import PrototypeSupport

// Entirely synthetic data. No fixture was copied from a household or credential store.
final class StatusTests: XCTestCase {
    func testOptionsAndSafeOutput() throws {
        XCTAssertThrowsError(try Options(["--timeout", "nan"], cloud: false))
        XCTAssertThrowsError(try Options(["--timeout", "0"], cloud: false))
        XCTAssertThrowsError(try Options(["--token", "DO_NOT_ECHO"], cloud: true))
        XCTAssertThrowsError(try Options(["--client-secret", "DO_NOT_ECHO"], cloud: true))
        XCTAssertThrowsError(try Options(["--set-credentials"], cloud: true))
        XCTAssertThrowsError(try Options(["--json", "--summary"], cloud: false))
        XCTAssertThrowsError(try Options(["--host", "10.0.0.1"], cloud: true))
        XCTAssertEqual(try Options(["--timeout", "2"], cloud: false).timeout, 2)
        let snapshot = Snapshot(transport: "UPnP", speakers: [SpeakerStatus(room: "Private room", group: "Private group", state: "playing", title: "Private title")])
        let summary = try snapshot.output(json: false, summary: true)
        XCTAssertFalse(summary.contains("Private"))
        XCTAssertTrue(summary.contains("playing"))
        XCTAssertEqual(terminalSafe("Name\u{1b}[2J\n\t"), "Name[2J")
        XCTAssertFalse(safeMessage(NSError(domain: "SECRET", code: 1)).contains("SECRET"))
    }

    func testURLAndDiscoveryValidation() throws {
        XCTAssertTrue(privateIPv4("10.1.2.3"))
        XCTAssertTrue(privateIPv4("172.16.1.2"))
        XCTAssertFalse(privateIPv4("172.32.1.2"))
        for value in ["http://example.com:1400/", "http://127.0.0.1:1400/", "http://10.0.0.1:80/",
                      "http://user:secret@10.0.0.1:1400/", "http://10.0.0.1:1400/?token=x"] {
            XCTAssertThrowsError(try speakerURL(value))
        }
        let reply = "HTTP/1.1 200 OK\r\nST: urn:schemas-upnp-org:device:ZonePlayer:1\r\nLOCATION: http://10.0.0.1:1400/xml/device_description.xml\r\n\r\n"
        XCTAssertNotNil(Discovery.location(reply, sender: "10.0.0.1"))
        XCTAssertNil(Discovery.location(reply, sender: "10.0.0.2"))
        XCTAssertNil(Discovery.location(reply.replacingOccurrences(of: "200 OK", with: "404 Not Found"), sender: "10.0.0.1"))
    }

    func testXMLValidationAndTopology() throws {
        XCTAssertThrowsError(try parseXML("<broken>"))
        XCTAssertThrowsError(try parseXML("<!DOCTYPE x [<!ENTITY y 'bad'>]><x>&y;</x>"))
        XCTAssertThrowsError(try parseXML("<root/>".data(using: .utf16)!))
        XCTAssertThrowsError(try parseXML(Data(repeating: 65, count: 2_000_001)))
        XCTAssertThrowsError(try parseXML("<Envelope><Fault><detail>PRIVATE</detail></Fault></Envelope>"))
        let node = try parseXML("<root xmlns:dc='urn:test'><dc:title>A &amp; B</dc:title></root>")
        XCTAssertEqual(node.value("title"), "A & B")
        let result = try zones(from: Data(topology.utf8))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].members.count, 3)
        XCTAssertEqual(result[0].members[1].role, "satellite")
        XCTAssertEqual(result[0].members[2].name, "Study")
    }

    func testUPnPGroupedPlaybackAndReadOnlyRequests() async throws {
        let recorder = Requests()
        let topologyText = topology
        let client = UPnPClient { request in
            await recorder.append(request)
            let action = request.value(forHTTPHeaderField: "SOAPACTION") ?? ""
            if action.contains("GetZoneGroupState") { return soap("ZoneGroupState", topologyText) }
            if action.contains("GetTransportInfo") { return soap("CurrentTransportState", "PLAYING") }
            if action.contains("GetPositionInfo") {
                return Data("<root><TrackURI>x-sonos-htastream:synthetic</TrackURI><TrackMetaData>\(escape("<DIDL-Lite><item><title>Example title</title><creator>Example artist</creator></item></DIDL-Lite>"))</TrackMetaData></root>".utf8)
            }
            throw StatusError("Unexpected action.")
        }
        let result = try await client.snapshot(seeds: [URL(string: "http://10.0.0.1:1400/xml/device_description.xml")!])
        XCTAssertEqual(result.speakers.count, 3)
        XCTAssertTrue(result.speakers.allSatisfy { $0.title == "Example title" && $0.state == "playing" && $0.source == "TV" })
        XCTAssertFalse(result.isPartial)
        let requests = await recorder.values
        XCTAssertEqual(requests.count, 3, "Query the coordinator once, not every member")
        XCTAssertTrue(requests.allSatisfy { ($0.value(forHTTPHeaderField: "SOAPACTION") ?? "").contains("#Get") })
    }

    func testUPnPPartialAndEmptyDiscovery() async throws {
        let topologyText = topology
        let client = UPnPClient { request in
            if (request.value(forHTTPHeaderField: "SOAPACTION") ?? "").contains("GetZoneGroupState") { return soap("ZoneGroupState", topologyText) }
            throw StatusError("Synthetic timeout.")
        }
        let result = try await client.snapshot(seeds: [URL(string: "http://10.0.0.1:1400/xml/device_description.xml")!])
        XCTAssertTrue(result.isPartial)
        XCTAssertTrue(result.speakers.allSatisfy { $0.state == "unknown" && $0.issue != nil })
        do { _ = try await client.snapshot(seeds: []); XCTFail("Expected no-discovery error") }
        catch { XCTAssertTrue(safeMessage(error).contains("No UPnP")) }
    }

    func testCloudGroupedPlaybackAndRequests() async throws {
        let recorder = Requests()
        let client = CloudClient(credentials: try CloudCredentials(token: "synthetic-test-token", apiKey: "synthetic-test-key")) { request in
            await recorder.append(request)
            switch request.url!.lastPathComponent {
            case "households": return Data(#"{"households":[{"id":"synthetic-household"}]}"#.utf8)
            case "groups": return Data(cloudGroups.utf8)
            case "playback": return Data(#"{"playbackState":"PLAYBACK_STATE_PAUSED"}"#.utf8)
            case "playbackMetadata": return Data(#"{"currentItem":{"track":{"name":"Example song","artist":{"name":"Example artist"}}},"container":{"service":{"name":"Example service"}}}"#.utf8)
            default: throw StatusError("Unexpected path.")
            }
        }
        let snapshot = try await client.snapshot()
        XCTAssertEqual(snapshot.speakers.count, 2)
        XCTAssertTrue(snapshot.speakers.allSatisfy { $0.state == "paused" && $0.title == "Example song" })
        XCTAssertFalse(snapshot.isPartial)
        XCTAssertEqual(snapshot.speakers.map(\.deviceCount).sorted(), [1, 2])
        let requests = await recorder.values
        XCTAssertEqual(requests.count, 4)
        XCTAssertTrue(requests.allSatisfy { $0.httpMethod == "GET" && $0.url?.host == "api.ws.sonos.com" })
        XCTAssertTrue(requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-test-token" })
    }

    func testOAuthAuthorizationURLAndSecureState() throws {
        let oauth = try SonosOAuth(apiKey: "synthetic-key", clientSecret: "synthetic-secret")
        let state = try SonosOAuth.randomState()
        XCTAssertEqual(state.count, 43)
        XCTAssertNotEqual(state, try SonosOAuth.randomState())
        let url = try oauth.authorizationURL(state: state)
        XCTAssertEqual(url.host, "api.sonos.com")
        XCTAssertEqual(url.path, "/login/v3/oauth")
        let parameters = Dictionary(uniqueKeysWithValues: URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!.map { ($0.name, $0.value!) })
        XCTAssertEqual(parameters["client_id"], "synthetic-key")
        XCTAssertEqual(parameters["response_type"], "code")
        XCTAssertEqual(parameters["state"], state)
        XCTAssertEqual(parameters["scope"], "playback-control-all")
        XCTAssertEqual(parameters["redirect_uri"], SonosOAuth.redirectURI)
        XCTAssertTrue(url.absoluteString.contains("redirect_uri=https%3A%2F%2Fnbeadman.github.io%2Fmultiroomkit%2Fsonos%2Fcallback%2F"))
        XCTAssertThrowsError(try oauth.authorizationURL(state: "bad state"))
        XCTAssertThrowsError(try SonosOAuth(apiKey: "synthetic", clientSecret: "bad\nsecret"))
        XCTAssertThrowsError(try SonosOAuth(apiKey: "bad:key", clientSecret: "synthetic"))
    }

    func testOAuthExchangesOnlyAfterStateMatches() async throws {
        let recorder = Requests()
        let oauth = try SonosOAuth(apiKey: "synthetic-key", clientSecret: "synthetic-secret") { request in
            await recorder.append(request)
            return Data(#"{"access_token":"synthetic-token","token_type":"Bearer","expires_in":86400,"refresh_token":"unused-synthetic-refresh","scope":"playback-control-all"}"#.utf8)
        }
        do {
            _ = try await oauth.exchange(code: "synthetic-code", returnedState: "wrong", expectedState: "expected")
            XCTFail("Mismatched state must fail")
        } catch { XCTAssertTrue(safeMessage(error).contains("state did not match")) }
        let before = await recorder.values
        XCTAssertTrue(before.isEmpty, "No token request should be sent for a mismatched state")
        let credentials = try await oauth.exchange(code: "synthetic-code", returnedState: "expected", expectedState: "expected")
        XCTAssertEqual(credentials.token, "synthetic-token")
        XCTAssertEqual(credentials.apiKey, "synthetic-key")
        let requests = await recorder.values
        XCTAssertEqual(requests.count, 1)
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://api.sonos.com/login/v3/oauth/access")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded;charset=utf-8")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Basic " + Data("synthetic-key:synthetic-secret".utf8).base64EncodedString())
        let body = String(decoding: try XCTUnwrap(request.httpBody), as: UTF8.self)
        XCTAssertTrue(body.contains("grant_type=authorization_code"))
        XCTAssertTrue(body.contains("code=synthetic-code"))
        XCTAssertTrue(body.contains("redirect_uri=https%3A%2F%2Fnbeadman.github.io%2Fmultiroomkit%2Fsonos%2Fcallback%2F"))
        XCTAssertFalse(body.contains("synthetic-secret"))
    }

    func testOAuthRejectsBadTokenResponseWithoutLeakingIt() async throws {
        let oauth = try SonosOAuth(apiKey: "synthetic-key", clientSecret: "synthetic-secret") { _ in
            Data(#"{"access_token":"PRIVATE_VALUE","token_type":"Other","expires_in":86400,"scope":"playback-control-all"}"#.utf8)
        }
        do {
            _ = try await oauth.exchange(code: "synthetic-code", returnedState: "same", expectedState: "same")
            XCTFail("Unsupported token type must fail")
        } catch {
            XCTAssertFalse(safeMessage(error).contains("PRIVATE_VALUE"))
            XCTAssertTrue(safeMessage(error).contains("unsupported token"))
        }
    }

    func testCloudMissingMetadataAndFailure() async throws {
        let client = CloudClient(credentials: try CloudCredentials(token: "synthetic", apiKey: "synthetic")) { request in
            switch request.url!.lastPathComponent {
            case "households": return Data(#"{"households":[{"id":"synthetic"}]}"#.utf8)
            case "groups": return Data(cloudGroups.utf8)
            case "playback": return Data(#"{"playbackState":"PLAYBACK_STATE_IDLE"}"#.utf8)
            default: throw StatusError("HTTP 503.")
            }
        }
        let result = try await client.snapshot()
        XCTAssertTrue(result.isPartial)
        XCTAssertTrue(result.speakers.allSatisfy { $0.title == nil && $0.state == "idle" })
    }

    func testCloudHouseholdSelectionAndMalformedData() async throws {
        let credentials = try CloudCredentials(token: "synthetic", apiKey: "synthetic")
        let multiple = CloudClient(credentials: credentials) { _ in Data(#"{"households":[{"id":"one"},{"id":"two"}]}"#.utf8) }
        do { _ = try await multiple.snapshot(); XCTFail("Should require selection") }
        catch { XCTAssertTrue(safeMessage(error).contains("Multiple households")) }
        let malformed = CloudClient(credentials: credentials) { _ in Data("PRIVATE INVALID RESPONSE".utf8) }
        do { _ = try await malformed.snapshot(); XCTFail("Should reject malformed response") }
        catch { XCTAssertFalse(safeMessage(error).contains("PRIVATE")) }
        XCTAssertThrowsError(try CloudCredentials(token: "bad\ntoken", apiKey: "synthetic"))
    }

    func testSourceAndStateMapping() {
        XCTAssertEqual(sourceName("x-rincon-stream:private"), "Line-in")
        XCTAssertEqual(sourceName("https://example.com/?token=private"), "Media")
        XCTAssertNil(sourceName(nil))
        XCTAssertEqual(playbackState("PAUSED_PLAYBACK"), "paused")
        XCTAssertEqual(playbackState("FUTURE_NEW_STATE"), "unknown")
    }

    func testCloudEmptyMetadataIsNotAnInventedTrack() async throws {
        let client = CloudClient(credentials: try CloudCredentials(token: "synthetic", apiKey: "synthetic")) { request in
            switch request.url!.lastPathComponent {
            case "households": return Data(#"{"households":[{"id":"one"},{"id":"two"}]}"#.utf8)
            case "groups":
                XCTAssertTrue(request.url!.path.contains("/households/two/"))
                return Data(cloudGroups.utf8)
            case "playback": return Data(#"{"playbackState":"PLAYBACK_STATE_IDLE"}"#.utf8)
            default: return Data(#"{"currentItem":null,"container":null}"#.utf8)
            }
        }
        let snapshot = try await client.snapshot(household: "two")
        XCTAssertFalse(snapshot.isPartial)
        XCTAssertTrue(snapshot.speakers.allSatisfy { $0.title == nil && $0.artist == nil && $0.source == nil })
    }

    func testCloudRejectsUnsafeResourceIDs() async throws {
        let client = CloudClient(credentials: try CloudCredentials(token: "synthetic", apiKey: "synthetic")) { request in
            XCTAssertEqual(request.url!.lastPathComponent, "households", "Unsafe ID must not produce another request")
            return Data(#"{"households":[{"id":"../outside"}]}"#.utf8)
        }
        do { _ = try await client.snapshot(); XCTFail("Expected invalid identifier") }
        catch { XCTAssertTrue(safeMessage(error).contains("Invalid resource identifier")) }
    }

    func testNoCloudHouseholds() async throws {
        let client = CloudClient(credentials: try CloudCredentials(token: "synthetic", apiKey: "synthetic")) { _ in
            Data(#"{"households":[]}"#.utf8)
        }
        do { _ = try await client.snapshot(); XCTFail("Expected no-household error") }
        catch { XCTAssertTrue(safeMessage(error).contains("No households")) }
    }
}

private actor Requests {
    var values: [URLRequest] = []
    func append(_ request: URLRequest) { values.append(request) }
}
private func escape(_ value: String) -> String {
    value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
}
private func soap(_ tag: String, _ value: String) -> Data { Data("<Envelope><Body><\(tag)>\(escape(value))</\(tag)></Body></Envelope>".utf8) }
private let topology = """
<ZoneGroups><ZoneGroup Coordinator="synthetic-a"><ZoneGroupMember UUID="synthetic-a" ZoneName="Lounge" Location="http://10.0.0.1:1400/xml/device_description.xml"><Satellite UUID="synthetic-sub" ZoneName="Lounge Sub" Location="http://10.0.0.2:1400/xml/device_description.xml"/></ZoneGroupMember><ZoneGroupMember UUID="synthetic-b" ZoneName="Study" Location="http://10.0.0.3:1400/xml/device_description.xml"/></ZoneGroup></ZoneGroups>
"""
private let cloudGroups = #"{"groups":[{"id":"synthetic-group","name":"Lounge + Study","playerIds":["a","b"]}],"players":[{"id":"a","name":"Lounge","deviceIds":["a","sub"]},{"id":"b","name":"Study","deviceIds":["b"]}]}"#
