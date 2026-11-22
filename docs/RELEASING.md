# Releasing Clipboard

## Build a local candidate

Use the toolchain in [Contributing](../CONTRIBUTING.md#build-from-a-clean-checkout). From the repository root, run the following commands.

```sh
./scripts/test.sh
./scripts/package-release.sh
cd build/releases
shasum -a 256 -c Clipboard-0.1.0-macOS-local-rc.zip.sha256
```

Open the ZIP in Finder to extract **Clipboard.app**. The script uses a fresh Release build, includes both MIT license notices inside the app, applies an ad-hoc hardened-runtime signature, and verifies both CPU architectures and the signature after extraction. It takes the archive version from the built app. Both output files are under the ignored `build/releases/` directory. The checksum detects a damaged or mismatched ZIP. Local candidates are for testing on the build Mac.

CI runs the unit tests and packages a fresh candidate on macOS for pushes and pull requests. UI tests need a logged-in macOS session. Run `./scripts/ui-test.sh` there.

## Smoke-test the package

Use a test macOS account for live capture. Record the OS version, hardware, archive checksum and result for each machine. Check the oldest supported macOS and both Apple silicon and Intel before advertising those configurations as tested.

1. Quit any running copy, unzip the package, move the app to Applications, and open it. Confirm its menu bar icon appears and **Settings… → About** shows the expected version.
2. Turn off **Fetch link titles and icons**, copy a distinctive sample sentence from TextEdit, open the panel with **⌘⇧V**, find the sentence, and press Return. Paste it into a blank document.
3. With Accessibility permission initially off, try **⌘Return**. Verify that the item is copied and the permission explanation appears. Grant permission to the installed app, retry from TextEdit, and verify the selected text appears at the insertion point.
4. Pin the sample, quit and reopen Clipboard, and find it again. Add a second unpinned item. In the test account, choose **Clear History…** and confirm the pinned sample survives while the second item disappears.
5. For a public build, repeat first launch from a browser-downloaded ZIP on a clean Mac and confirm normal Gatekeeper acceptance.

### 0.1.0 local candidate verification

Built with Xcode 26.6 and XcodeGen 2.48.0 on Apple silicon running macOS 26.2. The clean-checkout test run passed 119 unit tests and four UI tests. The extracted candidate passed strict signature verification and completed the panel-open demo using arm64 natively and x86_64 through Rosetta. Native Intel hardware, macOS 14, the live permission flow and a notarized browser download still need release testing.

## Prepare a public draft when signing is available

The maintainer needs an Apple Developer ID Application signing identity with its private key, a valid notarytool keychain profile, and GitHub CLI release access. Use `security find-identity -v -p codesigning` to identify the certificate. Set `DEVELOPER_ID_APPLICATION` to its full name and `NOTARY_PROFILE` to the profile name created with `xcrun notarytool store-credentials`. Keep credentials in Keychain.

1. Set the marketing version and build number in `Config/Shared.xcconfig`. Add notes at `docs/releases/<version>.md`. Review the README installation status, the history to be published and the private contact in `SECURITY.md`.
2. Once the intended release commit passes CI and has been reviewed, create and push its version tag (for example `v0.1.0`).
3. From a checkout containing the release scripts, run `./scripts/draft-release.sh v0.1.0`. It clones the upstream tag, confirms the tag matches the app version, runs unit tests, builds and signs the universal app, submits it to Apple, staples the ticket, repackages, then checks the signature, ticket and Gatekeeper assessment. GitHub receives the ZIP, checksum and notes in a draft. A signing or verification failure stops the upload.
4. Download the draft assets and verify the checksum and smoke tests. When ready to launch, confirm the repository visibility and publish the draft. Update the installation section to link to [the latest release](https://github.com/donkizzy/clipboard/releases/latest) and verify that link while signed out.

If verification fails, keep the draft unpublished and fix the cause. If a published build needs withdrawal, remove the affected asset from distribution, explain the affected version in the release notes, and issue a new version with a new checksum. Preserve the user's history when replacing the app.
