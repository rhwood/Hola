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
        title = "Foo"
    }

    // MARK: - Segues

    @IBAction func myUnwindAction(unwindSegue: UIStoryboardSegue) {
        // function is target, but has nothing to do
    }

    // MARK: - Table View

    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        ""
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        return cell
    }

    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
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
    /// - Returns: the network SSID or nil (always nil if not on Catalyst 14 or newer)
    func getSSID() -> String? {
        if #available(macCatalyst 14.0, *) {
            if let interfaces = CNCopySupportedInterfaces() as? [CFString],
               interfaces.count > 0,
               let interfaceData = (CNCopyCurrentNetworkInfo(interfaces[0])) as? [String: AnyObject] {
                return interfaceData["SSID"] as? String
            }
        }
        return nil
    }
}
