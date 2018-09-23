//
//  DomainViewController.swift
//  Hola
//
//  Created by Randall Wood on 9/16/17.
//  Copyright © 2017 Alexandria Software. All rights reserved.
//

import os.log
import UIKit
import SafariServices
import SystemConfiguration.CaptiveNetwork

class DomainViewController: UITableViewController {

    private var domains: [String] {
        return BrowserManager.shared.domains
    }
    private var serviceKeys: [String: [String]] {
        return BrowserManager.shared.serviceKeys
    }
    private var services: [String: [String: NetService]] {
        return BrowserManager.shared.services
    }
    private var urls: [String: URL] {
        return BrowserManager.shared.urls
    }
    private var didEndSearchingObserver: Any?
    private var didRemoveServiceObserver: Any?
    private var didResolveServiceObserver: Any?
    private var didStartSearchingObserver: Any?

    // MARK: - View

    override func viewWillAppear(_ animated: Bool) {
        didStartSearchingObserver = NotificationCenter.default.addObserver(
            forName: BrowserManager.didStartSearching,
            object: BrowserManager.shared,
            queue: OperationQueue.main) { (_) in
                self.refreshControl?.beginRefreshing()
        }
        didEndSearchingObserver = NotificationCenter.default.addObserver(
            forName: BrowserManager.didEndSearching,
            object: BrowserManager.shared,
            queue: OperationQueue.main) { (_) in
                self.endRefreshing()
        }
        didRemoveServiceObserver = NotificationCenter.default.addObserver(
            forName: BrowserManager.didRemoveService,
            object: BrowserManager.shared,
            queue: OperationQueue.main) { (_) in
                self.tableView.reloadData()
        }
        didResolveServiceObserver = NotificationCenter.default.addObserver(
            forName: BrowserManager.didResolveService,
            object: BrowserManager.shared,
            queue: OperationQueue.main) { (_) in
                self.tableView.reloadData()
        }
        BrowserManager.shared.search()
        super.viewWillAppear(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(didStartSearchingObserver!)
        NotificationCenter.default.removeObserver(didEndSearchingObserver!)
        NotificationCenter.default.removeObserver(didRemoveServiceObserver!)
        NotificationCenter.default.removeObserver(didResolveServiceObserver!)
        super.viewDidDisappear(animated)
    }

    @IBAction func refresh() {
        self.refreshControl?.beginRefreshing()
        BrowserManager.shared.refresh()
    }

    func endRefreshing() {
        self.refreshControl?.endRefreshing()
        self.tableView.reloadData()
    }

    func setTitle() {
        title = domains.count != 1
            ? NSLocalizedString("VIEW_TITLE", comment: "title if showing multiple or zero domains")
            : self.getTitle(domains[0])
    }

    // MARK: - Segues

    @IBAction func myUnwindAction(unwindSegue: UIStoryboardSegue) {
        // function is target, but has nothing to do
    }

    // MARK: - Table View

    override func numberOfSections(in tableView: UITableView) -> Int {
        return domains.count > 1 ? domains.count : 1
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section < domains.count && domains.count > 1 {
            return self.getTitle(domains[section])
        }
        return ""
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if domains.count > section {
            let domain = domains[section]
            if let domainServices = BrowserManager.shared.services[domain] {
                return domainServices.count >= 0 ? domainServices.count : 0
            }
        }
        return 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        if domains.count > 0,
            urls.count > 0,
            let domainKey = domains[indexPath.section] as String?,
            let domain = services[domainKey],
            domain.count > 0,
            serviceKeys[domainKey] != nil,
            let serviceKey = serviceKeys[domainKey]?[indexPath.row],
            let url = urls[serviceKey],
            let service = domain[serviceKey] {
            cell.textLabel!.text = service.name
            cell.detailTextLabel!.text = url.absoluteString
            cell.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
        } else if BrowserManager.shared.searching > 0 {
            cell.textLabel!.text = NSLocalizedString("SEARCHING", comment: "Cell title with active searches")
            cell.detailTextLabel!.text = nil
            cell.accessoryType = UITableViewCellAccessoryType.none
        } else {
            cell.textLabel!.text = NSLocalizedString("NO_SERVICES_CELL_TITLE", comment: "Cell title with no services")
            cell.detailTextLabel!.text = NSLocalizedString("NO_SERVICES_CELL_DETAIL",
                                                           comment: "Cell details with no services")
            cell.accessoryType = UITableViewCellAccessoryType.detailButton
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        if domains.count > 0 {
            // open sheet with details that allows site to be opened?
        } else {
            let network = getSSID()
            let message = String.localizedStringWithFormat(
                NSLocalizedString("NO_SERVICES_ALERT_MESSAGE",
                                  comment: "No services found alert message - replacement is network name"),
                network ?? NSLocalizedString("THIS_NETWORK", comment: "Network name for unknown network"))
            let alert = UIAlertController(
                title: NSLocalizedString("NO_SERVICES_ALERT_TITLE", comment: "No services found alert title"),
                message: message,
                preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(
                title: NSLocalizedString("NO_SERVICES_ALERT_OK_ACTION", comment: "No services found alert OK action"),
                style: UIAlertActionStyle.default,
                handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if domains.count == 0 ||
            services[domains[indexPath.section]] == nil ||
            services[domains[indexPath.section]]?.count == 0 {
            tableView.deselectRow(at: indexPath, animated: true)
        } else {
            if let key = serviceKeys[domains[indexPath.section]]?[indexPath.row],
                let url = urls[key] {
                let controller: SFSafariViewController
                if #available(iOS 11.0, *) {
                    let configuration = SFSafariViewController.Configuration()
                    configuration.barCollapsingEnabled = true
                    controller = SFSafariViewController.init(url: url, configuration: configuration)
                } else {
                    controller = SFSafariViewController.init(url: url)
                }
                if #available(iOS 10.0, *) {
                    controller.preferredControlTintColor = self.view.tintColor
                }
                present(controller, animated: true)
            }
        }
    }

    // MARK: - Utilities

    /// Get the title for the domain view. Use a full title for the local. domain and include the
    /// named domain if not local.
    ///
    /// - Parameter domain: The name of the domain
    /// - Returns: The view title based on the domain name
    func getTitle(_ domain: String) -> String {
        if domain == Domain.Local {
            return NSLocalizedString("LOCAL_SERVICES", comment: "services in default (local) domain")
        } else {
            return String.localizedStringWithFormat(
                NSLocalizedString("DOMAIN_SERVICES", comment: "services in non-default domain"),
                domain)
        }
    }

    /// Get the network SSID, if possible
    ///
    /// - Returns: the network SSID or nil
    func getSSID() -> String? {
        if let interfaces = CNCopySupportedInterfaces() as? [CFString],
            interfaces.count > 0,
            let interfaceData = (CNCopyCurrentNetworkInfo(interfaces[0])) as? [String: AnyObject] {
            return interfaceData["SSID"] as? String
        }
        return nil
    }
}
