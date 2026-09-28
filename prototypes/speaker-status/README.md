# Speaker status experiment

Two read-only macOS command-line tools in one Swift package, with no third-party
dependencies. Requires Swift 6 and macOS 13 or later. This is experimental code,
not the supported MultiroomKit SDK. Other Apple platforms have not been tested.

From the repository root:

```sh
swift test --package-path prototypes/speaker-status
swift run --package-path prototypes/speaker-status upnp-status
swift run --package-path prototypes/speaker-status upnp-status --json
swift run --package-path prototypes/speaker-status upnp-status --summary
```

The table shows room/player, group, role, reported device count, playback state,
title, artist, and source. Paused/idle content may be the last loaded track, not
currently audible music. An em dash means unavailable metadata. Exit status is
0 for a complete query, 1 for failure, and 2 for partial results. `--summary`
prints counts/states only for local verification. That summary is still private
household-derived information; do not publish it without explicit approval.

## UPnP

SSDP multicast discovers a seed speaker, then SOAP `GetZoneGroupState` obtains
the topology. Status and metadata are queried from each group's coordinator,
not separately from its followers. Satellites and hidden/bonded members appear
with their roles and inherit the group's playback information.

```sh
swift run --package-path prototypes/speaker-status upnp-status --timeout 5
# Substitute a known speaker's private IPv4 address; never post it in a PR.
swift run --package-path prototypes/speaker-status upnp-status --host PRIVATE_IPV4
```

Multicast queries all active private IPv4 multicast-capable LAN interfaces,
excluding loopback and point-to-point VPN interfaces. Use `--interface en0` (or
your LAN interface name) to select one explicitly. If no speakers are found,
check the same LAN, macOS Local Network permission, firewall/VPN behavior, and
the Sonos app's UPnP setting. `--host` bypasses multicast. No subnet scanning or
automatic security-setting changes are performed. This prototype restricts
speaker URLs to private/link-local IPv4 HTTP on port 1400, rejects redirects,
and does not support IPv6-only systems or unusual port configurations.

Sonos calls UPnP unsupported. Read-only describes the actions sent, not a
guarantee that future firmware will preserve this interface.

## Sonos Control API: account setup required

Live cloud verification is pending: authorized integration credentials have not
been configured for the prototype. Synthetic tests are not evidence of live
cloud success.

1. Create a developer account through the [Sonos developer portal](https://developer.sonos.com/).
2. Register a control integration and obtain its API key and client secret.
3. Follow [Sonos authorization](https://docs.sonos.com/docs/authorize). The
   documented flow requires a publicly routable HTTPS redirect URL, user consent,
   and a server-side code exchange using the client secret. Arrange that securely
   before authorizing; the diary is not an OAuth callback service.
4. Once an access token is available, enter the token and API key in a **local
   interactive terminal**, with input hidden, using the command below.

```sh
swift run --package-path prototypes/speaker-status cloud-status --set-credentials
swift run --package-path prototypes/speaker-status cloud-status
swift run --package-path prototypes/speaker-status cloud-status --json
swift run --package-path prototypes/speaker-status cloud-status --list-households
swift run --package-path prototypes/speaker-status cloud-status --household HOUSEHOLD_ID
```

Credentials are generic-password items in macOS Keychain, service
`org.multiroomkit.prototype.speaker-status`, accounts `access-token` and `api-key`.
You can remove those items using Keychain Access. The tool never asks for or
stores the client secret, Sonos password, or refresh token. It does not yet
implement OAuth login or automatic token refresh; replace expired access tokens
with `--set-credentials`. Do not embed a client secret in a released binary.

Sonos documents the broad `playback-control-all` OAuth scope, even though these
tools only query state. The cloud implementation uses GET requests for
households, groups, playback, and playbackMetadata. It neither subscribes to
events nor requires a webhook for the status snapshot.

Cloud rows represent logical players; `deviceCount` preserves the number of
reported bonded devices where available. UPnP can expose separate physical
members. Compare room/group playback, not just row counts. If multiple cloud
households exist, select one explicitly; IDs printed by `--list-households`
are private and must not be copied into GitHub.

## Secrets and test data

- Never pass tokens/secrets as command arguments or paste them into chat, GitHub,
  the diary, fixtures, or shell history.
- Normal and JSON output contain private room names and listening information.
  Keep them local. `--summary` omits identifying names but its counts and states
  remain private; do not copy live summaries into GitHub without explicit approval.
- No media URLs, device IDs, addresses, OAuth responses, or raw server errors are
  printed by the status commands. No responses are saved to disk.
- Tests use invented fixtures and an injected HTTP function. They do not access
  the LAN, Sonos cloud, or Keychain. CI needs no secrets.
- Review staged changes for private data before committing. Never commit raw
  household responses to make a test pass.

See [experiment results](../../docs/experiments/speaker-status.md) for the actual
verification record and remaining limitations.
