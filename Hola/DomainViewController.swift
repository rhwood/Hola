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
    var httpBrowsers = [String: NetServiceBrowser]()
    var httpsBrowsers = [String: NetServiceBrowser]()
    var httpSearching = 0
    var httpsSearching = 0
    var pendingServices = [NetService]()
    var services = [String: [URL: NetService]]()
    var domains = [String]()
    var urls = [String: [URL]]()
    let HTTP = "_http._tcp."
    // search for HTTPS even though not recommended
    // see https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xhtml?search=https
    // and scroll to Tim Berners Lee's comments on the HTTPS entry without associated port
    let HTTPS = "_https._tcp."
    let DEFAULT_DOMAIN = "" // use default instead of "local."
    let LOCAL_DOMAIN = "local." // the local domain, handled as "" in app

    // MARK: - View

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
            httpBrowser.value.stop()
        }
        for httpsBrowser in httpsBrowsers {
            httpsBrowser.value.stop()
        }
        super.viewDidDisappear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        services.removeAll()
    }

    @IBAction func refresh() {
        self.refreshControl?.beginRefreshing()
        for domain in domains {
            self.netServiceBrowser(domainBrowser, didRemoveDomain: domain, moreComing: true)
        }
        domainBrowser = nil
        domainBrowser = NetServiceBrowser()
        domainBrowser.delegate = self
        domainBrowser.searchForBrowsableDomains()
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500), execute: {
            self.endRefreshing()
        })
    }

    func endRefreshing() {
        self.refreshControl?.endRefreshing()
        self.tableView.reloadData()
    }

    func setTitle() {
        title = domains.count != 1 ? NSLocalizedString("VIEW_TITLE", comment: "title if showing multiple or zero domains") : self.getTitle(domains[0])
    }

    // MARK: - Segues

    @IBAction func myUnwindAction(unwindSegue: UIStoryboardSegue) {
        self.refresh()
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
            if let domainServices = services[domain] {
                return domainServices.count >= 0 ? domainServices.count : 0
            }
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
            cell.textLabel!.text = NSLocalizedString("NO_SERVICES_CELL_TITLE", comment: "Cell title with no services")
            cell.detailTextLabel!.text = NSLocalizedString("NO_SERVICES_CELL_DETAIL", comment: "Cell details with no services")
            cell.accessoryType = UITableViewCellAccessoryType.detailButton
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        if domains.count > 0 {
            // open sheet with details that allows site to be opened?
        } else {
            let network = getSSID()
            let message = NSString.localizedStringWithFormat(
                NSLocalizedString("NO_SERVICES_ALERT_MESSAGE", comment:"No services found alert message - replacement is network name") as NSString
                , network ?? "this network") as String
            let alert = UIAlertController(title: NSLocalizedString("NO_SERVICES_ALERT_TITLE", comment: "No services found alert title"), message: message, preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("NO_SERVICES_ALERT_OK_ACTION", comment: "No services found alert OK action"), style: UIAlertActionStyle.default, handler: nil))
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
            let url = urls[domains[indexPath.section]]![indexPath.row]
            let controller = SFSafariViewController.init(url: url)
            if #available(iOS 10.0, *) {
                controller.preferredControlTintColor = self.view.tintColor
            }
            present(controller, animated: true)
        }
    }

    // MARK: - NetServices Browser

    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        if httpBrowsers.values.contains(browser) {
            print("\(Date().debugDescription) Searching for HTTP services...")
            httpSearching += 1
        }
        if httpsBrowsers.values.contains(browser) {
            print("\(Date().debugDescription) Searching for HTTPS services...")
            httpsSearching += 1
        }
    }

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        if httpBrowsers.values.contains(browser) {
            print("\(Date().debugDescription) Stopped searching for HTTP services.")
            httpSearching -= 1
            if !(httpsSearching > 0) {
                self.endRefreshing()
            }
        }
        if httpsBrowsers.values.contains(browser) {
            print("\(Date().debugDescription) Stopped searching for HTTPS services.")
            httpsSearching -= 1
            if !(httpSearching > 0) {
                self.endRefreshing()
            }
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        if httpBrowsers.values.contains(browser) {
            print("\(Date().debugDescription) Something went wrong searching for HTTP services...")
            print(errorDict.description)
            httpSearching -= 1
            if !(httpsSearching > 0) {
                self.endRefreshing()
            }
        }
        if httpsBrowsers.values.contains(browser) {
            print("\(Date().debugDescription) Something went wrong searching for HTTPS services...")
            print(errorDict.description)
            httpsSearching -= 1
            if !(httpSearching > 0) {
                self.endRefreshing()
            }
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        print("\(Date().debugDescription) Found NetService \"\(service.name)\" in \"\(service.domain)\"...")
        service.delegate = self
        if service.port == -1 {
            pendingServices.append(service)
            service.resolve(withTimeout: 10)
        } else {
            self.netServiceDidResolveAddress(service)
        }
        if !moreComing {
            self.endRefreshing()
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        print("\(Date().debugDescription) Removing NetService \"\(service.name)\" from \"\(service.domain)\"...")
        if let key = url(service) {
            services[service.domain]?.removeValue(forKey: key)
            urls[service.domain]?.remove(at: (urls[service.domain]?.index(of: key)!)!)
            if (service.domain != LOCAL_DOMAIN) && (services[service.domain] != nil) && ((services[service.domain]?.count)! < 1) {
                domains.remove(at: domains.index(of: service.domain)!)
                setTitle()
            }
        } else {
            print("\(Date().debugDescription) Unknown NetService \"\(service.name)\" on host \"\(service.hostName ?? "no hostname")\" from \"\(service.domain)\"...")
            // reset and start over
            services.removeAll()
            urls.removeAll()
            self.refresh()
        }
        if !moreComing {
            self.endRefreshing()
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFindDomain domainString: String, moreComing: Bool) {
        print("\(Date().debugDescription) Adding domain \"\(domainString)\"...")
        if !domains.contains(domainString) {
            services[domainString] = [URL: NetService]()
            urls[domainString] = [URL]()
        }
        if !httpBrowsers.keys.contains(domainString) {
            let httpBrowser = NetServiceBrowser()
            httpBrowser.delegate = self
            httpBrowsers[domainString] = httpBrowser
            httpBrowser.searchForServices(ofType: HTTP, inDomain: domainString)
        }
        if !httpsBrowsers.keys.contains(domainString) {
            let httpsBrowser = NetServiceBrowser()
            httpsBrowser.delegate = self
            httpsBrowsers[domainString] = httpsBrowser
            httpsBrowser.searchForServices(ofType: HTTPS, inDomain: domainString)
        }
        if !moreComing {
            self.endRefreshing()
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemoveDomain domainString: String, moreComing: Bool) {
        print("\(Date().debugDescription) Removing domain \"\(domainString)\"...")
        if domains.contains(domainString) {
            domains.remove(at: domains.index(of: domainString)!)
            services.removeValue(forKey: domainString)
            urls.removeValue(forKey: domainString)
            httpBrowsers.removeValue(forKey: domainString)
            httpsBrowsers.removeValue(forKey: domainString)
            self.setTitle()
        }
        if !moreComing {
            self.endRefreshing()
        }
    }

    // MARK: - NetService

    func netServiceDidResolveAddress(_ service: NetService) {
        print("\(Date().debugDescription) Resolved NetService \"\(service.name)\" in \"\(service.domain)\"...")
        pendingServices.remove(at: pendingServices.index(of: service)!)
        if !domains.contains(service.domain) {
            domains.append(service.domain)
            domains.sort()
            setTitle()
        }
        if let key = url(service) {
            urls[service.domain]?.append(key)
            services[service.domain]?[key] = service
            self.endRefreshing()
        }
    }

    func url(_ service: NetService) -> URL? {
        var p = "http"
        if service.type == HTTPS {
            p = "https"
        }
        if let hostName = service.hostName {
            let dict = NetService.dictionary(fromTXTRecord: service.txtRecordData()!)
            let path = dict.keys.contains("path") ? String(data: dict["path"]!, encoding: .utf8) : ""
            return URL(string:"\(p)://\(hostName):\(service.port)\(path ?? "")")!
        }
        return nil
    }

    // MARK: - Utilities

    func getTitle(_ domain: String) -> String {
        if domain == LOCAL_DOMAIN {
            return NSLocalizedString("LOCAL_SERVICES", comment: "list of services in default (local) domain")
        } else {
            return String.localizedStringWithFormat(NSLocalizedString("DOMAIN_SERVICES", comment: "list of services in non-default domain - replacement is domain"), domain)
        }
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
        let unsafeInterfaceData = CNCopyCurrentNetworkInfo(interfaceName as CFString)
        if unsafeInterfaceData == nil {
            return nil
        }
        let interfaceData = unsafeInterfaceData as! Dictionary <String,AnyObject>
        return interfaceData["SSID"] as? String
    }
}

