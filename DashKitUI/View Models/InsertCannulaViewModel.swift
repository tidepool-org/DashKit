//
//  InsertCannulaViewModel.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 3/10/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import DashKit
import LoopKitUI
import PodSDK

class InsertCannulaViewModel: ObservableObject, Identifiable {

    enum InsertCannulaViewModelState {
        case ready
        case startingInsertion
        case inserting(finishTime: CFTimeInterval)
        case error(PodCommError)
        case finished
        
        var actionButtonAccessibilityLabel: String {
            switch self {
            case .ready, .startingInsertion:
                return LocalizedString("Insert Cannula", comment: "Insert cannula action button accessibility label while ready to pair")
            case .inserting:
                return LocalizedString("Inserting. Please wait.", comment: "Insert cannula action button accessibility label while pairing")
            case .error(let error):
                return String(format: "%@ %@", error.errorDescription ?? "", error.recoverySuggestion ?? "")
            case .finished:
                return LocalizedString("Cannula inserted successfully. Continue.", comment: "Insert cannula action button accessibility label when cannula insertion succeeded")
            }
        }

        var instructionsColor: UIColor {
            switch self {
            case .ready, .error:
                return UIColor.label
            default:
                return UIColor.secondaryLabel
            }
        }
        
        var nextActionButtonDescription: String {
            switch self {
            case .ready:
                return LocalizedString("Insert Cannula", comment: "Cannula insertion button text while ready to insert")
            case .error(let error):
                if error.recoverable {
                    return LocalizedString("Insert Cannula", comment: "Cannula insertion button text while showing error")
                } else {
                    return LocalizedString("Discard Pod", comment: "Cannula insertion button text after unrecoverable error")
                }
            case .inserting, .startingInsertion:
                return LocalizedString("Inserting...", comment: "CCannula insertion button text while inserting")
            case .finished:
                return LocalizedString("Continue", comment: "Cannula insertion button text when inserted")
            }
        }
        
        var nextActionButtonStyle: ActionButton.ButtonType {
            switch self {
            case .error(let error):
                if !error.recoverable {
                    return .destructive
                }
            default:
                break
            }
            return .primary
        }
        
        var progressState: ProgressIndicatorState {
            switch self {
            case .ready, .error:
                return .hidden
            case .startingInsertion:
                return .indeterminantProgress
            case .inserting(let finishTime):
                return .timedProgress(finishTime: finishTime)
            case .finished:
                return .completed
            }
        }
        
        var showProgressDetail: Bool {
            switch self {
            case .ready:
                return false
            default:
                return true
            }
        }
        
        var isProcessing: Bool {
            switch self {
            case .startingInsertion, .inserting:
                return true
            default:
                return false
            }
        }
        
        var isFinished: Bool {
            if case .finished = self {
                return true
            }
            return false
        }
    }
    
    var error: PodCommError? {
        if case .error(let error) = self.state {
            return error
        }
        return nil
    }

    @Published var state: InsertCannulaViewModelState = .ready
    
    var didFinish: (() -> Void)?
    
    var didCancel: (() -> Void)?
    
    var cannulaInserter: CannulaInserter
    
    weak var navigator: DashUINavigator?

    init(cannulaInserter: CannulaInserter, navigator: DashUINavigator) {
        self.cannulaInserter = cannulaInserter
        self.navigator = navigator
    }
    
    private func handleEvent(_ event: ActivationStep2Event) {
        switch event {
        case .insertingCannula:
            let finishTime = TimeInterval(Pod.estimatedCannulaInsertionDuration)
            state = .inserting(finishTime: CACurrentMediaTime() + finishTime)
        case .step2Completed:
            state = .finished
        default:
            break
        }
    }
    
    private func insertCannula() {
        state = .startingInsertion
        
        cannulaInserter.insertCannula { (status) in
            switch status {
            case .error(let error):
                self.state = .error(error)
            case .event(let event):
                self.handleEvent(event)
            }
        }
    }
    
    public func continueButtonTapped() {
        switch state {
        case .finished:
            didFinish?()
        case .error(let error):
            if error.recoverable {
                insertCannula()
            } else {
                navigator?.navigateTo(.deactivate)
            }
        default:
            insertCannula()
        }
    }
    
    public func cancelButtonTapped() {
        didCancel?()
    }
}
