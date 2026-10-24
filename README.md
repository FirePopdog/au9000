# Samsung AU9000 iPhone remote

This is a complete Xcode SwiftUI project for a basic iPhone remote that connects directly to a Samsung AU9000 over the home network. It uses the TV's local secure WebSocket remote-control endpoint on port 8002. The TV and iPhone must be on the same LAN. The first connection should display an approval prompt on the TV; subsequent connections reuse the TV-issued token stored on the iPhone.

## Build and install

### Build an unsigned IPA without owning a Mac

The included GitHub Actions workflow builds on a hosted macOS runner and packages an unsigned IPA. To run it:

1. Create a GitHub repository and upload the contents of this project folder.
2. Open the repository's **Actions** tab and enable workflows if prompted.
3. Select **Build unsigned iOS IPA** → **Run workflow**.
4. When it finishes, download the `AU9000Remote-unsigned-ipa` artifact from that run.

The bundle identifier is currently `com.example.AU9000Remote`; replace it with your own unique identifier in the Xcode project and `Info.plist` before signing. An unsigned IPA is a build artifact, not directly installable; sign it with your own certificate and provisioning profile using your preferred signing tool.

## Use

Find the TV's IP address in its network settings or your router, enter it in the app, and tap Connect. Accept the prompt on the TV. Controls send Samsung key names over the local network. Power-on while the TV is asleep and some input/app shortcuts may not be available through this endpoint.

The endpoint and pairing behavior are based on Samsung TV local-network remote implementations. Samsung's supported consumer path is the SmartThings app; compatibility can vary with TV firmware and local-network settings.
