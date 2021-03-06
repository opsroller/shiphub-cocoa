//
//  Diff.h
//  ShipHub
//
//  Created by James Howard on 10/12/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class GitCommit;
@class GitDiff;
@class GitFileTree;
@class GitRepo;
@class GitFileSearch;
@class GitFileSearchResult;

typedef NS_ENUM(NSInteger, DiffFileOperation) {
    DiffFileOperationAdded = 1,
    DiffFileOperationDeleted = 2,
    DiffFileOperationModified = 3,
    DiffFileOperationRenamed = 4,
    DiffFileOperationCopied = 5,
    DiffFileOperationTypeChange = 8,
    DiffFileOperationTypeConflicted = 10
};

typedef NS_ENUM(NSInteger, DiffFileMode) {
    DiffFileModeUnreadable          = 0000000,
    DiffFileModeTree                = 0040000,
    DiffFileModeBlob                = 0100644,
    DiffFileModeBlobExecutable      = 0100755,
    DiffFileModeLink                = 0120000,
    DiffFileModeCommit              = 0160000,
};

typedef void (^GitDiffFileTextCompletion)(NSString *oldFile, NSString *newFile, NSString *patch, NSError *error);
typedef void (^GitDiffFileBinaryCompletion)(NSData *oldFile, NSData *newFile, NSError *error);

@interface GitDiffFile : NSObject

@property (readonly) NSString *name;
@property (readonly) NSString *path;
@property (readonly) NSString *oldPath; // if copied or renamed

@property (readonly) DiffFileOperation operation;
@property (readonly) DiffFileMode mode;
@property (readonly) DiffFileMode oldMode;

@property (readonly, getter=isSubmodule) BOOL submodule;

@property (readonly, weak) GitFileTree *parentTree;

// Only valid if mode is Blob or BlobExecutable
// Exactly one of textCompletion or binaryCompletion will be called, depending on the contents of the file(s).
- (NSProgress *)loadContentsAsText:(GitDiffFileTextCompletion)textCompletion asBinary:(GitDiffFileBinaryCompletion)binaryCompletion;

// Figure out where (if anywhere) that lines in patch live in the patch for spanDiffFile.
// Completion provides an NSArray with length = lines in patch. Each entry in the mapping array maps from line number in patch to the line number in the patch for the provided spanDiffFile or -1 if there is no mapping.
+ (void)computePatchMappingFromPatch:(NSString *)patch toPatchForFile:(GitDiffFile *)spanDiffFile completion:(void (^)(NSArray *mapping))completion;

- (void)loadSubmoduleURL:(void (^)(NSURL *URL, NSString *oldSha, NSString *newSha, NSError *err))completion;

@end

@interface GitFileTree : NSObject

@property (readonly) NSString *name;
@property (readonly) NSString *dirname;
@property (readonly) NSString *path;
@property (readonly) NSArray /*either GitFileTree or GitFile*/ *children;

@property (readonly, weak) GitFileTree *parentTree; // may be nil
@property (readonly, weak) GitDiff *parentDiff;

@end

@interface GitDiff : NSObject

// equivalent to git diff baseRev...headRev
+ (GitDiff *)diffWithRepo:(GitRepo *)repo fromMergeBaseOfStart:(NSString *)baseRev to:(NSString *)headRev error:(NSError *__autoreleasing *)error;

// equivalent to git diff baseRev..headRev
+ (GitDiff *)diffWithRepo:(GitRepo *)repo from:(NSString *)baseRev to:(NSString *)headRev error:(NSError *__autoreleasing *)error;

+ (GitDiff *)emptyDiffAtRev:(NSString *)rev;

@property (readonly) NSArray<GitDiffFile *> *allFiles;

// Returns a sorted, hierarchical listing of files.
@property (readonly) GitFileTree *fileTree;

@property (readonly) NSString *baseRev;
@property (readonly) NSString *headRev;

- (GitDiff *)copyByFilteringFilesWithPredicate:(NSPredicate *)predicate;

// Text search allFiles
// handler is called in chunks with subsets of the overall results.
// handler will be called with a nil result when finished.
// search can be cancelled via the returned progress object.
- (NSProgress *)performTextSearch:(GitFileSearch *)search handler:(void (^)(NSArray<GitFileSearchResult *> *result))handler;

@end
