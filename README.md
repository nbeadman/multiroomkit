# MultiroomKit

An independent exploration of Sonos control with Swift, documented in a public
[developer diary](https://nbeadman.github.io/multiroomkit/). Not affiliated with Sonos.

## Repository layout

- `diary/`: the Eleventy website, Markdown content, templates, and its own Node dependencies. See [diary instructions](diary/README.md).
- `prototypes/`: disposable, independently buildable experiments. Local network support is called **UPnP**; cloud support is called **Sonos Control API**.
- `docs/architecture/`: architecture decisions and intended boundaries.
- `docs/experiments/`: reproducible experiments and clearly labeled verification results.
- Root `Package.swift`, `Sources/MultiroomKit/`, and `Tests/`: the first, experimental SDK slice: read-only speaker, group, and playback snapshots over both transports.
- Future `tools/multiroomctl/` and `tools/multiroom-mcp/`: supported CLI and MCP server consuming the SDK.
- Future `apps/Multiroom/`: Xcode project with shared, macOS, iOS, and potentially tvOS code.

Only implemented components get package manifests and source directories. Planned
platforms are not a claim of current support. Prototypes must not become a dependency
of supported apps or tools.

## SDK and testing

The root Swift package has no dependency on the prototypes. Its API is experimental,
not yet a stable supported SDK. It declares macOS 13, iOS 16, and tvOS 16 minimums;
simulator compilation is not evidence of real iOS or tvOS networking support.

```sh
swift test
```

Ordinary tests use invented data and loopback sockets only. Six live tests are
skipped by default and refuse to run in CI. See the [testing guide](docs/testing.md)
for opt-in real-system tests and the manual Sonos-app comparison checklist.

## Speaker status prototype

See [setup and usage](prototypes/speaker-status/README.md) for `upnp-status` and
`cloud-status`. Both are read-only Swift command-line tools for macOS. UPnP has
been exercised on a real system. Nick reported a successful private Sonos
Control API authorization and status query on 2026-10-08. The two paths have
not yet been compared against each other or the official Sonos app. See the
[verification record](docs/experiments/speaker-status.md).

## Diary development

```sh
cd diary
pnpm install --frozen-lockfile
pnpm dev
```

See [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md). All changes use
descriptive `codex/` branches and reviewable PRs; Nick makes the merge decision.

## Secrets and private system data

Never commit credentials, tokens, raw device responses, household identifiers,
serial numbers, or private network details. Ignore rules are only a backstop:
inspect staged changes before committing. Use synthetic test fixtures and keep
live results on the local machine. No real Sonos credentials belong in CI or Pages.
