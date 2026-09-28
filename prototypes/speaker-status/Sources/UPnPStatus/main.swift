import Foundation
import PrototypeSupport
import Darwin

@main struct UPnPStatus {
    static func main() async {
        do {
            let options = try Options(Array(CommandLine.arguments.dropFirst()), cloud: false)
            if options.help {
                print("""
                upnp-status [--json | --summary] [--timeout 1...30] [--interface NAME] [--host PRIVATE_IPV4]
                Read-only Sonos status via UPnP. Default discovery window: 3 seconds.
                --host bypasses multicast using a known speaker, on HTTP port 1400.
                --interface selects a LAN interface; by default all eligible LAN interfaces are queried.
                --summary omits names but still contains private household counts/states.
                Default/JSON output contains personal room names and listening information.
                Exit: 0 complete, 1 failed, 2 partial. No playback or configuration changes.
                """)
                return
            }
            let seeds: [URL]
            if let host = options.host {
                guard privateIPv4(host) else { throw StatusError("--host requires a private IPv4 address, not a URL or hostname.") }
                seeds = [try speakerURL("http://\(host):1400/xml/device_description.xml")]
            } else {
                seeds = try await Task.detached { try Discovery.discover(seconds: options.timeout, interface: options.interface) }.value
            }
            let snapshot = try await UPnPClient().snapshot(seeds: seeds)
            print(try snapshot.output(json: options.json, summary: options.summary))
            if snapshot.isPartial { exit(2) }
        } catch {
            FileHandle.standardError.write(Data((safeMessage(error) + "\n").utf8))
            exit(1)
        }
    }
}
