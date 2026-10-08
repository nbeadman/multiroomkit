import Foundation

public struct StatusError: Error, LocalizedError, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

public struct SpeakerStatus: Codable, Sendable {
    public var room: String
    public var group: String
    public var role: String
    public var deviceCount: Int
    public var state: String
    public var title: String?
    public var artist: String?
    public var source: String?
    public var issue: String?

    public init(room: String, group: String, role: String = "player", deviceCount: Int = 1,
                state: String = "unknown", title: String? = nil, artist: String? = nil,
                source: String? = nil, issue: String? = nil) {
        self.room = room; self.group = group; self.role = role; self.deviceCount = deviceCount
        self.state = state; self.title = title; self.artist = artist; self.source = source; self.issue = issue
    }
}

public struct Snapshot: Codable, Sendable {
    public var transport: String
    public var capturedAt = Date()
    public var speakers: [SpeakerStatus]
    public var warnings: [String] = []
    public var isPartial: Bool { !warnings.isEmpty || speakers.contains { $0.issue != nil } }

    public func output(json: Bool, summary: Bool) throws -> String {
        if summary {
            // Deliberately excludes room names, media, IDs, addresses, and error payloads.
            let states = Dictionary(grouping: speakers, by: \.state).mapValues(\.count)
            let encoded = try JSONSerialization.data(withJSONObject: [
                "transport": transport, "rows": speakers.count,
                "reportedDevices": speakers.reduce(0) { $0 + $1.deviceCount },
                "rowsWithTitle": speakers.filter { !($0.title ?? "").isEmpty }.count,
                "rowsWithArtist": speakers.filter { !($0.artist ?? "").isEmpty }.count,
                "rowsWithSource": speakers.filter { !($0.source ?? "").isEmpty }.count,
                "states": states, "partial": isPartial,
            ], options: [.sortedKeys])
            return String(decoding: encoded, as: UTF8.self)
        }
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return String(decoding: try encoder.encode(self), as: UTF8.self)
        }
        var lines = ["ROOM / PLAYER\tGROUP\tROLE\tDEVICES\tSTATE\tTITLE\tARTIST\tSOURCE"]
        for speaker in speakers {
            lines.append([speaker.room, speaker.group, speaker.role, String(speaker.deviceCount),
                          speaker.state, speaker.title ?? "—", speaker.artist ?? "—",
                          speaker.source ?? "—"].map(terminalSafe).joined(separator: "\t"))
            if let issue = speaker.issue { lines.append("  Warning: " + terminalSafe(issue)) }
        }
        lines += warnings.map { "Warning: " + terminalSafe($0) }
        return lines.joined(separator: "\n")
    }
}

// Metadata is untrusted; never allow terminal control sequences from a speaker.
public func terminalSafe(_ text: String) -> String {
    String(String.UnicodeScalarView(text.unicodeScalars.filter {
        !CharacterSet.controlCharacters.contains($0)
    }))
}

public func safeMessage(_ error: Error) -> String {
    // Never print URLSession/decoding descriptions: those can contain URLs or payloads.
    (error as? StatusError)?.message ?? "Request or response could not be processed."
}

public func playbackState(_ value: String?) -> String {
    switch value?.uppercased().replacingOccurrences(of: "PLAYBACK_STATE_", with: "") {
    case "PLAYING": "playing"
    case "PAUSED", "PAUSED_PLAYBACK": "paused"
    case "IDLE", "STOPPED", "NO_MEDIA_PRESENT": "idle"
    case "BUFFERING", "TRANSITIONING": "buffering"
    default: "unknown"
    }
}

public struct Options: Sendable {
    public var json = false
    public var summary = false
    public var help = false
    public var timeout: Double = 3
    public var host: String?
    public var interface: String?
    public var household: String?
    public var listHouseholds = false
    public init(_ arguments: [String], cloud: Bool) throws {
        var index = 0
        while index < arguments.count {
            let flag = arguments[index]
            switch flag {
            case "--help", "-h": help = true
            case "--json": json = true
            case "--summary": summary = true
            case "--list-households" where cloud: listHouseholds = true
            case "--timeout" where !cloud, "--host" where !cloud, "--interface" where !cloud, "--household" where cloud:
                index += 1
                guard index < arguments.count else { throw StatusError("Missing option value. Use --help.") }
                let value = arguments[index]
                if flag == "--timeout" {
                    guard let seconds = Double(value), seconds.isFinite, (1...30).contains(seconds) else {
                        throw StatusError("Timeout must be between 1 and 30 seconds.")
                    }
                    timeout = seconds
                } else if flag == "--host" { host = value }
                else if flag == "--interface" { interface = value }
                else { household = value }
            default: throw StatusError("Unknown option. Use --help. Credentials must never be command arguments.")
            }
            index += 1
        }
        guard !(json && summary) else { throw StatusError("Choose --json or --summary, not both.") }
        guard !listHouseholds || arguments.count == 1 else {
            throw StatusError("Use --list-households on its own.")
        }
    }
}
