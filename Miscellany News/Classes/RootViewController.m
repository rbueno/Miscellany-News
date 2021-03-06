//
//  RootViewController.m
//  Miscellany News
//
//  Created by Jesse Stuart on 8/14/11.
//  Copyright 2011 Vassar College. All rights reserved.
//

#import "RootViewController.h"
#import "ArticleViewController.h"
/* RSS */
#import "RSSEntry.h"
#import "RSSArticleParser.h"
/* Sorting unsorted entries */
#import "NSArray+Extras.h" 
/* XML parsing */
#import "TouchXML.h"
#import "CXMLElement+JDS.h"
/* View */
#import "MBProgressHUD.h"
#import "UIView+JMNoise.h"
#import "UIImage+ProportionalFill.h"
/* Fetching and caching images */
#import "EGOImageLoader.h"
/* Miscellaneous convenience methods */
#import "NSString+JDS.h"
#import "NSString+HTML.h"


@interface RootViewController ()
- (void)sortEntries:(NSMutableArray *)unsortedEntries;
@end

@implementation RootViewController

#pragma mark -
#pragma mark Feed parsing

- (void)feedLoaderDidLoadEntry:(RSSEntry *)entry
{
    RSSArticleParser *articleParser = [[RSSArticleParser alloc] initWithRSSEntry:entry];
    articleParser.delegate = _articleViewController;
    
    [_queue addOperationWithBlock:^{
        [articleParser parseArticleText];
        articleParser.delegate = nil;
    }];
}

- (void)feedLoaderFinishedLoadingEntries:(NSMutableArray *)entries
{
    [self sortEntries:entries];
    [MBProgressHUD hideHUDForView:self.view animated:YES];
}


- (void)sortEntries:(NSMutableArray *)unsortedEntries
{
    for (RSSEntry *entry in unsortedEntries) 
    {
        // Sort by date
        int insertIdx = [_allEntries indexForInsertingObject:entry
                                            sortedUsingBlock:^(id a, id b) {
                                                RSSEntry *entry1 = (RSSEntry *) a;
                                                RSSEntry *entry2 = (RSSEntry *) b;
                                                return [entry1.pubDate compare:entry2.pubDate];
                                            }];
        // Add to array
        [_allEntries insertObject:entry atIndex:insertIdx];
        
        // Add to table view
        NSArray *idxPaths = [NSArray arrayWithObject:[NSIndexPath indexPathForRow:insertIdx inSection:0]];
        [self.tableView insertRowsAtIndexPaths:idxPaths withRowAnimation:UITableViewRowAnimationRight];
    }
}

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"The Miscellany News";
    
    // Customize title bar
    UINavigationBar *navBar = self.navigationController.navigationBar;
    navBar.tintColor = [UIColor colorWithRed:0.502 green:0.0 blue:0.0 alpha:1.];
    [navBar applyNoiseWithOpacity:0.5];
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 400, 44)];
    label.backgroundColor = [UIColor clearColor];
    label.font = [UIFont fontWithName:@"Diploma" size:24];
    label.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    label.textAlignment = UITextAlignmentCenter;
    label.textColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
    label.text = self.title;
    self.navigationItem.titleView = label;
    
    // Customize TableView
    self.tableView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"background.png"]];
    self.tableView.rowHeight = 80;
    
    // Allocate ivars
    _allEntries = [[NSMutableArray alloc] init];
    _queue = [[NSOperationQueue alloc] init];

    // Show activity indicator
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    
    /*
     * Load ArticleViewController so it can be set as RSSArticleParser's delegate
     */
    if (_articleViewController == nil) 
    {
        _articleViewController = [[ArticleViewController alloc] initWithNibName:@"ArticleViewController" bundle:[NSBundle mainBundle]];
    }
    
    /*
     * Load EGORefreshTableHeaderView
     */
    if (_refreshHeaderView == nil) 
    {
        EGORefreshTableHeaderView *view = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.tableView.bounds.size.height, self.view.frame.size.width, self.tableView.bounds.size.height) arrowImageName:@"blackArrow.png" textColor:[UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1.0]];
        view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"background.png"]];
		view.delegate = self;
		[self.tableView addSubview:view];
		_refreshHeaderView = view;
	}
    
    // Update the last update date
    [_refreshHeaderView refreshLastUpdatedDate];
    
    // Begin parsing RSS feed
    NSURL *miscFeedURL = [NSURL URLWithString:[[[NSBundle mainBundle] infoDictionary] valueForKey:jFeedURL]];
    _feedLoader = [[RSSFeedLoader alloc] initWithFeedURL:miscFeedURL];
    _feedLoader.delegate = self;
    [_feedLoader loadFeed];
}

#pragma mark -
#pragma mark Memory management


- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    _refreshHeaderView = nil;
    _articleViewController = nil;
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
}

/*
 // Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	// Return YES for supported orientations.
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
 */

#pragma mark Table view configuration
// Customize the number of sections in the table view.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
//    return [[self.fetchedResultsController sections] count];
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_allEntries count];
    /* @TODO core data
    id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
    return [sectionInfo numberOfObjects];
     */
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) 
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle 
                                       reuseIdentifier:CellIdentifier];
    }

    // Configure the cell.
    RSSEntry *entry = [_allEntries objectAtIndex:indexPath.row];
    
    cell.textLabel.font = [UIFont fontWithName:@"Palatino-Bold" size:16.0];
    cell.textLabel.text = entry.title;
    cell.textLabel.numberOfLines = 2;
    
//    cell.imageView.image = entry.thumbnail;
    UIImageView *imageView = [[UIImageView alloc] initWithImage:entry.thumbnail];
    cell.accessoryView = imageView;

    cell.detailTextLabel.font = [UIFont fontWithName:@"Helvetica" size:13.0];
    cell.detailTextLabel.text = entry.summary;
    cell.detailTextLabel.numberOfLines = 2;
    
    return cell;
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return NO;
}

//- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
//{
//
//}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // The table view should not be re-orderable.
    return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Load article view if unloaded
    if (_articleViewController == nil) {
        _articleViewController = [[ArticleViewController alloc] initWithNibName:@"ArticleViewController" bundle:[NSBundle mainBundle]];
    }

    _articleViewController.entry = [_allEntries objectAtIndex:indexPath.row];
    [self.navigationController pushViewController:_articleViewController animated:YES];
    
    /*
    <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
    // ...
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:detailViewController animated:YES];
    [detailViewController release];
	*/
}

#pragma mark -
#pragma mark Data Source Loading / Reloading Methods

- (void)reloadTableViewDataSource{
	
	//  should be calling your tableviews data source model to reload
	//  put here just for demo
	_reloading = YES;
	
}

- (void)doneLoadingTableViewData{
	
	//  model should call this when its done loading
	_reloading = NO;
	[_refreshHeaderView egoRefreshScrollViewDataSourceDidFinishedLoading:self.tableView];
	
}


#pragma mark -
#pragma mark UIScrollViewDelegate Methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView{	
	
	[_refreshHeaderView egoRefreshScrollViewDidScroll:scrollView];
    
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate{
	
	[_refreshHeaderView egoRefreshScrollViewDidEndDragging:scrollView];
	
}


#pragma mark -
#pragma mark EGORefreshTableHeaderDelegate Methods

- (void)egoRefreshTableHeaderDidTriggerRefresh:(EGORefreshTableHeaderView*)view{
	
	[self reloadTableViewDataSource];
	[self performSelector:@selector(doneLoadingTableViewData) withObject:nil afterDelay:3.0];
	
}

- (BOOL)egoRefreshTableHeaderDataSourceIsLoading:(EGORefreshTableHeaderView*)view{
	
	return _reloading; // should return if data source model is reloading
	
}

- (NSDate*)egoRefreshTableHeaderDataSourceLastUpdated:(EGORefreshTableHeaderView*)view{
	
	return [NSDate date]; // should return date data source was last changed
	
}

@end
