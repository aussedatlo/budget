# Budget

A small iOS app (SwiftUI and SwiftData, iOS 17+) for tracking:

- **Expenses**: a view per month with a budget progress bar, a breakdown by category, fixed monthly charges (rent, subscriptions…) and one-off expenses.
- **Investments**: positions with buy/sell trades (quantity, unit price, fees, amount used) and price **snapshots**. You get the current value, net invested amount, gain/performance, average buy price and a chart of value vs. invested over time, both per position and for the whole portfolio. Use the camera button to snapshot the prices of every position at once.

All data stays on the device.

## Project layout

```
project.yml                 XcodeGen spec (the .xcodeproj is generated, not committed)
Budget/App                  App entry, tabs, settings
Budget/Models               SwiftData models + calculations
Budget/Expenses             Monthly expenses UI
Budget/Investments          Investments UI
.github/workflows/ios.yml   CI: build, sign, export .ipa
```

Local development on a Mac:

```sh
brew install xcodegen
xcodegen generate
open Budget.xcodeproj
```

## Installing with a free Apple ID (SideStore)

Every CI run builds an **unsigned** `Budget-unsigned.ipa`, which needs no secrets. You can download it from the workflow run's artifacts. Pushing a `v*` tag also attaches it to the GitHub release, which gives a stable link you can open from the phone.

1. Set up [SideStore](https://sidestore.io) once, following its guide (this part needs a computer).
2. On the iPhone, turn on Settings → Privacy & Security → **Developer Mode**.
3. Download `Budget-unsigned.ipa` on the phone, then in SideStore go to **My Apps → +** and pick the file. SideStore signs it with your Apple ID.
4. Free-account signatures last **7 days**. SideStore refreshes the app on the phone (open SideStore, or let its background refresh run). Your data is kept across refreshes and updates.

Free-account limits: 3 sideloaded apps at once, 10 App IDs per week.

## Signing in GitHub Actions (paid account)

You need a paid Apple Developer account. The workflow reads the team ID, bundle ID and export method (App Store / Ad Hoc / Development / Enterprise) **from the provisioning profile**, so you only provide a certificate and a profile.

1. In the Apple Developer portal:
   - Create an App ID, e.g. `com.yourname.budget`.
   - Create a certificate: **Apple Distribution** for App Store/TestFlight/Ad Hoc, or **Apple Development** for development builds.
   - Create a provisioning profile for that App ID and certificate. For Ad Hoc and Development profiles, include your iPhone's UDID.
2. Export the certificate and its private key from Keychain Access as a `.p12` file with a password.
3. Add these **repository secrets** (Settings → Secrets and variables → Actions):

   | Secret | Value |
   | --- | --- |
   | `BUILD_CERTIFICATE_BASE64` | `base64 -i cert.p12 \| pbcopy` (Linux: `base64 -w0 cert.p12`) |
   | `P12_PASSWORD` | password of the `.p12` |
   | `BUILD_PROVISION_PROFILE_BASE64` | `base64 -i Budget.mobileprovision` (Linux: `base64 -w0 …`) |

   Optional:
   - Repository **variable** `BUNDLE_ID`: only needed with a wildcard profile.
   - `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY` (contents of the `.p8`): an App Store Connect API key. With it, `v*` tags on an App Store profile upload to TestFlight automatically.

4. Push. Each run on `main` produces a signed `Budget-<n>.ipa` workflow artifact, and pushing a tag such as `v1.0.0` also attaches the `.ipa` to a GitHub release. The build number is the workflow run number.

If the secrets are missing, the signing steps are skipped and you only get the unsigned IPA.

### Installing the IPA

- **Ad Hoc / Development profile**: install the `.ipa` on a registered device with Apple Configurator, Xcode (Devices window), or a tool like `ideviceinstaller`.
- **App Store profile**: distribute via TestFlight (see the optional ASC secrets above).
