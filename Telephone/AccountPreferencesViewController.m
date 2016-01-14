//
//  AccountPreferencesViewController.m
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

#import "AccountPreferencesViewController.h"

#import "AKKeychain.h"

#import "AccountSetupController.h"
#import "PreferencesController.h"
#import "UserDefaultsKeys.h"


// Pasteboard type.
static NSString * const kAKSIPAccountPboardType = @"AKSIPAccountPboardType";

// Maximum number of accounts.
static const NSUInteger kAccountsMax = 32;

@implementation AccountPreferencesViewController

@synthesize accountSetupController = _accountSetupController;

- (AccountSetupController *)accountSetupController {
    if (_accountSetupController == nil) {
        _accountSetupController = [[AccountSetupController alloc] init];
    }
    return _accountSetupController;
}

- (instancetype)init {
    self = [super initWithNibName:@"AccountPreferencesView" bundle:nil];
    if (self != nil) {
        [self setTitle:NSLocalizedString(@"Accounts", @"Accounts preferences window title.")];
    }
    
    return self;
}

- (void)awakeFromNib {
    // Register a pasteboard type to rearrange accounts with drag and drop.
    [[self accountsTable] registerForDraggedTypes:@[kAKSIPAccountPboardType]];
    
    NSInteger row = [[self accountsTable] selectedRow];
    if (row != -1) {
        [self populateFieldsForAccountAtIndex:row];
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSUInteger accountsCount = [[defaults arrayForKey:kAccounts] count];
    if (accountsCount >= kAccountsMax) {
        [[self addAccountButton] setEnabled:NO];
    }
    
    // Subscribe to the account setup notifications.
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(accountSetupControllerDidAddAccount:)
               name:AKAccountSetupControllerDidAddAccountNotification
             object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (IBAction)showAddAccountSheet:(id)sender {
    [[[self accountSetupController] fullNameField] setStringValue:@""];
    [[[self accountSetupController] domainField] setStringValue:@""];
    [[[self accountSetupController] usernameField] setStringValue:@""];
    [[[self accountSetupController] passwordField] setStringValue:@""];
    
    [[[self accountSetupController] fullNameInvalidDataView] setHidden:YES];
    [[[self accountSetupController] domainInvalidDataView] setHidden:YES];
    [[[self accountSetupController] usernameInvalidDataView] setHidden:YES];
    [[[self accountSetupController] passwordInvalidDataView] setHidden:YES];
    
    [[[self accountSetupController] window] makeFirstResponder:
     [[self accountSetupController] fullNameField]];
    
    [NSApp beginSheet:[[self accountSetupController] window]
       modalForWindow:[[self view] window]
        modalDelegate:nil
       didEndSelector:NULL
          contextInfo:NULL];
}

- (IBAction)showRemoveAccountSheet:(id)sender {
    NSInteger index = [[self accountsTable] selectedRow];
    if (index == -1) {
        NSBeep();
        return;
    }
    
    NSTableColumn *theColumn = [[NSTableColumn alloc] initWithIdentifier:@"SIPAddress"];
    NSString *selectedAccount = [[[self accountsTable] dataSource] tableView:[self accountsTable]
                                                   objectValueForTableColumn:theColumn
                                                                         row:index];
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:NSLocalizedString(@"Delete", @"Delete button.")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel button.")];
    [[alert buttons][1] setKeyEquivalent:@"\033"];
    [alert setMessageText:[NSString stringWithFormat:
                           NSLocalizedString(@"Delete \\U201C%@\\U201D?", @"Account removal confirmation."),
                           selectedAccount]];
    [alert setInformativeText:
     [NSString stringWithFormat:
      NSLocalizedString(@"This will delete your currently set up account \\U201C%@\\U201D.",
                        @"Account removal confirmation informative text."),
      selectedAccount]];
    [alert setAlertStyle:NSWarningAlertStyle];
    SEL didEndSelector = @selector(removeAccountAlertDidEnd:returnCode:contextInfo:);
    [alert beginSheetModalForWindow:[[self accountsTable] window]
                      modalDelegate:self
                     didEndSelector:didEndSelector
                        contextInfo:NULL];
}

- (void)removeAccountAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSAlertFirstButtonReturn) {
        [self removeAccountAtIndex:[[self accountsTable] selectedRow]];
    }
}

- (void)removeAccountAtIndex:(NSInteger)index {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *savedAccounts = [NSMutableArray arrayWithArray:[defaults arrayForKey:kAccounts]];
    [savedAccounts removeObjectAtIndex:index];
    [defaults setObject:savedAccounts forKey:kAccounts];
    [defaults synchronize];
    
    if ([savedAccounts count] < kAccountsMax) {
        [[self addAccountButton] setEnabled:YES];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:AKPreferencesControllerDidRemoveAccountNotification
                                                        object:[self preferencesController]
                                                      userInfo:@{kAccountIndex: @(index)}];
    [[self accountsTable] reloadData];
    
    // Select none, last or previous account.
    if ([savedAccounts count] == 0) {
        return;
        
    } else if (index >= ([savedAccounts count] - 1)) {
        [[self accountsTable] selectRowIndexes:[NSIndexSet indexSetWithIndex:([savedAccounts count] - 1)]
                          byExtendingSelection:NO];
        
        [self populateFieldsForAccountAtIndex:([savedAccounts count] - 1)];
        
    } else {
        [[self accountsTable] selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
        
        [self populateFieldsForAccountAtIndex:index];
    }
}

- (void)populateFieldsForAccountAtIndex:(NSInteger)index {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *savedAccounts = [defaults arrayForKey:kAccounts];
    
    if (index >= 0) {
        NSDictionary *accountDict = savedAccounts[index];
        
        [[self accountEnabledCheckBox] setEnabled:YES];
        
        // Conditionally enable fields and set checkboxes state.
        if ([accountDict[kAccountEnabled] boolValue]) {
            [[self accountEnabledCheckBox] setState:NSOnState];
            [[self accountDescriptionField] setEnabled:NO];
            [[self fullNameField] setEnabled:NO];
            [[self domainField] setEnabled:NO];
            [[self usernameField] setEnabled:NO];
            [[self passwordField] setEnabled:NO];
            [[self reregistrationTimeField] setEnabled:NO];
            [[self substitutePlusCharacterCheckBox] setEnabled:NO];
            [[self substitutePlusCharacterCheckBox] setState:[accountDict[kSubstitutePlusCharacter] integerValue]];
            [[self plusCharacterSubstitutionField] setEnabled:NO];
            [[self useProxyCheckBox] setState:[accountDict[kUseProxy] integerValue]];
            [[self useProxyCheckBox] setEnabled:NO];
            [[self proxyHostField] setEnabled:NO];
            [[self proxyPortField] setEnabled:NO];
            [[self SIPAddressField] setEnabled:NO];
            [[self registrarField] setEnabled:NO];
            [[self cantEditAccountLabel] setHidden:NO];
            [[self updateHeadersCheckBox] setEnabled:NO];
            
        } else {
            [[self accountEnabledCheckBox] setState:NSOffState];
            [[self accountDescriptionField] setEnabled:YES];
            [[self fullNameField] setEnabled:YES];
            [[self domainField] setEnabled:YES];
            [[self usernameField] setEnabled:YES];
            [[self passwordField] setEnabled:YES];
            
            [[self reregistrationTimeField] setEnabled:YES];
            [[self substitutePlusCharacterCheckBox] setEnabled:YES];
            [[self substitutePlusCharacterCheckBox] setState:[accountDict[kSubstitutePlusCharacter] integerValue]];
            if ([[self substitutePlusCharacterCheckBox] state] == NSOnState) {
                [[self plusCharacterSubstitutionField] setEnabled:YES];
            } else {
                [[self plusCharacterSubstitutionField] setEnabled:NO];
            }
            
            [[self useProxyCheckBox] setEnabled:YES];
            [[self useProxyCheckBox] setState:[accountDict[kUseProxy] integerValue]];
            if ([[self useProxyCheckBox] state] == NSOnState) {
                [[self proxyHostField] setEnabled:YES];
                [[self proxyPortField] setEnabled:YES];
            } else {
                [[self proxyHostField] setEnabled:NO];
                [[self proxyPortField] setEnabled:NO];
            }
            
            [[self SIPAddressField] setEnabled:YES];
            [[self registrarField] setEnabled:YES];
            [[self cantEditAccountLabel] setHidden:YES];
            [[self updateHeadersCheckBox] setEnabled:YES];
        }
        
        // Populate fields.
        
        // Description.
        if ([accountDict[kDescription] length] > 0) {
            [[self accountDescriptionField] setStringValue:accountDict[kDescription]];
        } else {
            [[self accountDescriptionField] setStringValue:@""];
        }
        
        // Description's placeholder string.
        if ([accountDict[kSIPAddress] length] > 0) {
            [[[self accountDescriptionField] cell] setPlaceholderString:accountDict[kSIPAddress]];
        } else {
            [[[self accountDescriptionField] cell] setPlaceholderString:
             [NSString stringWithFormat:@"%@@%@",
              accountDict[kUsername], accountDict[kDomain]]];
        }
        
        // Full Name.
        [[self fullNameField] setStringValue:accountDict[kFullName]];
        
        // Domain.
        if ([accountDict[kDomain] length] > 0) {
            [[self domainField] setStringValue:accountDict[kDomain]];
        } else {
            [[self domainField] setStringValue:@""];
        }
        
        // User Name.
        [[self usernameField] setStringValue:accountDict[kUsername]];
        
        NSString *keychainServiceName;
        if ([accountDict[kRegistrar] length] > 0) {
            keychainServiceName = [NSString stringWithFormat:@"SIP: %@", accountDict[kRegistrar]];
        } else {
            keychainServiceName = [NSString stringWithFormat:@"SIP: %@", accountDict[kDomain]];
        }
        
        // Password.
        [[self passwordField] setStringValue:[AKKeychain passwordForServiceName:keychainServiceName accountName:accountDict[kUsername]]];
        
        // Reregister every...
        if ([accountDict[kReregistrationTime] integerValue] > 0) {
            [[self reregistrationTimeField] setStringValue:[accountDict[kReregistrationTime] stringValue]];
        } else {
            [[self reregistrationTimeField] setStringValue:@""];
        }
        
        // Substitute ... for "+".
        if (accountDict[kPlusCharacterSubstitutionString] != nil) {
            [[self plusCharacterSubstitutionField] setStringValue:
             accountDict[kPlusCharacterSubstitutionString]];
        } else {
            [[self plusCharacterSubstitutionField] setStringValue:@"00"];
        }
        
        // Proxy Server.
        if ([accountDict[kProxyHost] length] > 0) {
            [[self proxyHostField] setStringValue:accountDict[kProxyHost]];
        } else {
            [[self proxyHostField] setStringValue:@""];
        }
        
        // Proxy Port.
        if ([accountDict[kProxyPort] integerValue] > 0) {
            [[self proxyPortField] setStringValue:[accountDict[kProxyPort] stringValue]];
        } else {
            [[self proxyPortField] setStringValue:@""];
        }
        
        // SIP Address.
        if ([accountDict[kSIPAddress] length] > 0) {
            [[self SIPAddressField] setStringValue:accountDict[kSIPAddress]];
        } else {
            [[self SIPAddressField] setStringValue:@""];
        }
        
        // Registry Server.
        if ([accountDict[kRegistrar] length] > 0) {
            [[self registrarField] setStringValue:accountDict[kRegistrar]];
        } else {
            [[self registrarField] setStringValue:@""];
        }
        
        // SIP Address and Registry Server placeholder strings.
        if ([accountDict[kDomain] length] > 0) {
            [[[self SIPAddressField] cell] setPlaceholderString:[NSString stringWithFormat:@"%@@%@", accountDict[kUsername], accountDict[kDomain]]];
            [[[self registrarField] cell] setPlaceholderString:accountDict[kDomain]];
        } else {
            [[[self SIPAddressField] cell] setPlaceholderString:nil];
            [[[self registrarField] cell] setPlaceholderString:nil];
        }
        
        // Update headers checkbox.
        if ([accountDict[kUpdateContactHeader] boolValue] && [accountDict[kUpdateViaHeader] boolValue]) {
            [[self updateHeadersCheckBox] setState:NSOnState];
        } else {
            [[self updateHeadersCheckBox] setState:NSOffState];
        }
        
    } else {  // if (index >= 0)
        [[self accountEnabledCheckBox] setState:NSOffState];
        [[self accountDescriptionField] setStringValue:@""];
        [[[self accountDescriptionField] cell] setPlaceholderString:nil];
        [[self fullNameField] setStringValue:@""];
        [[self domainField] setStringValue:@""];
        [[self usernameField] setStringValue:@""];
        [[self passwordField] setStringValue:@""];
        [[self reregistrationTimeField] setStringValue:@""];
        [[self substitutePlusCharacterCheckBox] setState:NSOffState];
        [[self plusCharacterSubstitutionField] setStringValue:@"00"];
        [[self useProxyCheckBox] setState:NSOffState];
        [[self proxyHostField] setStringValue:@""];
        [[self proxyPortField] setStringValue:@""];
        [[self SIPAddressField] setStringValue:@""];
        [[self registrarField] setStringValue:@""];
        [[self updateHeadersCheckBox] setState:NSOffState];
        
        [[self accountEnabledCheckBox] setEnabled:NO];
        [[self accountDescriptionField] setEnabled:NO];
        [[self fullNameField] setEnabled:NO];
        [[self domainField] setEnabled:NO];
        [[self usernameField] setEnabled:NO];
        [[self passwordField] setEnabled:NO];
        [[self reregistrationTimeField] setEnabled:NO];
        [[self substitutePlusCharacterCheckBox] setEnabled:NO];
        [[self plusCharacterSubstitutionField] setEnabled:NO];
        [[self useProxyCheckBox] setEnabled:NO];
        [[self proxyHostField] setEnabled:NO];
        [[self proxyPortField] setEnabled:NO];
        [[self SIPAddressField] setEnabled:NO];
        [[[self SIPAddressField] cell] setPlaceholderString:nil];
        [[self registrarField] setEnabled:NO];
        [[[self registrarField] cell] setPlaceholderString:nil];
        [[self cantEditAccountLabel] setHidden:YES];
        [[self updateHeadersCheckBox] setEnabled:NO];
    }
}

- (IBAction)changeAccountEnabled:(id)sender {
    NSInteger index = [[self accountsTable] selectedRow];
    if (index == -1) {
        return;
    }
    
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    
    userInfo[kAccountIndex] = @(index);
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSMutableArray *savedAccounts = [NSMutableArray arrayWithArray:[defaults arrayForKey:kAccounts]];
    
    NSMutableDictionary *accountDict = [NSMutableDictionary dictionaryWithDictionary:savedAccounts[index]];
    
    BOOL isChecked = ([[self accountEnabledCheckBox] state] == NSOnState) ? YES : NO;
    accountDict[kAccountEnabled] = @(isChecked);
    
    if (isChecked) {
        // User enabled the account.
        // Account fields could be edited, save them.
        
        NSCharacterSet *spacesSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
        NSString *accountDescription = [[[self accountDescriptionField] stringValue]
                                        stringByTrimmingCharactersInSet:spacesSet];
        NSString *fullName = [[[self fullNameField] stringValue] stringByTrimmingCharactersInSet:spacesSet];
        NSString *domain = [[[self domainField] stringValue] stringByTrimmingCharactersInSet:spacesSet];
        NSString *username = [[[self usernameField] stringValue] stringByTrimmingCharactersInSet:spacesSet];
        NSString *registrar = [[[self registrarField] stringValue] stringByTrimmingCharactersInSet:spacesSet];
        
        accountDict[kDescription] = accountDescription;
        accountDict[kFullName] = fullName;
        accountDict[kDomain] = domain;
        accountDict[kUsername] = username;
        
        NSString *keychainServiceName;
        if ([registrar length] > 0) {
            keychainServiceName = [NSString stringWithFormat:@"SIP: %@", registrar];
        } else {
            keychainServiceName = [NSString stringWithFormat:@"SIP: %@", domain];
        }
        
        NSString *keychainAccountName = username;
        
        NSString *keychainPassword = [AKKeychain passwordForServiceName:keychainServiceName
                                                            accountName:keychainAccountName];
        
        NSString *currentPassword = [[self passwordField] stringValue];
        
        // Save password only if it's been changed.
        if (![keychainPassword isEqualToString:currentPassword]) {
            [AKKeychain addItemWithServiceName:keychainServiceName
                                   accountName:keychainAccountName
                                      password:currentPassword];
        }
        
        accountDict[kReregistrationTime] = @([[self reregistrationTimeField] integerValue]);
        
        if ([[self substitutePlusCharacterCheckBox] state] == NSOnState) {
            accountDict[kSubstitutePlusCharacter] = @YES;
        } else {
            accountDict[kSubstitutePlusCharacter] = @NO;
        }
        
        accountDict[kPlusCharacterSubstitutionString] = [[self plusCharacterSubstitutionField] stringValue];
        
        if ([[self useProxyCheckBox] state] == NSOnState) {
            accountDict[kUseProxy] = @YES;
        } else {
            accountDict[kUseProxy] = @NO;
        }
        
        NSString *proxyHost = [[[self proxyHostField] stringValue] stringByTrimmingCharactersInSet:spacesSet];
        accountDict[kProxyHost] = proxyHost;
        accountDict[kProxyPort] = @([[self proxyPortField] integerValue]);
        
        NSString *SIPAddress = [[[self SIPAddressField] stringValue] stringByTrimmingCharactersInSet:spacesSet];
        accountDict[kSIPAddress] = SIPAddress;
        
        accountDict[kRegistrar] = registrar;
        
        if (self.updateHeadersCheckBox.state == NSOnState) {
            accountDict[kUpdateContactHeader] = @YES;
            accountDict[kUpdateViaHeader] = @YES;
        } else {
            accountDict[kUpdateContactHeader] = @NO;
            accountDict[kUpdateViaHeader] = @NO;
        }
        
        // Set placeholders.
        
        if ([SIPAddress length] > 0) {
            [[[self accountDescriptionField] cell] setPlaceholderString:SIPAddress];
        } else {
            [[[self accountDescriptionField] cell] setPlaceholderString:
             [NSString stringWithFormat:@"%@@%@", username, domain]];
        }
        
        if ([domain length] > 0) {
            [[[self SIPAddressField] cell] setPlaceholderString:
             [NSString stringWithFormat:@"%@@%@", username, domain]];
            
            [[[self registrarField] cell] setPlaceholderString:domain];
            
        } else {
            [[[self SIPAddressField] cell] setPlaceholderString:nil];
            [[[self registrarField] cell] setPlaceholderString:nil];
        }
        
        // Disable account fields.
        [[self accountDescriptionField] setEnabled:NO];
        [[self fullNameField] setEnabled:NO];
        [[self domainField] setEnabled:NO];
        [[self usernameField] setEnabled:NO];
        [[self passwordField] setEnabled:NO];
        
        [[self reregistrationTimeField] setEnabled:NO];
        [[self substitutePlusCharacterCheckBox] setEnabled:NO];
        [[self plusCharacterSubstitutionField] setEnabled:NO];
        [[self useProxyCheckBox] setEnabled:NO];
        [[self proxyHostField] setEnabled:NO];
        [[self proxyPortField] setEnabled:NO];
        [[self SIPAddressField] setEnabled:NO];
        [[self registrarField] setEnabled:NO];
        [[self cantEditAccountLabel] setHidden:NO];
        [[self updateHeadersCheckBox] setEnabled:NO];
        
        // Mark accounts table as needing redisplay.
        [[self accountsTable] reloadData];
        
    } else {  // if (isChecked)
        // User disabled the account - enable account fields, set checkboxes state.
        [[self accountDescriptionField] setEnabled:YES];
        [[self fullNameField] setEnabled:YES];
        [[self domainField] setEnabled:YES];
        [[self usernameField] setEnabled:YES];
        [[self passwordField] setEnabled:YES];
        
        [[self reregistrationTimeField] setEnabled:YES];
        [[self substitutePlusCharacterCheckBox] setEnabled:YES];
        [[self substitutePlusCharacterCheckBox] setState:[accountDict[kSubstitutePlusCharacter] integerValue]];
        if ([[self substitutePlusCharacterCheckBox] state] == NSOnState) {
            [[self plusCharacterSubstitutionField] setEnabled:YES];
        }
        
        [[self useProxyCheckBox] setEnabled:YES];
        [[self useProxyCheckBox] setState:[accountDict[kUseProxy] integerValue]];
        if ([[self useProxyCheckBox] state] == NSOnState) {
            [[self proxyHostField] setEnabled:YES];
            [[self proxyPortField] setEnabled:YES];
        }
        
        [[self SIPAddressField] setEnabled:YES];
        [[self registrarField] setEnabled:YES];
        [[self cantEditAccountLabel] setHidden:YES];
        [[self updateHeadersCheckBox] setEnabled:YES];
    }
    
    savedAccounts[index] = accountDict;
    
    [defaults setObject:savedAccounts forKey:kAccounts];
    [defaults synchronize];
    
    [[NSNotificationCenter defaultCenter]
     postNotificationName:AKPreferencesControllerDidChangeAccountEnabledNotification
                   object:[self preferencesController]
                 userInfo:userInfo];
}

- (IBAction)changeSubstitutePlusCharacter:(id)sender {
    [[self plusCharacterSubstitutionField] setEnabled:([[self substitutePlusCharacterCheckBox] state] == NSOnState)];
}

- (IBAction)changeUseProxy:(id)sender {
    BOOL isChecked = ([[self useProxyCheckBox] state] == NSOnState) ? YES : NO;
    [[self proxyHostField] setEnabled:isChecked];
    [[self proxyPortField] setEnabled:isChecked];
}


#pragma mark -
#pragma mark NSTableView data source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [[defaults arrayForKey:kAccounts] count];
}

- (id)tableView:(NSTableView *)aTableView
        objectValueForTableColumn:(NSTableColumn *)aTableColumn
        row:(NSInteger)rowIndex {
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSDictionary *accountDict = [defaults arrayForKey:kAccounts][rowIndex];
    
    NSString *returnValue;
    NSString *accountDescription = accountDict[kDescription];
    if ([accountDescription length] > 0) {
        returnValue = accountDescription;
        
    } else {
        NSString *SIPAddress;
        if ([accountDict[kSIPAddress] length] > 0) {
            SIPAddress = accountDict[kSIPAddress];
        } else {
            SIPAddress = [NSString stringWithFormat:@"%@@%@", accountDict[kUsername], accountDict[kDomain]];
        }
        
        returnValue = SIPAddress;
    }
    
    return returnValue;
}

- (BOOL)tableView:(NSTableView *)aTableView
        writeRowsWithIndexes:(NSIndexSet *)rowIndexes
        toPasteboard:(NSPasteboard *)pboard {
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
    
    [pboard declareTypes:@[kAKSIPAccountPboardType] owner:self];
    
    [pboard setData:data forType:kAKSIPAccountPboardType];
    
    return YES;
}

- (NSDragOperation)tableView:(NSTableView *)aTableView
                validateDrop:(id <NSDraggingInfo>)info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)operation {
    
    NSData *data = [[info draggingPasteboard] dataForType:kAKSIPAccountPboardType];
    NSIndexSet *indexes = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    NSInteger draggingRow = [indexes firstIndex];
    
    if (row == draggingRow || row == draggingRow + 1) {
        return NSDragOperationNone;
    }
    
    [[self accountsTable] setDropRow:row dropOperation:NSTableViewDropAbove];
    
    return NSDragOperationMove;
}

- (BOOL)tableView:(NSTableView *)aTableView
       acceptDrop:(id <NSDraggingInfo>)info
              row:(NSInteger)row
    dropOperation:(NSTableViewDropOperation)operation {
    
    NSData *data = [[info draggingPasteboard] dataForType:kAKSIPAccountPboardType];
    NSIndexSet *indexes = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    NSInteger draggingRow = [indexes firstIndex];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *accounts = [[defaults arrayForKey:kAccounts] mutableCopy];
    id selectedAccount = accounts[[[self accountsTable] selectedRow]];
    
    // Swap accounts.
    [accounts insertObject:accounts[draggingRow] atIndex:row];
    if (draggingRow < row) {
        [accounts removeObjectAtIndex:draggingRow];
    } else if (draggingRow > row) {
        [accounts removeObjectAtIndex:(draggingRow + 1)];
    } else {  // This should never happen because we don't validate such drop.
        return NO;
    }
    
    [defaults setObject:accounts forKey:kAccounts];
    [defaults synchronize];
    
    [[self accountsTable] reloadData];
    
    // Preserve account selection.
    NSUInteger selectedAccountIndex = [accounts indexOfObject:selectedAccount];
    [[self accountsTable] selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedAccountIndex] byExtendingSelection:NO];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:AKPreferencesControllerDidSwapAccountsNotification
                                                        object:[self preferencesController]
                                                      userInfo:@{kSourceIndex: @(draggingRow), kDestinationIndex: @(row)}];
    
    return YES;
}


#pragma mark -
#pragma mark NSTableView delegate

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    NSInteger row = [[self accountsTable] selectedRow];
    [self populateFieldsForAccountAtIndex:row];
}


#pragma mark -
#pragma mark AccountSetupController notifications

- (void)accountSetupControllerDidAddAccount:(NSNotification *)notification {
    [[self accountsTable] reloadData];
    
    // Select the newly added account.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSUInteger accountsCount = [[defaults arrayForKey:kAccounts] count];
    NSUInteger index = accountsCount - 1;
    if (index != 0) {
        [[self accountsTable] selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
    }
    
    if (accountsCount >= kAccountsMax) {
        [[self addAccountButton] setEnabled:NO];
    }
}

@end
