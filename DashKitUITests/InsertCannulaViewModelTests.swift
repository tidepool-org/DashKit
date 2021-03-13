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
    
    var insertionError: PodCommError?


    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testContinueShouldStartCannulaInsertion() {
        let viewModel = InsertCannulaViewModel(cannulaInserter: self)
        viewModel.didFinish = {
            XCTFail("Unexpected finish")
        }
        viewModel.didRequestDeactivation = {
            XCTFail("Unexpected request for deactivation")
        }

        insertCannulaExpectation = expectation(description: "Cannula Insertion")
        
        viewModel.continueButtonTapped()
        
        waitForExpectations(timeout: 0.3, handler: nil)
    }
    
    func testContinueAfterUnrecoverableErrorShouldRequestDeactivation() {
        let viewModel = InsertCannulaViewModel(cannulaInserter: self)
        viewModel.didFinish = {
            XCTFail("Unexpected finish")
        }
        viewModel.didRequestDeactivation = {
            XCTFail("Unexpected request for deactivation")
        }

        insertionError = .podIsInAlarm(MockPodAlarm())

        insertCannulaExpectation = expectation(description: "Cannula Insertion")
        viewModel.continueButtonTapped()

        let didRequestDeactivationExpectation = expectation(description: "Request Deactivation")
        viewModel.didRequestDeactivation = {
            didRequestDeactivationExpectation.fulfill()
        }

        viewModel.continueButtonTapped()

        waitForExpectations(timeout: 0.3, handler: nil)
    }

    func testContinueAfterRecoverableErrorShouldRetry() {
        let viewModel = InsertCannulaViewModel(cannulaInserter: self)
        viewModel.didFinish = {
            XCTFail("Unexpected finish")
        }
        viewModel.didRequestDeactivation = {
            XCTFail("Unexpected request for deactivation")
        }

        insertionError = .bleCommunicationError
        
        insertCannulaExpectation = expectation(description: "Cannula Insertion")
        viewModel.continueButtonTapped()
        
        waitForExpectations(timeout: 0.3, handler: nil)
        
        insertCannulaExpectation = expectation(description: "Cannula Insertion Retry")
        viewModel.continueButtonTapped()
        
        waitForExpectations(timeout: 0.3, handler: nil)
    }
    
    func testContinueAfterSuccessfulInsertionShouldCallDidFinish() {
        let viewModel = InsertCannulaViewModel(cannulaInserter: self)
        viewModel.didFinish = {
            XCTFail("Unexpected finish")
        }
        viewModel.didRequestDeactivation = {
            XCTFail("Unexpected request for deactivation")
        }

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
