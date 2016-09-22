//
//  DeviceGUID.swift
//  Telephone
//
//  Copyright (c) 2008-2016 Alexey Kuznetsov
//  Copyright (c) 2016 64 Characters
//
//  Telephone is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Telephone is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//

import Foundation
import IOKit

struct DeviceGUID {
    let dataValue: NSData

    init() {
        dataValue = createGUID()
    }
}

private func createGUID() -> NSData {
    let iterator = createIterator()
    guard iterator != 0 else { return NSData() }

    var mac = NSData()
    var service = IOIteratorNext(iterator)
    while service != 0 {
        var parent: io_object_t = 0
        let status = IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent)
        if status == KERN_SUCCESS {
            mac = IORegistryEntryCreateCFProperty(parent, "IOMACAddress", kCFAllocatorDefault, 0).takeRetainedValue() as! CFDataRef
            IOObjectRelease(parent)
        }
        IOObjectRelease(service)
        service = IOIteratorNext(iterator)
    }

    IOObjectRelease(iterator)

    return mac
}

private func createIterator() -> io_iterator_t {
    var port: mach_port_t = 0
    var status = IOMasterPort(mach_port_t(MACH_PORT_NULL), &port)
    guard status == KERN_SUCCESS else { return 0 }
    guard let match = IOBSDNameMatching(port, 0, "en0") else { return 0 }
    var iterator: io_iterator_t = 0
    status = IOServiceGetMatchingServices(port, match, &iterator)
    guard status == KERN_SUCCESS else { return 0 }
    return iterator
}
