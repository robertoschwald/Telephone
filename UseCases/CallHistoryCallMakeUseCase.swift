//
//  CallHistoryCallMakeUseCase.swift
//  Telephone
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

public final class CallHistoryCallMakeUseCase {
    fileprivate let account: Account
    fileprivate let history: CallHistory
    fileprivate let index: Int

    public init(account: Account, history: CallHistory, index: Int) {
        self.account = account
        self.history = history
        self.index = index
    }
}

extension CallHistoryCallMakeUseCase: UseCase {
    public func execute() {
        account.makeCall(to: history.allRecords[index].uri)
    }
}
