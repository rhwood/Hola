//
//  DomainViewController.swift
//  Hola
//
//  Created by Randall Wood on 9/16/17.
//  Copyright © 2017 Alexandria Software. All rights reserved.
//

// TODO: Remove NSLog() calls once iOS 9.x is no longer supportable

import os.log
import UIKit
import SafariServices
import SystemConfiguration.CaptiveNetwork

class DomainViewController: UITableViewController, NetServiceBrowserDelegate, NetServiceDelegate {

    var domainBrowser: NetServiceBrowser!
    var servicesBrowsers = [String: NetServiceBrowser]()
    var typeBrowsers = [String: [String: NetServiceBrowser]]()
    var searching: Int = 0 {
        didSet {
            if #available(iOS 10.0, *) {
                os_log("%d active searches...", searching)
            } else {
                NSLog("%d active searches...", searching)
            }
            if searching < 0 {
                searching = 0
            }
            if !(searching > 0) {
                self.endRefreshing()
            }
        }
    }
    var pendingServices = [NetService]()
    var services = [String: [String: NetService]]() // [service.domain: [serviceKey(): service]]
    var domains = [String]() // [service.domain]
    var serviceKeys = [String: [String]]() // [service.domain: [serviceKey()]]
    var urls = [String: URL]() // [serviceKey(): url()]
    let SERVICES = "_services._dns-sd._udp."
    let HTTP = "_http._tcp."
    // search for HTTPS even though not recommended
    // see https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xhtml?search=https
    // and scroll to Tim Berners Lee's comments on the HTTPS entry without associated port
    let HTTPS = "_https._tcp."
    let DOMAIN_ROOT = "." // returned as domain for any types returned when searching for SERVICES
    let DEFAULT_DOMAIN = "" // use default instead of "local."
    let LOCAL_DOMAIN = "local." // the local domain, handled as "" in app

    // MARK: - View

    override func viewDidLoad() {
        super.viewDidLoad()
        domainBrowser = NetServiceBrowser()
        domainBrowser.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        searchForBrowsableDomains()
        super.viewWillAppear(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        for domain in domains {
            self.netServiceBrowser(domainBrowser, didRemoveDomain: domain, moreComing: true)
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
        searchForBrowsableDomains()
    }

    func endRefreshing() {
        self.refreshControl?.endRefreshing()
        self.tableView.reloadData()
    }

    func searchForBrowsableDomains() {
        domainBrowser.searchForBrowsableDomains()
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(2000), execute: {
            if #available(iOS 10.0, *) {
                os_log("Giving up on finding anything...")
            } else {
                NSLog("Giving up on finding anything...")
            }
            self.searching = 0
        })
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
        } else if searching > 0 {
            cell.textLabel!.text = NSLocalizedString("SEARCHING", comment: "Cell title with active searches")
            cell.detailTextLabel!.text = nil
            cell.accessoryType = UITableViewCellAccessoryType.none
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
            let message = String.localizedStringWithFormat(
                NSLocalizedString("NO_SERVICES_ALERT_MESSAGE",
                                  comment: "No services found alert message - replacement is network name"),
                network ?? "this network") // TODO: localize
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

    // MARK: - NetServices Browser

    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        if browser == domainBrowser {
            if #available(iOS 10.0, *) {
                os_log("Searching for browsable domains...")
            } else {
                NSLog("Searching for browsable domains...")
            }
            searching += 1
        }
        for domain in typeBrowsers {
            for type in domain.value where type.value == browser {
                if #available(iOS 10.0, *) {
                    os_log("Searching for \"%@\" services in \"%@\"...", type.key, domain.key)
                } else {
                    NSLog("Searching for \"%@\" services in \"%@\"...", type.key, domain.key)
                }
                searching += 1
            }
        }
    }

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        for domain in typeBrowsers {
            for type in domain.value where type.value == browser {
                if #available(iOS 10.0, *) {
                    os_log("Stopped searching for \"%@\" services in \"%@\"...", type.key, domain.key)
                } else {
                    NSLog("Stopped searching for \"%@\" services in \"%@\"...", type.key, domain.key)
                }
                searching -= 1
            }
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        for domain in typeBrowsers {
            for type in domain.value where type.value == browser {
                if #available(iOS 10.0, *) {
                    os_log("Error searching for \"%@\" services in \"%@\":\n%@", type.key, domain.key, errorDict.description)
                } else {
                    NSLog("Error searching for \"%@\" services in \"%@\":\n%@", type.key, domain.key, errorDict.description)
                }
                searching -= 1
            }
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        if #available(iOS 10.0, *) {
            os_log("Found NetService \"%@\" in \"%@\"...", service.name, service.domain)
        } else {
            NSLog("Found NetService \"%@\" in \"%@\"...", service.name, service.domain)
        }
        if service.type == HTTP || service.type == HTTPS {
            service.delegate = self
            if service.port == -1 {
                pendingServices.append(service)
                service.resolve(withTimeout: 10)
            } else {
                self.netServiceDidResolveAddress(service)
            }
            searching -= 1
        }
        // NOTE: when adding handlers for more than just HTTP, remember to properly decrement searching
        if !moreComing {
            self.endRefreshing()
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        if #available(iOS 10.0, *) {
            os_log("Removing NetService \"%@\" from \"%@\"...", service.name, service.domain)
        } else {
            NSLog("Removing NetService \"%@\" from \"%@\"...", service.name, service.domain)
        }
        if let key = serviceKey(service) {
            services[service.domain]?.removeValue(forKey: key)
            if let index = serviceKeys[service.domain]?.index(of: key) {
                serviceKeys[service.domain]?.remove(at: index)
            }
            urls.removeValue(forKey: key)
            if (service.domain != LOCAL_DOMAIN) && (services[service.domain] != nil) && ((services[service.domain]?.count)! < 1) {
                domains.remove(at: domains.index(of: service.domain)!)
                setTitle()
            }
            self.tableView.reloadData()
        } else {
            if #available(iOS 10.0, *) {
                os_log("Unknown NetService \"%@\" on host \"%@\" from \"%@\"...", service.name, service.hostName ?? "no hostname", service.domain)
            } else {
                NSLog("Unknown NetService \"%@\" on host \"%@\" from \"%@\"...", service.name, service.hostName ?? "no hostname", service.domain)
            }
            // reset and start over
            services.removeAll()
            urls.removeAll()
            self.refresh()
            return // do not check against moreComing to halt refresh
        }
        if !moreComing {
            self.endRefreshing()
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFindDomain domainString: String, moreComing: Bool) {
        if #available(iOS 10.0, *) {
            os_log("Adding domain \"%@\"...", domainString)
        } else {
            NSLog("Adding domain \"%@\"...", domainString)
        }
        if !domains.contains(domainString) {
            services[domainString] = [String: NetService]()
            serviceKeys[domainString] = [String]()
        }
        if !servicesBrowsers.keys.contains(domainString) {
            let browser = NetServiceBrowser()
            browser.delegate = self
            servicesBrowsers[domainString] = browser
            browser.searchForServices(ofType: SERVICES, inDomain: domainString)
        }
        if !typeBrowsers.keys.contains(domainString) {
            typeBrowsers[domainString] = [String: NetServiceBrowser]()
        }
        if typeBrowsers[domainString]![HTTP] == nil {
            let httpBrowser = NetServiceBrowser()
            httpBrowser.delegate = self
            typeBrowsers[domainString]![HTTP] = httpBrowser
            httpBrowser.searchForServices(ofType: HTTP, inDomain: domainString)
        }
        if typeBrowsers[domainString]![HTTPS] == nil {
            let httpsBrowser = NetServiceBrowser()
            httpsBrowser.delegate = self
            typeBrowsers[domainString]![HTTPS] = httpsBrowser
            httpsBrowser.searchForServices(ofType: HTTPS, inDomain: domainString)
        }
        searching -= 1
        if !moreComing {
            self.endRefreshing()
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemoveDomain domainString: String, moreComing: Bool) {
        if #available(iOS 10.0, *) {
            os_log("Removing domain \"%@\"...", domainString)
        } else {
            NSLog("Removing domain \"%@\"...", domainString)
        }
        if domains.contains(domainString) {
            domains.remove(at: domains.index(of: domainString)!)
            services.removeValue(forKey: domainString)
            serviceKeys.removeValue(forKey: domainString)
            urls.removeValue(forKey: domainString)
            if typeBrowsers.keys.contains(domainString) {
                for browsers in typeBrowsers[domainString]! {
                    browsers.value.stop()
                }
            }
            typeBrowsers.removeValue(forKey: domainString)
            self.setTitle()
        }
        if !moreComing {
            self.endRefreshing()
        }
    }

    // MARK: - NetService

    func netServiceDidResolveAddress(_ service: NetService) {
        if #available(iOS 10.0, *) {
            os_log("Resolved NetService \"%@\" in \"%@\"...", service.name, service.domain)
        } else {
            NSLog("Resolved NetService \"%@\" in \"%@\"...", service.name, service.domain)
        }
        if pendingServices.contains(service) {
            pendingServices.remove(at: pendingServices.index(of: service)!)
        }
        if !domains.contains(service.domain) {
            domains.append(service.domain)
            domains.sort()
            setTitle()
        }
        if let key = serviceKey(service), let url = url(service) {
            serviceKeys[service.domain]?.append(key)
            urls[key] = url
            services[service.domain]?[key] = service
            serviceKeys[service.domain]?.sort()
            searching -= 1
        }
    }

    /// Create the URL for a given service. Note that URLs are mutable within the lifetime of a
    /// service, so they are only usable to navigating to that service, not for (re)identifying a
    /// unique service; use `serviceKey(_ service: NetService)` for that.
    ///
    /// - Parameter service: The service to get a URL for
    /// - Returns: the URL for the service
    func url(_ service: NetService) -> URL? {
        if let hostName = service.hostName {
            switch service.type {
            case HTTP, HTTPS:
                // "protocol" is a reserved word, so simply use "p"
                let p = service.type == HTTPS ? "https" : "http"
                let dict = NetService.dictionary(fromTXTRecord: service.txtRecordData()!)
                let path = dict.keys.contains("path") ? String(data: dict["path"]!, encoding: .utf8) : ""
                return URL(string: "\(p)://\(hostName):\(service.port)\(path ?? "")")!
            default:
                return nil
            }
        }
        return nil
    }

    /// Create the service unique key for a given service, since service URLs can change,
    /// but service names and domains are immutable within the lifetime of a service in zeroconf
    /// networking.
    ///
    /// - Parameter service: The service to get a key for
    /// - Returns: the key for the service
    func serviceKey(_ service: NetService) -> String? {
        return "\(service.name).\(service.domain)"
    }

    // MARK: - Utilities

    /// Get the title for the domain view. Use a full title for the local. domain and include the
    /// named domain if not local.
    ///
    /// - Parameter domain: The name of the domain
    /// - Returns: The view title based on the domain name
    func getTitle(_ domain: String) -> String {
        if domain == LOCAL_DOMAIN {
            return NSLocalizedString("LOCAL_SERVICES", comment: "list of services in default (local) domain")
        } else {
            return String.localizedStringWithFormat(NSLocalizedString("DOMAIN_SERVICES", comment: "list of services in non-default domain - replacement is domain"), domain)
        }
    }

    /// Get the network SSID, if possible
    ///
    /// - Returns: the network SSID or nil
    func getSSID() -> String? {
        if let interfaces = CNCopySupportedInterfaces() as? [String] {
            if !(interfaces.count > 0) {
                return nil
            }
            let interfaceName = interfaces[0] as String
            if let unsafeInterfaceData = CNCopyCurrentNetworkInfo(interfaceName as CFString),
                let interfaceData = unsafeInterfaceData as? [String: AnyObject] {
                return interfaceData["SSID"] as? String
            }
        }
        return nil
    }
}
