# Repository boundaries

The diary is self-contained under `diary/`, including its build configuration,
lockfile, scripts, and authoring template. Its public URLs remain unchanged.

Experiments live under `prototypes/<experiment>/` with their own Swift package,
tests, and README. The first experiment implements read-only speaker status
over UPnP (SSDP discovery, then SOAP) and the Sonos Control API.

The first SDK slice is a root Swift package with `Sources/MultiroomKit/` and
separate unit, simulator integration, and opt-in live suites under `Tests/`.
This keeps the repository URL directly usable by Swift Package Manager. Its
read-only snapshot API is experimental, not a stable compatibility promise.
The SDK has no dependency on prototype code. See [testing boundaries](../testing.md).

Supported CLI and MCP products will have packages under `tools/` and depend on the
SDK. Apple apps will live under `apps/Multiroom/`, with platform-specific targets
and shared code. Split additional shared UI into a package only when needed.

Keep human-readable experiment reports under `docs/experiments/`; keep raw live
responses and credentials out of the repository. CI must use synthetic data and
must never depend on access to a real household.
