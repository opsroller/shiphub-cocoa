//
//  LocalRepo+CoreDataProperties.h
//  ShipHub
//
//  Created by James Howard on 3/14/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "LocalRepo.h"

@class LocalAccount, LocalIssue, LocalLabel, LocalMilestone, LocalHidden, LocalProject;

NS_ASSUME_NONNULL_BEGIN

@interface LocalRepo (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *fullName;
@property (nullable, nonatomic, retain) NSNumber *identifier;
@property (nullable, nonatomic, retain) NSString *name;
@property (nullable, nonatomic, retain) NSString *issueTemplate;
@property (nullable, nonatomic, retain) NSString *pullRequestTemplate;
@property (nullable, nonatomic, retain) NSNumber *private;
@property (nullable, nonatomic, retain) NSNumber *disabled;
@property (nullable, nonatomic, retain) NSString *repoDescription;
@property (nullable, nonatomic, retain) NSNumber *shipNeedsWebhookHelp;
@property (nullable, nonatomic, retain) NSSet<LocalAccount *> *assignees;
@property (nullable, nonatomic, retain) NSSet<LocalIssue *> *issues;
@property (nullable, nonatomic, retain) NSSet<LocalLabel *> *labels;
@property (nullable, nonatomic, retain) NSSet<LocalMilestone *> *milestones;
@property (nullable, nonatomic, retain) NSSet<LocalProject *> *projects;
@property (nullable, nonatomic, retain) LocalAccount *owner;
@property (nullable, nonatomic, retain) LocalHidden *hidden;
@property (nullable, nonatomic, retain) NSNumber *hasIssues;
@property (nullable, nonatomic, retain) NSNumber *allowMergeCommit;
@property (nullable, nonatomic, retain) NSNumber *allowRebaseMerge;
@property (nullable, nonatomic, retain) NSNumber *allowSquashMerge;

@end

@interface LocalRepo (CoreDataGeneratedAccessors)

- (void)addAssigneesObject:(LocalAccount *)value;
- (void)removeAssigneesObject:(LocalAccount *)value;
- (void)addAssignees:(NSSet<LocalAccount *> *)values;
- (void)removeAssignees:(NSSet<LocalAccount *> *)values;

- (void)addIssuesObject:(LocalIssue *)value;
- (void)removeIssuesObject:(LocalIssue *)value;
- (void)addIssues:(NSSet<LocalIssue *> *)values;
- (void)removeIssues:(NSSet<LocalIssue *> *)values;

- (void)addLabelsObject:(LocalLabel *)value;
- (void)removeLabelsObject:(LocalLabel *)value;
- (void)addLabels:(NSSet<LocalLabel *> *)values;
- (void)removeLabels:(NSSet<LocalLabel *> *)values;

- (void)addMilestonesObject:(LocalMilestone *)value;
- (void)removeMilestonesObject:(LocalMilestone *)value;
- (void)addMilestones:(NSSet<LocalMilestone *> *)values;
- (void)removeMilestones:(NSSet<LocalMilestone *> *)values;

- (void)addProjectsObject:(LocalProject *)value;
- (void)removeProjectsObject:(LocalProject *)value;
- (void)addProjects:(NSSet<LocalProject *> *)values;
- (void)removeProjects:(NSSet<LocalProject *> *)values;


@end

NS_ASSUME_NONNULL_END
