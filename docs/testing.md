# Testing the first SDK slice

The root Swift package implements **read-only status**, not playback control.
`UPnPClient` and `ControlAPIClient` implement `SpeakerStatusProvider.snapshot()`.
The returned `SystemSnapshot` separates speakers from group playback and includes
collection timestamps, partial-result issues, and warnings. These APIs are experimental.
The independently buildable prototypes remain separate and are not SDK dependencies.

## Automated, synthetic tests

From the repository root, with a Swift 6 toolchain:

```sh
swift test
```

- `MultiroomKitTests`: model normalization, configuration/address validation, and
  bounded XML parsing, including malformed XML, external entities, and SOAP faults.
- `MultiroomKitIntegrationTests`: a test-only server with independently authored
  JSON/XML for an invented household. The actual SDK clients use real URLSession
  requests, and discovery sends real UDP packets to an isolated loopback responder.
  Tests cover state changes, bonded-device representation, missing metadata,
  partial failures, disappeared groups, invalid credentials, forbidden access,
  throttling, invalid responses, unsafe topology addresses, redirects, response
  limits, timeouts, and cancellation.
- `MultiroomKitLiveTests`: skipped by default, even when ordinary tests run on a
  machine with speakers. They refuse to run when `CI` is set.

The simulator exercises a small Control API wire surface, **not the Sonos cloud**.
It does not validate OAuth, TLS, Sonos account permissions, service-specific
metadata, firmware behavior, or real LAN multicast. UDP tests use unicast loopback
instead of broadcasting into a household. Passing them is not a compatibility claim.
No simulator fixture is recorded from a real system.

CI runs synthetic tests on macOS and compiles the library for iOS and tvOS
Simulator targets. Those compilation checks do not run integration tests on those
platforms. Real iOS/tvOS networking, sandbox behavior, local-network permission,
multicast entitlement requirements, and ATS configuration remain app-level work.
watchOS and visionOS are not validated in this slice.

## Opt-in real-system tests

Run these yourself in an interactive terminal at the repository root. Do not put
credentials in arguments, environment variables, source files, or test reports.
Only non-secret opt-in flags belong in the environment.

```sh
MULTIROOMKIT_LIVE_UPNP=1 swift test --filter 'LiveTests/testUPnP$'
MULTIROOMKIT_LIVE_CLOUD=1 swift test --filter 'LiveTests/testControlAPI$'
```

UPnP requires the same LAN, UPnP enabled in the Sonos app, and local-network access
for the terminal/test runner. Discovery can fail transiently; a failed run must not
be reported as successful. Check network permissions, VPN/firewall, and connectivity
before rerunning. Applications may pass a private IPv4 speaker URL on port 1400 or
select a multicast interface through the SDK initializer for diagnosis.

The cloud test requests the integration key and client secret through hidden
`/dev/tty` prompts, then displays a private authorization URL on that terminal.
After browser authorization, copy the callback's state and code into the hidden
prompts. State is checked before the code exchange. The helper holds credentials
and the access token in memory only for that run; no Keychain writes, refresh-token
storage, or token refresh are implemented. Multiple households require a private
terminal selection. Do not share the authorization URL or callback values.

The current personal callback is the same published GitHub Pages callback used by
the prototype. GitHub Pages receives the initial URL containing the short-lived
code; this is an experimental flow, not a production authorization design.

Smoke assertions check nonempty, internally consistent snapshots and reject partial
results. They do not prove the names, membership, or metadata match the Sonos app.
Output is generic by default. An explicit private snapshot view is available for
manual comparison; it includes identifiers and household data, so never attach it
to GitHub, the diary, or a public test report.

## Manual comparison with the official Sonos app

Use the [Sonos web app](https://play.sonos.com/) as the visible reference for the
Control API, and the iPhone Sonos app through iPhone Mirroring as the visible
reference for UPnP. UI-assisted observation is separate from automated Swift tests.
Sign in yourself, and keep credentials and UI screenshots private. Mirroring must
be set up and the Sonos app open before observation; it is not a headless CI tool.
The web app's underlying API implementation has not been verified here; agreement
with it does not establish an independent backend or prove the protocol the iPhone
app used. These comparisons check user-visible behavior and the SDK's interpretation.

```sh
MULTIROOMKIT_LIVE_COMPARE=1 MULTIROOMKIT_LIVE_SHOW_SNAPSHOT=1 \
  swift test --filter LiveTests.testPairedSnapshotsForManualAppComparison
```

This authorizes cloud access first, then collects UPnP and cloud snapshots close
together and shows both on the private terminal. They are not atomic snapshots.
The automated test validates each independently; **it does not assert parity**.

1. Keep the system steady during collection. In the official app, note room names,
   group membership, playing/paused status, and any displayed title, artist, and source.
2. Compare logical rooms and group membership, not raw row counts: UPnP includes
   physical bonded/satellite members; Control API players may represent several
   physical devices through `deviceCount`. IDs and group naming can differ.
3. Allow for elapsed time and metadata absent from a transport or source. Record a
   discrepancy as unresolved rather than treating the app or either API as always
   authoritative. Repeat a steady-state observation if useful.
4. If you choose to test transitions, manually pause/resume a room in the Sonos app,
   wait for it to settle, and rerun. Separately try grouping/ungrouping, an idle room,
   or a different source. The test code never sends playback or grouping commands.
5. Record only generic outcomes and limitations publicly. Keep private observations
   and snapshots outside the repository. Disruptive offline/reboot tests should be
   separately planned, not performed as part of an ordinary test run.

## Repeatable household-specific assertions

The smoke tests above only validate internal consistency. To assert the actual
room inventory, group membership, and playback state, use an independent UI
observation as the expected result. Do not generate expectations from an SDK
snapshot and call agreement a successful validation.

The invented [example](live-household.example.json) shows the format. Put the
actual expectations in `.local/live-household.json` in your checkout, which is
ignored by Git. This is not a credential file. In a UI-assisted session, the
assistant can prepare this private file from the displayed Sonos UI, then ask you
to confirm it. You do not need to write JSON yourself. Never edit the public example
to contain real household details or force-add the private file to Git.

- `confirmedInSonosApp` must be `true` only after the observation is checked.
- Each transport has its own `rooms` list and `groups`, each group containing
  its room names and expected `playbackState` (`playing`, `paused`, `idle`, or
  `buffering`, or `notPlaying`). Use `notPlaying` when the UI offers a Play button
  but does not distinguish paused from stopped; it accepts SDK `paused` or `idle`,
  never `unknown`, `buffering`, or `playing`. Every expected room must belong to exactly one expected group.
- Names must be unique. Group names and IDs are not compared; group membership
  identifies the corresponding group. UPnP invisible bonded members and satellites
  are not counted as separate logical rooms.
- `physicalDeviceCount` is optional. Omit it when the UI does not establish that
  count; never substitute the number of displayed logical rooms.
- Optional group `title`, `artist`, and `source` values assert exact transport
  metadata. Omitted fields are not checked. Do not assume the two transports expose
  identical source names or metadata. No assertion of absent metadata is supported.

```sh
MULTIROOMKIT_LIVE_HOUSEHOLD_UPNP=1 \
  swift test --filter 'LiveTests/testUPnPMatchesHousehold$'
MULTIROOMKIT_LIVE_HOUSEHOLD_CLOUD=1 \
  swift test --filter 'LiveTests/testControlAPIMatchesHousehold$'
MULTIROOMKIT_LIVE_HOUSEHOLD_COMPARE=1 \
  swift test --filter 'LiveTests/testBothTransportsMatchHousehold$'
```

The cloud tests still require private terminal authorization. All three tests are
read-only and opt-in, refuse CI, and fail if the expected-state file is missing,
unconfirmed, or invalid. They never silently replace expectations to make a test
pass. Failure messages exclude the actual and expected household values.
Six synthetic tests exercise the matcher without contacting speakers.

Keep the system steady, compare UI and SDK observations close together, and
refresh expectations from the UI after intentional changes. One passing snapshot
does not validate state transitions. Cloud SDK and web-app comparison remain pending
until authorization is completed; adding these tests is not evidence of a
successful cloud household-specific run.

## SDK boundaries and validation record

Production cloud endpoints are fixed HTTPS Sonos URLs. The SDK accepts an async
credential provider; login UI, secure persistence, and refresh policy belong to the
caller. Do not embed a developer client secret in a shipped app. UPnP validates
private/link-local IPv4 HTTP addresses on port 1400 and refuses redirects. Internal
test initializers alone allow an exact loopback server port. Transport failures use
typed, sanitized errors rather than raw URLs, payloads, or underlying error details.

Playback is queried once per group. Metadata errors can produce partial snapshots;
authentication/permission/throttling failures on the cloud path stop the operation.
There are no subscriptions, automatic retries, writes, or durable credentials yet.

On October 9, 2026, local synthetic tests passed and the SDK compiled for iOS and
tvOS Simulator targets. A private SDK UPnP run passed after an initial discovery
attempt found no usable responses. This establishes a successful read-only run,
not dependable discovery on every attempt. A subsequent household-specific UPnP
test passed against room inventory, group membership, and playing/not-playing
expectations independently observed in the iPhone Sonos app through Mirroring.
No playback or grouping changes were made. Metadata and state transitions were
not validated by that comparison. SDK cloud live testing against the web-app
observation has **not yet been completed**. The earlier successful cloud prototype
run is not evidence that this new SDK cloud implementation works live.

Protocol reference: [Sonos Control API overview](https://docs.sonos.com/docs/control).
