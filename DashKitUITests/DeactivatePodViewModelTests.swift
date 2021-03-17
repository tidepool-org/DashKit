//
//  DeactivatePodViewModelTests.swift
//  DashKitUITests
//
//  Created by Pete Schwamb on 4/2/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import XCTest
import DashKit
import PodSDK
@testable import DashKitUI

class DeactivatePodViewModelTests: XCTestCase {
    
    var deactivationExpectation: XCTestExpectation?
    var discardPodExpectation: XCTestExpectation?

    var lastNavigation: DashUIScreen?
    var didNavigateExpectation: XCTestExpectation?
    
    var deactivationError: PodCommError?
    var discardError: PodCommError?


    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        deactivationError = nil
    }

    func testContinueShouldAttemptDeactivation() {
        let viewModel = DeactivatePodViewModel(podDeactivator: self, podAttachedToBody: true)
        
        deactivationExpectation = expectation(description: "Deactivate Pod")

        viewModel.continueButtonTapped()
        
        waitForExpectations(timeout: 0.3, handler: nil)
    }
    
    func testContinueAfterRecoverableErrorShouldRetry() {
        let viewModel = DeactivatePodViewModel(podDeactivator: self, podAttachedToBody: true)

        deactivationError = .bleCommunicationError
        
        deactivationExpectation = expectation(description: "Deactivate Pod")
        viewModel.continueButtonTapped()
        
        waitForExpectations(timeout: 0.3, handler: nil)
        
        deactivationExpectation = expectation(description: "Deactivate Pod Retry")
        viewModel.continueButtonTapped()
        
        waitForExpectations(timeout: 0.3, handler: nil)
        XCTAssertNil(lastNavigation)
    }
    
    func testContinueAfterSuccessfulDeactivationShouldCallDidFinish() {
        let viewModel = DeactivatePodViewModel(podDeactivator: self, podAttachedToBody: true)

        deactivationExpectation = expectation(description: "Deactivate Pod")
        viewModel.continueButtonTapped()
        
        waitForExpectations(timeout: 0.3, handler: nil)

        let didFinishExpectation = expectation(description: "Pod did deactivate")
        
        viewModel.didFinish = {
            didFinishExpectation.fulfill()
        }
        
        viewModel.continueButtonTapped()
        
        waitForExpectations(timeout: 0.3, handler: nil)
    }
    
    func testTappingDiscardShouldDiscardPodAndFinish() {
        let viewModel = DeactivatePodViewModel(podDeactivator: self, podAttachedToBody: true)

        discardPodExpectation = expectation(description: "Discard Pod")
        viewModel.discardPod()
        
        waitForExpectations(timeout: 0.3, handler: nil)

        let didFinishExpectation = expectation(description: "Pod did deactivate")
        
        viewModel.didFinish = {
            didFinishExpectation.fulfill()
        }
        
        viewModel.continueButtonTapped()
        
        waitForExpectations(timeout: 0.3, handler: nil)
    }

    func testTappingDiscardAfterErrorClearsShouldDiscardPodAndFinish() {
        let viewModel = DeactivatePodViewModel(podDeactivator: self, podAttachedToBody: true)

        discardError = .bleCommunicationError

        discardPodExpectation = expectation(description: "Discard Pod")
        viewModel.discardPod()
        
        waitForExpectations(timeout: 0.3, handler: nil)

        discardPodExpectation = expectation(description: "Discard Pod Retry ")
        
        let didFinishExpectation = expectation(description: "Interface did finish")
        
        viewModel.didFinish = {
            didFinishExpectation.fulfill()
        }
        
        discardError = nil

        viewModel.discardPod()

        waitForExpectations(timeout: 0.3, handler: nil)
    }


}

extension DeactivatePodViewModelTests: DashUINavigator {
    func navigateTo(_ screen: DashUIScreen) {
        lastNavigation = screen
        didNavigateExpectation?.fulfill()
    }
}

extension DeactivatePodViewModelTests: PodDeactivater {    
    func deactivatePod(completion: @escaping (PodCommResult<PartialPodStatus>) -> ()) {
        if let deactivationError = deactivationError {
            completion(.failure(deactivationError))
        } else {
            completion(.success(MockPodStatus.normal))
        }
        deactivationExpectation?.fulfill()
    }
    
    func discardPod(completion: @escaping (PodCommResult<Bool>) -> ()) {
        if let discardError = discardError {
            completion(.failure(discardError))
        } else {
            completion(.success(true))
        }
        discardPodExpectation?.fulfill()
    }
}
