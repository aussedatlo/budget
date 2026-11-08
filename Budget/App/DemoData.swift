import BudgetCore
import Foundation
import SwiftUI

/// Sample data used by the UI tests (launch argument `-demo-data`).
/// Stored in memory only: it never touches the user's real data.
enum DemoData {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-demo-data")
    }

    /// Animations are frozen on the demo data so XCTest can wait for the app
    /// to be idle, unless `-demo-animate` is passed (CI records them as GIFs).
    static var pausesAnimations: Bool {
        isEnabled && !ProcessInfo.processInfo.arguments.contains("-demo-animate")
    }

    /// Tab shown at launch on the demo data (`-demo-tab income`), to record it.
    static var startTab: String? {
        isEnabled ? UserDefaults.standard.string(forKey: "demo-tab") : nil
    }

    /// Months skipped before the current one (`-demo-missed-months 2`), to test
    /// catching up: their snapshots and the current month's are left out.
    static var missedMonths: Int {
        UserDefaults.standard.integer(forKey: "demo-missed-months")
    }

    /// Settings that tests expect at their default value. Not passed as
    /// launch arguments: those would override what the app saves during the test.
    static let resetKeys = ["includeHome", "netWorthHigh", "investmentsHigh", HiddenInvestments.key]

    /// A fresh database in memory with the sample data (the same as Android's,
    /// from the shared core).
    static func makeRepository() -> BudgetRepository {
        for key in resetKeys { UserDefaults.standard.removeObject(forKey: key) }
        HiddenInvestments.shared.reset()
        return BudgetStore.shared.openDemo(factory: DatabaseFactory(), missedMonths: Int32(missedMonths))
    }

    // MARK: - Starting over

    /// Sent between processes by the UI tests to get the demo data back as at
    /// launch, which is much faster than launching the app again for every test.
    static let resetSignal = "com.example.budget.demo-reset"
    static let resetRequested = Notification.Name("demo-reset-requested")

    /// Passes the tests' signal on inside the app. Debug builds only.
    static func listenForResets() {
        #if DEBUG
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: DemoData.resetRequested, object: nil)
                }
            },
            resetSignal as CFString, nil, .deliverImmediately)
        #endif
    }
}

extension View {
    /// With the demo data, runs `reset` when the UI tests ask to start over, and
    /// tells them how many times it did: they wait for `count` to go up.
    @ViewBuilder
    func demoResets(_ count: Int, perform reset: @escaping () -> Void) -> some View {
        #if DEBUG
        if DemoData.isEnabled {
            onReceive(NotificationCenter.default.publisher(for: DemoData.resetRequested)) { _ in reset() }
                .overlay(alignment: .topLeading) {
                    // Invisible, read by the tests
                    Text("\(count)")
                        .font(.system(size: 1))
                        .foregroundStyle(.clear)
                        .accessibilityIdentifier("demo-resets")
                        .allowsHitTesting(false)
                }
        } else {
            self
        }
        #else
        self
        #endif
    }
}
