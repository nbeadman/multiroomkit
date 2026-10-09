# MultiroomKit

An independent exploration of Sonos control with Swift, documented in a public
[developer diary](https://nbeadman.github.io/multiroomkit/). Not affiliated with Sonos.

## Repository layout

- `diary/`: the Eleventy website, Markdown content, templates, and its own Node dependencies. See [diary instructions](diary/README.md).
- `prototypes/`: disposable, independently buildable experiments. Local network support is called **UPnP**; cloud support is called **Sonos Control API**.
- `docs/architecture/`: architecture decisions and intended boundaries.
- `docs/experiments/`: reproducible experiments and clearly labeled verification results.
- Future root `Package.swift`, `Sources/MultiroomKit/`, and `Tests/MultiroomKitTests/`: the supported Apple-platform SDK, extracted only after experiments establish its API.
- Future `tools/multiroomctl/` and `tools/multiroom-mcp/`: supported CLI and MCP server consuming the SDK.
- Future `apps/Multiroom/`: Xcode project with shared, macOS, iOS, and potentially tvOS code.

Only implemented components get package manifests and source directories. Planned
platforms are not a claim of current support. Prototypes must not become a dependency
of supported apps or tools.

## Speaker status prototype

See [setup and usage](prototypes/speaker-status/README.md) for `upnp-status` and
`cloud-status`. Both are read-only Swift command-line tools for macOS. UPnP has
been exercised on a real system; live cloud testing awaits developer-account
setup. See the [verification record](docs/experiments/speaker-status.md).

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
