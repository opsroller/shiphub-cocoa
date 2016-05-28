//
//  ThreePaneController.m
//  ShipHub
//
//  Created by James Howard on 5/5/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "ThreePaneController.h"
#import "SearchResultsControllerPrivate.h"

#import "Extras.h"
#import "DataStore.h"
#import "Issue.h"
#import "Issue3PaneTableController.h"
#import "IssueViewController.h"

@interface ThreePaneController () <IssueTableControllerDelegate>

@property NSSplitViewController *splitController;
@property Issue3PaneTableController *tableController;
@property IssueViewController *issueController;

@property Issue *displayedIssue;

@end

@implementation ThreePaneController

- (void)loadView {
    self.table = _tableController = [Issue3PaneTableController new];
    _tableController.delegate = self;
    
    _issueController = [IssueViewController new];
    _issueController.columnBrowser = YES;
    
    _splitController = [NSSplitViewController new];
    
    NSSplitViewItem *tableItem = [NSSplitViewItem splitViewItemWithViewController:_tableController];
    NSSplitViewItem *issueItem = [NSSplitViewItem splitViewItemWithViewController:_issueController];
    
    if ([tableItem respondsToSelector:@selector(setMinimumThickness:)]) {
        tableItem.minimumThickness = 200.0;
        tableItem.maximumThickness = 400.0;
        issueItem.minimumThickness = 440.0;
    }
    
    [_splitController addSplitViewItem:tableItem];
    [_splitController addSplitViewItem:issueItem];
    
    NSView *view = [[NSView alloc] initWithFrame:CGRectMake(0, 0, 600, 600)];
    [view setContentView:_splitController.view];
    self.view = view;
    
    _splitController.splitView.autosaveName = @"3Pane";
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)issueTableController:(IssueTableController *)controller didChangeSelection:(NSArray<Issue *> *)selectedIssues {
    Issue *i = [selectedIssues firstObject];
    
    if ([[_displayedIssue fullIdentifier] isEqualToString:[i fullIdentifier]]) {
        return;
    }
    
    self.displayedIssue = i;
    
    DebugLog(@"%@", i.fullIdentifier);
    
    if (i) {
        [[DataStore activeStore] checkForIssueUpdates:i.fullIdentifier];
        [[DataStore activeStore] loadFullIssue:i.fullIdentifier completion:^(Issue *issue, NSError *error) {
            if ([self.displayedIssue.fullIdentifier isEqualToString:issue.fullIdentifier]) {
                _issueController.issue = issue;
            }
        }];
    } else {
        _issueController.issue = nil;
    }
}

- (NSSize)preferredMinimumSize {
    NSSize s = NSMakeSize(0.0, 200.0);
    for (NSSplitViewItem *item in _splitController.splitViewItems) {
        s.width += item.minimumThickness;
        s.width += [NSScroller scrollerWidthForControlSize:NSRegularControlSize scrollerStyle:NSScrollerStyleLegacy];
    }
    return s;
}

- (void)didUpdateItems {
    if (!self.displayedIssue) {
        [self.table selectSomething];
    }
}

@end