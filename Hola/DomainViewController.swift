//
//  DomainViewController.swift
//  Hola
//
//  Created by Randall Wood on 9/16/17.
//  Copyright © 2017 Alexandria Software. All rights reserved.
//

import UIKit
import SafariServices
import SystemConfiguration.CaptiveNetwork

class DomainViewController: UITableViewController, NetServiceBrowserDelegate, NetServiceDelegate {

    var httpBrowser: NetServiceBrowser!
    var httpsBrowser: NetServiceBrowser!
    var httpSearching = false
    var httpsSearching = false
    var pendingServices = [NetService]()
    var services = [URL: NetService]()
    var urls = [URL]()
    let HTTP = "_http._tcp."
    let HTTPS = "_https._tcp."
    let DOMAIN = "" // use default instead of "local"

    override func viewDidLoad() {
        super.viewDidLoad()
        httpBrowser = NetServiceBrowser()
        httpBrowser.delegate = self
        httpsBrowser = NetServiceBrowser()
        httpsBrowser.delegate = self

        // navigationItem.title = DOMAIN
        self.refreshControl?.addTarget(self, action: #selector(self.refresh(_:)), for: UIControlEvents.valueChanged)
    }

    override func viewWillAppear(_ animated: Bool) {
        httpBrowser.searchForServices(ofType: HTTP, inDomain: DOMAIN)
        httpsBrowser.searchForServices(ofType: HTTPS, inDomain: DOMAIN)
        super.viewWillAppear(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        httpBrowser.stop()
        httpsBrowser.stop()
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
                let controller = SFSafariViewController.init(url: url)
                present(controller, animated: true)
            }
        }
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        return services.count > 0
    }

    @IBAction func refresh(_ sender: UIBarButtonItem) {
        refreshControl?.beginRefreshing()
        httpBrowser.stop()
        httpsBrowser.stop()
        services.removeAll()
        urls.removeAll()
        httpBrowser.searchForServices(ofType: HTTP, inDomain: DOMAIN)
        httpsBrowser.searchForServices(ofType: HTTPS, inDomain: DOMAIN)
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500), execute: {
            self.refreshControl?.endRefreshing()
        })
    }

    // MARK: - Table View

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return services.count > 0 ? services.count : 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        if services.count > 0 {
            let service = services[urls[indexPath.row]]
            cell.textLabel!.text = service?.name
            cell.detailTextLabel!.text = urls[indexPath.row].absoluteString
            cell.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
        } else {
            cell.textLabel!.text = "No sites found"
            cell.detailTextLabel!.text = "Are expected sites running?"
            cell.accessoryType = UITableViewCellAccessoryType.detailButton
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        if services.count > 0 {
            // open sheet with details that allows site to be opened?
        } else {
            let network = getSSID()
            let message: String = """
Unable to find sites on \(network ?? "this network").

Ensure you are on the desired network and expected sites, applications, or devices are running.
"""
            let alert = UIAlertController(title: "No Sites Found", message: message, preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (services.count == 0) {
            tableView.deselectRow(at: indexPath, animated: true)
        } else {
            let url = urls[indexPath.row]
            let controller = SFSafariViewController.init(url: url)
            present(controller, animated: true)
        }
    }

    // MARK: - NetServices Browser

    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        if browser === httpBrowser {
            print("Searching for HTTP services...")
            httpSearching = true
        }
        if browser === httpsBrowser {
            print("Searching for HTTPS services...")
            httpsSearching = true
        }
    }

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        if browser === httpBrowser {
            print("Stopped searching for HTTP services.")
            httpSearching = false
            if !httpsSearching {
                refreshControl?.endRefreshing()
            }
        }
        if browser === httpsBrowser {
            print("Stopped searching for HTTPS services.")
            httpsSearching = false
            if !httpSearching {
                refreshControl?.endRefreshing()
            }
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        if browser === httpBrowser {
            print("Something went wrong searching for HTTP services...")
            print(errorDict.description)
            httpSearching = false
            if !httpsSearching {
                refreshControl?.endRefreshing()
            }
        }
        if browser === httpsBrowser {
            print("Something went wrong searching for HTTPS services...")
            print(errorDict.description)
            httpsSearching = false
            if !httpSearching {
                refreshControl?.endRefreshing()
            }
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        print("Found NetService \"\(service.name)\"...")
        if service.port == -1 {
            service.delegate = self
            pendingServices.append(service)
            service.resolve(withTimeout: 10)
        } else {
            self.netServiceDidResolveAddress(service)
        }
        if !moreComing {
            refreshControl?.endRefreshing()
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        print("Removing NetService \"\(service.name)\"...")
        if let key = url(service) {
            services.removeValue(forKey: key)
            urls.remove(at: urls.index(of: key)!)
        } else {
            // reset and start over
            services.removeAll()
            urls.removeAll()
            if !httpSearching {
                browser.searchForServices(ofType: HTTP, inDomain: DOMAIN)
            }
            if !httpsSearching {
                browser.searchForServices(ofType: HTTPS, inDomain: DOMAIN)
            }
        }
        if !moreComing {
            self.tableView.reloadData()
        }
    }

    // MARK: - NetService

    func netServiceDidResolveAddress(_ service: NetService) {
        print("Resolved NetService...")
        pendingServices.remove(at: pendingServices.index(of: service)!)
        if let key = url(service) {
            urls.append(key)
            services[key] = service
            self.tableView.reloadData()
        }
    }

    func url(_ service: NetService) -> URL? {
        var p = "http"
        if service.type == HTTPS {
            p = "https"
        }
        if let hostName = service.hostName {
            return URL(string:"\(p)://\(hostName):\(service.port)")!
        }
        return nil
    }

    func getSSID() -> String? {
        let interfaces = CNCopySupportedInterfaces()
        if interfaces == nil {
            return nil
        }
        let interfacesArray = interfaces as! [String]
        if interfacesArray.count <= 0 {
            return nil
        }
        let interfaceName = interfacesArray[0] as String
        let unsafeInterfaceData =     CNCopyCurrentNetworkInfo(interfaceName as CFString)
        if unsafeInterfaceData == nil {
            return nil
        }
        let interfaceData = unsafeInterfaceData as! Dictionary <String,AnyObject>
        return interfaceData["SSID"] as? String
    }
}

