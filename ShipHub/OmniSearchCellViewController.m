//
//  OmniSearchCellViewController.m
//  ShipHub
//
//  Created by James Howard on 8/31/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "OmniSearchCellViewController.h"

#import "OmniSearch.h"

@interface OmniSearchCellView : NSTableCellView

@end

@interface OmniSearchCellViewController ()

@end

@implementation OmniSearchCellViewController

- (void)updateUI {
    self.cellView.imageView.image = _item.image;
    self.cellView.textField.stringValue = _item.title ?: @"";
}

- (void)setItem:(OmniSearchItem *)item {
    _item = item;
    [self updateUI];
}

- (NSTableCellView *)cellView {
    return (NSTableCellView *)self.view;
}

@end

@implementation OmniSearchCellView

- (void)setBackgroundStyle:(NSBackgroundStyle)backgroundStyle {
    [super setBackgroundStyle:backgroundStyle];
    self.textField.textColor = backgroundStyle == NSBackgroundStyleDark ? [NSColor whiteColor] : [NSColor blackColor];
}

@end
