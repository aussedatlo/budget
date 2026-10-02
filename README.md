# Budget

A small iOS app (SwiftUI and SwiftData, iOS 17+) for tracking:

- **Income**: your main income, plus **other income** you only get some months (freelance work, a bonus…), each with a switch to count it or not. **Money lent** is followed like the home loan: log each repayment as it comes in to see what's repaid and what's left. An optional monthly repayment counts as income until everything is paid back, and money still owed is part of your net worth.
- **Month**: your monthly income (from the Income tab) minus recurring charges (rent, subscriptions, insurance…) shows how much is left each month, drawn as a jar that fills up. A bar splits the income into charges, savings and what's left, with amounts and percentages.
- **Savings plan**: set how much goes to each investment every month (for example 200 € to a savings account, 300 € to gold). The Month screen sets it aside, so the jar shows what's really left to spend, and new snapshots add it to "invested so far" automatically. A **Saved per month** chart shows what you actually saved each month, per position, from the changes in "invested so far". Market moves don't count.
- **Investments**: investments (ETFs, gold coins, crypto, savings…) followed through **snapshots**. Each snapshot records what a position is worth and how much was put in so far, with quantity × unit price as an option. A new snapshot starts as a copy of the latest one, so you only change what moved, and the camera button updates everything at once. The **home loan** is followed the same way, through what's left to repay and the home's value. The app shows what's already repaid, your home equity, and your net worth (investments + home equity). A toggle at the top switches between investments only (the default) and net worth.

The design is calm: neutral cards, one dusty-rose accent, an [OpenMoji](https://openmoji.org) icon for each item, numbers that roll when they change, and a small confetti burst when net worth reaches a new high. All data stays on the device.

## Project layout

```
project.yml                 XcodeGen spec (the .xcodeproj is generated, not committed)
Budget/App                  App entry, tabs, settings, demo data
Budget/Models               SwiftData models + calculations
Budget/Income               Income, other income and money lent
Budget/Monthly              Income vs. recurring charges
Budget/Investments          Investments UI
BudgetUITests               E2E tests (screenshots on PRs)
.github/workflows/ios.yml   CI: build, sign, export .ipa
```

Local development on a Mac:

```sh
brew install xcodegen
xcodegen generate
open Budget.xcodeproj
```

## E2E tests and screenshots (pull requests)

Every pull request runs the UI tests in `BudgetUITests/` on an iPad simulator. The tests launch the app with `-demo-data`, which loads sample data into memory and never touches real data. They walk through the main screens and take a screenshot of each.

CI pushes the screenshots to the `ci-screenshots` branch and posts them in a PR comment, which is updated on every run. They are also available as workflow artifacts. Pushes to `main` and tags don't run these tests.

To add a screen, call `snapshot("NN-name")` in a test. The number sets the order.

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

## Credits

Icons are [OpenMoji](https://openmoji.org), the open-source emoji and icon project, licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). They're stored as SVGs in `Budget/Assets.xcassets/OpenMoji`, named by code point (for example `1F3E0` for 🏠). To add one, download it from `https://raw.githubusercontent.com/hfg-gmuend/openmoji/master/color/svg/<CODE>.svg` into a new imageset with the same structure.
