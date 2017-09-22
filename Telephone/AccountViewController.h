//
//  AccountViewController.h
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

@import Cocoa;

@class ActiveAccountViewController, CallHistoryViewController, StoreWindowPresenter;
@class AsyncCallHistoryPurchaseCheckUseCaseFactory, AsyncCallHistoryViewEventTargetFactory;
@protocol Account;

NS_ASSUME_NONNULL_BEGIN

@interface AccountViewController : NSViewController

@property(nonatomic, readonly) BOOL allowsCallDestinationInput;

- (instancetype)initWithActiveAccountViewController:(ActiveAccountViewController *)activeAccountViewController
                          callHistoryViewController:(CallHistoryViewController *)callHistoryViewController
                  callHistoryViewEventTargetFactory:(AsyncCallHistoryViewEventTargetFactory *)callHistoryViewEventTargetFactory
                        purchaseCheckUseCaseFactory:(AsyncCallHistoryPurchaseCheckUseCaseFactory *)purchaseCheckUseCaseFactory
                                            account:(id<Account>)account
                               storeWindowPresenter:(StoreWindowPresenter *)storeWindowPresenter;

- (void)showActiveState;
- (void)showInactiveStateAnimated:(BOOL)animated;

- (void)makeCallToDestination:(NSString *)destination;

@end

NS_ASSUME_NONNULL_END
