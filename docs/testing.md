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
MULTIROOMKIT_LIVE_UPNP=1 swift test --filter LiveTests.testUPnP
MULTIROOMKIT_LIVE_CLOUD=1 swift test --filter LiveTests.testControlAPI
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

Live assertions check nonempty, internally consistent snapshots and reject partial
results. They do not prove the names, membership, or metadata match the Sonos app.
Output is generic by default. An explicit private snapshot view is available for
manual comparison; it includes identifiers and household data, so never attach it
to GitHub, the diary, or a public test report.

## Manual comparison with the official Sonos app

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
not dependable discovery on every attempt. SDK cloud live testing and the manual
Sonos-app comparison have **not yet been completed**. The earlier successful cloud
prototype run is not evidence that this new SDK cloud implementation works live.

Protocol reference: [Sonos Control API overview](https://docs.sonos.com/docs/control).
