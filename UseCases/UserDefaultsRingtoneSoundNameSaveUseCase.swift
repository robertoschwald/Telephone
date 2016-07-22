//
//  UserDefaultsRingtoneSoundNameSaveUseCase.swift
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

public final class UserDefaultsRingtoneSoundNameSaveUseCase {
    private let name: String
    private let userDefaults: UserDefaults

    public init(name: String, userDefaults: UserDefaults) {
        self.name = name
        self.userDefaults = userDefaults
    }
}

extension UserDefaultsRingtoneSoundNameSaveUseCase: UseCase {
    public func execute() {
        if !name.isEmpty {
            userDefaults[kRingingSound] = name
        }
    }
}
