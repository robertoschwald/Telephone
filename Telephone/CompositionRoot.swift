//
//  CompositionRoot.swift
//  Telephone
//
//  Copyright (c) 2008-2015 Alexei Kuznetsov. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//  1. Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//  2. Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other materials provided with the distribution.
//  3. Neither the name of the copyright holder nor the names of contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
//  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
//  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE THE COPYRIGHT HOLDER
//  OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
//  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
//  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
//  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
//  OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
//  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import Foundation
import UseCases

class CompositionRoot: NSObject {
    let userAgent: AKSIPUserAgent
    let preferencesController: PreferencesController
    private let userDefaults: NSUserDefaults
    private let queue: dispatch_queue_t

    private let userAgentNotificationsToObserverAdapter: UserAgentNotificationsToObserverAdapter
    private let devicesChangeMonitor: SystemAudioDevicesChangeMonitor!

    init(preferencesControllerDelegate: PreferencesControllerDelegate) {
        userAgent = AKSIPUserAgent.sharedUserAgent()
        userDefaults = NSUserDefaults.standardUserDefaults()
        queue = createQueue()

        let audioDevices = SystemAudioDevices()
        let interactorFactory = InteractorFactoryImpl(systemAudioDeviceRepository: audioDevices, userDefaults: userDefaults)

        preferencesController = PreferencesController(
            delegate: preferencesControllerDelegate,
            soundPreferencesViewObserver: SoundPreferencesViewEventHandler(
                interactorFactory: interactorFactory,
                presenterFactory: PresenterFactoryImpl(),
                userAgent: userAgent
            )
        )

        userAgentNotificationsToObserverAdapter = UserAgentNotificationsToObserverAdapter(
            observer: UserAgentSoundIOSelector(interactorFactory: interactorFactory),
            userAgent: userAgent
        )
        devicesChangeMonitor = SystemAudioDevicesChangeMonitor(
            observer: UserAgentAudioDeviceUpdater(
                interactor: UserAgentAudioDeviceUpdateAndSoundIOSelectionInteractor(
                    updateInteractor: UserAgentAudioDeviceUpdateInteractor(
                        userAgent: userAgent
                    ),
                    selectionInteractor: UserAgentSoundIOSelectionInteractor(
                        systemAudioDeviceRepository: audioDevices,
                        userAgent: userAgent,
                        userDefaults: userDefaults
                    )
                )
            ),
            queue: queue
        )

        super.init()

        devicesChangeMonitor.start()
    }

    deinit {
        devicesChangeMonitor.stop()
    }
}

private func createQueue() -> dispatch_queue_t {
    let label = NSBundle.mainBundle().bundleIdentifier! + ".background-queue"
    return dispatch_queue_create(label, DISPATCH_QUEUE_SERIAL)
}
