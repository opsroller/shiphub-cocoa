//
//  ProblemTableController.m
//  Ship
//
//  Created by James Howard on 5/26/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "IssueTableControllerPrivate.h"

#import "IssueDocumentController.h"

#import "DataStore.h"
#import "Extras.h"
#import "Issue.h"
#import "IssueIdentifier.h"

@interface IssueTableController () <ProblemTableViewDelegate, NSTableViewDataSource, NSMenuDelegate>

@property (strong) IBOutlet NSTableView *table;

@property (strong) NSMutableArray *tableColumns; // NSTableView .tableColumns property doesn't preserve order, and we want this in our order.

@property (strong) NSMutableArray *items;
@property (strong) NSMutableDictionary *itemLookup;
@property (strong) NSMutableDictionary *problemCache;
@property BOOL loading;
@property NSInteger loadGeneration;

@end

@implementation IssueTableController

+ (Class)tableClass {
    return [ProblemTableView class];
}

- (void)commonInit {
    _items = [NSMutableArray array];
    _itemLookup = [NSMutableDictionary dictionary];
    _problemCache = [NSMutableDictionary dictionary];
    _defaultColumns = [NSSet setWithArray:@[@"issue.number", @"issue.title", @"issue.assignee.login", @"issue.repo.fullName"]];
}

- (id)init {
    if (self = [super init]) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [self commonInit];
    }
    return self;
}

- (void)dealloc {
    _table.dataSource = nil;
    _table.delegate = nil;
}

- (void)loadView {
    CGRect r = CGRectMake(0, 0, 600, 600);
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:r];
    scroll.hasVerticalScroller = YES;
    scroll.hasHorizontalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.borderType = NSNoBorder;
    
    NSTableView *table = [[[[self class] tableClass] alloc] initWithFrame:r];
    table.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
    table.allowsColumnReordering = YES;
    table.allowsColumnResizing = YES;
    table.allowsColumnSelection = YES;
    table.allowsMultipleSelection = YES;
    table.usesAlternatingRowBackgroundColors = YES;
    [scroll setDocumentView:table];
    
    _table = table;
    _table.delegate = self;
    _table.dataSource = self;
    
    self.view = scroll;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _table.doubleAction = @selector(tableViewDoubleClicked:);
    [_table setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];
    [_table registerForDraggedTypes:@[(__bridge NSString *)kUTTypeURL]];
    
    NSMenu *menu = [[NSMenu alloc] init];
    menu.delegate = self;
    [menu addItemWithTitle:NSLocalizedString(@"Open", nil) action:@selector(openFromMenu:) keyEquivalent:@""];
    [menu addItemWithTitle:NSLocalizedString(@"Copy Issue #", nil) action:@selector(copyNumberFromMenu:) keyEquivalent:@""];
    [menu addItemWithTitle:NSLocalizedString(@"Copy Issue # and Title", nil) action:@selector(copyNumberAndTitleFromMenu:) keyEquivalent:@""];
    [menu addItemWithTitle:NSLocalizedString(@"Copy GitHub URL", nil) action:@selector(copyGitHubURLFromMenu:) keyEquivalent:@""];
    [menu addItemWithTitle:NSLocalizedString(@"Mark As Read", nil) action:@selector(markAsReadFromMenu:) keyEquivalent:@""];
    _table.menu = menu;
}

- (void)viewDidAppear {
    [super viewDidAppear];
    
    _table.autosaveTableColumns = YES;
    _table.autosaveName = _autosaveName;
    
    [self _makeColumns];
    [self _makeColumnHeaderMenu];
}

static NSString *const IssuePopupIdentifier = @"info.issuePopupIndex";

+ (NSArray *)columnSpecs {
    static NSArray *specs;
    if (!specs) {
        specs = @[
                  @{ @"identifier" : IssuePopupIdentifier,
                     @"title" : NSLocalizedString(@"Action", nil),
                     @"width" : @90,
                     @"fixed" : @YES,
                     @"editable" : @YES },
                  
#if !INCOMPLETE
                  @{ @"identifier" : @"issue.read",
                     @"title" : NSLocalizedString(@"•", nil),
                     @"menuTitle" : NSLocalizedString(@"Unread", nil),
                     @"formatter" : [BooleanDotFormatter new],
                     @"width" : @20,
                     @"maxWidth" : @20,
                     @"minWidth" : @20,
                     @"centered" : @YES,
                     @"cellClass" : @"ReadIndicatorCell",
                     @"titleFont" : [NSFont boldSystemFontOfSize:12.0] },
#endif
                  
                  @{ @"identifier" : @"issue.number",
                     @"title" : NSLocalizedString(@"#", nil),
                     @"formatter" : [NSNumberFormatter positiveAndNegativeIntegerFormatter],
                     @"width" : @46,
                     @"maxWidth" : @46,
                     @"minWidth" : @46 },
                  
                  @{ @"identifier" : @"info.issueFullIdentifier",
                     @"title" : NSLocalizedString(@"Path", nil),
                     @"width" : @180,
                     @"maxWidth" : @260,
                     @"minWidth" : @60 },
                  
                  @{ @"identifier" : @"issue.title",
                     @"title" : NSLocalizedString(@"Title", nil),
                     @"width" : @271,
                     @"minWidth" : @100,
                     @"maxWidth" : @10000 },
                  
                  @{ @"identifier" : @"issue.assignee.login",
                     @"title" : NSLocalizedString(@"Assignee", nil),
                     @"width" : @160,
                     @"minWidth" : @130,
                     @"maxWidth" : @200 },
                  
                  @{ @"identifier" : @"issue.originator.login",
                     @"title" : NSLocalizedString(@"Originator", nil),
                     @"width" : @160,
                     @"minWidth" : @130,
                     @"maxWidth" : @200 },
                  
                  @{ @"identifier" : @"issue.closedBy.login",
                     @"title" : NSLocalizedString(@"Resolver", nil),
                     @"width" : @160,
                     @"minWidth" : @130,
                     @"maxWidth" : @200 },
                  
                  @{ @"identifier" : @"issue.repository.fullName",
                     @"title" : NSLocalizedString(@"Repo", nil),
                     @"width" : @160,
                     @"minWidth" : @130,
                     @"maxWidth" : @250 },
                  
                  @{ @"identifier" : @"issue.milestone.title",
                     @"title" : NSLocalizedString(@"Milestone", nil),
                     @"width" : @160,
                     @"minWidth" : @130,
                     @"maxWidth" : @250 },
                  
                  @{ @"identifier" : @"issue.closed",
                     @"title" : NSLocalizedString(@"Closed", nil),
                     @"width" : @130,
                     @"minWidth" : @100,
                     @"maxWidth" : @150 },
                  
                  @{ @"identifier" : @"issue.updatedAt",
                     @"title" : NSLocalizedString(@"Modified", nil),
                     @"formatter" : [NSDateFormatter shortDateAndTimeFormatter],
                     @"width" : @130 },
                  
                  @{ @"identifier" : @"issue.createdAt",
                     @"formatter" : [NSDateFormatter shortDateAndTimeFormatter],
                     @"title" : NSLocalizedString(@"Created", nil),
                     @"width" : @130 },
                  ];
    }
    return specs;
}

+ (NSDictionary *)columnSpecWithIdentifier:(NSString *)identifier {
    static NSMutableDictionary *lookups;
    if (!lookups) {
        lookups = [NSMutableDictionary new];
    }
    NSMutableDictionary *lookup = lookups[NSStringFromClass(self)];
    if (!lookup) {
        NSArray *specs = [self columnSpecs];
        lookup = [NSMutableDictionary dictionaryWithCapacity:[specs count]];
        for (NSDictionary *spec in specs) {
            lookup[spec[@"identifier"]] = spec;
        }
        lookups[NSStringFromClass(self)] = lookup;
    }
    return lookup[identifier];
}

- (void)_makeColumnHeaderMenu {
    //create our contextual menu
    NSMenu *menu = [[NSMenu alloc] init];
    menu.delegate = self;
    [[_table headerView] setMenu:menu];
    //loop through columns, creating a menu item for each
    for (NSTableColumn *col in _tableColumns) {
        if ([[col identifier] isEqualToString:IssuePopupIdentifier]) {
            continue;
        }
        NSDictionary *spec = [[self class] columnSpecWithIdentifier:col.identifier];
        NSMenuItem *mi = [[NSMenuItem alloc] initWithTitle:spec[@"menuTitle"] ?: spec[@"title"]
                                                    action:@selector(toggleColumn:)  keyEquivalent:@""];
        mi.target = self;
        mi.representedObject = col;
        [menu addItem:mi];
    }
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *reset = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Reset to default", nil) action:@selector(resetColumns:) keyEquivalent:@""];
    reset.target = self;
    [menu addItem:reset];
    
    return;
}

- (void)toggleColumn:(id)sender {
    NSTableColumn *col = [sender representedObject];
    [col setHidden:![col isHidden]];
}

-(void)menuWillOpen:(NSMenu *)menu {
    if (menu == _table.headerView.menu) {
        for (NSMenuItem *mi in menu.itemArray) {
            NSTableColumn *col = [mi representedObject];
            if (col) {
                [mi setState:col.isHidden ? NSOffState : NSOnState];
            }
        }
    }
}

- (NSArray *)selectedItemsForMenu {
    NSInteger row = [_table clickedRow];
    NSMutableIndexSet *selectedIndexes = [[_table selectedRowIndexes] mutableCopy];
    
    if ([selectedIndexes containsIndex:row]) {
        return [_items objectsAtIndexes:selectedIndexes];
    } else if (row != NSNotFound && row < _items.count) {
        return @[_items[row]];
    } else {
        return nil;
    }
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    if (menu == _table.menu) {
        NSArray *selected = [self selectedItemsForMenu];
        BOOL any = [selected count] > 0;
        for (NSMenuItem *item in menu.itemArray) {
            item.hidden = !any;
        }
    }
}

- (void)openFromMenu:(id)sender {
    // FIXME: Hook up
    NSArray *selected = [self selectedItemsForMenu];
    NSArray *identifiers = [selected arrayByMappingObjects:^id(id obj) {
        return [[obj issue] fullIdentifier];
    }];
    [[IssueDocumentController sharedDocumentController] openIssuesWithIdentifiers:identifiers];
}

- (IBAction)copyNumberFromMenu:(id)sender {
    NSArray *selected = [self selectedItemsForMenu];
    [self copyNumbers:selected];
}

- (IBAction)copyNumberAndTitleFromMenu:(id)sender {
    NSArray *selected = [self selectedItemsForMenu];
    [self copyNumbersAndTitles:selected];
}

- (IBAction)copyGitHubURLFromMenu:(id)sender {
    NSArray *selected = [self selectedItemsForMenu];
    [[[[selected firstObject] issue] fullIdentifier] copyIssueGitHubURLToPasteboard:[NSPasteboard generalPasteboard]];
}

- (void)markAsReadFromMenu:(id)sender {
    // FIXME: Hook up
#if !INCOMPLETE
    NSArray *selected = [self selectedItemsForMenu];
    NSArray *identifiers = [selected arrayByMappingObjects:^id(id obj) {
        return [[obj problem] identifier];
    }];
    [[DataStore activeStore] markAsRead:identifiers];
#endif
}

- (void)_makeColumns {
    _table.autosaveTableColumns = NO;
    
    if (!_tableColumns) {
        _tableColumns = [NSMutableArray new];
    } else {
        [_tableColumns removeAllObjects];
    }
    
    NSArray *oldCols = [_table.tableColumns copy];
    for (NSTableColumn *old in oldCols) {
        [_table removeTableColumn:old];
    }
    
    NSArray *columnSpecs = [[self class] columnSpecs];
    for (NSDictionary *columnSpec in columnSpecs) {
        NSString *columnIdentifier = columnSpec[@"identifier"];
        NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:columnIdentifier];
        column.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:columnIdentifier ascending:YES];
        column.title = columnSpec[@"title"];
        column.width = [columnSpec[@"width"] doubleValue];
        column.minWidth = columnSpec[@"minWidth"] ? [columnSpec[@"minWidth"] doubleValue] : column.width;
        column.maxWidth = columnSpec[@"maxWidth"] ? [columnSpec[@"maxWidth"] doubleValue] : column.width;
        column.editable = [columnSpec[@"editable"] boolValue];
        if ([columnSpec[@"centered"] boolValue]) {
            column.headerCell.alignment = NSTextAlignmentCenter;
        }
        if (columnSpec[@"cellClass"]) {
            Class class = NSClassFromString(columnSpec[@"cellClass"]);
            column.dataCell = [class new];
        }
        if (columnSpec[@"titleFont"]) {
            column.headerCell.font = columnSpec[@"titleFont"];
        }
        NSCell *dataCell = column.dataCell;
        dataCell.formatter = columnSpec[@"formatter"];
        if ([columnIdentifier isEqualToString:IssuePopupIdentifier]) {
            column.title = _popupColumnTitle ?: column.title;
            column.hidden = [_popupItems count] == 0;
            NSPopUpButtonCell *cell = [[NSPopUpButtonCell alloc] init];
            cell.controlSize = NSMiniControlSize;
            cell.font = [NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSMiniControlSize]];
            [cell removeAllItems];
            if (_popupItems) {
                [cell addItemsWithTitles:_popupItems];
            }
            column.dataCell = cell;
        } else {
            column.hidden = ![_defaultColumns containsObject:columnIdentifier];
        }
        [_table addTableColumn:column];
        [_tableColumns addObject:column];
    }
    
    _table.autosaveTableColumns = YES;
    _table.autosaveName = _autosaveName;
}

- (void)resetColumns:(id)sender {
    _table.autosaveName = nil;
    [self _makeColumns];
    [self _makeColumnHeaderMenu];
    [_table sizeToFit];
    _table.autosaveName = self.autosaveName;
}

- (void)setAutosaveName:(NSString *)autosaveName {
    _autosaveName = [autosaveName copy];
    _table.autosaveName = _autosaveName;
}

- (void)setPopupItems:(NSArray *)popupItems {
    _popupItems = [popupItems copy];
    NSTableColumn *popCol = [_table tableColumnWithIdentifier:IssuePopupIdentifier];
    popCol.hidden = [_popupItems count] == 0;
    NSPopUpButtonCell *cell = popCol.dataCell;
    [cell removeAllItems];
    [cell addItemsWithTitles:popupItems];
    [_table reloadDataForRowIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _items.count)] columnIndexes:[NSIndexSet indexSetWithIndex:[_table columnWithIdentifier:IssuePopupIdentifier]]];
}

- (void)setPopupColumnTitle:(NSString *)popupColumnTitle {
    _popupColumnTitle = [popupColumnTitle copy];
    NSTableColumn *popCol = [_table tableColumnWithIdentifier:IssuePopupIdentifier];
    popCol.title = popupColumnTitle;
}

- (void)setDefaultColumns:(NSSet *)defaultColumns {
    _defaultColumns = [defaultColumns copy];
    for (NSTableColumn *col in _tableColumns) {
        col.hidden = ![_defaultColumns containsObject:col.identifier];
    }
}

- (void)setTableItems:(NSArray *)tableItems {
    [self setTableItems:tableItems clearSelection:NO];
}

- (void)setTableItems:(NSArray *)tableItems clearSelection:(BOOL)clearSelection {
    _tableItems = tableItems;
    [self _updateItemsAndClearSelection:clearSelection];
}

- (void)_sortItems {
    NSArray *sortDescriptors = _table.sortDescriptors;
    NSSortDescriptor *stability = [NSSortDescriptor sortDescriptorWithKey:@"info.issueFullIdentifier" ascending:YES];
    if (!sortDescriptors) {
        sortDescriptors = @[stability];
    } else {
        sortDescriptors = [sortDescriptors arrayByAddingObject:stability];
    }
    [_items sortUsingDescriptors:sortDescriptors];
}

- (void)_updateItemsAndClearSelection:(BOOL)clearSelection {
    NSSet *previouslySelectedIdentifiers = clearSelection ? nil : [self selectedItemIdentifiers];

    [_items removeAllObjects];
    [_itemLookup removeAllObjects];
    // Create item for each tableItem
    for (id<IssueTableItem> tableItem in _tableItems) {
        id identifier = tableItem.issueFullIdentifier;
        ProblemTableItem *item = [ProblemTableItem itemWithInfo:tableItem];
        [_items addObject:item];
        if (_itemLookup[identifier]) {
            [_itemLookup[identifier] addObject:item];
        } else {
            _itemLookup[identifier] = [NSMutableArray arrayWithObject:item];
        }
    }
    
    // Compute set of all problemIdentifiers
    NSMutableSet *knownIdentifiers = [NSMutableSet set];
    for (ProblemTableItem *item in _items) {
        [knownIdentifiers addObject:item.info.issueFullIdentifier];
    }
    
    // Filter out items from cache that are no longer referenced
    [_problemCache filterUsingBlock:^BOOL(id<NSCopying> key, id value) {
        return [knownIdentifiers containsObject:key];
    }];
    
    // Populate items's problems for anything already in cache.
    NSMutableSet *loadThese = [NSMutableSet set];
    for (ProblemTableItem *item in _items) {
        id problemIdentifier = item.info.issueFullIdentifier;
        Issue *snapshot = nil;
        if ([item.info respondsToSelector:@selector(issue)]) {
            snapshot = item.info.issue;
        }
        if (!snapshot) {
            snapshot = _problemCache[problemIdentifier];
            [loadThese addObject:problemIdentifier];
        }
        item.issue = snapshot;
    }
    
    // Load any needed problems from the store
    self.loading = YES;
    NSInteger loadGeneration = ++_loadGeneration;
    
    if ([loadThese count] > 0) {
        [[DataStore activeStore] issuesMatchingPredicate:[NSPredicate predicateWithFormat:@"fullIdentifier IN %@", loadThese] completion:^(NSArray<Issue *> *issues, NSError *error) {
            if (_loadGeneration != loadGeneration) {
                return;
            }

            for (Issue *i in issues) {
                _problemCache[i.fullIdentifier] = i;
                NSArray *items = _itemLookup[i.fullIdentifier];
                
                //            NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
                for (ProblemTableItem *item in items) {
                    item.issue = i;
                    //                NSUInteger idx = [_items indexOfObjectIdenticalTo:item];
                    //                [indexes addIndex:idx];
                }
            }
            
            self.loading = NO;
            [self _sortItems];
            [_table reloadData];
            [self selectItemsByIdentifiers:previouslySelectedIdentifiers];
        }];
    } else {
        self.loading = NO;
    }
    
    [self _sortItems];
    [_table reloadData];
    [self selectItemsByIdentifiers:previouslySelectedIdentifiers];
}
         
- (void)reloadProblemsAndClearSelection:(BOOL)invalidateSelection {
    [_problemCache removeAllObjects];
    [self _updateItemsAndClearSelection:invalidateSelection];
}

- (void)reloadProblems {
    [self reloadProblemsAndClearSelection:NO];
}

- (NSString *)tabSeparatedHeader {
    NSMutableString *str = [NSMutableString new];
    NSUInteger i = 0;
    NSArray *cols = _tableColumns;
    NSUInteger maxCols = [cols count];
    for (NSTableColumn *column in cols) {
        if ([column.identifier isEqualToString:IssuePopupIdentifier] && column.hidden) {
            i++;
            continue;
        } else if ([column.identifier isEqualToString:@"issue.read"]) {
            i++;
            continue;
        }
        [str appendString:column.title];
        i++;
        if (i < maxCols) {
            [str appendString:@"\t"];
        } else {
            [str appendString:@"\r"];
        }
    }
    return str;
}

- (NSString *)tabSeparatedRowForProblem:(id)problem {
    NSMutableString *str = [NSMutableString new];
    NSUInteger i = 0;
    NSArray *cols = _tableColumns;
    NSUInteger maxCols = [cols count];
    for (NSTableColumn *column in cols) {
        NSString *value = @"--";
        if ([column.identifier isEqualToString:IssuePopupIdentifier]) {
            if (column.hidden) {
                i++;
                continue;
            } else {
                value = _popupItems[[[problem valueForKeyPath:column.identifier] unsignedIntegerValue]];
            }
        } else if ([column.identifier isEqualToString:@"issue.read"]) {
            i++;
            continue;
        } else {
            id obj = [problem valueForKeyPath:column.identifier];
            if ([obj isKindOfClass:[NSDate class]]) {
                value = [obj longUserInterfaceString];
            } else {
                value = [obj description];
            }
            value = value ?: @"--";
        }
        [str appendString:value];
        i++;
        if (i < maxCols) {
            [str appendString:@"\t"];
        } else {
            [str appendString:@"\r"];
        }
    }
    return str;
}

- (IBAction)copy:(id)sender {
    NSArray *selected = [self selectedItems];
    if ([selected count] == 0) {
        return;
    }

    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    
    NSMutableString *str = [NSMutableString new];
    [str appendString:[self tabSeparatedHeader]];
    for (id item in selected) {
        [str appendString:[self tabSeparatedRowForProblem:item]];
    }
    [pb clearContents];
    [pb writeObjects:@[str]];
}

- (void)copyNumbers:(NSArray *)selected {
    [NSString copyIssueIdentifiers:[selected arrayByMappingObjects:^id(id obj) {
        return [[obj issue] fullIdentifier];
    }] toPasteboard:[NSPasteboard generalPasteboard]];
}

- (void)copyNumbersAndTitles:(NSArray *)selected {
    [NSString copyIssueIdentifiers:[selected arrayByMappingObjects:^id(id obj) {
        return [[obj issue] fullIdentifier];
    }] withTitles:[selected arrayByMappingObjects:^id(id obj) {
        return [[obj issue] title];
    }] toPasteboard:[NSPasteboard generalPasteboard]];
}

- (IBAction)copyIssueNumber:(id)sender {
    NSArray *selected = [self selectedItems];
    [self copyNumbers:selected];
}

- (IBAction)copyIssueNumberWithTitle:(id)sender {
    NSArray *selected = [self selectedItems];
    [self copyNumbersAndTitles:selected];
}

- (IBAction)copyIssueGitHubURL:(id)sender {
    NSArray *selected = [self selectedItems];
    [[[[selected firstObject] issue] fullIdentifier] copyIssueGitHubURLToPasteboard:[NSPasteboard generalPasteboard]];
}

- (IBAction)openDocument:(id)sender {
    NSArray *selected = [self selectedItems];
    NSArray *identifiers = [selected arrayByMappingObjects:^id(id obj) {
        return [[obj issue] fullIdentifier];
    }];
    [[IssueDocumentController sharedDocumentController] openIssuesWithIdentifiers:identifiers];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item {
    if (item.action == @selector(copyIssueNumber:)
        || item.action == @selector(copyIssueNumberWithTitle:)
        || item.action == @selector(openDocument:)) {
        return [[self selectedItems] count] > 0;
    }
    if (item.action == @selector(copyIssueGitHubURL:)) {
        return [[self selectedItems] count] == 1;
    }
    return YES;
}

#pragma mark - NSTableViewDataSource & NSTableViewDelegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [_items count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    ProblemTableItem *item = _items[row];
    id result = [item valueForKeyPath:tableColumn.identifier] ?: @"--";
    return result;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if (![tableColumn.identifier isEqualToString:IssuePopupIdentifier]) {
        return;
    }
    
    ProblemTableItem *item = _items[row];
    NSNumber *idx = object;
    [_delegate issueTableController:self item:item.info popupSelectedItemAtIndex:[idx integerValue]];
}

- (void)selectSomething {
    NSIndexSet *selected = [_table selectedRowIndexes];
    if ([selected count] == 0 && _items.count != 0) {
        [_table selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
        if ([self.delegate respondsToSelector:@selector(issueTableController:didChangeSelection:)]) {
            [self.delegate issueTableController:self didChangeSelection:[self selectedProblemSnapshots]];
        }
    }
}

- (NSSet *)selectedItemIdentifiers {
    return [NSSet setWithArray:[[self selectedItems] arrayByMappingObjects:^id(id obj) {
        return [obj identifier];
    }]];
}

- (void)selectItemsByIdentifiers:(NSSet *)identifiers {
    NSIndexSet *selected = [_items indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        return [identifiers containsObject:[obj identifier]];
    }];
    [_table selectRowIndexes:selected byExtendingSelection:NO];
    if ([self.delegate respondsToSelector:@selector(issueTableController:didChangeSelection:)]) {
        [self.delegate issueTableController:self didChangeSelection:[self selectedProblemSnapshots]];
    }
}

- (NSArray <Issue*> *)selectedProblemSnapshots {
    return [[self selectedItems] arrayByMappingObjects:^id(id obj) {
        return [obj issue];
    }];
}

- (NSArray *)selectedItems {
    NSIndexSet *selected = [_table selectedRowIndexes];
    return [_items objectsAtIndexes:selected];
}

- (void)selectItems:(NSArray *)items {
    NSSet *set = [NSSet setWithArray:items];
    NSIndexSet *selected = [_items indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        return [set containsObject:obj];
    }];
    [_table selectRowIndexes:selected byExtendingSelection:NO];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    if ([self.delegate respondsToSelector:@selector(issueTableController:didChangeSelection:)]) {
        [self.delegate issueTableController:self didChangeSelection:[self selectedProblemSnapshots]];
    }
}

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors {
    if (self.loading) {
        return; // We cannot sort during a load
    }
    
    NSArray *selected = [self selectedItems];
    [self _sortItems];
    [_table reloadData];
    [self selectItems:selected];
}

- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
    NSArray *items = [_items objectsAtIndexes:rowIndexes];
    [NSString copyIssueIdentifiers:[items arrayByMappingObjects:^id(id obj) {
        return [[obj issue] fullIdentifier];
    }] toPasteboard:pboard];
    
    return YES;
}

- (void)tableView:(NSTableView *)tableView draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint forRowIndexes:(NSIndexSet *)rowIndexes
{
    CGPoint dragLoc = session.draggingLocation;
    NSImage *dragImage = [NSImage imageNamed:@"AppIcon"];
    CGSize imageSize = { 32.0, 32.0 };
    CGFloat xOff = imageSize.width / 2.0;
    if (rowIndexes.count > 1) {
        NSDictionary *attr = @{ NSFontAttributeName : [NSFont boldSystemFontOfSize:11.0],
                                NSForegroundColorAttributeName : [NSColor whiteColor] };
        NSString *pillStr = [NSString localizedStringWithFormat:@"%tu", rowIndexes.count];
        
        CGSize strSize = [pillStr sizeWithAttributes:attr];
        
        CGSize pillSize = CGSizeMake(strSize.width + 14.0, strSize.height + 2.0);
        
        CGSize compositeSize = CGSizeMake(imageSize.width + pillSize.width - (pillSize.height / 2.0), imageSize.height);
        NSImage *composite = [[NSImage alloc] initWithSize:compositeSize];
        
        [composite lockFocus];
        
        [[NSColor clearColor] set];
        NSRectFill(CGRectMake(0, 0, compositeSize.width, compositeSize.height));
        
        [dragImage drawInRect:CGRectMake(0, 0, imageSize.width, imageSize.height)];
        
        CGRect pathRect = CGRectMake(compositeSize.width - pillSize.width - 1.0, 1.0, pillSize.width - 2.0, pillSize.height - 2.0);
        NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:pathRect xRadius:(pillSize.height - 2.0) / 2.0 yRadius:(pillSize.height - 2.0) / 2.0];
        [[NSColor whiteColor] setStroke];
        [[NSColor redColor] setFill];
        path.lineWidth = 1.0;
        [path fill];
        [path stroke];
        
        [pillStr drawInRect:CGRectMake(CGRectGetMinX(pathRect) + (CGRectGetWidth(pathRect) - strSize.width) / 2.0,
                                       CGRectGetMinY(pathRect) + (CGRectGetHeight(pathRect) - strSize.height) / 2.0,
                                       strSize.width, strSize.height) withAttributes:attr];
        
        [composite unlockFocus];
        dragImage = composite;
        imageSize = compositeSize;
        // leave xOff alone, we want the icon to be centered under the cursor, but not the count pill.
    }
    
    CGRect imageRect = CGRectMake(dragLoc.x - xOff,
                                 dragLoc.y - imageSize.height / 2.0,
                                 imageSize.width,
                                 imageSize.height);

    
    
    [session enumerateDraggingItemsWithOptions:0
                                       forView:nil
                                       classes:@[[NSPasteboardItem class]]
                                 searchOptions:@{}
                                    usingBlock:^(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop)
     {
         [draggingItem setDraggingFrame:imageRect contents:dragImage];
         *stop = YES;
     }];
}

- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id < NSDraggingInfo >)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{
    // FIXME: Hook up
#if !INCOMPLETE
    NSPasteboard *pb = [info draggingPasteboard];
    NSArray *URLs = [pb readObjectsForClasses:@[[NSURL class]] options:nil];
    
    if ([URLs count] != 1) {
        return NSDragOperationNone;
    }
    
    NSNumber *identifier = [Problem identifierFromURL:[URLs lastObject]];
    if (identifier && [_delegate respondsToSelector:@selector(issueTableController:shouldAcceptDrag:)] &&[_delegate issueTableController:self shouldAcceptDrag:identifier]) {
        return NSDragOperationLink;
    } else {
        return NSDragOperationNone;
    }
#else
    return NSDragOperationNone;
#endif
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation {
    // FIXME: Hook up
#if !INCOMPLETE
    NSPasteboard *pb = [info draggingPasteboard];
    NSArray *URLs = [pb readObjectsForClasses:@[[NSURL class]] options:nil];
    
    NSNumber *identifier = [Problem identifierFromURL:[URLs firstObject]];
    if (identifier && [_delegate respondsToSelector:@selector(issueTableController:didAcceptDrag:)]) {
        return [_delegate issueTableController:self didAcceptDrag:identifier];
    }
    
    return NO;
#else
    return NO;
#endif
}

- (void)tableViewDoubleClicked:(id)sender {
    NSInteger row = [_table clickedRow];
    if (row != NSNotFound && row < [_items count]) {
        ProblemTableItem *item = _items[row];
        
        [[IssueDocumentController sharedDocumentController] openIssueWithIdentifier:item.info.issueFullIdentifier];
    }
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if (![tableColumn.identifier isEqualToString:IssuePopupIdentifier]) {
        [cell setFont:[NSFont systemFontOfSize:12.0]];
    }
}

- (NSIndexSet *)tableView:(NSTableView *)tableView selectionIndexesForProposedSelection:(NSIndexSet *)proposedSelectionIndexes {
    if (self.loading) {
        // Can't change selection during loading
        return [tableView selectedRowIndexes];
    } else {
        return proposedSelectionIndexes;
    }
}

- (NSString *)tableView:(NSTableView *)tableView typeSelectStringForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (tableColumn.hidden) return nil;
    else return [[tableView preparedCellAtColumn:[tableView columnWithIdentifier:tableColumn.identifier] row:row] stringValue];
#pragma diagnostic pop
}

- (BOOL)tableView:(NSTableView *)tableView handleKeyPressEvent:(NSEvent *)event {
    if ([event isDelete] && [_delegate respondsToSelector:@selector(issueTableController:deleteItem:)]) {
        NSArray *selected = [self selectedItems];
        BOOL deletedAny = NO;
        for (ProblemTableItem *item in selected) {
            if ([_delegate issueTableController:self deleteItem:item.info]) {
                [_items removeObjectIdenticalTo:item];
                deletedAny = YES;
            }
        }
        if (deletedAny) {
            [_table reloadData];
        }
        return YES;
    } else if ([event isReturn]) {
        [self openDocument:tableView];
        return YES;
    }
    return NO;
}

@end

@implementation ProblemTableItem
         
+ (instancetype)itemWithInfo:(id<IssueTableItem>)info {
    ProblemTableItem *item = [[self alloc] init];
    item.info = info;
    return item;
}

- (id<NSCopying>)identifier {
    return [_info identifier];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ %p> info: %@ problem: %@", NSStringFromClass([self class]), self, self.info, self.issue];
}

@end

@implementation ProblemTableView

@dynamic delegate;

- (void)keyDown:(NSEvent *)theEvent {
    id<ProblemTableViewDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(tableView:handleKeyPressEvent:)]) {
        if ([delegate tableView:self handleKeyPressEvent:theEvent]) {
            return;
        }
    }
    [super keyDown:theEvent];
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)becomeFirstResponder {
    BOOL became = [super becomeFirstResponder];
    
    if (became) {
        NSIndexSet *selected = [self selectedRowIndexes];
        if ([selected count] == 0 && self.numberOfRows > 0) {
            [self selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:0];
        }
    }
    
    return became;
}

@end

@interface ReadIndicatorCell : NSTextFieldCell

@end

@implementation ReadIndicatorCell

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    BOOL read = [[self objectValue] boolValue];
    
    if (!read) {
        BOOL highlighted = [self isHighlighted];
        
        CGRect rect = CGRectMake(0, 0, 8.0, 8.0);
        rect = CenteredRectInRect(cellFrame, rect);
        rect = IntegralRect(rect);
        
        if (controlView.window.screen.backingScaleFactor > 1.9) {
            rect.origin.x += 0.5;
        }
        
        NSBezierPath *path = [NSBezierPath bezierPathWithOvalInRect:rect];
        
        if (highlighted) {
            [[NSColor whiteColor] setFill];
        } else {
            [[NSColor extras_controlBlue] setFill];
        }
        
        [path fill];
    }
}

@end
