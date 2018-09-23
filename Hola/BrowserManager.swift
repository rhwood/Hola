//
//  BrowserManager.swift
//  Hola
//
//  Created by Randall Wood on 9/23/18.
//  Copyright © 2018 Alexandria Software. All rights reserved.
//

import Foundation
import os.log

class BrowserManager: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {

    static public let shared = BrowserManager()
    static public let didStartSearching = Notification.Name(rawValue: "BrowserManager.DidStartSearching")
    static public let didEndSearching = Notification.Name(rawValue: "BrowserManager.DidEndSearching")
    static public let didRemoveService = Notification.Name(rawValue: "BrowserManager.DidRemoveService")
    static public let didResolveService = Notification.Name(rawValue: "BrowserManager.DidResolveService")

    private var domainBrowser: NetServiceBrowser {
        if _domainBrowser == nil {
            _domainBrowser = NetServiceBrowser()
            _domainBrowser!.delegate = self
        }
        return _domainBrowser!
    }
    private var _domainBrowser: NetServiceBrowser?
    public private(set) var servicesBrowsers = [String: NetServiceBrowser]()
    public private(set) var typeBrowsers = [String: [String: NetServiceBrowser]]()
    public private(set) var searching: Int = 0 {
        willSet {
            if searching == 0 && newValue >= 1 {
                NotificationCenter.default.post(name: BrowserManager.didStartSearching, object: self)
            }
        }
        didSet {
            if #available(iOS 10.0, *) {
                os_log("%d active searches...", searching)
            } else {
                NSLog("%d active searches...", searching)
            }
            if searching < 0 {
                searching = 0
            }
            if searching == 0 {
                NotificationCenter.default.post(name: BrowserManager.didEndSearching, object: self)
            }
        }
    }
    private var pendingServices = [NetService]()
    public private(set) var services = [String: [String: NetService]]() // [service.domain: [serviceKey(): service]]
    public private(set) var domains = [String]() // [service.domain]
    public private(set) var serviceKeys = [String: [String]]() // [service.domain: [serviceKey()]]
    public private(set) var urls = [String: URL]() // [serviceKey(): url()]

    // MARK: - Published Methods

    func search() {
        searchForDomain(false)
    }

    func stop() {
        for domain in domains {
            self.netServiceBrowser(domainBrowser, didRemoveDomain: domain, moreComing: true)
        }
        domainBrowser.stop()
    }

    func refresh() {
        stop()
        _domainBrowser = nil
        search()
    }

    /// Search for browsable or registration domains
    ///
    /// - Parameter registration: true if searching for a registration domain, false otherwise
    private func searchForDomain(_ registration: Bool) {
        if registration {
            domainBrowser.searchForRegistrationDomains()
        } else {
            domainBrowser.searchForBrowsableDomains()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(2000), execute: {
            if #available(iOS 10.0, *) {
                os_log("Giving up on finding anything...")
            } else {
                NSLog("Giving up on finding anything...")
            }
            self.searching -= 1
        })
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
                    os_log("Error searching for \"%@\" services in \"%@\":\n%@",
                           type.key, domain.key, errorDict.description)
                } else {
                    NSLog("Error searching for \"%@\" services in \"%@\":\n%@",
                          type.key, domain.key, errorDict.description)
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
        if service.type == ServiceType.HTTP || service.type == ServiceType.HTTPS {
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
            searching = 0
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
            if (service.domain != Domain.Local)
                && (services[service.domain] != nil)
                && ((services[service.domain]?.count)! < 1) {
                domains.remove(at: domains.index(of: service.domain)!)
            }
            NotificationCenter.default.post(name: BrowserManager.didRemoveService, object: self)
        } else {
            if #available(iOS 10.0, *) {
                os_log("Unknown NetService \"%@\" on host \"%@\" from \"%@\"...",
                       service.name, service.hostName ?? "no hostname", service.domain)
            } else {
                NSLog("Unknown NetService \"%@\" on host \"%@\" from \"%@\"...",
                      service.name, service.hostName ?? "no hostname", service.domain)
            }
            // reset and start over
            self.refresh()
            return // do not check against moreComing to halt refresh
        }
        if !moreComing {
            searching = 0
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
            browser.searchForServices(ofType: ServiceType.Services, inDomain: domainString)
        }
        if !typeBrowsers.keys.contains(domainString) {
            typeBrowsers[domainString] = [String: NetServiceBrowser]()
        }
        if typeBrowsers[domainString]![ServiceType.HTTP] == nil {
            let httpBrowser = NetServiceBrowser()
            httpBrowser.delegate = self
            typeBrowsers[domainString]![ServiceType.HTTP] = httpBrowser
            httpBrowser.searchForServices(ofType: ServiceType.HTTP, inDomain: domainString)
        }
        if typeBrowsers[domainString]![ServiceType.HTTPS] == nil {
            let httpsBrowser = NetServiceBrowser()
            httpsBrowser.delegate = self
            typeBrowsers[domainString]![ServiceType.HTTPS] = httpsBrowser
            httpsBrowser.searchForServices(ofType: ServiceType.HTTPS, inDomain: domainString)
        }
        searching -= 1
        if !moreComing {
            searching = 0
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
        }
        if !moreComing {
            searching = 0
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
        }
        if let key = serviceKey(service), let url = url(service) {
            serviceKeys[service.domain]?.append(key)
            urls[key] = url
            services[service.domain]?[key] = service
            serviceKeys[service.domain]?.sort()
            NotificationCenter.default.post(name: BrowserManager.didResolveService, object: self)
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
            case ServiceType.HTTP, ServiceType.HTTPS:
                let type = service.type == ServiceType.HTTPS ? "https" : "http"
                let dict = NetService.dictionary(fromTXTRecord: service.txtRecordData()!)
                let path = dict.keys.contains("path") ? String(data: dict["path"]!, encoding: .utf8) : ""
                return URL(string: "\(type)://\(hostName):\(service.port)\(path ?? "")")!
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

}
