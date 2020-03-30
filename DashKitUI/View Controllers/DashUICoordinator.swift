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
    case alarm
    case deactivate
    case settings
    case registration
    case settingsSetup
    case pairPod
    case insertCannula
    case setupComplete
    
    func next() -> DashUIScreen? {
        switch self {
        case .alarm:
            return .deactivate
        case .deactivate:
            return .pairPod
        case .settings:
            return nil
        case .registration:
            // if initial settings not set
            return .settingsSetup
            // else
            // return .pairPod
        case .settingsSetup:
            // if no pod paired
            return .pairPod
            // else if cannula not inserted
            // return .insertCannula
        case .pairPod:
            return .insertCannula
        case .insertCannula:
            return .setupComplete
        case .setupComplete:
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
    
    private func viewControllerForScreen(_ screen: DashUIScreen) -> UIViewController {
        switch screen {
        case .alarm:
            // TODO
            let view = PairPodView(viewModel: PairPodViewModel(podPairer: MockPodPairer(), navigator: self))
            return UIHostingController(rootView: view)
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
            return UIHostingController(rootView: view)
        case .settings:
            guard let pumpManager = pumpManager else {
                fatalError("Cannot create settings without PumpManager")
            }
            let viewModel = DashSettingsViewModel(pumpManager: pumpManager)
            let view = DashSettingsView(viewModel: viewModel, navigator: self)
            return UIHostingController(rootView: view)
        case .registration:
            let viewModel = RegistrationViewModel(registrationManager: registrationManager)
            viewModel.completion = { [weak self] in
                self?.stepFinished()
            }
            let view = RegisterView(viewModel: viewModel)
            return UIHostingController(rootView: view)
        case .settingsSetup:
            let settingsVC = PodSettingsSetupViewController.instantiateFromStoryboard()
            settingsVC.completion = { [weak self] in
                self?.stepFinished()
            }
            settingsVC.settingsProvider = self
            return settingsVC
        case .pairPod:
            #if targetEnvironment(simulator)
            let viewModel = PairPodViewModel(podPairer: MockPodPairer(), navigator: self)
            #else
            if pumpManager == nil,
                let basalRateSchedule = basalSchedule,
                let pumpManagerState = DashPumpManagerState(basalRateSchedule: basalRateSchedule)
            {
                let pumpManager = DashPumpManager(state: pumpManagerState)
                self.pumpManager = pumpManager
                setupDelegate?.pumpManagerSetupViewController(self, didSetUpPumpManager: pumpManager)
            }
            
            guard let pumpManager = pumpManager else {
                fatalError("Missing pumpManager or settings for pairing new pod")
            }
            let viewModel = PairPodViewModel(pairing: pumpManager, navigator: self)
            #endif

            viewModel.didFinish = { [weak self] in
                self?.stepFinished()
            }
            viewModel.didCancel = { [weak self] in
                self?.setupCanceled()
            }
            let view = PairPodView(viewModel: viewModel)
            return UIHostingController(rootView: view)
        case .insertCannula:
            #if targetEnvironment(simulator)
            let viewModel = InsertCannulaViewModel(cannulaInserter: MockCannulaInserter(), navigator: self)
            #else
            guard let pumpManager = pumpManager else {
                fatalError("Need pump manager for cannula insertion screen")
            }
            let viewModel = InsertCannulaViewModel(cannulaInsertion: pumpManager, navigator: self)
            #endif
            
            viewModel.didFinish = { [weak self] in
                self?.stepFinished()
            }
            viewModel.didCancel = { [weak self] in
                self?.setupCanceled()
            }

            let view = InsertCannulaView(viewModel: viewModel)
            return UIHostingController(rootView: view)
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
        }
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
    
    init(pumpManager: DashPumpManager? = nil) {
        #if targetEnvironment(simulator)
        self.registrationManager = MockRegistrationManager(isRegistered: true)
        #else
        self.registrationManager = RegistrationManager.shared
        #endif
                
        self.pumpManager = pumpManager
        
        super.init(navigationBarClass: UINavigationBar.self, toolbarClass: UIToolbar.self)
                
    }
    
    private func determineInitialStep() -> DashUIScreen {
        if let pumpManager = pumpManager, case .alarm = pumpManager.podCommState {
            return .alarm
        } else if !registrationManager.isRegistered() {
            return .registration
        } else if let pumpManager = pumpManager {
            if pumpManager.podCommState == .activating {
                return .insertCannula
            } else {
                return .settings
            }
        } else if maxBasalRateUnitsPerHour == nil || maxBolusUnits == nil || basalSchedule == nil {
            return .settingsSetup
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
}

extension DashUICoordinator: DashUINavigator {
    func navigateTo(_ screen: DashUIScreen) {
        screenStack.append(screen)
        let viewController = viewControllerForScreen(screen)
        self.pushViewController(viewController, animated: true)
    }
}
