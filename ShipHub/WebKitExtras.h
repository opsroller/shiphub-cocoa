//
//  WebKitExtras.h
//  ShipHub
//
//  Created by James Howard on 2/29/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <WebKit/WebKit.h>

typedef void (^ScriptMessageHandlerBlock)(WKScriptMessage *msg);

@interface WKUserContentController (Extras)

- (void)addScriptMessageHandlerBlock:(ScriptMessageHandlerBlock)block name:(NSString *)name;

@end

typedef void (^LegacyScriptMessageHandlerBlock)(NSDictionary *msg);

@interface WebScriptObject (Extras)

- (void)addScriptMessageHandlerBlock:(LegacyScriptMessageHandlerBlock)block name:(NSString *)name;

@end
