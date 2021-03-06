//
//  LocalComment+CoreDataProperties.h
//  ShipHub
//
//  Created by James Howard on 3/14/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "LocalComment.h"

@class LocalAccount;
@class LocalIssue;
@class LocalReaction;

NS_ASSUME_NONNULL_BEGIN

@interface LocalComment (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *body;
@property (nullable, nonatomic, retain) NSDate *createdAt;
@property (nullable, nonatomic, retain) NSNumber *identifier;
@property (nullable, nonatomic, retain) NSDate *updatedAt;
@property (nullable, nonatomic, retain) LocalAccount *user;
@property (nullable, nonatomic, retain) LocalIssue *issue;
@property (nullable, nonatomic, retain) NSSet<LocalReaction *> *reactions;

@end

@interface LocalComment (CoreDataGeneratedAccessors)

- (void)addReactionObject:(LocalReaction *)value;
- (void)removeReactionObject:(LocalReaction *)value;
- (void)addReactions:(NSSet<LocalReaction *> *)values;
- (void)removeReactions:(NSSet<LocalReaction *> *)values;

@end

NS_ASSUME_NONNULL_END
