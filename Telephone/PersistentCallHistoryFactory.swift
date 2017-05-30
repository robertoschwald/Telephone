//
//  PersistentCallHistoryFactory.swift
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

import Foundation
import UseCases

final class PersistentCallHistoryFactory {
    fileprivate let history: TruncatingCallHistoryFactory
    fileprivate let storage: SimplePropertyListStorageFactory
    fileprivate let locations: ApplicationDataLocations

    init(history: TruncatingCallHistoryFactory, storage: SimplePropertyListStorageFactory, locations: ApplicationDataLocations) {
        self.history = history
        self.storage = storage
        self.locations = locations
    }
}

extension PersistentCallHistoryFactory: CallHistoryFactory {
    func make(uuid: String) -> CallHistory {
        return PersistentCallHistory(
            origin: history.make(),
            storage: storage.make(url: SimplePropertyListStorageURL(directory: locations.callHistories(), name: uuid))
        )
    }
}
