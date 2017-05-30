//
//  AccountUUIDSettingsMigration.swift
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

final class AccountUUIDSettingsMigration {
    fileprivate let settings: KeyValueSettings

    init(settings: KeyValueSettings) {
        self.settings = settings
    }
}

extension AccountUUIDSettingsMigration: SettingsMigration {
    func execute() {
        save(accounts: loadAccounts().map(addUUIDIfNeeded))
    }

    private func loadAccounts() -> [[String: Any]] {
        return settings.array(forKey: kAccounts) as? [[String: Any]] ?? []
    }

    private func save(accounts: [[String: Any]]) {
        settings.set(accounts, forKey: kAccounts)
    }
}

private func addUUIDIfNeeded(to dict: [String: Any]) -> [String: Any] {
    if shouldAddUUID(to: dict) {
        return addUUID(to: dict)
    } else {
        return dict
    }
}

private func shouldAddUUID(to dict: [String: Any]) -> Bool {
    if let uuid = dict[kUUID] as? String, !uuid.isEmpty {
        return false
    } else {
        return true
    }
}

private func addUUID(to dict: [String: Any]) -> [String: Any] {
    var result = dict
    result[kUUID] = UUID().uuidString
    return result
}
