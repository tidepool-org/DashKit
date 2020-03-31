//
//  InsertCannulaViewModelTests.swift
//  DashKitUITests
//
//  Created by Pete Schwamb on 3/31/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import XCTest
import DashKit
import PodSDK
@testable import DashKitUI

class InsertCannulaViewModelTests: XCTestCase {
    
    var insertCannulaExpectation: XCTestExpectation?
    
    var lastNavigation: DashUIScreen?    
    var didNavigateExpectation: XCTestExpectation?
    
    var insertionError: PodCommError?


    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testContinueShouldStartCannulaInsertion() {
        let viewModel = InsertCannulaViewModel(cannulaInserter: self, navigator: self)
        
        insertCannulaExpectation = expectation(description: "Cannula Insertion")
        
        viewModel.continueButtonTapped()
        
        waitForExpectations(timeout: 0.3, handler: nil)
    }
    
    func testContinueAfterUnrecoverableErrorShouldNavigateToDeactivate() {
        let viewModel = InsertCannulaViewModel(cannulaInserter: self, navigator: self)

        insertionError = .podIsInAlarm(MockPodAlarm())

        insertCannulaExpectation = expectation(description: "Cannula Insertion")
        viewModel.continueButtonTapped()

        waitForExpectations(timeout: 0.3, handler: nil)

        didNavigateExpectation = expectation(description: "Navigate to deactivate")
        viewModel.continueButtonTapped()

        waitForExpectations(timeout: 0.3, handler: nil)
        XCTAssertEqual(.deactivate, lastNavigation)
    }

    func testContinueAfterRecoverableErrorShouldRetry() {
        let viewModel = InsertCannulaViewModel(cannulaInserter: self, navigator: self)

        insertionError = .bleCommunicationError
        
        insertCannulaExpectation = expectation(description: "Cannula Insertion")
        viewModel.continueButtonTapped()
        
        waitForExpectations(timeout: 0.3, handler: nil)
        
        insertCannulaExpectation = expectation(description: "Cannula Insertion Retry")
        viewModel.continueButtonTapped()
        
        waitForExpectations(timeout: 0.3, handler: nil)
        XCTAssertNil(lastNavigation)
    }
    
    func testContinueAfterSuccessfulInsertionShouldCallDidFinish() {
        let viewModel = InsertCannulaViewModel(cannulaInserter: self, navigator: self)

        insertCannulaExpectation = expectation(description: "Cannula Insertion")
        viewModel.continueButtonTapped()
        
        waitForExpectations(timeout: 0.3, handler: nil)

        let didFinishExpectation = expectation(description: "Cannula Insertion did finish")
        
        viewModel.didFinish = {
            didFinishExpectation.fulfill()
        }
        
        viewModel.continueButtonTapped()
        
        waitForExpectations(timeout: 0.3, handler: nil)
    }

}

extension InsertCannulaViewModelTests: DashUINavigator {
    func navigateTo(_ screen: DashUIScreen) {
        lastNavigation = screen
        didNavigateExpectation?.fulfill()
    }
}

extension InsertCannulaViewModelTests: CannulaInserter {
    func insertCannula(eventListener: @escaping (ActivationStatus<ActivationStep2Event>) -> ()) {
        if let insertionError = insertionError {
            eventListener(.error(insertionError))
        } else {
            eventListener(.event(.insertingCannula))
            eventListener(.event(.step2Completed))
        }
        insertCannulaExpectation?.fulfill()
    }
}
