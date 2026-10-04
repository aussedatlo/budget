# Budget

A small iOS app (SwiftUI and SwiftData, iOS 17+) for tracking:

- **Budget**: your monthly income minus recurring charges (rent, subscriptions, insurance…) shows how much is left each month, drawn as a jar that fills up. A bar splits the income into charges, savings and what's left, with amounts and percentages.
- **Income**: your income lines (a salary, freelance work, a bonus…), each with a switch to count it or not in the months it doesn't come in. The main income of earlier versions becomes a "Salary" line. **Money lent** shows what's already repaid; an optional monthly repayment counts as income until everything is paid back, and money still owed is part of your net worth.
- **Wealth**: what each position (ETFs, gold coins, crypto, savings…) is worth now and how much was put in so far, with quantity × unit price as an option. The **home loan** is followed the same way, through what's left to repay and the home's value. A toggle at the top switches between investments only (the default) and net worth (investments + home equity + money lent).
- **Savings plan**: set how much goes to each investment every month (for example 200 € to a savings account, 300 € to gold). The Budget screen sets it aside, so the jar shows what's really left to spend, and it's added to "invested so far" automatically.
- **Trends**: how everything moved over time: net worth and what it's made of, investments value against money put in, what you saved each month, the monthly budget (income, charges, savings, what's left) and recurring charges per category. Tap a chart to see the value at that date and open that month's snapshot. Below the charts, the list of snapshots shows what each one saved.

### Snapshots

The first three tabs hold your **current state**: update them whenever you have time. Then, about once a month, tap the calendar button (on every tab) to take the month's **snapshot**, which saves the whole picture: income, recurring charges, savings plan, investments, home loan and money lent.

The snapshot screen is pre-filled with the current values, so it's also the place to check everything and fix what you forgot (a new price, a charge that went up): what you change there becomes the current state. There is one snapshot per month: taking it again replaces it. If you skipped a month, the app asks whether to catch up on the missing month or go for the current one. Each snapshot adds a point to the charts of the Trends tab. The calendar button shows an exclamation mark while the month's snapshot is still to take, and a checkmark once it's done.

In the snapshot screen, each item shows its last recorded value, and what you changed shows in color. Leaving with unsaved changes asks first, and so does every delete in the app. Deleting a snapshot can keep that month's investment, home loan and money lent values, or remove them too.

The design is calm: neutral cards, one dusty-rose accent, an [OpenMoji](https://openmoji.org) icon for each item, numbers that roll when they change, and a small confetti burst when net worth reaches a new high. All data stays on the device.

## Project layout

```
project.yml                 XcodeGen spec (the .xcodeproj is generated, not committed)
Budget/App                  App entry, tabs, settings, demo data
Budget/Models               SwiftData models + calculations
Budget/Income               Income, other income and money lent
Budget/Monthly              Income vs. recurring charges
Budget/Investments          Investments UI
Budget/Stats                Snapshot of everything + evolution charts
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

Every pull request runs the UI tests in `BudgetUITests/` on an iPad simulator, split over 4 jobs that run at the same time. The tests launch the app with `-demo-data`, which loads sample data into memory and never touches real data. The app is launched once: before each test it is asked to start over with new sample data (debug builds only), which is much faster than launching it again. Each test is one scenario of the Gherkin plan (Given / When / Then steps, one file per tab). Only the main screens are screenshotted, plus the screen of any failing test.

CI pushes the screenshots to the `ci-screenshots` branch and posts them in a PR comment, which is updated on every run. They are also available as workflow artifacts. Pushes to `main` and tags don't run these tests.

To add a screen, call `snapshot("NN-name")` in a test. The number sets the order.

## Installing with a free Apple ID (SideStore)

The iOS build runs only when a `v*` tag is pushed (or when started by hand from the Actions tab). It builds an **unsigned** `Budget-unsigned.ipa`, which needs no secrets. You can download it from the workflow run's artifacts, and it is also attached to the tag's GitHub release, which gives a stable link you can open from the phone.

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

4. Push a tag such as `v1.0.0`. The run produces a signed `Budget-<n>.ipa` workflow artifact and attaches the `.ipa` to the GitHub release. The build number is the workflow run number.

If the secrets are missing, the signing steps are skipped and you only get the unsigned IPA.

### Installing the IPA

- **Ad Hoc / Development profile**: install the `.ipa` on a registered device with Apple Configurator, Xcode (Devices window), or a tool like `ideviceinstaller`.
- **App Store profile**: distribute via TestFlight (see the optional ASC secrets above).

## Credits

Icons are [OpenMoji](https://openmoji.org), the open-source emoji and icon project, licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). They're stored as SVGs in `Budget/Assets.xcassets/OpenMoji`, named by code point (for example `1F3E0` for 🏠). To add one, download it from `https://raw.githubusercontent.com/hfg-gmuend/openmoji/master/color/svg/<CODE>.svg` into a new imageset with the same structure.
