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

    var domainBrowser: NetServiceBrowser!
    var httpBrowsers = [NetServiceBrowser]()
    var httpsBrowsers = [NetServiceBrowser]()
    var httpSearching = 0
    var httpsSearching = 0
    var pendingServices = [NetService]()
    var services = [String: [URL: NetService]]()
    var domains = [String]()
    var urls = [String: [URL]]()
    let HTTP = "_http._tcp."
    let HTTPS = "_https._tcp."
    let DOMAIN = "" // use default instead of "local."
    let LOCAL_DOMAIN = "local." // the local domain, handled as "" in app

    override func viewDidLoad() {
        super.viewDidLoad()
        domainBrowser = NetServiceBrowser()
        domainBrowser.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        domainBrowser.searchForBrowsableDomains();
        super.viewWillAppear(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        domainBrowser.stop();
        for httpBrowser in httpBrowsers {
            httpBrowser.stop()
        }
        for httpsBrowser in httpsBrowsers {
            httpsBrowser.stop()
        }
        super.viewDidDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        services.removeAll()
    }

    @IBAction func refresh(_ sender: UIBarButtonItem) {
        refreshControl?.beginRefreshing()
        domainBrowser.stop()
        for httpBrowser in httpBrowsers {
            httpBrowser.stop()
        }
        for httpsBrowser in httpsBrowsers {
            httpsBrowser.stop()
        }
        services.removeAll()
        urls.removeAll()
        domainBrowser.searchForBrowsableDomains()
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500), execute: {
            self.refreshControl?.endRefreshing()
        })
    }

    // MARK: - Table View

    override func numberOfSections(in tableView: UITableView) -> Int {
        return domains.count > 1 ? domains.count : 1
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section < domains.count ? domains[section] : ""
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if domains.count > section {
            return services[domains[section]]!.count >= 0 ? services[domains[section]]!.count : 0
        }
        return 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        if domains.count > 0,
            urls.count > 0,
            let domain = services[domains[indexPath.section]],
            domain.count > 0,
            urls[domains[indexPath.section]] != nil,
            let url = urls[domains[indexPath.section]]?[indexPath.row],
            let service = domain[url] {
            cell.textLabel!.text = service.name
            cell.detailTextLabel!.text = url.absoluteString
            cell.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
        } else {
            cell.textLabel!.text = NSLocalizedString("NO_SITES_CELL_TITLE", comment: "Cell title with no sites")
            cell.detailTextLabel!.text = NSLocalizedString("NO_SITES_CELL_DETAIL", comment: "Cell details with no sites")
            cell.accessoryType = UITableViewCellAccessoryType.detailButton
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        if services.count > 0 {
            // open sheet with details that allows site to be opened?
        } else {
            let network = getSSID()
            let message = NSString.localizedStringWithFormat(
                NSLocalizedString("NO_SITES_ALERT_MESSAGE", comment:"No sites found alert message - replacement is network name") as NSString
                , network ?? "this network") as String
            let alert = UIAlertController(title: NSLocalizedString("NO_SITES_ALERT_TITLE", comment: "No sites found alert title"), message: message, preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("NO_SITES_ALERT_OK_ACTION", comment: "No sites found alert OK action"), style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if services[domains[indexPath.section]] == nil || services[domains[indexPath.section]]?.count == 0 {
            tableView.deselectRow(at: indexPath, animated: true)
        } else {
            let url = urls[domains[indexPath.section]]![indexPath.row]
            let controller = SFSafariViewController.init(url: url)
            present(controller, animated: true)
        }
    }

    // MARK: - NetServices Browser

    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        if httpBrowsers.contains(browser) {
            print("Searching for HTTP services...")
            httpSearching += 1
        }
        if httpsBrowsers.contains(browser) {
            print("Searching for HTTPS services...")
            httpsSearching += 1
        }
    }

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        if httpBrowsers.contains(browser) {
            print("Stopped searching for HTTP services.")
            httpSearching -= 1
            if !(httpsSearching > 0) {
                refreshControl?.endRefreshing()
            }
        }
        if httpsBrowsers.contains(browser) {
            print("Stopped searching for HTTPS services.")
            httpsSearching -= 1
            if !(httpSearching > 0) {
                refreshControl?.endRefreshing()
            }
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        if httpBrowsers.contains(browser) {
            print("Something went wrong searching for HTTP services...")
            print(errorDict.description)
            httpSearching -= 1
            if !(httpsSearching > 0) {
                refreshControl?.endRefreshing()
            }
        }
        if httpsBrowsers.contains(browser) {
            print("Something went wrong searching for HTTPS services...")
            print(errorDict.description)
            httpsSearching -= 1
            if !(httpSearching > 0) {
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
            domains.append(service.domain)
            domains.sort()
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
            services[service.domain]?.removeValue(forKey: key)
            urls[service.domain]?.remove(at: (urls[service.domain]?.index(of: key)!)!)
            if (service.domain != LOCAL_DOMAIN) && (services[service.domain] != nil) && ((services[service.domain]?.count)! < 1) {
                domains.remove(at: domains.index(of: service.domain)!)
            }
        } else {
            // reset and start over
            services.removeAll()
            urls.removeAll()
            if !(httpSearching > 0) {
                browser.searchForServices(ofType: HTTP, inDomain: DOMAIN)
            }
            if !(httpsSearching > 0) {
                browser.searchForServices(ofType: HTTPS, inDomain: DOMAIN)
            }
        }
        if !moreComing {
            self.tableView.reloadData()
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFindDomain domainString: String, moreComing: Bool) {
        print("Adding domain \"\(domainString)\"...")
        if !domains.contains(domainString) {
            let httpBrowser = NetServiceBrowser()
            let httpsBrowser = NetServiceBrowser()
            httpBrowser.delegate = self
            httpsBrowser.delegate = self
            httpBrowsers.append(httpBrowser)
            httpsBrowsers.append(httpsBrowser)
            services[domainString] = [URL: NetService]()
            urls[domainString] = [URL]()
            httpBrowser.searchForServices(ofType: HTTP, inDomain: domainString)
            httpsBrowser.searchForServices(ofType: HTTPS, inDomain: domainString)
        }
        if !moreComing {
            self.tableView.reloadData()
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemoveDomain domainString: String, moreComing: Bool) {
        print("Removing domain \"\(domainString)\"...")
        if domains.contains(domainString) {
            domains.remove(at: domains.index(of: domainString)!)
            services.remove(at: services.index(forKey: domainString)!)
            urls.remove(at: urls.index(forKey: domainString)!)
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
            urls[service.domain]?.append(key)
            services[service.domain]?[key] = service
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

