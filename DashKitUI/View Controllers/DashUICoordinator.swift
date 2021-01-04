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

class DashUICoordinator: UINavigationController, PumpManagerSetupViewController, CompletionNotifying, SettingsProvider, UINavigationControllerDelegate {
    
    var setupDelegate: PumpManagerSetupViewControllerDelegate?
    var completionDelegate: CompletionDelegate?
    
    var pumpManager: DashPumpManager?
    
    public var maxBasalRateUnitsPerHour: Double?

    public var maxBolusUnits: Double?

    public var basalSchedule: BasalRateSchedule?

    private var disposables = Set<AnyCancellable>()
    
    private var registrationManager: PDMRegistrator
    
    var currentScreen: DashUIScreen {
        return screenStack.last!
    }
    
    var screenStack = [DashUIScreen]()
    
    private let insulinTintColor: Color
    
    private let guidanceColors: GuidanceColors
    
    public var pumpManagerType: DashPumpManager.Type?
    
    private func viewControllerForScreen(_ screen: DashUIScreen) -> UIViewController {
        switch screen {
        case .deactivate:
            guard let pumpManager = pumpManager else {
                fatalError("Need pump manager for pod deactivate screen")
            }
            let viewModel = DeactivatePodViewModel(podDeactivator: pumpManager)

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
            guard let pumpManager = pumpManager else {
                fatalError("Cannot create settings without PumpManager")
            }
            let viewModel = DashSettingsViewModel(pumpManager: pumpManager)
            viewModel.didFinish = { [weak self] in
                self?.stepFinished()
            }
            let view = DashSettingsView(viewModel: viewModel, navigator: self)
            return hostingController(rootView: view)
        case .registration:
            let viewModel = RegistrationViewModel(registrationManager: registrationManager)
            viewModel.completion = { [weak self] in
                self?.stepFinished()
            }
            let view = hostingController(rootView: RegisterView(viewModel: viewModel))
            view.navigationItem.title = LocalizedString("Register Device", comment: "Title for register device screen")
            return view
        case .pairPod:
            if pumpManager == nil,
                let basalRateSchedule = basalSchedule,
                let pumpManagerType = pumpManagerType,
                let maxBasalRateUnitsPerHour = maxBasalRateUnitsPerHour,
                let pumpManagerState = DashPumpManagerState(basalRateSchedule: basalRateSchedule, maximumTempBasalRate: maxBasalRateUnitsPerHour)
            {
                let pumpManager = pumpManagerType.init(state: pumpManagerState)
                self.pumpManager = pumpManager
                setupDelegate?.pumpManagerSetupViewController(self, didSetUpPumpManager: pumpManager)
            }
            
            guard let pumpManager = pumpManager else {
                fatalError("Missing pumpManager or settings for pairing new pod")
            }

            let viewModel = PairPodViewModel(podPairer: pumpManager, navigator: self)

            viewModel.didFinish = { [weak self] in
                self?.stepFinished()
            }
            viewModel.didCancel = { [weak self] in
                self?.setupCanceled()
            }
            let view = hostingController(rootView: PairPodView(viewModel: viewModel))
            view.navigationItem.title = LocalizedString("Pod Pairing", comment: "Title for pod pairing screen")
            return view
        case .insertCannula:
            guard let pumpManager = pumpManager else {
                fatalError("Need pump manager for cannula insertion screen")
            }
            let viewModel = InsertCannulaViewModel(cannulaInserter: pumpManager, navigator: self)
            
            viewModel.didFinish = { [weak self] in
                self?.stepFinished()
            }
            viewModel.didCancel = { [weak self] in
                self?.setupCanceled()
            }

            let view = hostingController(rootView: InsertCannulaView(viewModel: viewModel))
            view.navigationItem.title = LocalizedString("Insert Cannula", comment: "Title for insert cannula screen")
            return view
        case .checkInsertedCannula:
            var view = CheckInsertedCannulaView()
            view.wasInsertedProperly = { [weak self] (ok) in
                if ok {
                    self?.stepFinished()
                } else {
                    self?.navigateTo(.deactivate)
                }
            }
            let hostedView = hostingController(rootView: view)
            hostedView.navigationItem.title = LocalizedString("Check Cannula", comment: "Title for check cannula screen")
            return hostedView
        case .setupComplete:
            if let pumpManager = pumpManager {
                let vc = PodSetupCompleteViewController.instantiateFromStoryboard(pumpManager, navigator: self)
                vc.completion = { [weak self] in
                    self?.stepFinished()
                }
                return vc
            } else {
                fatalError("Need pump manager for cannula insertion screen")
            }
        case .pendingCommandRecovery:
            if let pumpManager = pumpManager, let pendingCommand = pumpManager.state.pendingCommand {

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
                fatalError("Need pump manager for cannula insertion screen")
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
        return DismissibleHostingController(rootView: rootView, guidanceColors: guidanceColors, insulinTintColor: insulinTintColor)
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
    
    init(pumpManager: DashPumpManager? = nil, insulinTintColor: Color, guidanceColors: GuidanceColors) {
        #if targetEnvironment(simulator)
        self.registrationManager = MockRegistrationManager(isRegistered: true)
        #else
        self.registrationManager = RegistrationManager.shared
        #endif
                
        self.pumpManager = pumpManager
        self.insulinTintColor = insulinTintColor
        self.guidanceColors = guidanceColors
        
        super.init(navigationBarClass: UINavigationBar.self, toolbarClass: UIToolbar.self)
                
    }
    
    private func determineInitialStep() -> DashUIScreen {
        if !registrationManager.isRegistered() {
            return .registration
        } else if let pumpManager = pumpManager {
            if pumpManager.state.pendingCommand != nil {
                return .pendingCommandRecovery
            } else if pumpManager.podCommState == .activating {
                return .insertCannula
            } else {
                return .settings
            }
        } else {
            return .pairPod
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        screenStack = [determineInitialStep()]
        let viewController = viewControllerForScreen(currentScreen)
        setViewControllers([viewController], animated: false)
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
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as! String
}

extension DashUICoordinator: DashUINavigator {
    func navigateTo(_ screen: DashUIScreen) {
        screenStack.append(screen)
        let viewController = viewControllerForScreen(screen)
        self.pushViewController(viewController, animated: true)
    }
}
