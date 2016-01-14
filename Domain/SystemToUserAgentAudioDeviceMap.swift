//
//  SystemToUserAgentAudioDeviceMap.swift
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

public class SystemToUserAgentAudioDeviceMap {
    public let systemDevices: [SystemAudioDevice]
    public let userAgentDevices: [UserAgentAudioDevice]

    private var map = [SystemAudioDevice: UserAgentAudioDevice]()
    private var userAgentDeviceNameToDeviceMap = [String: UserAgentAudioDevice]()

    public init(systemDevices: [SystemAudioDevice], userAgentDevices: [UserAgentAudioDevice]) {
        self.systemDevices = systemDevices
        self.userAgentDevices = userAgentDevices
        updateMap()
    }

    public func userAgentDeviceForSystemDevice(systemDevice: SystemAudioDevice) throws -> UserAgentAudioDevice {
        if let device = map[systemDevice] {
            return device
        } else {
            throw Error.SystemToUserAgentAudioDeviceMapError
        }
    }

    private func updateMap() {
        updateUserAgentDeviceNameToDeviceMap()
        for device in systemDevices {
            updateMapWithSystemDevice(device)
        }
    }

    private func updateUserAgentDeviceNameToDeviceMap() {
        for device in userAgentDevices {
            userAgentDeviceNameToDeviceMap[device.name] = device
        }
    }

    private func updateMapWithSystemDevice(device: SystemAudioDevice) {
        if let userAgentDevice = userAgentDeviceNameToDeviceMap[device.name] {
            map[device] = userAgentDevice
        }
    }
}
