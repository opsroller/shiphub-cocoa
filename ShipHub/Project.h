//
//  Project.h
//  ShipHub
//
//  Created by James Howard on 9/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MetadataItem.h"

@interface Project : MetadataItem

@property (readonly) NSNumber *number;
@property (readonly) NSString *name;
@property (readonly) NSString *body;
@property (readonly) NSDate *updatedAt;
@property (readonly) NSDate *createdAt;

@end
