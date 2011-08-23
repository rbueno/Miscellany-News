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
#import "CXMLElement+(JDS).h"
/* View */
#import "MBProgressHUD.h"
#import "UIView+JMNoise.h"
#import "UIImage+ProportionalFill.h"
/* Fetching and caching images */
#import "EGOImageLoader.h"
/* Miscellaneous convenience methods */
#import "NSString+JDS.h"

// WILL BE REMOVED
#import "MWFeedParser.h"

@interface RootViewController ()
    @property (retain) NSMutableArray *unsortedEntries;
@end

@implementation RootViewController

@synthesize unsortedEntries;
@synthesize allEntries = _allEntries;
@synthesize queue = _queue;
@synthesize articleViewController = _articleViewController;

@synthesize fetchedResultsController = __fetchedResultsController;
@synthesize managedObjectContext = __managedObjectContext;

#pragma mark Feed parsing

- (void)refreshFeed
{
    NSLog(@"refresh feed");
    
    // Pull feed URL from info plist, initialize ASIHTTP request, and add to queue
    NSURL *feedURL = [NSURL URLWithString:[[[NSBundle mainBundle] infoDictionary] valueForKey:kFeedURL]];
    ASIHTTPRequest *request = [[ASIHTTPRequest alloc] initWithURL:feedURL];
    request.delegate = self;
    [_queue addOperation:request];
    NSLog(@"after adding operation");
}

- (void)requestStarted:(ASIHTTPRequest *)request
{
    NSLog(@"request started");
}

- (void)requestFailed:(ASIHTTPRequest *)request
{
    NSLog(@"request failed");
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Network error" 
                                                    message:@"Failed to retrieve feed." 
                                                   delegate:nil 
                                          cancelButtonTitle:@"Close" 
                                          otherButtonTitles:nil];
    [alert show];
    [alert release], alert = nil;
}

- (void)requestFinished:(ASIHTTPRequest *)request
{
    NSLog(@"request finished");
    NSError *error = nil;
    CXMLDocument *document = [[CXMLDocument alloc] initWithData:[request responseData] options:0 error:&error];
    JSAssert(error == nil, @"Error creating document from feed");
    
    CXMLElement *root = [document rootElement];
    CXMLElement *channel = [[root elementsForName:@"channel"] lastObject];
    
    NSDateFormatter *pubDateFormatter = [[NSDateFormatter alloc] init];
    [pubDateFormatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];
    [pubDateFormatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss zzz"];
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    for (CXMLElement *item in [channel elementsForName:@"item"])
    {
        RSSEntry *entry = [[RSSEntry alloc] initWithTitle:[[item elementForName:@"title"] stringByFlatteningHTML]
                                                     link:[item elementForName:@"link"]
                                                   author:[item elementForName:@"author"]
                                                  summary:[[[item elementForName:@"description"] stringByRemovingLeadingWhitespace] stringByFlatteningHTML]
                                                  pubDate:[pubDateFormatter dateFromString:[item elementForName:@"pubDate"]]
                                                     guid:[item elementForName:@"guid"] 
                                                 category:[item elementForName:@"category"]];
        JSAssert(entry != nil, @"Error allocating entry");
        [unsortedEntries addObject:entry];
    }
    
    [pool drain];
    
    for (RSSEntry *entry in unsortedEntries) 
    {
        // Sort by date
        int insertIdx = [_allEntries indexForInsertingObject:[entry retain]
                                            sortedUsingBlock:^(id a, id b) {
                                                RSSEntry *entry1 = (RSSEntry *) a;
                                                RSSEntry *entry2 = (RSSEntry *) b;
                                                return [entry1.articleDate compare:entry2.articleDate];
                                            }];
        
        // Add to array
        [_allEntries insertObject:entry atIndex:insertIdx];
        [entry release];
        
        // Add to table view
        NSArray *idxPaths = [NSArray arrayWithObject:[NSIndexPath indexPathForRow:insertIdx inSection:0]];
        [self.tableView insertRowsAtIndexPaths:idxPaths withRowAnimation:UITableViewRowAnimationRight];
    }
    [MBProgressHUD hideHUDForView:self.view animated:YES];
}

/**
 *  Called when view is loaded. Pulls RSS feed information.
 */
- (void)parseFeed
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        // Create feed parser and pass the URL of the feed (defined in Constants.h)
        NSURL *feedURL = [[[NSBundle mainBundle] infoDictionary] valueForKey:kFeedURL];
        MWFeedParser *feedParser = [[MWFeedParser alloc] initWithFeedURL:feedURL];
        // Delegate must conform to MWFeedParserDelegate
//        feedParser.delegate = self;
        
        // Parse the feeds info (title, link) and all feed items
        feedParser.feedParseType = ParseTypeItemsOnly;
        // Connection type
        feedParser.connectionType = ConnectionTypeSynchronously;
        // Begin parsing
        [feedParser parse];
        
        [feedParser release];
    }];
}

/**
 *  MWFeedParserDelegate callback when an article is parsed. We use this
 *  info to initialize a new RSSEntry, add it to an error, and fetch the
 *  article's text in the background.
 */
-(void)feedParser:(MWFeedParser *)parser didParseFeedItem:(MWFeedItem *)item
{
    // Create RSSEntry from parsed item and add to array
    RSSEntry *entry = [[RSSEntry alloc] initWithArticleTitle:item.title
                                                  articleUrl:item.link 
                                                 articleDate:item.date
                                              articleSummary:[item.summary substringBetweenString:@"<p> " andString:@"</p>" regex:NO]
                                                 articleText:nil];
    
    [unsortedEntries addObject:entry];
    
    NSString *imageURLString = [item.summary substringBetweenString:@"<img src=" andString:@">" regex:NO];
    entry.image = [[[EGOImageLoader sharedImageLoader] imageForURL:[NSURL URLWithString:imageURLString] shouldLoadWithObserver:nil] imageCroppedToFitSize:CGSizeMake(70, 70)];
    
    
    
    [_queue addOperationWithBlock:^{
        RSSArticleParser *articleParser = [[RSSArticleParser alloc] initWithRSSEntry:entry];
        articleParser.delegate = _articleViewController;
        [articleParser parseArticleText];
        [articleParser release];        
    }];
}

/**
 *  MWFeedParserDelegate callback when it feed has been fully parsed.
 *  We sort the articles by date, add to allEntries and insert in table
 *  view.
 */
-(void)feedParserDidFinish:(MWFeedParser *)parser
{
    for (RSSEntry *entry in unsortedEntries) 
    {
        // Sort by date
        int insertIdx = [_allEntries indexForInsertingObject:[entry retain]
                                            sortedUsingBlock:^(id a, id b) {
                                                RSSEntry *entry1 = (RSSEntry *) a;
                                                RSSEntry *entry2 = (RSSEntry *) b;
                                                return [entry1.articleDate compare:entry2.articleDate];
                                            }];
        
        // Add to array
        [_allEntries insertObject:entry atIndex:insertIdx];
        [entry release];
        
        // Add to table view
        NSArray *idxPaths = [NSArray arrayWithObject:[NSIndexPath indexPathForRow:insertIdx inSection:0]];
        [self.tableView insertRowsAtIndexPaths:idxPaths withRowAnimation:UITableViewRowAnimationRight];
    }
    [MBProgressHUD hideHUDForView:self.view animated:YES];
}

-(void)articleTextParsedForEntry:(RSSEntry *)entry
{
    // Do something
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"The Miscellany News";
    
    // Customize title bar
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.502 green:0.0 blue:0.0 alpha:1.];
    [self.navigationController.navigationBar applyNoiseWithOpacity:0.4];
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 400, 44)];
    label.backgroundColor = [UIColor clearColor];
    label.font = [UIFont fontWithName:@"Palatino-Bold" size:20.0];
    label.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    label.textAlignment = UITextAlignmentCenter;
    label.textColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
    label.text = self.title;
    self.navigationItem.titleView = label;
    [label release];
    
    // Customize TableView
    self.tableView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"background.png"]];
    self.tableView.rowHeight = 80;
    
    // Allocate ivars
    self.allEntries = [NSMutableArray array];
    self.unsortedEntries = [NSMutableArray array];
    self.queue = [[NSOperationQueue alloc] init];

    // Show activity indicator
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    
    if (_articleViewController == nil) {
        _articleViewController = [[[ArticleViewController alloc] initWithNibName:@"ArticleViewController" bundle:[NSBundle mainBundle]] retain];
    }
    
    // Begin parsing RSS feed
    [self refreshFeed];
//    [self parseFeed];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
}

- (void)dealloc
{
    NSLog(@"dealloc");
    [__fetchedResultsController release];
    [__managedObjectContext release];
    
    [_allEntries release];
    _allEntries = nil;
    
    [unsortedEntries release];
    unsortedEntries = nil;
    
    [_queue release];
    _queue = nil;
    
    [super dealloc];
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
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle 
                                       reuseIdentifier:CellIdentifier] autorelease];
    }

    // Configure the cell.
    RSSEntry *entry = [[_allEntries objectAtIndex:indexPath.row] retain];
    
    cell.textLabel.font = [UIFont fontWithName:@"Palatino-Bold" size:16.0];
    cell.textLabel.text = entry.articleTitle;
    cell.textLabel.numberOfLines = 2;
    
//    cell.imageView.image = entry.image;
    UIImageView *imageView = [[UIImageView alloc] initWithImage:entry.image];
    cell.accessoryView = imageView;
    [imageView release];

    cell.detailTextLabel.font = [UIFont fontWithName:@"Helvetica" size:13.0];
    cell.detailTextLabel.text = entry.articleSummary;
    cell.detailTextLabel.numberOfLines = 2;
    
    [entry release];
    
//    if (indexPath.row == 0) {
//        cell.imageView.image = [UIImage imageNamed:@"2623635910.JPG"];
//    } else if (indexPath.row == 2) {
//        cell.imageView.image = [UIImage imageNamed:@"221749802.jpg"];
//    }
    
    return cell;
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return NO;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
//    NSLog(@"weird method");
//    if (editingStyle == UITableViewCellEditingStyleDelete)
//    {
//        // Delete the managed object for the given index path
//        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
//        [context deleteObject:[self.fetchedResultsController objectAtIndexPath:indexPath]];
//        
//        // Save the context.
//        NSError *error = nil;
//        if (![context save:&error])
//        {
//            /*
//             Replace this implementation with code to handle the error appropriately.
//             
//             abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
//             */
//            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
//            abort();
//        }
//    }   
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // The table view should not be re-orderable.
    return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Load article view if unloaded
    if (_articleViewController == nil) {
        _articleViewController = [[[ArticleViewController alloc] initWithNibName:@"ArticleViewController" bundle:[NSBundle mainBundle]] retain];
    }

    _articleViewController.entry = [_allEntries objectAtIndex:indexPath.row];
    [self.navigationController pushViewController:[_articleViewController retain] animated:YES];
    
    /*
    <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
    // ...
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:detailViewController animated:YES];
    [detailViewController release];
	*/
}
@end
