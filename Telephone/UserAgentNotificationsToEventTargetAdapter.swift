//
//  UserAgentNotificationsToEventTargetAdapter.swift
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

final class UserAgentNotificationsToEventTargetAdapter {
    private let target: UserAgentEventTarget
    private let agent: UserAgent

    init(target: UserAgentEventTarget, agent: UserAgent) {
        self.target = target
        self.agent = agent
        subscribe()
    }

    deinit {
        unsubscribe()
    }

    private func subscribe() {
        let nc = NotificationCenter.default
        nc.addObserver(
            self,
            selector: #selector(SIPUserAgentDidFinishStarting),
            name: NSNotification.Name.AKSIPUserAgentDidFinishStarting,
            object: agent
        )
        nc.addObserver(
            self,
            selector: #selector(SIPUserAgentDidFinishStopping),
            name: NSNotification.Name.AKSIPUserAgentDidFinishStopping,
            object: agent
        )
        nc.addObserver(
            self,
            selector: #selector(SIPUserAgentDidDetectNAT),
            name: NSNotification.Name.AKSIPUserAgentDidDetectNAT,
            object: agent
        )
        nc.addObserver(
            self,
            selector: #selector(SIPUserAgentDidMakeCall),
            name: NSNotification.Name.AKSIPCallCalling,
            object: nil
        )
        nc.addObserver(
            self,
            selector: #selector(SIPUserAgentDidReceiveCall),
            name: NSNotification.Name.AKSIPCallIncoming,
            object: nil
        )
    }

    private func unsubscribe() {
        let nc = NotificationCenter.default
        nc.removeObserver(self, name: NSNotification.Name.AKSIPUserAgentDidFinishStarting, object: agent)
        nc.removeObserver(self, name: NSNotification.Name.AKSIPUserAgentDidFinishStopping, object: agent)
        nc.removeObserver(self, name: NSNotification.Name.AKSIPUserAgentDidDetectNAT, object: agent)
    }

    @objc private func SIPUserAgentDidFinishStarting(_ notification: Notification) {
        assert(agent === notification.object as! UserAgent)
        target.userAgentDidFinishStarting(agent)
    }

    @objc private func SIPUserAgentDidFinishStopping(_ notification: Notification) {
        assert(agent === notification.object as! UserAgent)
        target.userAgentDidFinishStopping(agent)
    }

    @objc private func SIPUserAgentDidDetectNAT(_ notification: Notification) {
        assert(agent === notification.object as! UserAgent)
        target.userAgentDidDetectNAT(agent)
    }

    @objc private func SIPUserAgentDidMakeCall(_ notification: Notification) {
        target.userAgentDidMakeCall(agent)
    }

    @objc private func SIPUserAgentDidReceiveCall(_ notification: Notification) {
        target.userAgentDidReceiveCall(agent)
    }
}
