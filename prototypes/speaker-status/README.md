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

## Sonos Control API: interactive authorization

Live cloud verification is pending. Synthetic OAuth and cloud tests are not
evidence of a successful authorization or a live speaker query.

1. Create a developer account through the [Sonos developer portal](https://developer.sonos.com/).
2. Register a **control** integration and its redirect URI exactly as
   `https://nbeadman.github.io/multiroomkit/sonos/callback/`. Keep the generated
   API key and client secret private.
3. In your own interactive macOS Terminal, run `cloud-status`. It prompts with
   echo disabled for the API key and client secret. Do not put them in the
   command, an environment variable, a file in this repository, or a Codex
   tool call.
4. Open the printed Sonos login URL in your browser and approve access to your
   household. The callback page shows a short-lived authorization code and
   state. Enter both into the still-running terminal when prompted. The tool
   checks the state, exchanges the code with Sonos over HTTPS using the client
   secret, then performs the read-only status query in the same run.

```sh
swift run --package-path prototypes/speaker-status cloud-status
swift run --package-path prototypes/speaker-status cloud-status --summary
swift run --package-path prototypes/speaker-status cloud-status --json
swift run --package-path prototypes/speaker-status cloud-status --list-households
swift run --package-path prototypes/speaker-status cloud-status --household HOUSEHOLD_ID
```

The API key, secret, authorization code, access token, and returned refresh
token are not saved to Keychain or disk; the refresh token is ignored. Each
invocation repeats authorization and uses its access token for that run only.
There is no automatic token refresh. The old `--set-credentials` option is
removed. If an earlier version saved credentials under Keychain service
`org.multiroomkit.prototype.speaker-status`, this version does not read or
delete them; remove those items yourself in Keychain Access if no longer needed.
Do not embed a client secret in a released binary.

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

- Never pass keys, secrets, codes, or tokens as command arguments or paste them
  into chat, GitHub, the diary, fixtures, or shell history. Terminal prompts
  suppress echo; the printed login URL contains the integration key, so keep
  terminal scrollback private too.
- Normal and JSON output contain private room names and listening information.
  Keep them local. `--summary` omits identifying names but its counts and states
  remain private; do not copy live summaries into GitHub without explicit approval.
- No media URLs, device IDs, addresses, token responses, or raw server errors
  are printed by the status commands. The user-facing login URL is printed,
  and the callback displays the one-time code and state locally. GitHub Pages
  still receives the initial callback URL containing the code; this is a
  personal prototype, not production-grade OAuth hosting.
- Tests use invented fixtures and an injected HTTP function. They do not access
  the LAN, Sonos cloud, or Keychain. CI needs no secrets.
- Review staged changes for private data before committing. Never commit raw
  household responses to make a test pass.

See [experiment results](../../docs/experiments/speaker-status.md) for the actual
verification record and remaining limitations.
