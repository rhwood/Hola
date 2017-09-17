//
//  MasterViewController.swift
//  Ola
//
//  Created by Randall Wood on 9/16/17.
//  Copyright © 2017 Alexandria Software. All rights reserved.
//

import UIKit

class MasterViewController: UITableViewController, NetServiceBrowserDelegate, NetServiceDelegate {

    var detailViewController: DetailViewController? = nil
    var httpBrowser: NetServiceBrowser!
    var pendingServices = [NetService]()
    var services = [URL: NetService]()
    var urls = [URL]()
    let HTTP = "_http._tcp."
    let DOMAIN = "local"

    override func viewDidLoad() {
        super.viewDidLoad()
        httpBrowser = NetServiceBrowser()
        httpBrowser.delegate = self
        // Do any additional setup after loading the view, typically from a nib.
        navigationItem.title = DOMAIN
        navigationItem.leftBarButtonItem = editButtonItem

        if let split = splitViewController {
            let controllers = split.viewControllers
            detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
        httpBrowser.searchForServices(ofType: HTTP, inDomain: DOMAIN)
        super.viewWillAppear(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        httpBrowser.stop()
        super.viewDidDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        services.removeAll()
    }

    // MARK: - Segues

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            if let indexPath = tableView.indexPathForSelectedRow {
                let url = urls[indexPath.row]
                let service = services[url]
                let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
                controller.service = service
                controller.url = url
                controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
                controller.navigationItem.leftItemsSupplementBackButton = true
            }
        }
    }

    // MARK: - Table View

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return services.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        let service = services[urls[indexPath.row]]
        cell.textLabel!.text = service?.name
        cell.detailTextLabel!.text = urls[indexPath.row].absoluteString
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    // MARK: - NetServices Browser

    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        print("Searching...")
    }

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        print("Stopped Search")
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        print("Something went wrong...")
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        print("Found NetService...")
        if service.port == -1 {
            service.delegate = self
            pendingServices.append(service)
            service.resolve(withTimeout: 10)
        } else {
            self.netServiceDidResolveAddress(service)
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        print("Removed NetService...")
        let key = url(service)
        services.removeValue(forKey: key)
        urls.remove(at: urls.index(of: key)!)
        if !moreComing {
            self.tableView.reloadData()
        }
    }

    // MARK: - NetService

    func netServiceDidResolveAddress(_ service: NetService) {
        print("Resolved NetService...")
        pendingServices.remove(at: pendingServices.index(of: service)!)
        let key = url(service)
        urls.append(key)
        services[key] = service
        self.tableView.reloadData()
    }

    func url(_ service: NetService) -> URL {
        return URL(string:"http://\(service.hostName!):\(service.port)")!
    }
}

