//
//  KeyValueUserDefaults.swift
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

@objc public protocol KeyValueUserDefaults {
    subscript(key: String) -> String? { get set }
    func stringForKey(key: String) -> String?

    func setBool(value: Bool, forKey key: String)
    func boolForKey(key: String) -> Bool

    func setArray(array: [AnyObject], forKey key: String)
    func arrayForKey(key: String) -> [AnyObject]?

    func registerDefaults(defaults: [String: AnyObject])
}
