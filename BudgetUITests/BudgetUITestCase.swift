import XCTest

/// Base of every UI test. Each test is one scenario of the Gherkin plan,
/// written with `given`, `when`, `then` and `and` steps so it reads like the plan.
/// The app starts with demo data (see `DemoData` in the app), stored in memory only.
///
/// Only a few tests attach a screenshot of a main screen; a failing test
/// always attaches one of the screen at the time of failure.
class BudgetUITestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        launch()
    }

    override func tearDown() {
        if let run = testRun, run.failureCount > 0, app != nil {
            // name is "-[MoneyLentTests testOpenMoneyLent]"
            let method = name.split(separator: " ").last.map { String($0.dropLast()) } ?? "test"
            screenshot("99-failure-\(method)")
        }
        super.tearDown()
    }

    // MARK: - Launching

    /// Starts the app again.
    /// - Parameters:
    ///   - demoData: false to open the real (empty) store instead of the demo data.
    ///   - missedMonths: the last months left without a snapshot in the demo data.
    ///   - currency: nil to keep the currency saved in the app.
    ///   - arguments: more launch arguments, e.g. old settings.
    func launch(demoData: Bool = true, missedMonths: Int = 0, currency: String? = "EUR",
                arguments: [String] = []) {
        app?.terminate()
        app = XCUIApplication()
        var launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if demoData { launchArguments.append("-demo-data") }
        if missedMonths > 0 { launchArguments += ["-demo-missed-months", "\(missedMonths)"] }
        // UserDefaults read by @AppStorage
        if let currency { launchArguments += ["-currencyCode", currency] }
        app.launchArguments = launchArguments + arguments
        app.launch()
    }

    // MARK: - Steps

    func given(_ description: String, _ step: () -> Void = {}) {
        XCTContext.runActivity(named: "Given \(description)") { _ in step() }
    }

    func when(_ description: String, _ step: () -> Void) {
        XCTContext.runActivity(named: "When \(description)") { _ in step() }
    }

    func then(_ description: String, _ step: () -> Void) {
        XCTContext.runActivity(named: "Then \(description)") { _ in step() }
    }

    func and(_ description: String, _ step: () -> Void) {
        XCTContext.runActivity(named: "And \(description)") { _ in step() }
    }

    // MARK: - Finding things

    func text(_ label: String) -> XCUIElement {
        app.staticTexts[label].firstMatch
    }

    func text(containing part: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", part)).firstMatch
    }

    /// Any element whose label or value contains `part`: a text, a link,
    /// a row read as one ("Value", "€450.00")…
    func anything(containing part: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", part, part)).firstMatch
    }

    /// Section headers can be shown in capitals.
    func header(_ label: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
    }

    func button(_ label: String) -> XCUIElement {
        app.buttons[label].firstMatch
    }

    func button(containing part: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", part)).firstMatch
    }

    /// A text field by its accessibility identifier.
    func field(_ identifier: String) -> XCUIElement {
        app.textFields[identifier].firstMatch
    }

    /// A text field without an identifier, by the hint shown when it's empty.
    func field(placeholder: String) -> XCUIElement {
        app.textFields.matching(NSPredicate(format: "placeholderValue == %@", placeholder)).firstMatch
    }

    func toggle(_ identifier: String) -> XCUIElement {
        app.switches[identifier].firstMatch
    }

    func screen(_ title: String) -> XCUIElement {
        app.navigationBars[title].firstMatch
    }

    /// How many texts read exactly `label`.
    func count(of label: String) -> Int {
        app.staticTexts.matching(NSPredicate(format: "label == %@", label)).count
    }

    // MARK: - Doing things

    func openTab(_ name: String) {
        // Tab bar at the bottom on iPhone, at the top on iPad (iOS 18+)
        let tabBarButton = app.tabBars.buttons[name]
        if tabBarButton.exists {
            tabBarButton.tap()
        } else {
            app.buttons[name].firstMatch.tap()
        }
    }

    func openSnapshot() {
        let snapshot = button("Snapshot")
        XCTAssertTrue(snapshot.waitForExistence(timeout: 10))
        snapshot.tap()
        XCTAssertTrue(screen("Snapshot").waitForExistence(timeout: 5), "The snapshot should open")
    }

    /// Goes back from a pushed page.
    func goBack() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(scrollUntilVisible(element), "Not found on screen: \(element)", file: file, line: line)
        element.tap()
    }

    func type(_ text: String, into field: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        tapAtTheEnd(of: field, file: file, line: line)
        field.typeText(text)
    }

    /// Replaces what's in a field with `text`.
    func replace(_ field: XCUIElement, with text: String, file: StaticString = #filePath, line: UInt = #line) {
        tapAtTheEnd(of: field, file: file, line: line)
        let current = field.value as? String ?? ""
        let placeholder = field.placeholderValue ?? ""
        let length = current == placeholder ? 0 : current.count
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: length) + text)
    }

    func clear(_ field: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        replace(field, with: "", file: file, line: line)
    }

    /// Tapping the middle of a short, right-aligned value puts the cursor
    /// before it, so tap the far end of the field. A field being edited
    /// keeps the cursor where it was, so select its value instead.
    private func tapAtTheEnd(of field: XCUIElement, file: StaticString, line: UInt) {
        XCTAssertTrue(scrollUntilVisible(field), "Not found on screen: \(field)", file: file, line: line)
        if field.value(forKey: "hasKeyboardFocus") as? Bool == true {
            field.doubleTap()
        } else {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        }
    }

    /// Flips a switch. In a form the switch element is the whole row,
    /// with the control itself inside it.
    func flip(_ toggle: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(scrollUntilVisible(toggle), "Not found on screen: \(toggle)", file: file, line: line)
        let control = toggle.switches.firstMatch
        if control.exists {
            control.tap()
        } else {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        }
    }

    /// Long-presses `element` and picks `option` in its menu.
    func choose(_ option: String, inMenuOf element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(scrollUntilVisible(element), "Not found on screen: \(element)", file: file, line: line)
        element.press(forDuration: 1.2)
        pick(option, file: file, line: line)
    }

    /// Picks an option in a menu that is open.
    func pick(_ option: String, file: StaticString = #filePath, line: UInt = #line) {
        let item = app.buttons[option].firstMatch
        let menuItem = app.menuItems[option].firstMatch
        if item.waitForExistence(timeout: 3) {
            item.tap()
        } else {
            XCTAssertTrue(menuItem.waitForExistence(timeout: 2), "No menu option \(option)", file: file, line: line)
            menuItem.tap()
        }
    }

    /// Checks the question asked before something is done, then answers it.
    func answer(_ question: String, with answer: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(text(question).waitForExistence(timeout: 5), "Should ask “\(question)”", file: file, line: line)
        let choice = button(answer)
        XCTAssertTrue(choice.waitForExistence(timeout: 5), "No answer “\(answer)”", file: file, line: line)
        choice.tap()
    }

    func save() { button("Save").tap() }
    func cancel() { button("Cancel").tap() }

    // MARK: - Checking things

    func expect(_ element: XCUIElement, _ message: String = "", timeout: TimeInterval = 5,
                file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "\(message) — not found: \(element)",
                      file: file, line: line)
    }

    func expectNo(_ element: XCUIElement, _ message: String = "", timeout: TimeInterval = 5,
                  file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(waitUntilGone(element, timeout: timeout), "\(message) — still there: \(element)",
                      file: file, line: line)
    }

    /// True once `element` no longer exists, false if it's still there after `timeout`.
    @discardableResult
    func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }

    /// Whether `top` is shown above `bottom`.
    func isAbove(_ top: XCUIElement, _ bottom: XCUIElement) -> Bool {
        top.frame.minY < bottom.frame.minY
    }

    // MARK: - Scrolling

    /// Scrolls the list or form in front, with short drags, until `element` is
    /// wholly in view: below the title bar and above the keyboard.
    /// Works from the frames on screen because `isHittable` can't be trusted
    /// in a sheet: true for a row cut off at the bottom, false for a row of
    /// texts read as one.
    @discardableResult
    func scrollUntilVisible(_ element: XCUIElement, maxSwipes: Int = 25) -> Bool {
        _ = element.waitForExistence(timeout: 2)
        for _ in 0...maxSwipes {
            let area = visibleArea()
            guard element.exists, !element.frame.isEmpty else {
                drag(in: area, up: true)
                continue
            }
            let frame = element.frame
            if isInABar(frame) { return element.isHittable }
            if frame.minY < area.minY - 1 && frame.maxY < area.maxY {
                drag(in: area, up: false)
            } else if frame.maxY > area.maxY + 1 && frame.minY > area.minY {
                drag(in: area, up: true)
            } else {
                return true
            }
        }
        return false
    }

    /// Bar buttons don't scroll.
    private func isInABar(_ frame: CGRect) -> Bool {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let bars = app.navigationBars.allElementsBoundByIndex + app.tabBars.allElementsBoundByIndex
            + app.toolbars.allElementsBoundByIndex
        return bars.contains { $0.exists && $0.frame.contains(center) }
    }

    /// The part of the frontmost list or form that isn't covered.
    private func visibleArea() -> CGRect {
        let screen = app.frame
        // The frontmost list is the smallest tall one: a sheet's form is
        // narrower than the tab behind it.
        let lists = (app.collectionViews.allElementsBoundByIndex
                     + app.scrollViews.allElementsBoundByIndex
                     + app.tables.allElementsBoundByIndex)
            .map(\.frame)
            .filter { $0.width >= screen.width * 0.4 && $0.height >= screen.height * 0.3 }
        var area = (lists.min { $0.width * $0.height < $1.width * $1.height } ?? screen).intersection(screen)
        var top = area.minY
        for bar in app.navigationBars.allElementsBoundByIndex where bar.exists {
            let frame = bar.frame
            if frame.minX < area.maxX, frame.maxX > area.minX, frame.minY < area.midY, frame.maxY > top {
                top = frame.maxY
            }
        }
        var bottom = area.maxY
        let keyboard = app.keyboards.firstMatch
        if keyboard.exists { bottom = min(bottom, keyboard.frame.minY) }
        area = CGRect(x: area.minX, y: top, width: area.width, height: max(bottom - top, 1))
        return area
    }

    /// A short drag without momentum in the middle of `area`.
    private func drag(in area: CGRect, up: Bool) {
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let low = origin.withOffset(CGVector(dx: area.midX, dy: area.minY + area.height * 0.75))
        let high = origin.withOffset(CGVector(dx: area.midX, dy: area.minY + area.height * 0.3))
        if up {
            low.press(forDuration: 0.05, thenDragTo: high)
        } else {
            high.press(forDuration: 0.05, thenDragTo: low)
        }
    }

    func scrollToTop() {
        for _ in 0..<4 { app.swipeDown() }
    }

    // MARK: - Dates, as the app writes them

    /// "September 2026"
    func monthName(monthsAgo: Int) -> String {
        format(month(monthsAgo: monthsAgo), "MMMM yyyy")
    }

    /// "Sep 5, 2026": a day of a month, counted from the current month.
    func day(_ day: Int, monthsAgo: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: day - 1, to: month(monthsAgo: monthsAgo))!
        return format(date, "MMM d, yyyy")
    }

    /// "Oct 3, 2026"
    var today: String { format(Date(), "MMM d, yyyy") }

    private func month(monthsAgo: Int) -> Date {
        let calendar = Calendar.current
        let thisMonth = calendar.dateInterval(of: .month, for: Date())!.start
        return calendar.date(byAdding: .month, value: -monthsAgo, to: thisMonth)!
    }

    private func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    // MARK: - Screenshots

    /// Attaches a screenshot, shown in the PR comment. Names sort in reading order.
    func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
