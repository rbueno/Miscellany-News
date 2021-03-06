//
//  ArticleListController.h
//  Miscellany News
//
//  Created by Jesse Stuart on 9/20/11.
//  Copyright (c) 2011 Vassar College. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "EGORefreshTableHeaderView.h"

@class ArticleViewController;

@interface ArticleListController : UIViewController <UITableViewDelegate, UITableViewDataSource, EGORefreshTableHeaderDelegate, UIScrollViewDelegate>
{
    BOOL _reloading;
    
    UINavigationController *_navigationController;
}

@property (strong) NSMutableArray *entries;

@property (strong) UITableView *tableView;
@property (strong) EGORefreshTableHeaderView *refreshHeaderView;
@property (strong) ArticleViewController *articleViewController;

- (void)loadEntries:(NSMutableArray *)entries;

@end
