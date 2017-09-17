//
//  DomainsViewController.swift
//  Hola
//
//  Created by Randall Wood on 9/17/17.
//  Copyright © 2017 Alexandria Software. All rights reserved.
//

import UIKit

class DomainsViewController: UITableViewController, NetServiceBrowserDelegate, NetServiceDelegate {

    var servicesViewController: DomainViewController? = nil
    var domainsBrowser: NetServiceBrowser!
    var searching = false
    var domains = [String]()

    override func viewDidLoad() {
        super.viewDidLoad()
        domainsBrowser = NetServiceBrowser()
        domainsBrowser.delegate = self

        navigationItem.leftBarButtonItem = editButtonItem

        if let split = splitViewController {
            let controllers = split.viewControllers
            servicesViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DomainViewController
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
        domainsBrowser.searchForBrowsableDomains()
        super.viewWillAppear(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        domainsBrowser.stop()
        super.viewDidDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        domains.removeAll()
    }

    // MARK: - Segues

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            if let indexPath = tableView.indexPathForSelectedRow {
                let domain = domains[indexPath.row]
                let controller = (segue.destination as! UINavigationController).topViewController as! DomainViewController
                controller.domain = domain
                controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
                controller.navigationItem.leftItemsSupplementBackButton = true
            }
        }
    }

    @IBAction func refresh(_ sender: UIBarButtonItem) {
        domainsBrowser.stop()
        domains.removeAll()
        domainsBrowser.searchForBrowsableDomains()
    }

    // MARK: - Table View

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return domains.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        let domain = domains[indexPath.row]
        cell.textLabel!.text = domain
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    // MARK: - NetServices Browser

    func netServiceBrowser(_ browser: NetServiceBrowser, didFindDomain domainString: String, moreComing: Bool) {
        if !domains.contains(domainString) {
            domains.append(domainString)
        }
        if !moreComing {
            tableView.reloadData()
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemoveDomain domainString: String, moreComing: Bool) {
        if domains.contains(domainString) {
            domains.remove(at: domains.index(of: domainString)!)
        }
        if !moreComing {
            tableView.reloadData()
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        print("Did not search for domains...")
    }

    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        print("Searching for domains...")
    }
}

