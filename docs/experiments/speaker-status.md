# Experiment: read-only speaker status

Date: 2026-09-28. Implementation and this report were written by OpenAI Codex
from Nick's requirements. No human-authored notes have been invented.

## Question

Can a small macOS Swift tool enumerate Sonos speakers and report what they are
playing using UPnP and the Sonos Control API? Keep the implementations isolated
from the future public SDK until live results establish useful boundaries.

## Implemented

- One Swift package, two executables: `upnp-status` and `cloud-status`.
- Shared table/JSON output and a privacy-preserving counts-only summary.
- UPnP SSDP discovery on eligible LAN interfaces, topology including bonded
  members/satellites, and coordinator-based status and metadata reads.
- Cloud household selection, logical players and device counts, playback state,
  and playback metadata queries. Credentials come from macOS Keychain.
- Bounded network requests, partial-result reporting, synthetic tests, no state
  changes, no third-party package dependencies, and no secrets in CI.

## Verification observed so far

- Swift 6.4 on Apple silicon: package compiled and automated tests passed.
- Both command help paths run without network access or credentials.
- Initial UPnP multicast using the system-selected interface returned no
  responses. After explicitly querying eligible LAN interfaces, a live run
  successfully returned device status and metadata. This suggests an interface-routing issue, but does
  not prove which adapter caused the original failure.
- The normal display was shown to Nick privately for comparison. Household
  counts, playback states, metadata availability, room names, and media details
  are intentionally not reproduced here.
- Live cloud verification is **not performed**: authorized integration
  credentials are not configured for the prototype yet. Mock responses only verify our
  request construction, parsing, grouping, and failure handling.
- No tokens, room names, media titles, household/device IDs, or network addresses
  are included in this report or committed fixtures. No playback or security
  configuration changes were made.

The coding environment required temporary build/module caches and SwiftPM's
`--disable-sandbox` option because nested build sandboxing was unavailable. This
is a build-environment detail, not a recommendation to disable macOS security or
Sonos protections. Normal terminal/CI instructions retain standard SwiftPM use.

## Remaining checks and limits

- Compare displayed rooms and current titles against the official Sonos app.
- Exercise paused media, radio, TV/line-in, unreachable coordinators, and topology
  changes on real hardware. These are not all established by one successful run.
- Set up Sonos developer access and a secure OAuth callback/code-exchange flow;
  obtain a token locally, then compare cloud and UPnP snapshots of the same system.
- Test Keychain entry/retrieval with real user-authorized credentials. OAuth login
  and refresh are explicitly not implemented by this first status tool.
- UPnP rows are physical topology members; cloud rows are logical players with
  reported device counts. Do not infer an error merely from different row counts.
- Snapshots are sequential observations, not atomic views. Sources may omit
  metadata; paused/idle players can retain the last loaded track.
- UPnP is restricted to private/link-local IPv4 and port 1400. An explicit host
  bypasses multicast; multiple discovered systems produce a warning when detected.
- Declared minimum is macOS 13; it has not been tested on every macOS version.
  iOS, tvOS, MCP, the supported CLI, and a public SDK are not implemented.

## Protocol sources

- [Sonos connection security](https://support.sonos.com/en-gb/article/adjust-connection-security-settings): UPnP naming and unsupported status.
- [Sonos discovery and object model](https://docs.sonos.com/docs/discover): households, groups, logical players, and bonded devices.
- [Sonos authorization](https://docs.sonos.com/docs/authorize): developer integration, HTTPS redirect, tokens, and broad OAuth scope.
- [Playback state](https://docs.sonos.com/reference/playback-getplaybackstatus-groupid).
- [Playback metadata](https://docs.sonos.com/reference/playbackmetadata-getmetadatastatus-groupid).
- [Sonos sample metadata handler](https://github.com/sonos/api-web-sample-app/blob/main/sample-app/Client/src/App/MuseDataHandlers/PlaybackMetadataHandler.js): current item and service metadata fields.

No code was copied from a third-party controller; the prototype is an independent
implementation of the queries used for this experiment.
