//
//  UserDefaultsFake.swift
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
import UseCases

public final class UserDefaultsFake {
    public var date: NSDate = NSDate.distantPast()
    public var version = ""

    public var registeredDefaults: [String: AnyObject] {
        return registered
    }

    private var dictionary: [String: AnyObject] = [:]
    private var registered: [String: AnyObject] = [:]

    public init() {}
}

extension UserDefaultsFake: KeyValueUserDefaults {
    @objc public subscript(key: String) -> String? {
        get {
            return stringForKey(key)
        }
        set {
            dictionary[key] = newValue
        }
    }

    @objc public func stringForKey(key: String) -> String? {
        return dictionary[key] as? String
    }

    @objc public func setBool(value: Bool, forKey key: String) {
        dictionary[key] = value
    }

    @objc public func boolForKey(key: String) -> Bool {
        return dictionary[key] as? Bool ?? false
    }

    @objc public func setArray(array: [AnyObject], forKey key: String) {
        dictionary[key] = array
    }

    @objc public func arrayForKey(key: String) -> [AnyObject]? {
        return dictionary[key] as? [AnyObject]
    }

    @objc public func registerDefaults(defaults: [String : AnyObject]) {
        for (key, value) in defaults {
            registered.updateValue(value, forKey: key)
            dictionary.updateValue(value, forKey: key)
        }
    }
}

extension UserDefaultsFake: PurchaseReminderUserDefaults {}
