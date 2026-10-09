import Foundation

public enum SonosTransport: String, Codable, Sendable {
    case upnp
    case controlAPI
}

public enum SpeakerRole: String, Codable, Sendable {
    case player
    case bonded
    case satellite
}

public enum PlaybackState: String, Codable, Sendable {
    case playing, paused, idle, buffering, unknown

    init(wireValue: String?) {
        switch wireValue?.uppercased().replacingOccurrences(of: "PLAYBACK_STATE_", with: "") {
        case "PLAYING": self = .playing
        case "PAUSED", "PAUSED_PLAYBACK": self = .paused
        case "STOPPED", "IDLE", "NO_MEDIA_PRESENT": self = .idle
        case "BUFFERING", "TRANSITIONING": self = .buffering
        default: self = .unknown
        }
    }
}

/// A physical UPnP member or a logical Control API player. IDs are private system data.
public struct Speaker: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let role: SpeakerRole
    public let deviceCount: Int
}

public struct PlaybackMetadata: Codable, Equatable, Sendable {
    public let title: String?
    public let artist: String?
    public let source: String?
}

public struct StatusIssue: Codable, Equatable, Sendable {
    public enum Operation: String, Codable, Sendable {
        case playback, metadata, source
    }

    public let operation: Operation
    public let error: MultiroomError
}

/// Playback belongs to a group, including a group containing only one player.
public struct SpeakerGroup: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let speakerIDs: [String]
    public let playbackState: PlaybackState
    public let metadata: PlaybackMetadata
    public let issues: [StatusIssue]
}

public enum SnapshotWarning: String, Codable, Sendable {
    case ungroupedPlayers
    case discoveryOutsideSelectedTopology
    case noPlayers
}

/// A sequence of observations, not an atomic view. The contents are private household data.
public struct SystemSnapshot: Codable, Sendable {
    public let transport: SonosTransport
    public let startedAt: Date
    public let capturedAt: Date
    public let speakers: [Speaker]
    public let groups: [SpeakerGroup]
    public let warnings: [SnapshotWarning]

    public var isPartial: Bool {
        !warnings.isEmpty || groups.contains { !$0.issues.isEmpty }
    }
}

/// The first SDK capability. Implementations query status and never change playback.
public protocol SpeakerStatusProvider: Sendable {
    func snapshot() async throws -> SystemSnapshot
}
