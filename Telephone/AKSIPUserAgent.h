//
//  AKSIPUserAgent.h
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

#import <Foundation/Foundation.h>
#import <pjsua-lib/pjsua.h>

#import "AKSIPUserAgentDelegate.h"
#import "AKSIPUserAgentNotifications.h"


// User agent states.
typedef NS_ENUM(NSUInteger, AKSIPUserAgentState) {
    kAKSIPUserAgentStopped,
    kAKSIPUserAgentStarting,
    kAKSIPUserAgentStarted
};

// NAT types, as specified by RFC 3489.
typedef NS_ENUM(NSUInteger, AKNATType) {
    kAKNATTypeUnknown        = PJ_STUN_NAT_TYPE_UNKNOWN,
    kAKNATTypeErrorUnknown   = PJ_STUN_NAT_TYPE_ERR_UNKNOWN,
    kAKNATTypeOpen           = PJ_STUN_NAT_TYPE_OPEN,
    kAKNATTypeBlocked        = PJ_STUN_NAT_TYPE_BLOCKED,
    kAKNATTypeSymmetricUDP   = PJ_STUN_NAT_TYPE_SYMMETRIC_UDP,
    kAKNATTypeFullCone       = PJ_STUN_NAT_TYPE_FULL_CONE,
    kAKNATTypeSymmetric      = PJ_STUN_NAT_TYPE_SYMMETRIC,
    kAKNATTypeRestricted     = PJ_STUN_NAT_TYPE_RESTRICTED,
    kAKNATTypePortRestricted = PJ_STUN_NAT_TYPE_PORT_RESTRICTED
};

typedef struct _AKSIPUserAgentCallData {
    pj_timer_entry timer;
    pj_bool_t ringbackOn;
    pj_bool_t ringbackOff;
} AKSIPUserAgentCallData;

// An invalid identifier for all sorts of identifiers.
extern const NSInteger kAKSIPUserAgentInvalidIdentifier;

@class AKSIPAccount, AKSIPCall;

// The AKSIPUserAgent class implements SIP User Agent functionality. You can use it to create, configure, and start user
// agent, add and remove accounts, and set sound devices for input and output. You need to restart the user agent after
// you change its properties when it is already running.
@interface AKSIPUserAgent : NSObject {
  @private
    AKSIPUserAgentCallData _callData[PJSUA_MAX_CALLS];
}

// The receiver's delegate.
@property(nonatomic, weak) id <AKSIPUserAgentDelegate> delegate;

// Accounts added to the receiver.
@property(nonatomic, readonly, strong) NSMutableArray *accounts;

// A Boolean value indicating whether the receiver has been started.
@property(nonatomic, readonly, assign, getter=isStarted) BOOL started;

// Receiver's state.
@property(readonly, assign) AKSIPUserAgentState state;

// NAT type that has been detected by the receiver.
@property(nonatomic, assign) AKNATType detectedNATType;

// A lock that is used to start and stop the receiver.
@property(strong) NSLock *pjsuaLock;

// The number of acitve calls controlled by the receiver.
@property(nonatomic, readonly, assign) NSUInteger activeCallsCount;

// Receiver's call data.
@property(nonatomic, readonly, assign) AKSIPUserAgentCallData *callData;

// A pool used by the underlying PJSUA library of the receiver.
@property(readonly, assign) pj_pool_t *pjPool;

// An array of DNS servers to use by the receiver. If set, DNS SRV will be
// enabled. Only first kAKSIPUserAgentNameserversMax are used.
@property(nonatomic, copy) NSArray *nameservers;

// SIP proxy host to visit for all outgoing requests. Will be used for all
// accounts. The final route set for outgoing requests consists of this proxy
// and proxy configured for the account.
@property(nonatomic, copy) NSString *outboundProxyHost;

// Network port to use with the outbound proxy.
// Default: 5060.
@property(nonatomic, assign) NSUInteger outboundProxyPort;

// STUN server host.
@property(nonatomic, copy) NSString *STUNServerHost;

// Network port to use with the STUN server.
// Default: 3478.
@property(nonatomic, assign) NSUInteger STUNServerPort;

// User agent string.
@property(nonatomic, copy) NSString *userAgentString;

// Path to the log file.
@property(nonatomic, copy) NSString *logFileName;

// Verbosity level.
// Default: 3.
@property(nonatomic, assign) NSUInteger logLevel;

// Verbosity leverl for console.
// Default: 0.
@property(nonatomic, assign) NSUInteger consoleLogLevel;

// A Boolean value indicating whether Voice Activity Detection is used.
// Default: YES.
@property(nonatomic, assign) BOOL detectsVoiceActivity;

// A Boolean value indicating whether Interactive Connectivity Establishment
// is used.
// Default: NO.
@property(nonatomic, assign) BOOL usesICE;

// Network port to use for SIP transport. Set 0 for any available port.
// Default: 0.
@property(nonatomic, assign) NSUInteger transportPort;

// Host name or IP address to advertise as the address of SIP transport.
@property(nonatomic, copy) NSString *transportPublicHost;

/// A Boolean value indicating if only G.711 codec is used.
@property(nonatomic, assign) BOOL usesG711Only;


// Returns the shared SIP user agent object.
+ (AKSIPUserAgent *)sharedUserAgent;

// Designated initializer. Initializes a SIP user agent and sets its delegate.
- (instancetype)initWithDelegate:(id<AKSIPUserAgentDelegate>)aDelegate;

// Starts user agent.
- (void)start;

// Stops user agent.
- (void)stop;

// Adds an account to the user agent.
- (BOOL)addAccount:(AKSIPAccount *)anAccount withPassword:(NSString *)aPassword;

// Removes an account from the user agent.
- (BOOL)removeAccount:(AKSIPAccount *)account;

// Returns a SIP account with a given identifier.
- (AKSIPAccount *)accountByIdentifier:(NSInteger)anIdentifier;

// Returns a SIP call with a given identifier.
- (AKSIPCall *)SIPCallByIdentifier:(NSInteger)anIdentifier;

// Hangs up all calls controlled by the receiver.
- (void)hangUpAllCalls;

// Starts local ringback sound for the specified call.
- (void)startRingbackForCall:(AKSIPCall *)call;

// Stops local ringback sound for the specified call.
- (void)stopRingbackForCall:(AKSIPCall *)call;

// Sets sound input and output.
- (BOOL)setSoundInputDevice:(NSInteger)input
          soundOutputDevice:(NSInteger)output;

// Stops sound.
- (BOOL)stopSound;

// Updates list of audio devices.
// You might want to call this method when system audio devices are changed. After calling this method,
// |setSoundInputDevice:soundOutputDevice:| must be called to set appropriate sound IO.
- (void)updateAudioDevices;

// Returns a string that describes given SIP response code from RFC 3261.
- (NSString *)stringForSIPResponseCode:(NSInteger)responseCode;

@end
