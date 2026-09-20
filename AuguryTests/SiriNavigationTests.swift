import XCTest
@testable import Augury

final class SiriNavigationTests: XCTestCase {
    override func tearDown() {
        _ = SiriNavigation.consumePendingDestination()
        super.tearDown()
    }

    func testReadingRequestIsAvailableToAColdLaunch() {
        SiriNavigation.request(.reading)
        XCTAssertEqual(SiriNavigation.consumePendingDestination(), .reading)
        XCTAssertNil(SiriNavigation.consumePendingDestination())
    }

    func testJournalRequestIsAvailableToAColdLaunch() {
        SiriNavigation.request(.journal)
        XCTAssertEqual(SiriNavigation.consumePendingDestination(), .journal)
    }
}
