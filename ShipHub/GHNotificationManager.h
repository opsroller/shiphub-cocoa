//
//  GHNotificationManager.h
//  ShipHub
//
//  Created by James Howard on 7/9/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DataStore;

// Private utility class for the exclusive use of DataStore, for managing GitHub notifications.
// Handles polling for notifications as well as storing them.
@interface GHNotificationManager : NSObject

- (id)initWithDataStore:(DataStore *)store;

@property (weak) DataStore *store;

@end
