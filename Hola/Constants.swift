//
//  Constants.swift
//  Hola
//
//  Created by Randall Wood on 9/7/18.
//  Copyright © 2018 Randall Wood. All rights reserved.
//

struct ServiceType {
    static let Services = "_services._dns-sd._udp."
    static let HTTP = "_http._tcp."
    // search for HTTPS even though not recommended
    // see https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xhtml?search=https
    // and scroll to Tim Berners Lee's comments on the HTTPS entry without associated port
    static let HTTPS = "_https._tcp."
}
