# Repository boundaries

The diary is self-contained under `diary/`, including its build configuration,
lockfile, scripts, and authoring template. Its public URLs remain unchanged.

Experiments live under `prototypes/<experiment>/` with their own Swift package,
tests, and README. The first planned experiment compares read-only speaker status
over UPnP (SSDP discovery, then SOAP) and the Sonos Control API.

When the experiments establish a useful stable boundary, add the SDK as a root
Swift package with `Sources/MultiroomKit/` and `Tests/MultiroomKitTests/`. This keeps
the repository URL directly usable by Swift Package Manager. Do not create an
empty SDK or promise an API before the experiment.

Supported CLI and MCP products will have packages under `tools/` and depend on the
SDK. Apple apps will live under `apps/Multiroom/`, with platform-specific targets
and shared code. Split additional shared UI into a package only when needed.

Keep human-readable experiment reports under `docs/experiments/`; keep raw live
responses and credentials out of the repository. CI must use synthetic data and
must never depend on access to a real household.
