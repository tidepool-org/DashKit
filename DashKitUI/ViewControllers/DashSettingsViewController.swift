//
//  DashSettingsViewController.swift
//  DashKitUI
//
//  Created by Pete Schwamb on 4/19/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import UIKit
import DashKit
import LoopKit
import LoopKitUI

class DashSettingsViewController: UITableViewController {

    var pumpManager: DashPumpManager! {
        didSet {
            pumpManager.addPodStatusObserver(self, queue: .main)
            pumpManager.addStatusObserver(self, queue: .main)
        }
    }
    
    let insulinFormatter: QuantityFormatter = {
        let insulinFormatter = QuantityFormatter()
        insulinFormatter.numberFormatter.minimumFractionDigits = 2
        insulinFormatter.numberFormatter.maximumFractionDigits = 2
        return insulinFormatter
    }()
    
    lazy var suspendResumeTableViewCell: SuspendResumeTableViewCell = {
        let cell = SuspendResumeTableViewCell(style: .default, reuseIdentifier: nil)
        cell.basalDeliveryState = pumpManager.status.basalDeliveryState
        return cell
    }()

    static public func instantiateFromStoryboard(pumpManager: DashPumpManager) -> DashSettingsViewController {

        let storyboard = UIStoryboard(name: "DashPumpManager", bundle: Bundle(for: DashPumpManagerSetupViewController.self))
        let settings = storyboard.instantiateViewController(withIdentifier: "SettingsWithPod") as! DashSettingsViewController
        settings.pumpManager = pumpManager
        return settings
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44

        tableView.register(TextButtonTableViewCell.self, forCellReuseIdentifier: TextButtonTableViewCell.className)
        tableView.register(SettingsTableViewCell.self, forCellReuseIdentifier: SettingsTableViewCell.className)

        let button = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped(_:)))
        self.navigationItem.setRightBarButton(button, animated: false)
        
        // Trigger refresh
        pumpManager.getPodStatus { (_) in }
    }

    @objc func doneTapped(_ sender: Any) {
        done()
    }

    private func done() {
        switch navigationController {
        case let nav as SettingsNavigationViewController:
            nav.notifyComplete()
        case let nav as DashPumpManagerSetupViewController:
            nav.finishedSettingsDisplay()
        default:
            break
        }
    }


    // MARK: - Data Source

    private enum Section: Int, CaseIterable {
        case status = 0
        case reminders
        case actions
        case replacePod
    }

    private enum StatusRow: Int, CaseIterable {
        case insulin = 0
        case expiration
        case connectionStatus
        case totalDelivery
    }
    
    private enum ActionRow: Int, CaseIterable {
        case suspendResume = 0
    }

    // MARK: UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .status:
            return StatusRow.allCases.count
        case .reminders:
            return 1
        case .actions:
            return ActionRow.allCases.count
        case .replacePod:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .status:
            switch StatusRow(rawValue: indexPath.row)! {
            case .insulin:
                let cell = tableView.dequeueReusableCell(withIdentifier: "InsulinCell", for: indexPath) as! InsulinStatusTableViewCell
                if let reservoirLevel = pumpManager.reservoirLevel, let lastStatusDate = pumpManager.lastStatusDate {
                    cell.setReservoir(level: reservoirLevel, validAt: lastStatusDate)
                }
                return cell
            case .expiration:
                let cell = tableView.dequeueReusableCell(withIdentifier: "ExpirationCell", for: indexPath) as! PodExpirationTableViewCell
                if let podExpiresAt = pumpManager.podExpiresAt {
                    cell.expirationDate = podExpiresAt
                }
                return cell
            case .connectionStatus:
                let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
                cell.textLabel?.text = NSLocalizedString("Connection Status", comment: "The title text for the pod connection status cell")
                cell.detailTextLabel?.text = pumpManager.state.connectionState?.localizedDescription ?? "-"
                return cell
            case .totalDelivery:
                let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
                cell.textLabel?.text = NSLocalizedString("Total Pod Delivery", comment: "The title text for the total pod delivery status cell")
                if let delivery = pumpManager.podTotalDelivery {
                    cell.detailTextLabel?.text = insulinFormatter.string(from: delivery, for: .internationalUnit())
                } else {
                    cell.detailTextLabel?.text = "-"
                }
                return cell
            }
        case .reminders:
            let cell = tableView.dequeueReusableCell(withIdentifier: "RemindersCell", for: indexPath)
            return cell
        case .actions:
            switch ActionRow(rawValue: indexPath.row)! {
            case .suspendResume:
                return suspendResumeTableViewCell
            }
        case .replacePod:
            let cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath) as! TextButtonTableViewCell
            cell.textLabel?.text = LocalizedString("Change Pod", comment: "The title of the command to replace pod")
            cell.tintColor = .deleteColor
            cell.textLabel?.textAlignment = .center
            cell.isEnabled = true
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        switch Section(rawValue: indexPath.section)! {
        case .actions:
            return true
        default:
            return false
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .actions:
            switch ActionRow(rawValue: indexPath.row)! {
            case .suspendResume:
                suspendResumeTapped()
                tableView.deselectRow(at: indexPath, animated: true)
            }            
        case .replacePod:
            let vc = PodReplacementNavigationController.instantiatePodReplacementFlow(pumpManager)
            vc.completionDelegate = self
            self.navigationController?.present(vc, animated: true, completion: nil)
        default:
            break
        }
        
    }
        
    private func suspendResumeTapped() {
        switch suspendResumeTableViewCell.shownAction {
        case .resume:
            pumpManager.resumeDelivery { (error) in
                if let error = error {
                    DispatchQueue.main.async {
                        let title = LocalizedString("Error Resuming", comment: "The alert title for a resume error")
                        self.present(UIAlertController(with: error, title: title), animated: true)
                    }
                }
            }
        case .suspend:
            pumpManager.suspendDelivery { (error) in
                if let error = error {
                    DispatchQueue.main.async {
                        let title = LocalizedString("Error Suspending", comment: "The alert title for a suspend error")
                        self.present(UIAlertController(with: error, title: title), animated: true)
                    }
                }
            }
        }
    }
}

extension DashSettingsViewController: PumpManagerStatusObserver {
    func pumpManager(_ pumpManager: PumpManager, didUpdate status: PumpManagerStatus, oldStatus: PumpManagerStatus) {
        self.suspendResumeTableViewCell.basalDeliveryState = status.basalDeliveryState
    }
}


extension DashSettingsViewController: CompletionDelegate {
    func completionNotifyingDidComplete(_ object: CompletionNotifying) {
        if let vc = object as? UIViewController {
            vc.dismiss(animated: false, completion: nil)
        }
    }
}

extension DashSettingsViewController: PodStatusObserver {
    func didUpdatePodStatus() {
        tableView.reloadData()
    }
}
