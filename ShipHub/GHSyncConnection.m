//
//  GHSyncConnection.m
//  ShipHub
//
//  Created by James Howard on 3/16/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "GHSyncConnection.h"

#import "Auth.h"
#import "Error.h"
#import "Extras.h"

#define POLL_INTERVAL 120.0

typedef NS_ENUM(NSInteger, SyncState) {
    SyncStateIdle,
    SyncStateRoot,
};

@interface GHSyncConnection () {
    dispatch_queue_t _q;
    dispatch_source_t _heartbeat;

    NSDictionary *_syncVersions;
    SyncState _state;
}

@end

@implementation GHSyncConnection

- (id)initWithAuth:(Auth *)auth {
    if (self = [super initWithAuth:auth]) {
        _q = dispatch_queue_create("SyncConnection", NULL);
        _heartbeat = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _q);
        
        __weak __typeof(self) weakSelf = self;
        dispatch_source_set_timer(_heartbeat, DISPATCH_TIME_NOW, POLL_INTERVAL * NSEC_PER_SEC, 10.0 * NSEC_PER_SEC);
        dispatch_source_set_event_handler(_heartbeat, ^{
            id strongSelf = weakSelf;
            [strongSelf heartbeat];
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(POLL_INTERVAL * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            dispatch_resume(_heartbeat);
        });
    }
    return self;
}

- (void)syncWithVersions:(NSDictionary *)versions {
    dispatch_async(_q, ^{
        _syncVersions = [versions copy];
        [self heartbeat];
    });
}

- (void)heartbeat {
    dispatch_assert_current_queue(_q);
    
    if (_state == SyncStateIdle && _syncVersions) {
        [self startSync];
    }
}

- (NSMutableURLRequest *)get:(NSString *)endpoint {
    return [self get:endpoint params:nil];
}

- (NSMutableURLRequest *)get:(NSString *)endpoint params:(NSDictionary *)params  {
    NSMutableURLRequest *req = nil;
    if ([endpoint hasPrefix:@"https://"]) {
        req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:endpoint]];
    } else {
        if (![endpoint hasPrefix:@"/"]) {
            endpoint = [@"/" stringByAppendingString:endpoint];
        }
        NSURLComponents *c = [NSURLComponents new];
        c.scheme = @"https";
        c.host = self.auth.account.ghHost;
        c.path = endpoint;
        
        NSMutableArray *qps = [NSMutableArray new];
        for (NSString *k in [params allKeys]) {
            id v = params[k];
            [qps addObject:[NSURLQueryItem queryItemWithName:k value:[v description]]];
        }
        [qps addObject:[NSURLQueryItem queryItemWithName:@"per_page" value:@"100"]];
        c.queryItems = qps;
        
        
        req = [NSMutableURLRequest requestWithURL:[c URL]];
        NSAssert(req.URL, @"Request must have a URL (1)");
    }
    NSAssert(req.URL, @"Request must have a URL (2)");
    req.HTTPMethod = @"GET";
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [req setValue:[NSString stringWithFormat:@"token %@", self.auth.ghToken] forHTTPHeaderField:@"Authorization"];
    
    return req;
}

- (NSURLSessionDataTask *)jsonTask:(NSURLRequest *)request completion:(void (^)(id json, NSHTTPURLResponse *response, NSError *err))completion {
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(_q, ^{
            NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
            if (![self.auth checkResponse:response]) {
                completion(nil, http, [NSError shipErrorWithCode:ShipErrorCodeNeedsAuthToken]);
                return;
            } else if (error) {
                completion(nil, http, error);
                return;
            }
            
            NSError *err = nil;
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
            if (err) {
                completion(nil, http, err);
                return;
            }
            
            completion(json, http, nil);
        });
    }];
    [task resume];
    return task;
}

- (NSArray<NSURLSessionDataTask *> *)jsonTasks:(NSArray<NSURLRequest *>*)requests completion:(void (^)(NSArray *json, NSError *err))completion {
    NSArray<NSURLSessionDataTask *> *tasks = [[NSURLSession sharedSession] dataTasksWithRequests:requests completion:^(NSArray<URLSessionResult *> *results) {
        dispatch_async(_q, ^{
            NSError *anyError = nil;
            for (URLSessionResult *r in results) {
                anyError = r.error;
                if (![self.auth checkResponse:r.response]) {
                    anyError = [NSError shipErrorWithCode:ShipErrorCodeNeedsAuthToken];
                }
                if (anyError) break;
            }
            if (anyError) {
                completion(nil, anyError);
                return;
            }
            
            NSMutableArray *json = [NSMutableArray arrayWithCapacity:results.count];
            for (URLSessionResult *r in results) {
                NSError *err = nil;
                id v = [NSJSONSerialization JSONObjectWithData:r.data options:0 error:&err];
                if (err) {
                    completion(nil, err);
                    return;
                }
                [json addObject:v];
            }
            
            completion(json, nil);
        });
    }];
    // tasks are automatically resumed
    return tasks;
}

#if 0
 function pagedFetch(url) /* => Promise */ {
     var opts = { headers: { Authorization: "token " + debugToken }, method: "GET" };
     var initial = fetch(url, opts);
     return initial.then(function(resp) {
         var pages = []
         var link = resp.headers.get("Link");
         if (link) {
             var [next, last] = link.split(", ");
             var matchNext = next.match(/\<(.*?)\>; rel="next"/);
             var matchLast = last.match(/\<(.*?)\>; rel="last"/);
             console.log(matchNext);
             console.log(matchLast);
             if (matchNext && matchLast) {
                 var second = parseInt(matchNext[1].match(/page=(\d+)/)[1]);
                 var last = parseInt(matchLast[1].match(/page=(\d+)/)[1]);
                 console.log("second: " + second + " last: " + last);
                 for (var i = second; i <= last; i++) {
                     var pageURL = matchNext[1].replace(/page=\d+/, "page=" + i);
                     console.log("Adding pageURL: " + pageURL);
                     pages.push(fetch(pageURL, opts).then(function(resp) { return resp.json(); }));
                 }
             }
         }
         return Promise.all([resp.json()].concat(pages));
     }).then(function(pages) {
         return pages.reduce(function(a, b) { return a.concat(b); });
     });
 }
#endif

- (void)fetchPaged:(NSURLRequest *)rootRequest completion:(void (^)(NSArray *data, NSError *err))completion {
    NSParameterAssert(rootRequest);
    NSParameterAssert(completion);
    // Must first fetch the rootRequest and then can fetch each page
    DebugLog(@"%@", rootRequest);
    [self jsonTask:rootRequest completion:^(id first, NSHTTPURLResponse *response, NSError *err) {
        if (err) {
            completion(nil, err);
            return;
        }
        
        NSMutableArray *pageRequests = [NSMutableArray array];
        
        NSString *link = [response allHeaderFields][@"Link"];
        
        if (link) {
            NSString *next, *last;
            NSArray *comps = [link componentsSeparatedByString:@", "];
            next = [comps firstObject];
            last = [comps lastObject];
            
            NSTextCheckingResult *matchNext = [[[NSRegularExpression regularExpressionWithPattern:@"\\<(.*?)\\>; rel=\"next\"" options:0 error:NULL] matchesInString:next options:0 range:NSMakeRange(0, next.length)] firstObject];
            NSTextCheckingResult *matchLast = [[[NSRegularExpression regularExpressionWithPattern:@"\\<(.*?)\\>; rel=\"last\"" options:0 error:NULL] matchesInString:next options:0 range:NSMakeRange(0, last.length)] firstObject];
            
            if (matchNext && matchLast) {
                NSString *nextPageURLStr = [next substringWithRange:[matchNext rangeAtIndex:1]];
                NSString *lastPageURLStr = [last substringWithRange:[matchLast rangeAtIndex:1]];
                NSRegularExpression *pageExp = [NSRegularExpression regularExpressionWithPattern:@"page=(\\d+)" options:0 error:NULL];
                NSTextCheckingResult *secondPageMatch = [[pageExp matchesInString:nextPageURLStr options:0 range:NSMakeRange(0, nextPageURLStr.length)] firstObject];
                NSTextCheckingResult *lastPageMatch = [[pageExp matchesInString:lastPageURLStr options:0 range:NSMakeRange(0, lastPageURLStr.length)] firstObject];
                
                if (secondPageMatch && lastPageMatch) {
                    NSInteger secondIdx = [[nextPageURLStr substringWithRange:[secondPageMatch rangeAtIndex:1]] integerValue];
                    NSInteger lastIdx = [[lastPageURLStr substringWithRange:[lastPageMatch rangeAtIndex:1]] integerValue];
                    
                    for (NSInteger i = secondIdx; i <= lastIdx; i++) {
                        NSString *pageURLStr = [nextPageURLStr stringByReplacingCharactersInRange:[secondPageMatch rangeAtIndex:1] withString:[NSString stringWithFormat:@"page=%td", i]];
                        [pageRequests addObject:[self get:pageURLStr]];
                    }
                }
            }
        }
        
        if (pageRequests.count) {
            [self jsonTasks:pageRequests completion:^(NSArray *rest, NSError *restErr) {
                if (err) {
                    ErrLog(@"%@", err);
                    completion(nil, restErr);
                } else {
                    NSMutableArray *all = [first mutableCopy];
                    for (NSArray *page in rest) {
                        [all addObjectsFromArray:page];
                    }
                    DebugLog(@"%@ finished with %td pages: %@", rootRequest, 1+rest.count, all);
                    completion(all, nil);
                }
            }];
        } else {
            DebugLog(@"%@ finished with 1 page: %@", rootRequest, first);
            completion(first, nil);
        }
        
    }];
}


- (void)startSync {
    Trace();
    dispatch_assert_current_queue(_q);
    NSAssert(_state == SyncStateIdle, nil);
    
    if (self.auth.authState == AuthStateInvalid) {
        DebugLog(@"Not auth'd. Bailing out.");
        return;
    }
    
    _state = SyncStateRoot;
    
    [self fetchPaged:[self get:@"/user/repos"] completion:^(NSArray *repos, NSError *err) {
        if (err || repos.count == 0) {
            ErrLog(@"%@", err);
            _state = SyncStateIdle;
            return;
        }
        
        repos = [repos filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"has_issues = YES"]];
        
        // now find all the valid assignees for each of the repos. these will be our set of users.
        NSMutableArray *assigneeRequests = [NSMutableArray new];
        for (NSDictionary *repo in repos) {
            NSString *assigneesEndpoint = [NSString stringWithFormat:@"/repos/%@/%@/assignees", repo[@"owner"][@"login"], repo[@"name"]];
            [assigneeRequests addObject:[self get:assigneesEndpoint]];
        }
        
        // additionally the orgs who own our repos are our set of orgs
        NSMutableArray *orgs = [NSMutableArray new];
        for (NSDictionary *repo in repos) {
            if ([repo[@"owner"][@"type"] isEqualToString:@"Organization"]) {
                [orgs addObject:repo[@"owner"]];
            }
        }
        NSArray *dedupedOrgs = [[NSDictionary lookupWithObjects:orgs keyPath:@"id"] allValues];
        
        
        [self jsonTasks:assigneeRequests completion:^(NSArray *assignees, NSError *assigneeErr) {
            if (assigneeErr) {
                _state = SyncStateIdle;
                return;
            }
            
            // need to deduplicate assigness
            NSMutableArray *allAssignees = [NSMutableArray new];
            for (NSArray *assigneeGroup in assignees) {
                [allAssignees addObjectsFromArray:assigneeGroup];
            }
            NSDictionary *assigneesLookup = [NSDictionary lookupWithObjects:allAssignees keyPath:@"id"];
            NSArray *dedupedAssignees = [assigneesLookup allValues];
            
            NSArray *userIDs = [assigneesLookup allKeys];
            
            NSArray *orgIDs = [dedupedOrgs arrayByMappingObjects:^id(NSDictionary *obj) {
                return obj[@"id"];
            }];
            
            NSMutableArray *reposWithAssignees = [NSMutableArray new];
            NSInteger i = 0;
            for (NSDictionary *repo in repos) {
                NSMutableDictionary *d = [repo mutableCopy];
                d[@"assignees"] = [assignees[i] arrayByMappingObjects:^id(NSDictionary *obj) {
                    return obj[@"id"];
                }];
                [reposWithAssignees addObject:d];
                i++;
            }
            
            
            
            // yield the root object to the delegate
            [self.delegate syncConnection:self receivedRootIdentifiers:@{@"users": userIDs, @"orgs": orgIDs} version:1];
            
            // yield the users to the delegate
            [self yield:accountsWithRepos(dedupedAssignees, repos) type:@"user" version:1];
            
            
            // Need to wait for orgs and milestones before we can yield repos.
            dispatch_group_t waitForOrgsAndMilestones = dispatch_group_create();
            
            // find the milestones for each repo
            __block NSArray *reposWithInfo = nil;
            dispatch_group_enter(waitForOrgsAndMilestones);
            [self findMilestonesAndLabels:reposWithAssignees completion:^(NSArray *rwi) {
                reposWithInfo = rwi;
                dispatch_group_leave(waitForOrgsAndMilestones);
            }];
            
            // now find the org membership
            dispatch_group_enter(waitForOrgsAndMilestones);
            [self orgMembership:dedupedOrgs repos:repos validMembers:assigneesLookup completion:^{
                dispatch_group_leave(waitForOrgsAndMilestones);
            }];
            
            dispatch_group_notify(waitForOrgsAndMilestones, _q, ^{
                // yield the repos
                [self yield:reposWithInfo type:@"repo" version:1];
                
                [self findIssues:reposWithInfo];
            });
        }];
    }];
}

static id accountsWithRepos(NSArray *accounts, NSArray *repos) {
    NSMutableDictionary *partitionedRepos = [NSMutableDictionary new];
    for (NSDictionary *repo in repos) {
        NSMutableArray *l = partitionedRepos[repo[@"owner"][@"id"]];
        if (!l) {
            l = [NSMutableArray new];
            partitionedRepos[repo[@"owner"][@"id"]] = l;
        }
        [l addObject:repo[@"id"]];
    }
    NSMutableArray *augmented = [NSMutableArray arrayWithCapacity:accounts.count];
    for (NSDictionary *d in accounts) {
        NSMutableDictionary *m = [d mutableCopy];
        m[@"repos"] = partitionedRepos[d[@"id"]];
        [augmented addObject:m];
    }
    return augmented;
}

- (void)orgMembership:(NSArray *)dedupedOrgs repos:(NSArray *)repos validMembers:(NSDictionary *)users completion:(dispatch_block_t)completion {
    NSMutableArray *spideredOrgs = [NSMutableArray arrayWithCapacity:dedupedOrgs.count];
    __block BOOL failed = NO;
    for (NSDictionary *org in dedupedOrgs) {
        NSMutableDictionary *orgWithUsers = [org mutableCopy];
        NSString *memberEndpoint = [NSString stringWithFormat:@"orgs/%@/members", org[@"login"]];
        
        [self fetchPaged:[self get:memberEndpoint] completion:^(NSArray *data, NSError *err) {
            if (failed) {
                return;
            }
            if (err) {
                _state = SyncStateIdle;
                failed = YES;
                completion();
                return;
            }
            
            orgWithUsers[@"users"] = [data filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"id IN %@", [users allKeys]]];
            
            [spideredOrgs addObject:orgWithUsers];
            
            if (spideredOrgs.count == dedupedOrgs.count) {
                // can yield orgs
                [self yield:accountsWithRepos(spideredOrgs, repos) type:@"org" version:1];
                completion();
            }
        }];
    }
}

- (void)findMilestonesAndLabels:(NSArray *)repos completion:(void (^)(NSArray *rwi))completion {
    __block NSUInteger remaining = repos.count * 2;
    NSMutableArray *rwis = [NSMutableArray arrayWithCapacity:repos.count];
    
    dispatch_block_t done = ^{
        remaining--;
        if (remaining == 0) {
            completion(rwis);
        }
    };
    
    for (NSDictionary *repo in repos) {
        NSMutableDictionary *rwi = [repo mutableCopy];
        [rwis addObject:rwi];
        
        NSString *baseEndpoint = [NSString stringWithFormat:@"repos/%@/%@", repo[@"owner"][@"login"], repo[@"name"]];
        NSString *labelsEndpoint = [baseEndpoint stringByAppendingPathComponent:@"labels"];
        NSString *milestonesEndpoint = [baseEndpoint stringByAppendingPathComponent:@"milestones"];
        [self fetchPaged:[self get:labelsEndpoint] completion:^(NSArray *data, NSError *err) {
            rwi[@"labels"] = data;
            done();
        }];
        
        [self fetchPaged:[self get:milestonesEndpoint] completion:^(NSArray *data, NSError *err) {
            rwi[@"milestones"] = data;
            done();
        }];
    }
}

- (void)findIssues:(NSArray *)repos {
    // calculate the since date for our query
    
    int64_t issuesSince = [_syncVersions[@"issue"] longLongValue];
    NSDate *since = [NSDate dateWithTimeIntervalSinceReferenceDate:(double)(issuesSince / 1000)];
    NSString *sinceStr = [since JSONString];
    
    NSDictionary *params = @{ @"filter": @"all",
                              @"since": sinceStr,
                              @"state": @"all",
                              @"sort": @"updated",
                              @"direction": @"asc" };
    
    // fetch all the issues per repo
    
    __block NSInteger remaining = repos.count;
    __block NSMutableArray *issues = [NSMutableArray new];
    
    // XXX: This is truly awful since it doesn't stream and there's no progress ...
    // But this whole class is a gross hack that needs to die in a radioactive fire so ...
    
    for (NSDictionary *repo in repos) {
        NSString *endpoint = [NSString stringWithFormat:@"repos/%@/%@/issues", repo[@"owner"][@"login"], repo[@"name"]];
        
        [self fetchPaged:[self get:endpoint params:params] completion:^(NSArray *data, NSError *err) {
            if (data) {
                NSArray *issuesOnly = [data filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"pull_request = nil OR pull_request = NO"]];
                
                [issues addObjectsFromArray:[issuesOnly arrayByMappingObjects:^id(id obj) {
                    NSMutableDictionary *issue = [obj mutableCopy];
                    issue[@"repository"] = repo[@"id"];
                    return issue;
                }]];
            }
            
            remaining--;
            if (remaining == 0) {
                
                // calculate the max date in all of issues and that's our latest since str
                NSString *maxDate = nil;
                for (NSDictionary *issue in issues) {
                    NSString *created = issue[@"created_at"];
                    NSString *updated = issue[@"updated_at"];
                    
                    if (!maxDate || [created compare:maxDate] == NSOrderedDescending) {
                        maxDate = created;
                    }
                    
                    if (!maxDate || [updated compare:maxDate] == NSOrderedDescending) {
                        maxDate = updated;
                    }
                }
                
                int64_t version = [_syncVersions[@"issue"] longLongValue];
                if (maxDate) {
                    version = ([[NSDate dateWithJSONString:maxDate] timeIntervalSinceReferenceDate] * 1000);
                    NSMutableDictionary *newVersions = [_syncVersions mutableCopy];
                    newVersions[@"issue"] = @(version);
                    _syncVersions = newVersions;
                }
                
                [self yield:issues type:@"issue" version:version];
                
                _state = SyncStateIdle;
                
            }
        }];
    }
}

- (void)yield:(id)json type:(NSString *)type version:(int64_t)version {
    [self.delegate syncConnection:self receivedSyncObjects:renameFields(json) type:type version:version];
}

static NSString *barsToCamels(NSString *s) {
    if ([s isEqualToString:@"id"]) {
        return @"identifier";
    }
    if ([s rangeOfString:@"_"].location == NSNotFound) {
        return s;
    }
    NSArray *comps = [s componentsSeparatedByString:@"_"];
    __block NSInteger i = 0;
    comps = [comps arrayByMappingObjects:^id(id obj) {
        i++;
        if (i > 1) {
            return [obj PascalCase];
        } else {
            return obj;
        }
    }];
    return [comps componentsJoinedByString:@""];
}

static id renameFields(id json) {
    if ([json isKindOfClass:[NSArray class]]) {
        return [json arrayByMappingObjects:^id(id obj) {
            return renameFields(obj);
        }];
    } else if ([json isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:[json count]];
        for (NSString *key in [json allKeys]) {
            d[barsToCamels(key)] = renameFields(json[key]);
        }
        return d;
    } else {
        return json;
    }
}

@end