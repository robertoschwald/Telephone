//
//  SimpleMusicPlayerUserDefaultsTests.swift
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

import UseCases
import UseCasesTestDoubles
import XCTest

final class SimpleMusicPlayerUserDefaultsTests: XCTestCase {
    func testGetsFromUserDefaultsWithExpectedKey() {
        let defaults = UserDefaultsFake()
        defaults.setBool(true, forKey: key)
        let sut = SimpleMusicPlayerUserDefaults(defaults: defaults)

        XCTAssertTrue(sut.shouldPause)
    }

    func testSetsToUserDefaultsWithExpectedKey() {
        let defaults = UserDefaultsFake()
        let sut = SimpleMusicPlayerUserDefaults(defaults: defaults)

        sut.shouldPause = true

        XCTAssertTrue(defaults.boolForKey(key))
    }

    func testRegistersDefaults() {
        let defaults = UserDefaultsFake()
        _ = SimpleMusicPlayerUserDefaults(defaults: defaults)

        XCTAssertTrue(defaults.registeredDefaults[key] as! Bool)
    }
}

private let key = "PauseITunes"
