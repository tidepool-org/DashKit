//
//  PairPodViewModelTests.swift
//  DashKitUITests
//
//  Created by Pete Schwamb on 3/30/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import XCTest
import DashKit
import PodSDK
@testable import DashKitUI

class PairPodViewModelTests: XCTestCase {
    
    var _podCommState: PodCommState = .active
    
    var pairingError: PodCommError?
    
    var lastNavigation: DashUIScreen?
    var didNavigateExpectation: XCTestExpectation?
    
    var didPairExpectation: XCTestExpectation?
    
    var discardPodExpectation: XCTestExpectation?

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        didNavigateExpectation = nil
        didPairExpectation = nil
        discardPodExpectation = nil
        lastNavigation = nil
        pairingError = nil
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testContinueShouldStartPairing() {
        let viewModel = PairPodViewModel(podPairer: self, navigator: self)
        
        didPairExpectation = expectation(description: "Pair Attempt")
        
        viewModel.continueButtonTapped()
        
        waitForExpectations(timeout: 0.3, handler: nil)
    }
    
    func testContinueAfterUnrecoverableErrorShouldNavigateToDeactivate() {
        let viewModel = PairPodViewModel(podPairer: self, navigator: self)
        
        pairingError = .podIsInAlarm(MockPodAlarm())
        
        didPairExpectation = expectation(description: "Pair Attempt")
        viewModel.continueButtonTapped()
        
        waitForExpectations(timeout: 0.3, handler: nil)
        
        didNavigateExpectation = expectation(description: "Navigate to deactivate")
        viewModel.continueButtonTapped()
        
        waitForExpectations(timeout: 0.3, handler: nil)
        XCTAssertEqual(.deactivate, lastNavigation)
    }
    
    func testContinueAfterRecoverableErrorShouldRetry() {
        let viewModel = PairPodViewModel(podPairer: self, navigator: self)
        
        pairingError = .bleCommunicationError
        
        didPairExpectation = expectation(description: "Pair Attempt")
        viewModel.continueButtonTapped()
        
        waitForExpectations(timeout: 0.3, handler: nil)
        
        didPairExpectation = expectation(description: "Pair Retry")
        viewModel.continueButtonTapped()
        
        waitForExpectations(timeout: 0.3, handler: nil)
        XCTAssertNil(lastNavigation)
    }

    func testContinueAfterSuccessfulPairShouldCallDidFinish() {
        let viewModel = PairPodViewModel(podPairer: self, navigator: self)
        
        didPairExpectation = expectation(description: "Pair Attempt")
        viewModel.continueButtonTapped()
        
        waitForExpectations(timeout: 0.3, handler: nil)

        let didFinishExpectation = expectation(description: "Pairing did finish")
        
        viewModel.didFinish = {
            didFinishExpectation.fulfill()
        }
        
        viewModel.continueButtonTapped()
        
        waitForExpectations(timeout: 0.3, handler: nil)
    }
    
    func testCancelButtonTapShouldCallDidCancel() {
        let viewModel = PairPodViewModel(podPairer: self, navigator: self)
        
        let didCancelExpectation = expectation(description: "didCancel() called")

        viewModel.didCancel = {
            didCancelExpectation.fulfill()
        }

        viewModel.cancelButtonTapped()
        
        waitForExpectations(timeout: 0.3, handler: nil)
    }
    
    func testCancelButtonTapShouldDiscardPodWhenPodStateIsActivating() {
        let viewModel = PairPodViewModel(podPairer: self, navigator: self)
        
        pairingError = .activationError(.activationPhase1NotCompleted)
        _podCommState = .activating
        
        didPairExpectation = expectation(description: "Pair Attempt")
        viewModel.continueButtonTapped()
        
        waitForExpectations(timeout: 0.3, handler: nil)

        discardPodExpectation =  expectation(description: "discard pod")

        viewModel.cancelButtonTapped()
        
        waitForExpectations(timeout: 0.3, handler: nil)
    }

}

extension PairPodViewModelTests: DashUINavigator {
    func navigateTo(_ screen: DashUIScreen) {
        lastNavigation = screen
        didNavigateExpectation?.fulfill()
    }
}

extension PairPodViewModelTests: PodPairer {
    var podCommState: PodCommState {
        return _podCommState
    }
    
    func pair(eventListener: @escaping (ActivationStatus<ActivationStep1Event>) -> ()) {
        if let pairingError = pairingError {
            eventListener(.error(pairingError))
        } else {
            eventListener(.event(.primingPod))
            eventListener(.event(.step1Completed))
        }
        didPairExpectation?.fulfill()
    }
    
    func discardPod(completion: @escaping (PodCommResult<Bool>) -> ()) {
        discardPodExpectation?.fulfill()
    }
}
