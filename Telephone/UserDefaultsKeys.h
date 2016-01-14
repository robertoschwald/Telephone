//
//  UserDefaultsKeys.h
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

@import Foundation;
@import UseCases;

extern NSString * const kAccounts;
extern NSString * const kSTUNServerHost;
extern NSString * const kSTUNServerPort;
extern NSString * const kSTUNDomain;
extern NSString * const kLogFileName;
extern NSString * const kLogLevel;
extern NSString * const kConsoleLogLevel;
extern NSString * const kVoiceActivityDetection;
extern NSString * const kTransportPort;
extern NSString * const kTransportPublicHost;
extern NSString * const kRingingSound;
extern NSString * const kFormatTelephoneNumbers;
extern NSString * const kTelephoneNumberFormatterSplitsLastFourDigits;
extern NSString * const kOutboundProxyHost;
extern NSString * const kOutboundProxyPort;
extern NSString * const kUseICE;
extern NSString * const kUseDNSSRV;
extern NSString * const kSignificantPhoneNumberLength;
extern NSString * const kPauseITunes;
extern NSString * const kAutoCloseCallWindow;
extern NSString * const kAutoCloseMissedCallWindow;
extern NSString * const kCallWaiting;
extern NSString * const kShowGrowlNotifications;
extern NSString * const kUseG711Only;

// Account keys
extern NSString * const kDescription;
extern NSString * const kFullName;
extern NSString * const kSIPAddress;
extern NSString * const kRegistrar;
extern NSString * const kDomain;
extern NSString * const kRealm;
extern NSString * const kUsername;
extern NSString * const kAccountIndex;
extern NSString * const kAccountEnabled;
extern NSString * const kReregistrationTime;
extern NSString * const kSubstitutePlusCharacter;
extern NSString * const kPlusCharacterSubstitutionString;
extern NSString * const kUseProxy;
extern NSString * const kProxyHost;
extern NSString * const kProxyPort;
extern NSString * const kUpdateContactHeader;
extern NSString * const kUpdateViaHeader;
