//
//  AppController.m
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

#import "AppController.h"

@import SystemConfiguration;
@import UseCases;

#import "AKAddressBookPhonePlugIn.h"
#import "AKAddressBookSIPAddressPlugIn.h"
#import "AKNetworkReachability.h"
#import "AKNSString+Scanning.h"
#import "AKSIPAccount.h"
#import "AKSIPCall.h"

#import "AccountController.h"
#import "AccountPreferencesViewController.h"
#import "AccountSetupController.h"
#import "ActiveAccountViewController.h"
#import "AuthenticationFailureController.h"
#import "CallController.h"
#import "PreferencesController.h"
#import "UserDefaultsKeys.h"

#import "Telephone-Swift.h"


NSString * const kUserNotificationCallControllerIdentifierKey = @"UserNotificationCallControllerIdentifier";

// Bouncing icon in the Dock time interval.
static const NSTimeInterval kUserAttentionRequestInterval = 8.0;

// Delay for restarting user agent when DNS servers change.
static const NSTimeInterval kUserAgentRestartDelayAfterDNSChange = 3.0;

// Dynamic store key to the global DNS settings.
static NSString * const kDynamicStoreDNSSettings = @"State:/Network/Global/DNS";

// Dynamic store callback for DNS changes.
static void NameserversChanged(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info);

NS_ASSUME_NONNULL_BEGIN

@interface AppController () <AKSIPUserAgentDelegate, NSUserNotificationCenterDelegate, PreferencesControllerDelegate>

@property(nonatomic, readonly) AKSIPUserAgent *userAgent;
@property(nonatomic, readonly) NSMutableArray *accountControllers;
@property(nonatomic, readonly) AccountSetupController *accountSetupController;
@property(nonatomic) BOOL shouldRegisterAllAccounts;
@property(nonatomic) BOOL shouldRestartUserAgentASAP;
@property(nonatomic, getter=isTerminating) BOOL terminating;
@property(nonatomic) BOOL shouldPresentUserAgentLaunchError;
@property(nonatomic, nullable) NSTimer *userAttentionTimer;
@property(nonatomic) NSArray *accountsMenuItems;
@property(nonatomic, weak) IBOutlet NSMenu *windowMenu;
@property(nonatomic, weak) IBOutlet NSMenuItem *preferencesMenuItem;

@property(nonatomic, readonly) CompositionRoot *compositionRoot;
@property(nonatomic, readonly) PreferencesController *preferencesController;
@property(nonatomic, readonly) id<RingtonePlaybackUseCase> ringtonePlayback;
@property(nonatomic, readonly) id<MusicPlayer> musicPlayer;
@property(nonatomic, readonly) id<ApplicationDataLocations> locations;
@property(nonatomic, readonly) WorkspaceSleepStatus *sleepStatus;
@property(nonatomic, readonly) AsyncCallHistoryViewEventTargetFactory *factory;
@property(nonatomic, getter=isFinishedLaunching) BOOL finishedLaunching;
@property(nonatomic, copy) NSString *destinationToCall;
@property(nonatomic, getter=isUserSessionActive) BOOL userSessionActive;

@end

NS_ASSUME_NONNULL_END


@implementation AppController

@synthesize accountSetupController = _accountSetupController;

- (NSArray *)enabledAccountControllers {
    return [[self accountControllers] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"enabled == YES"]];
}

- (AccountSetupController *)accountSetupController {
    if (_accountSetupController == nil) {
        _accountSetupController = [[AccountSetupController alloc] init];
    }
    return _accountSetupController;
}

- (BOOL)hasIncomingCallControllers {
    for (AccountController *accountController in [self enabledAccountControllers]) {
        for (CallController *callController in [accountController callControllers]) {
            if ([[callController call] identifier] != kAKSIPUserAgentInvalidIdentifier &&
                [[callController call] isIncoming] &&
                [callController isCallActive] &&
                ([[callController call] state] == kAKSIPCallIncomingState ||
                 [[callController call] state] == kAKSIPCallEarlyState)) {
                    return YES;
                }
        }
    }
    
    return NO;
}

- (BOOL)hasActiveCallControllers {
    for (AccountController *accountController in [self enabledAccountControllers]) {
        for (CallController *callController in [accountController callControllers]) {
            if ([callController isCallActive]) {
                return YES;
            }
        }
    }
    
    return NO;
}

- (NSArray *)currentNameservers {
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *bundleName = [mainBundle infoDictionary][@"CFBundleName"];
    
    SCDynamicStoreRef dynamicStore = SCDynamicStoreCreate(NULL, (__bridge CFStringRef)bundleName, NULL, NULL);
    
    CFPropertyListRef DNSSettings = SCDynamicStoreCopyValue(dynamicStore,
                                                            (__bridge CFStringRef)kDynamicStoreDNSSettings);
    
    NSArray *nameservers = nil;
    if (DNSSettings != NULL) {
        nameservers = ((__bridge NSDictionary *)DNSSettings)[@"ServerAddresses"];
        
        CFRelease(DNSSettings);
    }
    
    CFRelease(dynamicStore);
    
    return nameservers;
}

- (NSUInteger)unhandledIncomingCallsCount {
    NSUInteger count = 0;
    for (AccountController *accountController in [self enabledAccountControllers]) {
        for (CallController *callController in [accountController callControllers]) {
            if ([[callController call] isIncoming] && [callController isCallUnhandled]) {
                ++count;
            }
        }
    }
    
    return count;
}

+ (void)initialize {
    // Register defaults.
    static BOOL initialized = NO;
    
    if (!initialized) {
        NSMutableDictionary *defaultsDict = [NSMutableDictionary dictionary];
        
        defaultsDict[kUseDNSSRV] = @NO;
        defaultsDict[kOutboundProxyHost] = @"";
        defaultsDict[kOutboundProxyPort] = @0;
        defaultsDict[kSTUNServerHost] = @"";
        defaultsDict[kSTUNServerPort] = @0;
        defaultsDict[kVoiceActivityDetection] = @NO;
        defaultsDict[kUseICE] = @NO;
        defaultsDict[kLogLevel] = @3;
        defaultsDict[kConsoleLogLevel] = @0;
        defaultsDict[kTransportPort] = @0;
        defaultsDict[kTransportPublicHost] = @"";
        defaultsDict[kRingingSound] = @"Purr";
        defaultsDict[kSignificantPhoneNumberLength] = @9;
        defaultsDict[kAutoCloseCallWindow] = @NO;
        defaultsDict[kAutoCloseMissedCallWindow] = @NO;
        defaultsDict[kCallWaiting] = @YES;
        defaultsDict[kUseG711Only] = @NO;

        NSString *preferredLocalization = [[NSBundle mainBundle] preferredLocalizations][0];
        
        // Do not format phone numbers in German localization by default.
        if ([preferredLocalization isEqualToString:@"de"]) {
            defaultsDict[kFormatTelephoneNumbers] = @NO;
        } else {
            defaultsDict[kFormatTelephoneNumbers] = @YES;
        }
        
        // Split last four digits in Russian localization by default.
        if ([preferredLocalization isEqualToString:@"ru"]) {
            defaultsDict[kTelephoneNumberFormatterSplitsLastFourDigits] = @YES;
        } else {
            defaultsDict[kTelephoneNumberFormatterSplitsLastFourDigits] = @NO;
        }
        
        [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDict];
        
        initialized = YES;
    }
}

- (instancetype)init {
    self = [super init];
    if (self == nil) {
        return nil;
    }

    _compositionRoot = [[CompositionRoot alloc] initWithPreferencesControllerDelegate:self conditionalRingtonePlaybackUseCaseDelegate:self];
    
    _userAgent = _compositionRoot.userAgent;
    [[self userAgent] setDelegate:self];
    _preferencesController = _compositionRoot.preferencesController;
    _ringtonePlayback = _compositionRoot.ringtonePlayback;
    _musicPlayer = _compositionRoot.musicPlayer;
    _locations = _compositionRoot.applicationDataLocations;
    _sleepStatus = _compositionRoot.workstationSleepStatus;
    _factory = _compositionRoot.callHistoryViewEventTargetFactory;
    _destinationToCall = @"";
    _userSessionActive = YES;
    _accountControllers = [[NSMutableArray alloc] init];
    _accountsMenuItems = @[];

    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    
    [notificationCenter addObserver:self
                           selector:@selector(accountSetupControllerDidAddAccount:)
                               name:AKAccountSetupControllerDidAddAccountNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(SIPCallCalling:)
                               name:AKSIPCallCallingNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(SIPCallIncoming:)
                               name:AKSIPCallIncomingNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(SIPCallConnecting:)
                               name:AKSIPCallConnectingNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(SIPCallDidDisconnect:)
                               name:AKSIPCallDidDisconnectNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(authenticationFailureControllerDidChangeUsernameAndPassword:)
                               name:AKAuthenticationFailureControllerDidChangeUsernameAndPasswordNotification
                             object:nil];
    
    notificationCenter = [[NSWorkspace sharedWorkspace] notificationCenter];
    [notificationCenter addObserver:self
                           selector:@selector(workspaceWillSleep:)
                               name:NSWorkspaceWillSleepNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(workspaceDidWake:)
                               name:NSWorkspaceDidWakeNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(workspaceSessionDidResignActive:)
                               name:NSWorkspaceSessionDidResignActiveNotification
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(workspaceSessionDidBecomeActive:)
                               name:NSWorkspaceSessionDidBecomeActiveNotification
                             object:nil];
    
    NSDistributedNotificationCenter *distributedNotificationCenter = [NSDistributedNotificationCenter defaultCenter];
    
    [distributedNotificationCenter addObserver:self
                                      selector:@selector(addressBookDidDialCallDestination:)
                                          name:AKAddressBookDidDialPhoneNumberNotification
                                        object:@"AddressBook"
                            suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
    
    [distributedNotificationCenter addObserver:self
                                      selector:@selector(addressBookDidDialCallDestination:)
                                          name:AKAddressBookDidDialSIPAddressNotification
                                        object:@"AddressBook"
                            suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
    
    [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self
                                                       andSelector:@selector(handleGetURLEvent:withReplyEvent:)
                                                     forEventClass:kInternetEventClass
                                                        andEventID:kAEGetURL];
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
}

- (void)stopUserAgent {
    [self hangUpCallsAndRemoveAccountsFromUserAgent];
    [self.userAgent stop];
}

- (void)stopUserAgentAndWait {
    [self hangUpCallsAndRemoveAccountsFromUserAgent];
    [self.userAgent stopAndWait];
}

- (void)hangUpCallsAndRemoveAccountsFromUserAgent {
    for (AccountController *accountController in self.enabledAccountControllers) {
        for (CallController *callController in accountController.callControllers) {
            [callController hangUpCall];
        }
        [accountController removeAccountFromUserAgent];
    }
}

- (void)restartUserAgent {
    if ([[self userAgent] isStarted]) {
        [self setShouldRegisterAllAccounts:YES];
        [self stopUserAgent];
    }
}

- (IBAction)showStoreWindow:(id)sender {
    [self.compositionRoot.storeWindowController showWindowCentered];
}

- (IBAction)showPreferencePanel:(id)sender {
    if (![[[self preferencesController] window] isVisible]) {
        [[[self preferencesController] window] center];
    }
    
    [[self preferencesController] showWindow:nil];
}

- (IBAction)addAccountOnFirstLaunch:(id)sender {
    [[self accountSetupController] addAccount:sender];
    
    if ([[[[self accountSetupController] fullNameField] stringValue] length] > 0 &&
        [[[[self accountSetupController] domainField] stringValue] length] > 0 &&
        [[[[self accountSetupController] usernameField] stringValue] length] > 0 &&
        [[[[self accountSetupController] passwordField] stringValue] length] > 0) {
        // Re-enable Preferences.
        [[self preferencesMenuItem] setAction:@selector(showPreferencePanel:)];
        
        // Change back targets and actions of addAccountWindow buttons.
        [[[self accountSetupController] defaultButton] setTarget:[self accountSetupController]];
        [[[self accountSetupController] defaultButton] setAction:@selector(addAccount:)];
        [[[self accountSetupController] otherButton] setTarget:[self accountSetupController]];
        [[[self accountSetupController] otherButton] setAction:@selector(closeSheet:)];
        
        [NSUserNotificationCenter defaultUserNotificationCenter].delegate = self;
        [self installDNSChangesCallback];
    }
}

- (BOOL)canStopPlayingRingtone {
    return ![self hasIncomingCallControllers];
}

- (void)startUserAttentionTimer {
    if ([self userAttentionTimer] != nil) {
        [[self userAttentionTimer] invalidate];
    }
    
    [self setUserAttentionTimer:[NSTimer scheduledTimerWithTimeInterval:kUserAttentionRequestInterval
                                                                 target:self
                                                               selector:@selector(requestUserAttentionTick:)
                                                               userInfo:nil
                                                                repeats:YES]];
}

- (void)stopUserAttentionTimerIfNeeded {
    if (![self hasIncomingCallControllers] && [self userAttentionTimer] != nil) {
        [[self userAttentionTimer] invalidate];
        [self setUserAttentionTimer:nil];
    }
}

- (void)requestUserAttentionTick:(NSTimer *)theTimer {
    [NSApp requestUserAttention:NSInformationalRequest];
}

- (CallController *)callControllerByIdentifier:(NSString *)identifier {
    for (AccountController *accountController in [self enabledAccountControllers]) {
        for (CallController *callController in [accountController callControllers]) {
            if ([[callController identifier] isEqualToString:identifier]) {
                return callController;
            }
        }
    }
    
    return nil;
}

- (void)updateAccountsMenuItems {
    // Remove old menu items.
    for (NSMenuItem *menuItem in [self accountsMenuItems]) {
        [[self windowMenu] removeItem:menuItem];
    }
    
    // Create new menu items.
    NSArray *enabledControllers = [self enabledAccountControllers];
    NSMutableArray *itemsArray = [NSMutableArray arrayWithCapacity:[enabledControllers count]];
    NSUInteger accountNumber = 1;
    for (AccountController *accountController in enabledControllers) {
        NSMenuItem *menuItem = [[NSMenuItem alloc] init];
        [menuItem setRepresentedObject:accountController];
        [menuItem setAction:@selector(toggleAccountWindow:)];
        [menuItem setTitle:[accountController accountDescription]];
        if (accountNumber < 10) {
            // Only add key equivalents for Command-[1..9].
            [menuItem setKeyEquivalent:[NSString stringWithFormat:@"%lu", accountNumber]];
        }
        [itemsArray addObject:menuItem];
        accountNumber++;
    }
    if ([itemsArray count] > 0) {
        [itemsArray insertObject:[NSMenuItem separatorItem] atIndex:0];
    }
    [self setAccountsMenuItems:itemsArray];
    
    // Add menu items to the Window menu.
    NSUInteger itemTag = 4;
    for (NSMenuItem *menuItem in itemsArray) {
        [[self windowMenu] insertItem:menuItem atIndex:itemTag];
        itemTag++;
    }
}

- (IBAction)toggleAccountWindow:(id)sender {
    AccountController *accountController = [sender representedObject];
    if ([[accountController window] isKeyWindow]) {
        [[accountController window] performClose:self];
    } else {
        [[accountController window] makeKeyAndOrderFront:self];
    }
}

- (void)updateDockTileBadgeLabel {
    NSString *badgeString;
    NSUInteger badgeNumber = [self unhandledIncomingCallsCount];
    if (badgeNumber == 0) {
        badgeString = @"";
    } else {
        badgeString = [NSString stringWithFormat:@"%lu", badgeNumber];
    }
    
    [[NSApp dockTile] setBadgeLabel:badgeString];
}

- (void)installDNSChangesCallback {
    NSString *bundleName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    SCDynamicStoreRef dynamicStore = SCDynamicStoreCreate(kCFAllocatorDefault,
                                                          (__bridge CFStringRef)bundleName,
                                                          &NameserversChanged,
                                                          NULL);
    
    NSArray *keys = @[kDynamicStoreDNSSettings];
    SCDynamicStoreSetNotificationKeys(dynamicStore, (__bridge CFArrayRef)keys, NULL);
    
    CFRunLoopSourceRef runLoopSource = SCDynamicStoreCreateRunLoopSource(kCFAllocatorDefault, dynamicStore, 0);
    
    CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, kCFRunLoopDefaultMode);
    CFRelease(runLoopSource);
    CFRelease(dynamicStore);
}

- (void)updateCallsShouldDisplayAccountInfo {
    NSUInteger enabledCount = [self.enabledAccountControllers count];
    BOOL shouldDisplay = enabledCount > 1;
    for (AccountController *accountController in self.accountControllers) {
        accountController.callsShouldDisplayAccountInfo = shouldDisplay;
    }
}

- (void)remindAboutPurchasingAfterDelay {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.compositionRoot.purchaseReminder execute];
    });
}

- (void)optOutOfAutomaticWindowTabbing {
    if ([NSWindow respondsToSelector:@selector(allowsAutomaticWindowTabbing)]) {
        NSWindow.allowsAutomaticWindowTabbing = NO;
    }
}

- (NSString *)localizedStringForSIPResponseCode:(NSInteger)responseCode {
    NSString *localizedString = nil;
    
    switch (responseCode) {
            // Provisional 1xx.
        case PJSIP_SC_TRYING:
            localizedString = NSLocalizedStringFromTable(@"Trying", @"SIPResponses", @"100 Trying.");
            break;
        case PJSIP_SC_RINGING:
            localizedString = NSLocalizedStringFromTable(@"Ringing", @"SIPResponses", @"180 Ringing.");
            break;
        case PJSIP_SC_CALL_BEING_FORWARDED:
            localizedString = NSLocalizedStringFromTable(@"Call Is Being Forwarded",
                                                         @"SIPResponses",
                                                         @"181 Call Is Being Forwarded.");
            break;
        case PJSIP_SC_QUEUED:
            localizedString = NSLocalizedStringFromTable(@"Queued", @"SIPResponses", @"182 Queued.");
            break;
        case PJSIP_SC_PROGRESS:
            localizedString
                = NSLocalizedStringFromTable(@"Session Progress", @"SIPResponses", @"183 Session Progress.");
            break;
            
            // Successful 2xx.
        case PJSIP_SC_OK:
            localizedString = NSLocalizedStringFromTable(@"OK", @"SIPResponses", @"200 OK.");
            break;
        case PJSIP_SC_ACCEPTED:
            localizedString = NSLocalizedStringFromTable(@"Accepted", @"SIPResponses", @"202 Accepted.");
            break;
            
            // Redirection 3xx.
        case PJSIP_SC_MULTIPLE_CHOICES:
            localizedString
                = NSLocalizedStringFromTable(@"Multiple Choices", @"SIPResponses", @"300 Multiple Choices.");
            break;
        case PJSIP_SC_MOVED_PERMANENTLY:
            localizedString
                = NSLocalizedStringFromTable(@"Moved Permanently", @"SIPResponses", @"301 Moved Permanently.");
            break;
        case PJSIP_SC_MOVED_TEMPORARILY:
            localizedString
                = NSLocalizedStringFromTable(@"Moved Temporarily", @"SIPResponses", @"302 Moved Temporarily.");
            break;
        case PJSIP_SC_USE_PROXY:
            localizedString = NSLocalizedStringFromTable(@"Use Proxy", @"SIPResponses", @"305 Use Proxy.");
            break;
        case PJSIP_SC_ALTERNATIVE_SERVICE:
            localizedString
                = NSLocalizedStringFromTable(@"Alternative Service", @"SIPResponses", @"380 Alternative Service.");
            break;
            
            // Request Failure 4xx.
        case PJSIP_SC_BAD_REQUEST:
            localizedString = NSLocalizedStringFromTable(@"Bad Request", @"SIPResponses", @"400 Bad Request.");
            break;
        case PJSIP_SC_UNAUTHORIZED:
            localizedString = NSLocalizedStringFromTable(@"Unauthorized", @"SIPResponses", @"401 Unauthorized.");
            break;
        case PJSIP_SC_PAYMENT_REQUIRED:
            localizedString
                = NSLocalizedStringFromTable(@"Payment Required", @"SIPResponses", @"402 Payment Required.");
            break;
        case PJSIP_SC_FORBIDDEN:
            localizedString = NSLocalizedStringFromTable(@"Forbidden", @"SIPResponses", @"403 Forbidden.");
            break;
        case PJSIP_SC_NOT_FOUND:
            localizedString = NSLocalizedStringFromTable(@"Not Found", @"SIPResponses", @"404 Not Found.");
            break;
        case PJSIP_SC_METHOD_NOT_ALLOWED:
            localizedString
                = NSLocalizedStringFromTable(@"Method Not Allowed", @"SIPResponses", @"405 Method Not Allowed.");
            break;
        case PJSIP_SC_NOT_ACCEPTABLE:
            localizedString = NSLocalizedStringFromTable(@"Not Acceptable", @"SIPResponses", @"406 Not Acceptable.");
            break;
        case PJSIP_SC_PROXY_AUTHENTICATION_REQUIRED:
            localizedString = NSLocalizedStringFromTable(@"Proxy Authentication Required",
                                                         @"SIPResponses",
                                                         @"407 Proxy Authentication Required.");
            break;
        case PJSIP_SC_REQUEST_TIMEOUT:
            localizedString = NSLocalizedStringFromTable(@"Request Timeout", @"SIPResponses", @"408 Request Timeout.");
            break;
        case PJSIP_SC_GONE:
            localizedString = NSLocalizedStringFromTable(@"Gone", @"SIPResponses", @"410 Gone.");
            break;
        case PJSIP_SC_REQUEST_ENTITY_TOO_LARGE:
            localizedString = NSLocalizedStringFromTable(@"Request Entity Too Large",
                                                         @"SIPResponses",
                                                         @"413 Request Entity Too Large.");
            break;
        case PJSIP_SC_REQUEST_URI_TOO_LONG:
            localizedString
                = NSLocalizedStringFromTable(@"Request-URI Too Long", @"SIPResponses", @"414 Request-URI Too Long.");
            break;
        case PJSIP_SC_UNSUPPORTED_MEDIA_TYPE:
            localizedString = NSLocalizedStringFromTable(@"Unsupported Media Type",
                                                         @"SIPResponses",
                                                         @"415 Unsupported Media Type.");
            break;
        case PJSIP_SC_UNSUPPORTED_URI_SCHEME:
            localizedString = NSLocalizedStringFromTable(@"Unsupported URI Scheme",
                                                         @"SIPResponses",
                                                         @"416 Unsupported URI Scheme.");
            break;
        case PJSIP_SC_BAD_EXTENSION:
            localizedString = NSLocalizedStringFromTable(@"Bad Extension", @"SIPResponses", @"420 Bad Extension.");
            break;
        case PJSIP_SC_EXTENSION_REQUIRED:
            localizedString
                = NSLocalizedStringFromTable(@"Extension Required", @"SIPResponses", @"421 Extension Required.");
            break;
        case PJSIP_SC_SESSION_TIMER_TOO_SMALL:
            localizedString = NSLocalizedStringFromTable(@"Session Timer Too Small",
                                                         @"SIPResponses",
                                                         @"422 Session Timer Too Small.");
            break;
        case PJSIP_SC_INTERVAL_TOO_BRIEF:
            localizedString
                = NSLocalizedStringFromTable(@"Interval Too Brief", @"SIPResponses", @"423 Interval Too Brief.");
            break;
        case PJSIP_SC_TEMPORARILY_UNAVAILABLE:
            localizedString = NSLocalizedStringFromTable(@"Temporarily Unavailable",
                                                        @"SIPResponses",
                                                         @"480 Temporarily Unavailable.");
            break;
        case PJSIP_SC_CALL_TSX_DOES_NOT_EXIST:
            localizedString = NSLocalizedStringFromTable(@"Call/Transaction Does Not Exist",
                                                         @"SIPResponses",
                                                         @"481 Call/Transaction Does Not Exist.");
            break;
        case PJSIP_SC_LOOP_DETECTED:
            localizedString = NSLocalizedStringFromTable(@"Loop Detected", @"SIPResponses", @"482 Loop Detected.");
            break;
        case PJSIP_SC_TOO_MANY_HOPS:
            localizedString = NSLocalizedStringFromTable(@"Too Many Hops", @"SIPResponses", @"483 Too Many Hops.");
            break;
        case PJSIP_SC_ADDRESS_INCOMPLETE:
            localizedString
                = NSLocalizedStringFromTable(@"Address Incomplete", @"SIPResponses", @"484 Address Incomplete.");
            break;
        case PJSIP_AC_AMBIGUOUS:
            localizedString = NSLocalizedStringFromTable(@"Ambiguous", @"SIPResponses", @"485 Ambiguous.");
            break;
        case PJSIP_SC_BUSY_HERE:
            localizedString = NSLocalizedStringFromTable(@"Busy Here", @"SIPResponses", @"486 Busy Here.");
            break;
        case PJSIP_SC_REQUEST_TERMINATED:
            localizedString
                = NSLocalizedStringFromTable(@"Request Terminated", @"SIPResponses", @"487 Request Terminated.");
            break;
        case PJSIP_SC_NOT_ACCEPTABLE_HERE:
            localizedString
                = NSLocalizedStringFromTable(@"Not Acceptable Here", @"SIPResponses", @"488 Not Acceptable Here.");
            break;
        case PJSIP_SC_BAD_EVENT:
            localizedString = NSLocalizedStringFromTable(@"Bad Event", @"SIPResponses", @"489 Bad Event.");
            break;
        case PJSIP_SC_REQUEST_UPDATED:
            localizedString = NSLocalizedStringFromTable(@"Request Updated", @"SIPResponses", @"490 Request Updated.");
            break;
        case PJSIP_SC_REQUEST_PENDING:
            localizedString = NSLocalizedStringFromTable(@"Request Pending", @"SIPResponses", @"491 Request Pending.");
            break;
        case PJSIP_SC_UNDECIPHERABLE:
            localizedString = NSLocalizedStringFromTable(@"Undecipherable", @"SIPResponses", @"493 Undecipherable.");
            break;
            
            // Server Failure 5xx.
        case PJSIP_SC_INTERNAL_SERVER_ERROR:
            localizedString
                = NSLocalizedStringFromTable(@"Server Internal Error", @"SIPResponses", @"500 Server Internal Error.");
            break;
        case PJSIP_SC_NOT_IMPLEMENTED:
            localizedString = NSLocalizedStringFromTable(@"Not Implemented", @"SIPResponses", @"501 Not Implemented.");
            break;
        case PJSIP_SC_BAD_GATEWAY:
            localizedString = NSLocalizedStringFromTable(@"Bad Gateway", @"SIPResponses", @"502 Bad Gateway.");
            break;
        case PJSIP_SC_SERVICE_UNAVAILABLE:
            localizedString
                = NSLocalizedStringFromTable(@"Service Unavailable", @"SIPResponses", @"503 Service Unavailable.");
            break;
        case PJSIP_SC_SERVER_TIMEOUT:
            localizedString = NSLocalizedStringFromTable(@"Server Time-out", @"SIPResponses", @"504 Server Time-out.");
            break;
        case PJSIP_SC_VERSION_NOT_SUPPORTED:
            localizedString
                = NSLocalizedStringFromTable(@"Version Not Supported", @"SIPResponses", @"505 Version Not Supported.");
            break;
        case PJSIP_SC_MESSAGE_TOO_LARGE:
            localizedString
                = NSLocalizedStringFromTable(@"Message Too Large", @"SIPResponses", @"513 Message Too Large.");
            break;
        case PJSIP_SC_PRECONDITION_FAILURE:
            localizedString
                = NSLocalizedStringFromTable(@"Precondition Failure", @"SIPResponses", @"580 Precondition Failure.");
            break;
            
            // Global Failures 6xx.
        case PJSIP_SC_BUSY_EVERYWHERE:
            localizedString = NSLocalizedStringFromTable(@"Busy Everywhere", @"SIPResponses", @"600 Busy Everywhere.");
            break;
        case PJSIP_SC_DECLINE:
            localizedString = NSLocalizedStringFromTable(@"Decline", @"SIPResponses", @"603 Decline.");
            break;
        case PJSIP_SC_DOES_NOT_EXIST_ANYWHERE:
            localizedString = NSLocalizedStringFromTable(@"Does Not Exist Anywhere",
                                                         @"SIPResponses",
                                                         @"604 Does Not Exist Anywhere.");
            break;
        case PJSIP_SC_NOT_ACCEPTABLE_ANYWHERE:
            localizedString = NSLocalizedStringFromTable(@"Not Acceptable", @"SIPResponses", @"606 Not Acceptable.");
            break;
        default:
            localizedString = nil;
            break;
    }
    
    return localizedString;
}


#pragma mark - Account registration

- (void)registerAllAccounts {
    for (AccountController *controller in [self enabledAccountControllers]) {
        [controller registerAccount];
    }
}

- (void)registerReachableAccounts {
    for (AccountController *controller in [self enabledAccountControllers]) {
        if ([[controller registrarReachability] isReachable]) {
            [controller registerAccount];
        }
    }
}

- (void)registerAllAccountsWhereManualRegistrationRequired {
    for (AccountController *accountController in [self enabledAccountControllers]) {
        [self registerAccountIfManualRegistrationRequired:accountController];
    }
}

- (void)registerAccountIfManualRegistrationRequired:(AccountController *)controller {
    ServiceAddress *registrar = [[ServiceAddress alloc] initWithString:controller.account.registrar];
    if (registrar.host.ak_isIPAddress && [controller.registrarReachability isReachable]) {
        [controller registerAccount];
    }
}

- (void)unregisterAllAccounts {
    for (AccountController *controller in [self enabledAccountControllers]) {
        if ([controller isAccountRegistered]) {
            [controller unregisterAccount];
        }
    }
}


#pragma mark -
#pragma mark AccountSetupController delegate

- (void)accountSetupControllerDidAddAccount:(NSNotification *)notification {
    NSDictionary *dict = [notification userInfo];
    
    AKSIPAccount *account = [[AKSIPAccount alloc] initWithUUID:dict[kUUID]
                                                      fullName:dict[kFullName]
                                                    SIPAddress:dict[kSIPAddress]
                                                     registrar:dict[kDomain]
                                                         realm:dict[kRealm]
                                                      username:dict[kUsername]
                                                        domain:dict[kDomain]];
    
    AccountController *controller = [[AccountController alloc] initWithSIPAccount:account
                                                                        userAgent:self.userAgent
                                                                 ringtonePlayback:self.ringtonePlayback
                                                                      musicPlayer:self.musicPlayer
                                                                      sleepStatus:self.sleepStatus
                                                                          factory:self.factory];
    
    [controller setAccountDescription:[[controller account] SIPAddress]];
    [controller setEnabled:YES];
    
    [[self accountControllers] addObject:controller];
    [self updateCallsShouldDisplayAccountInfo];
    [self updateAccountsMenuItems];
    
    [[controller window] orderFront:self];

    [self registerAccountIfManualRegistrationRequired:controller];
}


#pragma mark -
#pragma mark PreferencesController delegate

- (void)preferencesControllerDidRemoveAccount:(NSNotification *)notification {
    NSInteger index = [[notification userInfo][kAccountIndex] integerValue];
    AccountController *controller = [self accountControllers][index];
    
    if ([controller isEnabled]) {
        [controller removeAccountFromUserAgent];
    }
    
    [[self accountControllers] removeObjectAtIndex:index];
    [self updateCallsShouldDisplayAccountInfo];
    [self updateAccountsMenuItems];
}

- (void)preferencesControllerDidChangeAccountEnabled:(NSNotification *)notification {
    NSUInteger index = [[notification userInfo][kAccountIndex] integerValue];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *savedAccounts = [defaults arrayForKey:kAccounts];
    NSDictionary *accountDict = savedAccounts[index];
    
    BOOL isEnabled = [accountDict[kAccountEnabled] boolValue];
    if (isEnabled) {
        AKSIPAccount *account = [[AKSIPAccount alloc] initWithUUID:accountDict[kUUID]
                                                          fullName:accountDict[kFullName]
                                                        SIPAddress:accountDict[kSIPAddress]
                                                         registrar:accountDict[kRegistrar]
                                                             realm:accountDict[kRealm]
                                                          username:accountDict[kUsername]
                                                            domain:accountDict[kDomain]];

        account.reregistrationTime = [accountDict[kReregistrationTime] integerValue];
        if ([accountDict[kUseProxy] boolValue]) {
            account.proxyHost = accountDict[kProxyHost];
            account.proxyPort = [accountDict[kProxyPort] integerValue];
        }
        account.updatesContactHeader = [accountDict[kUpdateContactHeader] boolValue];
        account.updatesViaHeader = [accountDict[kUpdateViaHeader] boolValue];
        
        AccountController *controller = [[AccountController alloc] initWithSIPAccount:account
                                                                            userAgent:self.userAgent
                                                                     ringtonePlayback:self.ringtonePlayback
                                                                          musicPlayer:self.musicPlayer
                                                                          sleepStatus:self.sleepStatus
                                                                              factory:self.factory];
        
        NSString *description = accountDict[kDescription];
        if ([description length] == 0) {
            description = account.SIPAddress;
        }
        [controller setAccountDescription:description];
        
        [controller setAccountUnavailable:NO];
        [controller setEnabled:YES];
        [controller setSubstitutesPlusCharacter:[accountDict[kSubstitutePlusCharacter] boolValue]];
        [controller setPlusCharacterSubstitution:accountDict[kPlusCharacterSubstitutionString]];
        
        [self accountControllers][index] = controller;
        
        [[controller window] orderFront:nil];

        [self registerAccountIfManualRegistrationRequired:controller];
        
    } else {
        AccountController *controller = [self accountControllers][index];
        
        // Close all call windows hanging up all calls.
        [[controller callControllers] makeObjectsPerformSelector:@selector(close)];
        
        // Remove account from the user agent.
        [controller removeAccountFromUserAgent];
        [controller setEnabled:NO];
        [controller setAttemptingToRegisterAccount:NO];
        [controller setAttemptingToUnregisterAccount:NO];
        [controller setShouldPresentRegistrationError:NO];
        [[controller window] orderOut:nil];
    }
    
    [self updateCallsShouldDisplayAccountInfo];
    [self updateAccountsMenuItems];
}

- (void)preferencesControllerDidSwapAccounts:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    NSInteger sourceIndex = [userInfo[kSourceIndex] integerValue];
    NSInteger destinationIndex = [userInfo[kDestinationIndex] integerValue];
    
    if (sourceIndex == destinationIndex) {
        return;
    }
    
    [[self accountControllers] insertObject:[self accountControllers][sourceIndex] atIndex:destinationIndex];
    if (sourceIndex < destinationIndex) {
        [[self accountControllers] removeObjectAtIndex:sourceIndex];
    } else if (sourceIndex > destinationIndex) {
        [[self accountControllers] removeObjectAtIndex:(sourceIndex + 1)];
    }
    
    [self updateAccountsMenuItems];
}

- (void)preferencesControllerDidChangeNetworkSettings:(NSNotification *)notification {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [[self userAgent] setTransportPort:[defaults integerForKey:kTransportPort]];
    [[self userAgent] setSTUNServerHost:[defaults stringForKey:kSTUNServerHost]];
    [[self userAgent] setSTUNServerPort:[defaults integerForKey:kSTUNServerPort]];
    [[self userAgent] setUsesICE:[defaults boolForKey:kUseICE]];
    [[self userAgent] setOutboundProxyHost:[defaults stringForKey:kOutboundProxyHost]];
    [[self userAgent] setOutboundProxyPort:[defaults integerForKey:kOutboundProxyPort]];
    
    if ([defaults boolForKey:kUseDNSSRV]) {
        [[self userAgent] setNameservers:[self currentNameservers]];
    } else {
        [[self userAgent] setNameservers:nil];
    }
    
    // Restart SIP user agent.
    if ([[self userAgent] isStarted]) {
        [self setShouldPresentUserAgentLaunchError:YES];
        [self restartUserAgent];
    }
}


#pragma mark -
#pragma mark AKSIPUserAgentDelegate

- (BOOL)SIPUserAgentShouldAddAccount:(AKSIPAccount *)account {
    if (self.userAgent.isStarted) {
        return YES;
    } else {
        if (self.userAgent.state == AKSIPUserAgentStateStopped) {
            [self.userAgent start];
        }
        return NO;
    }
}

- (void)SIPUserAgentDidFinishStarting:(NSNotification *)notification {
    if ([[self userAgent] isStarted]) {
        if ([self shouldRegisterAllAccounts]) {
            [self registerAllAccounts];
        }
        
        [self setShouldRegisterAllAccounts:NO];
        [self setShouldRestartUserAgentASAP:NO];
        
    } else {
        NSLog(@"Could not start SIP user agent. "
              "Please check your network connection and STUN server settings.");
        
        [self setShouldRegisterAllAccounts:NO];
        
        // Set |shouldPresentUserAgentLaunchError| if needed and if it wasn't set
        // somewhere else.
        if (![self shouldPresentUserAgentLaunchError]) {
            // Check whether any AccountController is trying to register or unregister
            // an acount. If so, we should present SIP user agent launch error.
            for (AccountController *accountController in [self enabledAccountControllers]) {
                if ([accountController shouldPresentRegistrationError]) {
                    [self setShouldPresentUserAgentLaunchError:YES];
                    [accountController setAttemptingToRegisterAccount:NO];
                    [accountController setAttemptingToUnregisterAccount:NO];
                    [accountController setShouldPresentRegistrationError:NO];
                }
            }
        }
        
        if ([self shouldPresentUserAgentLaunchError] && [NSApp modalWindow] == nil) {
            // Display application modal alert.
            NSAlert *alert = [[NSAlert alloc] init];
            [alert addButtonWithTitle:@"OK"];
            [alert setMessageText:NSLocalizedString(@"Could not start SIP user agent.",
                                                    @"SIP user agent start error.")];
            [alert setInformativeText:
             NSLocalizedString(@"Please check your network connection and STUN server settings.",
                               @"SIP user agent start error informative text.")];
            [alert runModal]; 
        }
    }
    
    [self setShouldPresentUserAgentLaunchError:NO];
}

- (void)SIPUserAgentDidFinishStopping:(NSNotification *)notification {
    if ([self isTerminating]) {
        [NSApp replyToApplicationShouldTerminate:YES];
        
    } else if ([self shouldRegisterAllAccounts]) {
        if ([[self enabledAccountControllers] count] > 0) {
            [[self userAgent] start];
        } else {
            [self setShouldRegisterAllAccounts:NO];
        }
    }
}

- (void)SIPUserAgentDidDetectNAT:(NSNotification *)notification {
    if ([[self userAgent] detectedNATType] != kAKNATTypeBlocked) {
        return;
    }

    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];

    [alert setMessageText:
     NSLocalizedString(@"Failed to communicate with STUN server.",
                       @"Failed to communicate with STUN server.")];
    [alert setInformativeText:
     NSLocalizedString(@"UDP packets are probably blocked. It is "
                       "impossible to make or receive calls without that. "
                       "Make sure that your local firewall and the "
                       "firewall at your router allow UDP protocol.",
                       @"Failed to communicate with STUN server "
                       "informative text.")];
    [alert runModal];
}


#pragma mark -
#pragma mark NSWindow notifications

- (void)windowWillClose:(NSNotification *)notification {
    // User closed Account Setup window. Terminate application.
    if ([[notification object] isEqual:[[self accountSetupController] window]]) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:NSWindowWillCloseNotification
                                                      object:[[self accountSetupController] window]];
        
        [NSApp terminate:self];
    }
}


#pragma mark -
#pragma mark NSApplication delegate methods

// Application control starts here.
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    [self optOutOfAutomaticWindowTabbing];

    [self.compositionRoot.settingsMigration execute];
    
    // Read main settings from defaults.
    if ([defaults boolForKey:kUseDNSSRV]) {
        [[self userAgent] setNameservers:[self currentNameservers]];
    }
    
    [[self userAgent] setOutboundProxyHost:[defaults stringForKey:kOutboundProxyHost]];
    
    [[self userAgent] setOutboundProxyPort:[defaults integerForKey:kOutboundProxyPort]];
    
    [[self userAgent] setSTUNServerHost:[defaults stringForKey:kSTUNServerHost]];
    
    [[self userAgent] setSTUNServerPort:[defaults integerForKey:kSTUNServerPort]];
    
    NSString *bundleName = [mainBundle infoDictionary][@"CFBundleName"];
    NSString *bundleShortVersion = [mainBundle infoDictionary][@"CFBundleShortVersionString"];
    
    [[self userAgent] setUserAgentString:[NSString stringWithFormat:@"%@ %@", bundleName, bundleShortVersion]];
    [[self userAgent] setLogFileName:[[self.locations logs] URLByAppendingPathComponent:@"Telephone.log"].path];
    [[self userAgent] setLogLevel:[defaults integerForKey:kLogLevel]];
    [[self userAgent] setConsoleLogLevel:[defaults integerForKey:kConsoleLogLevel]];
    [[self userAgent] setDetectsVoiceActivity:[defaults boolForKey:kVoiceActivityDetection]];
    [[self userAgent] setUsesICE:[defaults boolForKey:kUseICE]];
    [[self userAgent] setTransportPort:[defaults integerForKey:kTransportPort]];
    [[self userAgent] setTransportPublicHost:[defaults stringForKey:kTransportPublicHost]];
    [[self userAgent] setUsesG711Only:[defaults boolForKey:kUseG711Only]];

    NSArray *savedAccounts = [defaults arrayForKey:kAccounts];
    
    // Setup an account on first launch.
    if ([savedAccounts count] == 0) {
        // There are no saved accounts, prompt user to add one.
        
        // Disable Preferences during the first account prompt.
        [[self preferencesMenuItem] setAction:NULL];
        
        // Subscribe to addAccountWindow close to terminate application.
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(windowWillClose:)
                                                     name:NSWindowWillCloseNotification
                                                   object:[[self accountSetupController] window]];
        
        // Set different targets and actions of addAccountWindow buttons to add the first account.
        [[[self accountSetupController] defaultButton] setTarget:self];
        [[[self accountSetupController] defaultButton] setAction:@selector(addAccountOnFirstLaunch:)];
        [[[self accountSetupController] otherButton] setTarget:[[self accountSetupController] window]];
        [[[self accountSetupController] otherButton] setAction:@selector(performClose:)];
        
        [[[self accountSetupController] window] center];
        [[[self accountSetupController] window] makeKeyAndOrderFront:self];
        
        // Early return.
        return;
    }
    
    // There are saved accounts, open account windows.
    for (NSUInteger i = 0; i < [savedAccounts count]; ++i) {
        NSDictionary *accountDict = savedAccounts[i];

        AKSIPAccount *account = [[AKSIPAccount alloc] initWithUUID:accountDict[kUUID]
                                                          fullName:accountDict[kFullName]
                                                        SIPAddress:accountDict[kSIPAddress]
                                                         registrar:accountDict[kRegistrar]
                                                             realm:accountDict[kRealm]
                                                          username:accountDict[kUsername]
                                                            domain:accountDict[kDomain]];

        account.reregistrationTime = [accountDict[kReregistrationTime] integerValue];
        if ([accountDict[kUseProxy] boolValue]) {
            account.proxyHost = accountDict[kProxyHost];
            account.proxyPort = [accountDict[kProxyPort] integerValue];
        }
        account.updatesContactHeader = [accountDict[kUpdateContactHeader] boolValue];
        account.updatesViaHeader = [accountDict[kUpdateViaHeader] boolValue];
        
        AccountController *controller = [[AccountController alloc] initWithSIPAccount:account
                                                                            userAgent:self.userAgent
                                                                     ringtonePlayback:self.ringtonePlayback
                                                                          musicPlayer:self.musicPlayer
                                                                          sleepStatus:self.sleepStatus
                                                                              factory:self.factory];
        
        NSString *description = accountDict[kDescription];
        if ([description length] == 0) {
            description = account.SIPAddress;
        }
        [controller setAccountDescription:description];
        
        [controller setEnabled:[accountDict[kAccountEnabled] boolValue]];
        [controller setSubstitutesPlusCharacter:[accountDict[kSubstitutePlusCharacter] boolValue]];
        [controller setPlusCharacterSubstitution:accountDict[kPlusCharacterSubstitutionString]];
        
        [[self accountControllers] addObject:controller];
        
        if (![controller isEnabled]) {
            continue;
        }
        
        if (i == 0) {
            [[controller window] makeKeyAndOrderFront:self];
            
        } else {
            NSWindow *previousAccountWindow = [[self accountControllers][(i - 1)] window];
            
            [[controller window] orderWindow:NSWindowBelow relativeTo:[previousAccountWindow windowNumber]];
        }
    }
    
    // Update callsShouldDisplayAccountInfo on account controllers.
    [self updateCallsShouldDisplayAccountInfo];
    
    // Update account menu items.
    [self updateAccountsMenuItems];
    
    [NSUserNotificationCenter defaultUserNotificationCenter].delegate = self;
    [self installDNSChangesCallback];
    
    [self setShouldPresentUserAgentLaunchError:YES];
    
    // Register as service provider to allow making calls from the Services
    // menu and context menus.
    [NSApp setServicesProvider:self];

    [self remindAboutPurchasingAfterDelay];
    
    [self registerAllAccountsWhereManualRegistrationRequired];

    [self makeCallAfterLaunchIfNeeded];

    [self setFinishedLaunching:YES];
}

// Reopen all account windows when the user clicks the dock icon.
- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag {
    
    // Show incoming call window, if any.
    if ([self hasIncomingCallControllers]) {
        for (AccountController *accountController in [self enabledAccountControllers]) {
            for (CallController *callController in [accountController callControllers]) {
                if ([[callController call] identifier] != kAKSIPUserAgentInvalidIdentifier &&
                    [[callController call] state] == kAKSIPCallIncomingState) {
                    
                    [callController showWindow:nil];
                    
                    // Return early, beause we can't break from two for loops.
                    return YES;
                }
            }
        }
    } else {
        // Show window of first enalbed account.
        if ([NSApp keyWindow] == nil && [[self enabledAccountControllers] count] > 0) {
            [[self enabledAccountControllers][0] showWindow:self];
        }
    }
    
    return YES;
}

- (void)applicationDidBecomeActive:(NSNotification *)aNotification {
    // Invalidate application's Dock icon bouncing timer.
    if ([self userAttentionTimer] != nil) {
        [[self userAttentionTimer] invalidate];
        [self setUserAttentionTimer:nil];
    }
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    if ([self hasActiveCallControllers]) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:NSLocalizedString(@"Quit", @"Quit button.")];
        [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button.")];
        [[alert buttons][1] setKeyEquivalent:@"\033"];
        [alert setMessageText:NSLocalizedString(@"Are you sure you want to quit Telephone?",
                                                @"Telephone quit confirmation.")];
        [alert setInformativeText:NSLocalizedString(@"All active calls will be disconnected.",
                                                    @"Telephone quit confirmation informative text.")];
        NSInteger choice = [alert runModal];
        
        if (choice == NSAlertSecondButtonReturn) {
            return NSTerminateCancel;
        }
    }
    
    if ([[self userAgent] isStarted]) {
        [self setTerminating:YES];
        [self stopUserAgent];
        
        // Terminate after SIP user agent is stopped in the secondary thread.
        // We should send replyToApplicationShouldTerminate: to NSApp from
        // AKSIPUserAgentDidFinishStoppingNotification.
        return NSTerminateLater;
    }
    
    return NSTerminateNow;
}


#pragma mark -
#pragma mark AKSIPCall notifications

- (void)SIPCallCalling:(NSNotification *)notification {
    [self updateDockTileBadgeLabel];
}

- (void)SIPCallIncoming:(NSNotification *)notification {
    [self updateDockTileBadgeLabel];
    if (![NSApp isActive]) {
        [NSApp requestUserAttention:NSInformationalRequest];
        [self startUserAttentionTimer];
    }
}

- (void)SIPCallConnecting:(NSNotification *)notification {
    [self updateDockTileBadgeLabel];
}

- (void)SIPCallDidDisconnect:(NSNotification *)notification {
    [self updateDockTileBadgeLabel];
    if ([[notification object] isIncoming]) {
        [self stopUserAttentionTimerIfNeeded];
    }
    if ([self shouldRestartUserAgentASAP] && ![self hasActiveCallControllers]) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(restartUserAgent) object:nil];
        [self setShouldRestartUserAgentASAP:NO];
        [self restartUserAgent];
    }
}


#pragma mark -
#pragma mark AuthenticationFailureController notifications

- (void)authenticationFailureControllerDidChangeUsernameAndPassword:(NSNotification *)notification {
    AccountController *accountController = [[notification object] accountController];
    NSUInteger index = [[self accountControllers] indexOfObject:accountController];
    
    if (index != NSNotFound) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        NSMutableArray *accounts = [NSMutableArray arrayWithArray:[defaults arrayForKey:kAccounts]];
        
        NSMutableDictionary *accountDict = [NSMutableDictionary dictionaryWithDictionary:accounts[index]];
        
        accountDict[kUsername] = [[accountController account] username];
        
        accounts[index] = accountDict;
        [defaults setObject:accounts forKey:kAccounts];
        
        AccountPreferencesViewController *accountPreferencesViewController
            = [[self preferencesController] accountPreferencesViewController];
        if ([[accountPreferencesViewController accountsTable] selectedRow] == index) {
            [accountPreferencesViewController populateFieldsForAccountAtIndex:index];
        }
    }
}

#pragma mark - NSUserNotificationCenterDelegate

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
    NSString *identifier = notification.userInfo[kUserNotificationCallControllerIdentifierKey];
    CallController *controller = [self callControllerByIdentifier:identifier];
    switch (notification.activationType) {
        case NSUserNotificationActivationTypeContentsClicked:
            [controller showWindow:self];
            [center removeDeliveredNotification:notification];
            break;
        case NSUserNotificationActivationTypeActionButtonClicked:
            [controller acceptCall];
            break;
        case NSUserNotificationActivationTypeAdditionalActionClicked:
            [controller hangUpCall];
            break;
        default:
            break;
    }
}


#pragma mark -
#pragma mark NSWorkspace notifications

- (void)workspaceWillSleep:(NSNotification *)notification {
    if (self.userAgent.isStarted) {
        [self stopUserAgentAndWait];
    }
}

- (void)workspaceDidWake:(NSNotification *)notification {
    if (self.isUserSessionActive) {
        [self registerReachableAccounts];
    }
}

- (void)workspaceSessionDidResignActive:(NSNotification *)notification {
    self.userSessionActive = NO;
    [self unregisterAllAccounts];
}

- (void)workspaceSessionDidBecomeActive:(NSNotification *)notification {
    self.userSessionActive = YES;
    [self registerAllAccounts];
}


#pragma mark -
#pragma mark Address Book plug-in notifications

// TODO(eofster): Here we receive contact's name and call destination (phone or
// SIP address). Then we set text field string value as when the user typed in
// the name directly and Telephone autocompleted the input. The result is that
// Address Book is searched for the person record. As an alternative we could
// send person and selected call destination identifiers and get another
// destinations here (no new AB search).
// If we change it to work with identifiers, we'll probably want to somehow
// change ActiveAccountViewController's
// tokenField:representedObjectForEditingString:.
- (void)addressBookDidDialCallDestination:(NSNotification *)notification {
    [NSApp activateIgnoringOtherApps:YES];
    [self makeCallOrRememberDestination:[self callDestinationWithAddressBookDidDialNotification:notification]];
}

- (NSString *)callDestinationWithAddressBookDidDialNotification:(NSNotification *)notification {
    NSString *SIPAddressOrNumber = nil;
    if ([[notification name] isEqualToString:AKAddressBookDidDialPhoneNumberNotification]) {
        SIPAddressOrNumber = notification.userInfo[@"AKPhoneNumber"];
    } else if ([[notification name] isEqualToString:AKAddressBookDidDialSIPAddressNotification]) {
        SIPAddressOrNumber = notification.userInfo[@"AKSIPAddress"];
    }

    NSString *name = notification.userInfo[@"AKFullName"];

    NSString *result;
    if ([name length] > 0) {
        result = [NSString stringWithFormat:@"%@ <%@>", name, SIPAddressOrNumber];
    } else {
        result = SIPAddressOrNumber;
    }

    return result;
}


#pragma mark -
#pragma mark Apple event handler for URLs support

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
    [self makeCallOrRememberDestination:[[event paramDescriptorForKeyword:keyDirectObject] stringValue]];
}


#pragma mark -
#pragma mark Service Provider

- (void)makeCallFromTextService:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error {
    if ([NSPasteboard instancesRespondToSelector:@selector(canReadObjectForClasses:options:)] &&
        ![pboard canReadObjectForClasses:@[[NSString class]] options:@{}]) {
        NSLog(@"Could not make call, pboard couldn't give string.");
        return;
    }
    [self makeCallOrRememberDestination:[pboard stringForType:NSPasteboardTypeString]];
}

#pragma mark -

- (void)makeCallAfterLaunchIfNeeded {
    if (self.destinationToCall.length > 0) {
        [self makeCallTo:self.destinationToCall];
        self.destinationToCall = @"";
    }
}

- (void)makeCallOrRememberDestination:(NSString *)destination {
    if (self.isFinishedLaunching) {
        [self makeCallTo:destination];
    } else {
        self.destinationToCall = destination;
    }
}

- (void)makeCallTo:(NSString *)destination {
    if ([self canMakeCall]) {
        [self.enabledAccountControllers[0] makeCallToDestinationRegisteringAccountIfNeeded:destination];
    }
}

- (BOOL)canMakeCall {
    return NSApp.modalWindow == nil && self.enabledAccountControllers.count > 0;
}

@end


#pragma mark -

static void NameserversChanged(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info) {
    id appDelegate = [NSApp delegate];
    NSArray *nameservers = [appDelegate currentNameservers];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if ([defaults boolForKey:kUseDNSSRV] &&
        [nameservers count] > 0 &&
        ![[[appDelegate userAgent] nameservers] isEqualToArray:nameservers]) {
        
        [[appDelegate userAgent] setNameservers:nameservers];
        
        if (![appDelegate hasActiveCallControllers]) {
            [NSObject cancelPreviousPerformRequestsWithTarget:appDelegate
                                                     selector:@selector(restartUserAgent)
                                                       object:nil];
            
            // Schedule user agent restart in several seconds to coalesce several
            // nameserver changes during a short time period.
            [appDelegate performSelector:@selector(restartUserAgent)
                              withObject:nil
                              afterDelay:kUserAgentRestartDelayAfterDNSChange];
        } else {
            [appDelegate setShouldRestartUserAgentASAP:YES];
        }
    }
}
