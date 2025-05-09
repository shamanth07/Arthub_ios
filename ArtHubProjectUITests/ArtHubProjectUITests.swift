//
//  ArtHubProjectUITests.swift
//  ArtHubProjectUITests
//
//  Created by User on 2025-05-08.
//

import XCTest

final class ArtHubProjectUITests: XCTestCase {

    override func setUpWithError() throws {
     
        continueAfterFailure = false

    }

    override func tearDownWithError() throws {
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()

    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
