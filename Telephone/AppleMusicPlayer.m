//
//  AppleMusicPlayer.m
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

#import "AppleMusicPlayer.h"

#import "iTunes.h"

NS_ASSUME_NONNULL_BEGIN

@interface AppleMusicPlayer ()

@property(nonatomic, readonly) iTunesApplication *app;
@property(nonatomic) BOOL didPause;

@end

NS_ASSUME_NONNULL_END

@implementation AppleMusicPlayer

- (nullable instancetype)init {
    if ((self = [super init])) {
        _app = [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
        if (!_app) {
            return nil;
        }
    }
    return self;
}

#pragma mark - MusicPlayer

- (void)pause {
    if (!self.app.isRunning || self.app.playerState != iTunesEPlSPlaying) {
        return;
    }
    [self.app pause];
    self.didPause = YES;
}

- (void)resume {
    if (!self.app.isRunning || !self.didPause) {
        return;
    }
    if (self.app.playerState == iTunesEPlSPaused) {
        [self.app playOnce:NO];
    }
    self.didPause = NO;
}

@end
