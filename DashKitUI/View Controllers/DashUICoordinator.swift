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

protocol DashUINavigator: class {
    func navigateTo(_ screen: DashUIScreen)
}

class DashUICoordinator: UINavigationController, PumpManagerCreateNotifying, PumpManagerOnboardNotifying, CompletionNotifying, UINavigationControllerDelegate {
    
    public weak var pumpManagerCreateDelegate: PumpManagerCreateDelegate?

    public weak var pumpManagerOnboardDelegate: PumpManagerOnboardDelegate?

    public weak var completionDelegate: CompletionDelegate?
    
    var pumpManager: DashPumpManager
    
    private var disposables = Set<AnyCancellable>()
    
    var currentScreen: DashUIScreen {
        return screenStack.last!
    }
    
    var screenStack = [DashUIScreen]()
    
    private let colorPalette: LoopUIColorPalette

    private var pumpManagerType: DashPumpManager.Type?
    
    private var initialSettings: PumpManagerSetupSettings?
    
    private func viewControllerForScreen(_ screen: DashUIScreen) -> UIViewController {
        switch screen {
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
            pumpManagerCreateDelegate?.pumpManagerCreateNotifying(didCreatePumpManager: pumpManager)

            let viewModel = PairPodViewModel(podPairer: pumpManager, navigator: self)

            viewModel.didFinish = stepFinished
            viewModel.didCancelSetup = setupCanceled
            viewModel.didRequestDeactivation = { self.navigateTo(.deactivate) }
            
            let view = hostingController(rootView: PairPodView(viewModel: viewModel))
            view.navigationItem.title = LocalizedString("Pod Pairing", comment: "Title for pod pairing screen")
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
            return vc

        case .insertCannula:
            let viewModel = InsertCannulaViewModel(cannulaInserter: pumpManager)
            
            viewModel.didFinish = stepFinished
            viewModel.didRequestDeactivation = { self.navigateTo(.deactivate) }

            let view = hostingController(rootView: InsertCannulaView(viewModel: viewModel))
            view.navigationItem.title = LocalizedString("Insert Cannula", comment: "Title for insert cannula screen")
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
                    if let initialSettings = self.initialSettings {
                        self.pumpManagerOnboardDelegate?.pumpManagerOnboardNotifying(didOnboardPumpManager: self.pumpManager, withFinalSettings: initialSettings)
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
    
    private var isOnboarding: Bool
    
    init(pumpManager: DashPumpManager? = nil, colorPalette: LoopUIColorPalette, pumpManagerType: DashPumpManager.Type? = nil, initialSettings: PumpManagerSetupSettings? = nil)
    {
        if pumpManager == nil {
            PodCommManager.shared.setup(withLaunchingOptions: nil)
        }
        
        if pumpManager == nil,
           let initialSettings = initialSettings,
           let basalRateSchedule = initialSettings.basalSchedule,
           let maxBasalRateUnitsPerHour = initialSettings.maxBasalRateUnitsPerHour,
           let pumpManagerType = pumpManagerType,
           let pumpManagerState = DashPumpManagerState(basalRateSchedule: basalRateSchedule, maximumTempBasalRate: maxBasalRateUnitsPerHour, lastPodCommState: .noPod)
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

        self.initialSettings = initialSettings
        
        self.isOnboarding = initialSettings != nil
        
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
            } else if pumpManager.podCommState == .noPod && isOnboarding {
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
                
        // Deal with UIHostingController navigationItem.backBarButtonItem being nil at view load time
        // Seems like an iOS bug; hopefully fixed with later SwiftUI updates.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if viewController.navigationItem.backBarButtonItem == nil, let title = viewController.navigationItem.title {
                viewController.navigationItem.backBarButtonItem = UIBarButtonItem(title: title, style: .plain, target: nil, action: nil)
            }
        }

        setOverrideTraitCollection(customTraitCollection, forChild: viewController)
        
        if viewControllers.count < screenStack.count {
            // Navigation back
            let _ = screenStack.popLast()
        }
        viewController.view.backgroundColor = UIColor.secondarySystemBackground
    }
        
    let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as! String
}

extension DashUICoordinator: DashUINavigator {
    func navigateTo(_ screen: DashUIScreen) {
        screenStack.append(screen)
        let viewController = viewControllerForScreen(screen)
        viewController.isModalInPresentation = false
        self.pushViewController(viewController, animated: true)
    }
}
