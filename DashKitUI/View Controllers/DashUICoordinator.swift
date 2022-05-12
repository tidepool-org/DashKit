//
//  DashSetupViewController.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 2/16/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import Foundation

import UIKit
import SwiftUI
import Combine
import LoopKit
import LoopKitUI
import DashKit
import PodSDK

enum DashUIScreen {
    case podSetup
    case expirationReminderSetup
    case lowReservoirReminderSetup
    case deactivate
    case settings
    case registration
    case pairPod
    case insertCannula
    case confirmAttachment
    case checkInsertedCannula
    case setupComplete
    case pendingCommandRecovery
    case uncertaintyRecovered
    
    func next() -> DashUIScreen? {
        switch self {
        case .podSetup:
            return .expirationReminderSetup
        case .expirationReminderSetup:
            return .lowReservoirReminderSetup
        case .lowReservoirReminderSetup:
            return .pairPod
        case .deactivate:
            return .pairPod
        case .settings:
            return nil
        case .registration:
            // if no pod paired
            return .pairPod
            // else if cannula not inserted
            // return .insertCannula
        case .pairPod:
            return .confirmAttachment
        case .confirmAttachment:
            return .insertCannula
        case .insertCannula:
            return .checkInsertedCannula
        case .checkInsertedCannula:
            return .setupComplete
        case .setupComplete:
            return nil
        case .pendingCommandRecovery:
            return .deactivate
        case .uncertaintyRecovered:
            return nil
        }
    }
}

protocol DashUINavigator: AnyObject {
    func navigateTo(_ screen: DashUIScreen)
}

class DashUICoordinator: UINavigationController, PumpManagerOnboarding, CompletionNotifying, UINavigationControllerDelegate {

    public weak var pumpManagerOnboardingDelegate: PumpManagerOnboardingDelegate?

    public weak var completionDelegate: CompletionDelegate?
    
    var pumpManager: DashPumpManager
    
    private var disposables = Set<AnyCancellable>()
    
    var currentScreen: DashUIScreen {
        return screenStack.last!
    }
    
    var screenStack = [DashUIScreen]()
    
    private let colorPalette: LoopUIColorPalette

    private var pumpManagerType: DashPumpManager.Type?
    
    private var basalSchedule: BasalRateSchedule?
    
    private var allowDebugFeatures: Bool
    
    private func viewControllerForScreen(_ screen: DashUIScreen) -> UIViewController {
        switch screen {
        case .podSetup:
            let view = PodSetupView(nextAction: stepFinished,
                                    allowDebugFeatures: allowDebugFeatures,
                                    skipOnboarding: {    // NOTE: DEBUG FEATURES - DEBUG AND TEST ONLY
                                        self.pumpManager.markOnboardingCompleted()
                                        self.completionDelegate?.completionNotifyingDidComplete(self)
                                    })
            return hostingController(rootView: view)
        case .expirationReminderSetup:
            var view = ExpirationReminderSetupView(expirationReminderDefault: Int(pumpManager.defaultExpirationReminderOffset.hours))
            view.valueChanged = { value in
                self.pumpManager.defaultExpirationReminderOffset = .hours(Double(value))
            }
            view.continueButtonTapped = {
                self.stepFinished()
            }
            let hostedView = hostingController(rootView: view)
            hostedView.navigationItem.title = LocalizedString("Expiration Reminder", comment: "Title for ExpirationReminderSetupView")
            return hostedView
        case .lowReservoirReminderSetup:
            var view = LowReservoirReminderSetupView(lowReservoirReminderValue: Int(pumpManager.lowReservoirReminderValue))
            view.valueChanged = { value in
                self.pumpManager.lowReservoirReminderValue = Double(value)
            }
            view.continueButtonTapped = {
                self.pumpManager.initialConfigurationCompleted = true
                self.stepFinished()
            }
            
            let hostedView = hostingController(rootView: view)
            hostedView.navigationItem.title = LocalizedString("Low Reservoir", comment: "Title for LowReservoirReminderSetupView")
            hostedView.navigationItem.backButtonDisplayMode = .generic
            return hostedView
        case .deactivate:
            let viewModel = DeactivatePodViewModel(podDeactivator: pumpManager, podAttachedToBody: pumpManager.podAttachmentConfirmed)

            viewModel.didFinish = { [weak self] in
                self?.stepFinished()
            }
            viewModel.didCancel = { [weak self] in
                self?.setupCanceled()
            }
            let view = DeactivatePodView(viewModel: viewModel)
            let hostedView = hostingController(rootView: view)
            hostedView.navigationItem.title = LocalizedString("Deactivate Pod", comment: "Title for deactivate pod screen")
            return hostedView
        case .settings:
            let viewModel = DashSettingsViewModel(pumpManager: pumpManager)
            viewModel.didFinish = { [weak self] in
                self?.stepFinished()
            }
            let view = DashSettingsView(viewModel: viewModel, navigator: self)
            return hostingController(rootView: view)
        case .registration:
            let viewModel = RegistrationViewModel(registrationManager: pumpManager.registrationManager)
            viewModel.completion = { [weak self] in
                self?.stepFinished()
            }
            let view = hostingController(rootView: RegisterView(viewModel: viewModel))
            view.navigationItem.title = LocalizedString("Register Device", comment: "Title for register device screen")
            return view
        case .pairPod:
            pumpManagerOnboardingDelegate?.pumpManagerOnboarding(didCreatePumpManager: pumpManager)

            let viewModel = PairPodViewModel(podPairer: pumpManager, navigator: self)

            viewModel.didFinish = stepFinished
            viewModel.didCancelSetup = setupCanceled
            viewModel.didRequestDeactivation = { self.navigateTo(.deactivate) }
            
            let view = hostingController(rootView: PairPodView(viewModel: viewModel))
            view.navigationItem.title = LocalizedString("Pair Pod", comment: "Title for pod pairing screen")
            view.navigationItem.backButtonDisplayMode = .generic
            return view
        case .confirmAttachment:
            let view = AttachPodView(
                didConfirmAttachment: {
                    self.pumpManager.podAttachmentConfirmed = true
                    self.stepFinished()
                },
                didRequestDeactivation: {
                    self.navigateTo(.deactivate)
                })
            
            let vc = hostingController(rootView: view)
            vc.navigationItem.title = LocalizedString("Attach Pod", comment: "Title for Attach Pod screen")
            vc.navigationItem.hidesBackButton = true
            return vc

        case .insertCannula:
            let viewModel = InsertCannulaViewModel(cannulaInserter: pumpManager)
            
            viewModel.didFinish = stepFinished
            viewModel.didRequestDeactivation = { self.navigateTo(.deactivate) }

            let view = hostingController(rootView: InsertCannulaView(viewModel: viewModel))
            view.navigationItem.title = LocalizedString("Insert Cannula", comment: "Title for insert cannula screen")
            view.navigationItem.hidesBackButton = true
            return view
        case .checkInsertedCannula:
            let view = CheckInsertedCannulaView(
                didRequestDeactivation: {
                    self.navigateTo(.deactivate)
                },
                wasInsertedProperly: {
                    self.stepFinished()
                }
            )
            let hostedView = hostingController(rootView: view)
            hostedView.navigationItem.title = LocalizedString("Check Cannula", comment: "Title for check cannula screen")
            hostedView.navigationItem.hidesBackButton = true
            return hostedView
        case .setupComplete:
            guard let expirationReminderDate = pumpManager.scheduledExpirationReminder,
                  let podExpiresAt = pumpManager.podExpiresAt,
                  let allowedExpirationReminderDates = pumpManager.allowedExpirationReminderDates
            else {
                fatalError("Cannot show setup complete UI without expiration reminder date.")
            }
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short

            let view = SetupCompleteView(
                scheduledReminderDate: expirationReminderDate,
                dateFormatter: formatter,
                allowedDates: allowedExpirationReminderDates,
                onSaveScheduledExpirationReminder: { (newExpirationReminderDate, completion) in
                    let intervalBeforeExpiration = podExpiresAt.timeIntervalSince(newExpirationReminderDate)
                    self.pumpManager.updateExpirationReminder(intervalBeforeExpiration, completion: completion)
                },
                didFinish: {
                    if !self.pumpManager.isOnboarded {
                        self.pumpManager.markOnboardingCompleted()
                        self.pumpManagerOnboardingDelegate?.pumpManagerOnboarding(didOnboardPumpManager: self.pumpManager)
                    }
                    self.stepFinished()
                },
                didRequestDeactivation: { self.navigateTo(.deactivate) }
            )
            
            let hostedView = hostingController(rootView: view)
            hostedView.navigationItem.title = LocalizedString("Setup Complete", comment: "Title for setup complete screen")
            return hostedView
        case .pendingCommandRecovery:
            if let pendingCommand = pumpManager.state.pendingCommand {

                let model = DeliveryUncertaintyRecoveryViewModel(appName: appName, uncertaintyStartedAt: pendingCommand.commandDate)
                model.didRecover = { [weak self] in
                    self?.navigateTo(.uncertaintyRecovered)
                }
                model.onDeactivate = { [weak self] in
                    self?.navigateTo(.deactivate)
                }
                model.onDismiss = { [weak self] in
                    if let self = self {
                        self.completionDelegate?.completionNotifyingDidComplete(self)
                    }
                }
                pumpManager.addStatusObserver(model, queue: DispatchQueue.main)
                pumpManager.attemptUnacknowledgedCommandRecovery()
                
                let view = DeliveryUncertaintyRecoveryView(model: model)
                
                let hostedView = hostingController(rootView: view)
                hostedView.navigationItem.title = LocalizedString("Unable To Reach Pod", comment: "Title for pending command recovery screen")
                return hostedView
            } else {
                fatalError("Pending command recovery UI attempted without pending command")
            }
        case .uncertaintyRecovered:
            var view = UncertaintyRecoveredView(appName: appName)
            view.didFinish = { [weak self] in
                self?.stepFinished()
            }
            let hostedView = hostingController(rootView: view)
            hostedView.navigationItem.title = LocalizedString("Comms Recovered", comment: "Title for uncertainty recovered screen")
            return hostedView
        }
    }
    
    private func hostingController<Content: View>(rootView: Content) -> DismissibleHostingController {
        return DismissibleHostingController(rootView: rootView, colorPalette: colorPalette)
    }
    
    private func stepFinished() {
        if let nextStep = currentScreen.next() {
            navigateTo(nextStep)
        } else {
            completionDelegate?.completionNotifyingDidComplete(self)
        }
    }
    
    private func setupCanceled() {
        completionDelegate?.completionNotifyingDidComplete(self)
    }
    
    init(pumpManager: DashPumpManager? = nil, colorPalette: LoopUIColorPalette, pumpManagerType: DashPumpManager.Type? = nil, basalSchedule: BasalRateSchedule? = nil, allowDebugFeatures: Bool)
    {
        if pumpManager == nil {
            PodCommManager.shared.setup(withLaunchingOptions: nil)
        }
        
        if pumpManager == nil,
           let pumpManagerType = pumpManagerType,
           let basalSchedule = basalSchedule,
           let pumpManagerState = DashPumpManagerState(basalRateSchedule: basalSchedule, lastPodCommState: .noPod)
        {
            let pumpManager = pumpManagerType.init(state: pumpManagerState)
            self.pumpManager = pumpManager
        } else {
            guard let pumpManager = pumpManager else {
                fatalError("Unable to create Omnipod PumpManager")
            }
            self.pumpManager = pumpManager
        }

        self.colorPalette = colorPalette
        
        self.pumpManagerType = pumpManagerType

        self.basalSchedule = basalSchedule
        
        self.allowDebugFeatures = allowDebugFeatures
        
        super.init(navigationBarClass: UINavigationBar.self, toolbarClass: UIToolbar.self)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func determineInitialStep() -> DashUIScreen {
        if !pumpManager.registrationManager.isRegistered() {
            return .registration
        } else {
            if pumpManager.state.pendingCommand != nil {
                return .pendingCommandRecovery
            } else if pumpManager.podCommState == .activating {
                if pumpManager.podAttachmentConfirmed {
                    return .insertCannula
                } else {
                    return .confirmAttachment
                }
            } else if !pumpManager.isOnboarded {
                if !pumpManager.initialConfigurationCompleted {
                    return .podSetup
                }
                return .pairPod
            } else {
                return .settings
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if screenStack.isEmpty {
            screenStack = [determineInitialStep()]
            let viewController = viewControllerForScreen(currentScreen)
            viewController.isModalInPresentation = false
            setViewControllers([viewController], animated: false)
        }
    }
    
    var customTraitCollection: UITraitCollection {
        // Select height reduced layouts on iPhone SE and iPod Touch,
        // and select regular width layouts on larger screens, for list rendering styles
        if UIScreen.main.bounds.height <= 640 {
            return UITraitCollection(traitsFrom: [super.traitCollection, UITraitCollection(verticalSizeClass: .compact)])
        } else {
            return UITraitCollection(traitsFrom: [super.traitCollection, UITraitCollection(horizontalSizeClass: .regular)])
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationBar.prefersLargeTitles = true
        delegate = self
    }

    public func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
                
        setOverrideTraitCollection(customTraitCollection, forChild: viewController)
        
        if viewControllers.count < screenStack.count {
            // Navigation back
            let _ = screenStack.popLast()
        }
        viewController.view.backgroundColor = UIColor.secondarySystemBackground
        if let currentScreen = screenStack.last {
            setNavigationBarVisibilityFor(currentScreen)
        }
    }

    // NOTE: This method is to deal with a bug in iOS 15 described here: https://github.com/ps2/navigation_bar_hiding_ios15
    // When the bug is fixed, this method (and the calls to it) should be removed, as the SwiftUI views already describe the
    // necessary navigation bar visibility/title
    public func setNavigationBarVisibilityFor(_ screen: DashUIScreen) {
        switch screen {
        case .podSetup:
            setNavigationBarHidden(true, animated: false)
        default:
            break
        }
    }
        
    let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as! String
}

extension DashUICoordinator: DashUINavigator {
    func navigateTo(_ screen: DashUIScreen) {
        screenStack.append(screen)
        let viewController = viewControllerForScreen(screen)
        viewController.isModalInPresentation = false
        self.pushViewController(viewController, animated: true)
        viewController.view.layoutSubviews()
    }
}
