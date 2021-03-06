//
//  NSString+IssueIdentifier.h
//  ShipHub
//
//  Created by James Howard on 3/24/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_MAC
#import <AppKit/AppKit.h>
#endif

@interface NSString (IssueIdentifier)

+ (NSString *)issueIdentifierWithGitHubURL:(NSURL *)URL;
+ (NSString *)issueIdentifierWithGitHubURL:(NSURL *)URL commentIdentifier:(NSNumber *__autoreleasing *)outCommentIdentifier;
+ (NSString *)issueIdentifierWithOwner:(NSString *)ownerLogin repo:(NSString *)repoName number:(NSNumber *)number;

@property (readonly, getter=isIssueIdentifier) BOOL issueIdentifier;

- (NSString *)issueRepoOwner;
- (NSString *)issueRepoName;
- (NSString *)issueRepoFullName;
- (NSNumber *)issueNumber;

- (NSURL *)issueGitHubURL;
- (NSURL *)pullRequestGitHubURL;

#if TARGET_OS_MAC
- (void)copyIssueIdentifierToPasteboard:(NSPasteboard *)pboard;
- (void)copyIssueIdentifierToPasteboard:(NSPasteboard *)pboard withTitle:(NSString *)title;
- (void)copyIssueGitHubURLToPasteboard:(NSPasteboard *)pboard;

+ (void)copyIssueIdentifiers:(NSArray<NSString *> *)identifiers toPasteboard:(NSPasteboard *)pboard;
+ (void)copyIssueIdentifiers:(NSArray<NSString *> *)identifiers withTitles:(NSArray<NSString *> *)titles toPasteboard:(NSPasteboard *)pboard;

+ (BOOL)canReadIssueIdentifiersFromPasteboard:(NSPasteboard *)pboard;
+ (NSArray<NSString *> *)readIssueIdentifiersFromPasteboard:(NSPasteboard *)pboard;

#endif

@end
