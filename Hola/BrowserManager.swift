//
//  BrowserManager.swift
//  Hola
//
//  Created by Randall Wood on 9/23/18.
//  Copyright © 2018, 2022 Alexandria Software. All rights reserved.
//

import Foundation
import Network
import os

public struct Domain {
    let name: String
    var services: [HolaService] = []

    static let Local = "local." // the local domain, handled as "" in app
}

public struct HolaService {
    let service: NWBrowser.Result?
    let netService: NetService?
    var name: String {
        if let service = netService {
            return service.name
        } else if case let .service(name, _, _, _) = service?.endpoint {
            return name
        }
        return ""
    }
    var type: String {
        if let service = netService {
            return service.type
        } else if case let .service(_, type, _, _) = service?.endpoint {
            return type
        }
        return ""
    }
    var domain: String {
        if let service = netService {
            return service.domain
        } else if case let .service(_, _, domain, _) = service?.endpoint {
            return domain
        }
        return ""
    }
    var key: String {
        "\(name).\(domain)"
    }
    var url: URL?
}

class BrowserManager: NSObject, NetServiceBrowserDelegate, NetServiceDelegate, ObservableObject {

    @Published var state: NWBrowser.State = .cancelled
    @Published var services: [HolaService] = []
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "", category: "Browser")
    let nsbLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "", category: "NSBBrowser")
    private var browsers: [NWBrowser] = []

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
    @Published public private(set) var searching: Int = 0 {
        didSet {
            nsbLogger.debug("\(self.searching) active searches...")
            if searching < 0 {
                searching = 0
            }
        }
    }
    private var pendingServices: [NetService] = []

    // MARK: - Published Methods

    func search() {
        searchForDomain()
//        // DO NOT use browsers until able to get URL from NWBrowser.Result
//        if browsers.isEmpty {
//            ["_http._tcp.", "_https._tcp."].forEach {
//                let browser = NWBrowser(for: .bonjourWithTXTRecord(type: $0, domain: nil), using: NWParameters())
//                browser.browseResultsChangedHandler = { results, changes in
//                    DispatchQueue.main.async {
//                        self.services = results.map({ HolaService(service: $0, netService: nil) })
//                    }
//                    results.forEach {
//                        self.logger.debug("Got \($0.endpoint.debugDescription)")
//                    }
//                }
//                browsers.append(browser)
//            }
//        }
//        browsers.forEach { $0.start(queue: DispatchQueue.global()) }
        logger.debug("Started browsers.")
    }

    func stop() {
        servicesBrowsers.forEach {
            $1.stop()
            $1.delegate = nil
        }
        servicesBrowsers.removeAll()
        typeBrowsers.forEach {
            $1.forEach {
                $1.stop()
                $1.delegate = nil
            }
        }
        typeBrowsers.removeAll()
        domainBrowser.stop()
        browsers.forEach { $0.cancel() }
        logger.debug("Stopped browsers.")
    }

    func refresh() {
        stop()
        if let browser = _domainBrowser {
            browser.delegate = nil
        }
        services.removeAll()
        _domainBrowser = nil
        search()
    }

    /// Search for browsable domains
    private func searchForDomain() {
        domainBrowser.searchForBrowsableDomains()
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(2000), execute: {
            self.nsbLogger.debug("Giving up on finding anything...")
            self.searching -= 1
        })
    }

    // MARK: - NetServices Browser

    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        if browser == domainBrowser {
            nsbLogger.debug("Searching for browsable domains...")
            searching += 1
        }
        for domain in typeBrowsers {
            for type in domain.value where type.value == browser {
                nsbLogger.debug("Searching for \"\(type.key)\" services in \"\(domain.key)\"...")
                searching += 1
            }
        }
    }

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        for domain in typeBrowsers {
            for type in domain.value where type.value == browser {
                nsbLogger.debug("Stopped searching for \"\(type.key)\" services in \"\(domain.key)\"...")
                searching -= 1
            }
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        for domain in typeBrowsers {
            for type in domain.value where type.value == browser {
                nsbLogger.error("Error searching for \"\(type.key)\" services in \"\(domain.key)\":\n\(errorDict.description)")
                searching -= 1
            }
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        nsbLogger.debug("Found NetService \"\(service.name)\" in \"\(service.domain)\"...")
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
        if !moreComing {
            searching -= 1
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        nsbLogger.debug("Removing NetService \"\(service.name)\" from \"\(service.domain)\"...")
        if let key = serviceKey(service) {
            services = services.filter({ $0.key != key })
        } else {
            nsbLogger.error("Unknown NetService \"\(service.name)\" on host \"\(service.hostName ?? "no hostname")\" from \"\(service.domain)\"...")
            // reset and start over
            self.refresh()
            return // do not check against moreComing to halt refresh
        }
        if !moreComing {
            searching -= 1
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFindDomain domainString: String, moreComing: Bool) {
        nsbLogger.debug("Adding domain \"\(domainString)\"...")
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
            searching -= 1
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemoveDomain domainString: String, moreComing: Bool) {
        nsbLogger.debug("Removing domain \"\(domainString)\"...")
        services = services.filter({ $0.domain != domainString })
        if typeBrowsers.keys.contains(domainString) {
            for browsers in typeBrowsers[domainString]! {
                browsers.value.stop()
            }
            typeBrowsers.removeValue(forKey: domainString)
        }
        if !moreComing {
            searching -= 1
        }
    }

    // MARK: - NetService

    func netServiceDidResolveAddress(_ service: NetService) {
        nsbLogger.debug("Resolved NetService \"\(service.name)\" in \"\(service.domain)\"...")
        if pendingServices.contains(service) {
            pendingServices.remove(at: pendingServices.firstIndex(of: service)!)
        }
        if let url = url(service) {
            if !services.contains(where: { existing in
                existing.key == serviceKey(service)
            }) {
                services.append(HolaService(service: nil, netService: service, url: url))
            }
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

    /// Create the service unique key for a given service, since service URLs can change,
    /// but service names and domains are immutable within the lifetime of a service in zeroconf
    /// networking.
    ///
    /// - Parameter service: The service to get a key for
    /// - Returns: the key for the service
    func serviceKey(_ service: NWBrowser.Result) -> String? {
        if case let .service(name, _, domain, _) = service.endpoint {
            return "\(name).\(domain)"
        }
        return nil
    }

}
