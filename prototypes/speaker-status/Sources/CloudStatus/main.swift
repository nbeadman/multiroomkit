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
                Read-only Sonos Control API status. Each run prompts in a local terminal
                for your integration API key and client secret, then guides you through
                Sonos login and a one-time authorization-code exchange.
                Input is hidden and held only for this run; no Keychain or file storage.
                Never pass credentials or the returned code as command arguments.
                --list-households prints private household IDs for explicit selection.
                No automatic token refresh: authorize again on the next run.
                Default/JSON output contains personal room names and listening information.
                Exit: 0 complete, 1 failed, 2 partial. No playback or configuration changes.
                """)
                return
            }
            let apiKey = try TerminalInput.hidden("Sonos integration API key (hidden): ")
            let secret = try TerminalInput.hidden("Sonos client secret (hidden): ")
            let oauth = try SonosOAuth(apiKey: apiKey, clientSecret: secret)
            let expectedState = try SonosOAuth.randomState()
            let loginURL = try oauth.authorizationURL(state: expectedState)
            print("Open this Sonos authorization URL in a browser. Do not share it:")
            print(loginURL.absoluteString)
            print("After Sonos redirects to the MultiroomKit callback, copy its state and code into this terminal.")
            let returnedState = try TerminalInput.hidden("Returned state (hidden): ")
            let code = try TerminalInput.hidden("Authorization code (hidden): ")
            let client = CloudClient(credentials: try await oauth.exchange(
                code: code, returnedState: returnedState, expectedState: expectedState))
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
