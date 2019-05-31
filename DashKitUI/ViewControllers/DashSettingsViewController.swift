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
            pumpManager.addStatusObserver(self, queue: .main)
        }
    }

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

        let button = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped(_:)))
        self.navigationItem.setRightBarButton(button, animated: false)
    }

    @objc func doneTapped(_ sender: Any) {
        done()
    }

    private func done() {
        if let nav = navigationController as? SettingsNavigationViewController {
            nav.notifyComplete()
        }
        if let nav = navigationController as? DashPumpManagerSetupViewController {
            nav.finishedSettingsDisplay()
        }
    }


    // MARK: - Data Source

    private enum Section: Int, CaseIterable {
        case delivery = 0
        case reminders
        case replacePod
    }

    private enum DeliveryRow: Int, CaseIterable {
        case insulin = 0
        case expiration
    }

    // MARK: UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .delivery:
            return DeliveryRow.allCases.count
        case .reminders:
            return 1
        case .replacePod:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .delivery:
            switch DeliveryRow(rawValue: indexPath.row)! {
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
            }
        case .reminders:
            let cell = tableView.dequeueReusableCell(withIdentifier: "RemindersCell", for: indexPath)
            return cell
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
        case .replacePod:
            return true
        default:
            return false
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .replacePod:
            let vc = PodReplacementNavigationController.instantiatePodReplacementFlow(pumpManager)
            vc.completionDelegate = self
            self.navigationController?.present(vc, animated: true, completion: nil)
        default:
            break
        }
    }
}

extension DashSettingsViewController: PumpManagerStatusObserver {
    func pumpManager(_ pumpManager: PumpManager, didUpdate status: PumpManagerStatus, oldStatus: PumpManagerStatus) {
    }
}

extension DashSettingsViewController: CompletionDelegate {
    func completionNotifyingDidComplete(_ object: CompletionNotifying) {
        if let vc = object as? UIViewController {
            vc.dismiss(animated: false, completion: nil)
        }
    }
}
