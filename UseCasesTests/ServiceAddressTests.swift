//
//  ServiceAddressTests.swift
//  Telephone
//
//  Copyright © 2008-2016 Alexey Kuznetsov
//  Copyright © 2016-2017 64 Characters
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
import XCTest

final class ServiceAddressTests: XCTestCase {
    func testHostIsFullSourceStringWhenNoPortIsSpecified() {
        let sut = ServiceAddress(string: "any")

        XCTAssertEqual(sut.host, "any")
    }

    func testHostIsSubstringBeforeColon() {
        let sut = ServiceAddress(string: "any:123")

        XCTAssertEqual(sut.host, "any")
    }

    func testPortIsSubstringAfterColon() {
        let sut = ServiceAddress(string: "any:123")

        XCTAssertEqual(sut.port, "123")
    }

    func testPortIsEmptyStringWhenSourceStringEndsWithColon() {
        let sut = ServiceAddress(string: "any:")

        XCTAssertEqual(sut.port, "")
    }
}
