//
//  SearchResultsControllerPrivate.h
//  ShipHub
//
//  Created by James Howard on 5/5/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "SearchResultsController.h"
#import "IssueTableController.h"

@interface SearchResultsController (Private) <IssueTableControllerDelegate>

@property IssueTableController *table;

- (void)didUpdateItems;

- (void)updateTablePrefs;
- (NSString *)autosaveName;

@end
