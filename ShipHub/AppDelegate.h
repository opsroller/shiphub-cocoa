//
//  AppDelegate.h
//  ShipHub
//
//  Created by James Howard on 2/24/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Auth;
@class OverviewController;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (readonly) Auth *auth;

+ (instancetype)sharedDelegate;

- (OverviewController *)defaultOverviewController;
- (OverviewController *)activeOverviewController;
- (IBAction)newOverviewController:(id)sender;

- (IBAction)showBilling:(id)sender;
- (IBAction)showRepoController:(id)sender;

- (void)openURL:(NSURL *)URL;

@end

