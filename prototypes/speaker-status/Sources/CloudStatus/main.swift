import Foundation
import PrototypeSupport
import Darwin

@main struct CloudStatus {
    static func main() async {
        do {
            let options = try Options(Array(CommandLine.arguments.dropFirst()), cloud: true)
            if options.help {
                print("""
                cloud-status [--json | --summary] [--household ID]
                cloud-status --list-households
                cloud-status --set-credentials
                Read-only Sonos Control API status. Requires a registered Sonos integration
                and an OAuth access token. Credentials are read from macOS Keychain.
                --set-credentials prompts securely; never pass credentials as arguments.
                --list-households prints private household IDs for explicit selection.
                This prototype does not implement OAuth login or automatic token refresh.
                Default/JSON output contains personal room names and listening information.
                Exit: 0 complete, 1 failed, 2 partial. No playback or configuration changes.
                """)
                return
            }
            if options.setCredentials {
                try CredentialStore.promptAndSave()
                print("Credentials saved in macOS Keychain.")
                return
            }
            let client = CloudClient(credentials: try CredentialStore.load())
            if options.listHouseholds {
                for id in try await client.householdIDs() { print(terminalSafe(id)) }
                return
            }
            let snapshot = try await client.snapshot(household: options.household)
            print(try snapshot.output(json: options.json, summary: options.summary))
            if snapshot.isPartial { exit(2) }
        } catch {
            FileHandle.standardError.write(Data((safeMessage(error) + "\n").utf8))
            exit(1)
        }
    }
}
