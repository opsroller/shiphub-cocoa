//
//  WebSession.h
//  ShipHub
//
//  Created by James Howard on 9/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AuthAccount;

@interface WebSession : NSObject

- (id)initWithAuthAccount:(AuthAccount *)account;
- (id)initWithAuthAccount:(AuthAccount *)account initialCookies:(NSArray<NSHTTPCookie *> *)cookies;

@property (readonly, strong) AuthAccount *account;
@property (readonly, copy) NSString *host;

@property (readonly, strong) NSArray<NSHTTPCookie *> *cookies;

- (void)addToRequest:(NSMutableURLRequest *)request;
- (BOOL)updateSessionWithResponse:(NSHTTPURLResponse *)response;

+ (NSArray<NSHTTPCookie *> *)sessionCookiesInResponse:(NSHTTPURLResponse *)response;

@end
