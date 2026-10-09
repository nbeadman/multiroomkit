import Foundation
@preconcurrency import Network
import Darwin

// Independent synthetic wire fixtures: this server does not import SDK models or codecs.
struct SimulatedRoom {
    let id: String
    let name: String
    let satelliteIDs: [String]
}

struct SimulatedHousehold {
    let rooms = [SimulatedRoom(id: "fixture-a", name: "Lounge", satelliteIDs: ["fixture-sub"]),
                 SimulatedRoom(id: "fixture-b", name: "Study", satelliteIDs: [])]
    var playing = true
}

struct CapturedRequest: Sendable {
    let method: String
    let path: String
    let headers: [String: String]
    let body: String
}

enum SimulatorFailure: Error { case couldNotStart }

final class SonosSimulator: @unchecked Sendable {
    enum Scenario: Sendable {
        case normal, missingMetadata, metadataFailure, groupGone, unauthorized, forbidden, rateLimited
        case malformedJSON, unknownState, duplicatePlayer, unsafeTopology, redirect, oversized, slow
        case noHouseholds, multipleHouseholds, ungroupedPlayer, noPlayers, groupUnauthorized
    }

    private let listener: NWListener
    private let queue = DispatchQueue(label: "MultiroomKit.SonosSimulator")
    private let lock = NSLock()
    private var household = SimulatedHousehold()
    private var scenario: Scenario
    private var captured: [CapturedRequest] = []
    private var connections: [NWConnection] = []
    var port: UInt16 { listener.port!.rawValue }

    var baseURL: URL { URL(string: "http://127.0.0.1:\(port)")! }
    var requests: [CapturedRequest] { lock.withLock { captured } }

    init(scenario: Scenario = .normal) throws {
        self.scenario = scenario
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        let listener = try NWListener(using: parameters)
        self.listener = listener
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { connection.cancel(); return }
            self.lock.withLock { self.connections.append(connection) }
            connection.start(queue: self.queue)
            self.receive(connection, accumulated: Data())
        }
        let ready = DispatchSemaphore(value: 0)
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready, .failed, .cancelled: ready.signal()
            default: break
            }
        }
        listener.start(queue: queue)
        guard ready.wait(timeout: .now() + 5) == .success, listener.port != nil else {
            listener.cancel()
            throw SimulatorFailure.couldNotStart
        }
    }

    func stop() {
        listener.cancel()
        let active = lock.withLock { connections }
        for connection in active { connection.cancel() }
    }

    func setPlaying(_ playing: Bool) { lock.withLock { household.playing = playing } }

    private func receive(_ connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, complete, error in
            guard let self else { connection.cancel(); return }
            var buffer = accumulated
            buffer.append(data ?? Data())
            guard buffer.count <= 65536 else { connection.cancel(); return }
            if let boundary = buffer.range(of: Data("\r\n\r\n".utf8)) {
                let lines = String(decoding: buffer[..<boundary.lowerBound], as: UTF8.self).components(separatedBy: "\r\n")
                let parts = (lines.first ?? "").split(separator: " ")
                guard parts.count >= 2 else { connection.cancel(); return }
                var headers: [String: String] = [:]
                for line in lines.dropFirst() {
                    guard let colon = line.firstIndex(of: ":") else { continue }
                    headers[String(line[..<colon]).lowercased()] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                }
                let length = Int(headers["content-length"] ?? "0") ?? 0
                if buffer.count - boundary.upperBound >= length {
                    let body = String(decoding: buffer[boundary.upperBound...].prefix(length), as: UTF8.self)
                    let request = CapturedRequest(method: String(parts[0]), path: String(parts[1]), headers: headers, body: body)
                    self.lock.withLock { self.captured.append(request) }
                    let response = self.response(to: request)
                    self.queue.asyncAfter(deadline: .now() + response.delay) {
                        var packet = Data("HTTP/1.1 \(response.status) Test\r\nContent-Length: \(response.body.count)\r\nConnection: close\r\n\(response.headers)\r\n".utf8)
                        packet.append(response.body)
                        connection.send(content: packet, completion: .contentProcessed { _ in connection.cancel() })
                    }
                    return
                }
            }
            if complete || error != nil { connection.cancel() }
            else { self.receive(connection, accumulated: buffer) }
        }
    }

    private struct Response: Sendable {
        var status = 200
        var headers = "Content-Type: application/json\r\n"
        var body = Data()
        var delay: TimeInterval = 0
    }

    private func response(to request: CapturedRequest) -> Response {
        let (scenario, household) = lock.withLock { (scenario, household) }
        if scenario == .slow { return Response(body: Data("{}".utf8), delay: 2) }
        if scenario == .redirect {
            return Response(status: 302, headers: "Location: \(baseURL)/must-not-follow\r\n")
        }
        if scenario == .oversized { return Response(body: Data(repeating: 65, count: 2048)) }
        if request.path.hasPrefix("/control/api/v1/") {
            guard request.method == "GET", request.body.isEmpty else { return Response(status: 405) }
            guard request.headers["authorization"] == "Bearer synthetic-token",
                  request.headers["x-sonos-api-key"] == "synthetic-key", scenario != .unauthorized else {
                return Response(status: 401)
            }
            if scenario == .forbidden { return Response(status: 403) }
            if scenario == .rateLimited { return Response(status: 429, headers: "Retry-After: 2\r\n") }
            if scenario == .malformedJSON { return Response(body: Data("private malformed fixture".utf8)) }
            switch request.path {
            case "/control/api/v1/households":
                if scenario == .noHouseholds { return json(["households": []]) }
                if scenario == .multipleHouseholds { return json(["households": [["id": "fixture-household"], ["id": "fixture-other"]]]) }
                return json(["households": [["id": "fixture-household"]]])
            case "/control/api/v1/households/fixture-household/groups":
                if scenario == .noPlayers { return json(["groups": [], "players": []]) }
                var players = household.rooms.map { ["id": $0.id, "name": $0.name, "deviceIds": [$0.id] + $0.satelliteIDs] as [String: Any] }
                if scenario == .duplicatePlayer { players.append(players[0]) }
                let members = scenario == .ungroupedPlayer ? [household.rooms[0].id] : household.rooms.map(\.id)
                return json(["groups": [["id": "fixture-group", "name": "Lounge + Study", "playerIds": members]],
                             "players": players, "futureField": "ignored"])
            case "/control/api/v1/groups/fixture-group/playback":
                if scenario == .groupUnauthorized { return Response(status: 401) }
                if scenario == .groupGone { return Response(status: 410) }
                return json(["playbackState": scenario == .unknownState ? "PLAYBACK_STATE_FUTURE" :
                                (household.playing ? "PLAYBACK_STATE_PLAYING" : "PLAYBACK_STATE_PAUSED")])
            case "/control/api/v1/groups/fixture-group/playbackMetadata":
                if scenario == .groupGone { return Response(status: 410) }
                if scenario == .metadataFailure { return Response(status: 503) }
                if scenario == .missingMetadata { return json(["currentItem": NSNull(), "container": NSNull()]) }
                return json(["currentItem": ["track": ["name": "Fixture song", "artist": ["name": "Fixture artist"]]],
                             "container": ["service": ["name": "Fixture service"]]])
            default: return Response(status: 404)
            }
        }
        guard request.method == "POST", request.headers["content-type"]?.contains("text/xml") == true else {
            return Response(status: 405)
        }
        let action = request.headers["soapaction"] ?? ""
        if request.path == "/ZoneGroupTopology/Control", action == "\"urn:schemas-upnp-org:service:ZoneGroupTopology:1#GetZoneGroupState\"",
           request.body.contains("<u:GetZoneGroupState ") {
            let location = scenario == .unsafeTopology ? "http://example.com:1400/" : "\(baseURL)/xml/device_description.xml"
            let members = household.rooms.map { room in
                let satellites = room.satelliteIDs.map { "<Satellite UUID=\"\($0)\" ZoneName=\"Fixture satellite\" Location=\"\(location)\"/>" }.joined()
                return "<ZoneGroupMember UUID=\"\(room.id)\" ZoneName=\"\(room.name)\" Location=\"\(location)\">\(satellites)</ZoneGroupMember>"
            }.joined()
            let topology = "<ZoneGroups><ZoneGroup Coordinator=\"fixture-a\">\(members)</ZoneGroup></ZoneGroups>"
            return soap("ZoneGroupState", escape(topology))
        }
        guard request.path == "/MediaRenderer/AVTransport/Control", request.body.contains("<InstanceID>0</InstanceID>") else {
            return Response(status: 400)
        }
        if action == "\"urn:schemas-upnp-org:service:AVTransport:1#GetTransportInfo\"" {
            return soap("CurrentTransportState", household.playing ? "PLAYING" : "PAUSED_PLAYBACK")
        }
        if action == "\"urn:schemas-upnp-org:service:AVTransport:1#GetPositionInfo\"" {
            if scenario == .metadataFailure { return Response(status: 503) }
            let metadata = scenario == .missingMetadata ? "" : "<DIDL-Lite><item><title>Fixture song</title><creator>Fixture artist</creator></item></DIDL-Lite>"
            let body = "<Envelope><Body><TrackURI>x-sonos-htastream:fixture</TrackURI><TrackMetaData>\(escape(metadata))</TrackMetaData></Body></Envelope>"
            return Response(headers: "Content-Type: text/xml\r\n", body: Data(body.utf8))
        }
        if action == "\"urn:schemas-upnp-org:service:AVTransport:1#GetMediaInfo\"" {
            return soap("CurrentURI", "x-sonos-htastream:fixture")
        }
        return Response(status: 400)
    }

    private func json(_ object: [String: Any]) -> Response {
        Response(body: try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
    }

    private func soap(_ name: String, _ text: String) -> Response {
        Response(headers: "Content-Type: text/xml\r\n", body: Data("<Envelope><Body><\(name)>\(text)</\(name)></Body></Envelope>".utf8))
    }

    private func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
    }
}

final class SSDPResponder: @unchecked Sendable {
    private let source: DispatchSourceRead
    private let lock = NSLock()
    private var queryCount = 0
    let port: UInt16
    var receivedQueries: Int { lock.withLock { queryCount } }

    init(location: URL) throws {
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { throw SimulatorFailure.couldNotStart }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        inet_pton(AF_INET, "127.0.0.1", &address.sin_addr)
        let bound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        var size = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &size) }
        }
        guard bound == 0, named == 0 else { close(fd); throw SimulatorFailure.couldNotStart }
        port = UInt16(bigEndian: address.sin_port)
        _ = fcntl(fd, F_SETFL, O_NONBLOCK)
        source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: DispatchQueue(label: "MultiroomKit.SSDPResponder"))
        source.setCancelHandler { close(fd) }
        let response = Data("HTTP/1.1 200 OK\r\nST: urn:schemas-upnp-org:device:ZonePlayer:1\r\nLOCATION: \(location)\r\n\r\n".utf8)
        source.setEventHandler { [weak self] in
            var buffer = [UInt8](repeating: 0, count: 8192)
            var sender = sockaddr_in()
            var size = socklen_t(MemoryLayout<sockaddr_in>.size)
            let count = withUnsafeMutablePointer(to: &sender) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
                    buffer.withUnsafeMutableBytes { recvfrom(fd, $0.baseAddress, $0.count, 0, address, &size) }
                }
            }
            guard count > 0 else { return }
            let query = String(decoding: buffer.prefix(count), as: UTF8.self)
            guard query.hasPrefix("M-SEARCH * HTTP/1.1\r\n"),
                  query.contains("ST: urn:schemas-upnp-org:device:ZonePlayer:1\r\n") else { return }
            self?.lock.withLock { self?.queryCount += 1 }
            _ = withUnsafePointer(to: &sender) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
                    response.withUnsafeBytes { sendto(fd, $0.baseAddress, $0.count, 0, address, size) }
                }
            }
        }
        source.resume()
    }

    func stop() { source.cancel() }
}
