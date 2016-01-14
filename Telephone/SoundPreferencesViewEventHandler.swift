//
//  SoundPreferencesViewEventHandler.swift
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

import UseCases

class SoundPreferencesViewEventHandler: NSObject {
    let interactorFactory: InteractorFactory
    let presenterFactory: PresenterFactory
    let userAgent: UserAgent

    init(interactorFactory: InteractorFactory, presenterFactory: PresenterFactory, userAgent: UserAgent) {
        self.interactorFactory = interactorFactory
        self.presenterFactory = presenterFactory
        self.userAgent = userAgent
    }
}

extension SoundPreferencesViewEventHandler: SoundPreferencesViewObserver {
    func viewShouldReloadData(view: SoundPreferencesView) {
        let interactor = interactorFactory.createUserDefaultsSoundIOLoadInteractorWithOutput(
            presenterFactory.createSoundIOPresenterWithOutput(view)
        )
        do {
            try interactor.execute()
        } catch {
            print("Could not load Sound IO view data")
        }
    }

    func viewDidChangeSoundInput(soundInput: String, soundOutput: String, ringtoneOutput: String) {
        updateUserDefaultsWithSoundInput(soundInput, soundOutput: soundOutput, ringtoneOutput: ringtoneOutput)
        selectUserAgentAudioDevicesOrLogError()
    }

    private func updateUserDefaultsWithSoundInput(soundInput: String, soundOutput: String, ringtoneOutput: String) {
        let interactor = interactorFactory.createUserDefaultsSoundIOSaveInteractorWithSoundIO(
            SoundIO(soundInput: soundInput, soundOutput: soundOutput, ringtoneOutput: ringtoneOutput)
        )
        interactor.execute()
    }

    private func selectUserAgentAudioDevicesOrLogError() {
        do {
            try interactorFactory.createUserAgentSoundIOSelectionInteractorWithUserAgent(userAgent).execute()
        } catch {
            print("Could not select user agent audio devices: \(error)")
        }
    }
}
