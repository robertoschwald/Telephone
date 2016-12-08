//
//  DefaultSoundPreferencesViewEventTarget.swift
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

final class DefaultSoundPreferencesViewEventTarget: NSObject {
    fileprivate let useCaseFactory: UseCaseFactory
    fileprivate let presenterFactory: PresenterFactory
    fileprivate let userAgentSoundIOSelection: UseCase
    fileprivate let ringtoneOutputUpdate: ThrowingUseCase
    fileprivate let ringtoneSoundPlayback: SoundPlaybackUseCase

    init(useCaseFactory: UseCaseFactory,
         presenterFactory: PresenterFactory,
         userAgentSoundIOSelection: UseCase,
         ringtoneOutputUpdate: ThrowingUseCase,
         ringtoneSoundPlayback: SoundPlaybackUseCase) {
        self.useCaseFactory = useCaseFactory
        self.presenterFactory = presenterFactory
        self.userAgentSoundIOSelection = userAgentSoundIOSelection
        self.ringtoneOutputUpdate = ringtoneOutputUpdate
        self.ringtoneSoundPlayback = ringtoneSoundPlayback
    }
}

extension DefaultSoundPreferencesViewEventTarget: SoundPreferencesViewEventTarget {
    func viewShouldReloadData(_ view: SoundPreferencesView) {
        loadSettingsSoundIOInViewOrLogError(view)
    }

    func viewShouldReloadSoundIO(_ view: SoundPreferencesView) {
        loadSettingsSoundIOInViewOrLogError(view)
    }

    func viewDidChangeSoundIO(input: String, output: String, ringtoneOutput: String) {
        updateSettings(
            with: PresentationSoundIO(input: input, output: output, ringtoneOutput: ringtoneOutput)
        )
        userAgentSoundIOSelection.execute()
        updateRingtoneOutputOrLogError()
    }

    func viewDidChangeRingtoneName(_ name: String) {
        updateSettings(withRingtoneSoundName: name)
        playRingtoneSoundOrLogError()
    }

    func viewWillDisappear(_ view: SoundPreferencesView) {
        ringtoneSoundPlayback.stop()
    }

    private func loadSettingsSoundIOInViewOrLogError(_ view: SoundPreferencesView) {
        do {
            try makeSettingsSoundIOLoadUseCase(view: view).execute()
        } catch {
            print("Could not load Sound IO view data")
        }
    }

    private func updateSettings(with soundIO: PresentationSoundIO) {
        useCaseFactory.makeSettingsSoundIOSaveUseCase(soundIO: soundIO).execute()
    }

    private func updateRingtoneOutputOrLogError() {
        do {
            try ringtoneOutputUpdate.execute()
        } catch {
            print("Could not update ringtone output: \(error)")
        }
    }

    private func updateSettings(withRingtoneSoundName name: String) {
        useCaseFactory.makeSettingsRingtoneSoundNameSaveUseCase(name: name).execute()
    }

    private func playRingtoneSoundOrLogError() {
        do {
            try ringtoneSoundPlayback.play()
        } catch {
            print("Could not play ringtone sound: \(error)")
        }
    }

    private func makeSettingsSoundIOLoadUseCase(view: SoundPreferencesView) -> ThrowingUseCase {
        return useCaseFactory.makeSettingsSoundIOLoadUseCase(
            output: presenterFactory.makeSoundIOPresenter(output: view)
        )
    }
}
