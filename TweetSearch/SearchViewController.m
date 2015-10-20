//
//  TweetSearch
//  Created by John Mikelich on 7/29/15
//
//  The twitter handlers for this class have been writted by
//  Created by Keith Harrison on 06-June-2011 http://useyourloaf.com
//  Copyright (c) 2011 Keith Harrison. All rights reserved.
//  His extended license is available in the 'License' file.
//
//
//  SearchViewController handles searching twitter 'tweets' using the
//  string typed in by the user from the main view. SeachViewController
//  then displays up to 100 responses. The user has the ability to
//  select/deselect their preffered tweets. Once the user exits this
//  view (either to the ViewController or minimizing the app), the saved
//  tweets are added to the Core Data Stack.
//


#import "SearchViewController.h"
#import <Accounts/Accounts.h>
#import <Social/Social.h>
#import <CoreData/CoreData.h>

// Various twitter request states
typedef NS_ENUM(NSUInteger, UYLTwitterSearchState)
{
    UYLTwitterSearchStateLoading,
    UYLTwitterSearchStateNotFound,
    UYLTwitterSearchStateRefused,
    UYLTwitterSearchStateFailed
};

@interface SearchViewController ()

// Twitter search variables
@property (nonatomic,strong) NSURLConnection *connection;
@property (nonatomic,strong) NSMutableData *buffer;
@property (nonatomic,strong) NSMutableArray *results;
@property (nonatomic,strong) ACAccountStore *accountStore;
@property (nonatomic,assign) UYLTwitterSearchState searchState;

// Active dictionary used to save selected/deselected tweets
@property (nonatomic,strong) NSMutableDictionary *selectedTweetData;
// Ensures user only sees funtionality description once
@property (nonatomic,assign) BOOL firstSearch;

@end

@implementation SearchViewController

- (ACAccountStore *)accountStore
{
    if (_accountStore == nil)
    {
        _accountStore = [[ACAccountStore alloc] init];
    }
    return _accountStore;
}

- (NSString *)searchMessageForState:(UYLTwitterSearchState)state
{
    // Handle all connection cases
    switch (state)
    {
        case UYLTwitterSearchStateLoading:
            return @"Loading...";
            break;
        case UYLTwitterSearchStateNotFound:
            return @"No results found";
            break;
        case UYLTwitterSearchStateRefused:
            return @"Twitter Access Refused";
            break;
        default:
            return @"Not Available";
            break;
    }
}

- (IBAction)refreshSearchResults
{
    [self cancelConnection];
    [self loadQuery];
}

#pragma mark -
#pragma mark === View Setup ===
#pragma mark -

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Add the target action to the refresh control as it seems not to take
    // effect when set in the storyboard.
    [self.refreshControl addTarget:self action:@selector(refreshSearchResults) forControlEvents:UIControlEventValueChanged];
    
    // Init usage vars
    _firstSearch = false;
    _selectedTweetData = [NSMutableDictionary new];
    
    // Save search string and query twitter
    self.title = self.query;
    [self loadQuery];
}

- (void)viewWillDisappear:(BOOL)animated
{
    // Save user selected tweets to core data stack.
    [self saveCoreDataOnExit];
    
    [super viewWillDisappear:animated];
    [self cancelConnection];
}

- (void)dealloc
{
    [self cancelConnection];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}


#pragma mark -
#pragma mark === CoreData Handlers ===
#pragma mark -

-(void) saveCoreDataOnExit
{
    // Add saved tweets to core data stack
    NSManagedObjectContext *context = [self managedObjectContext];
    
    for (id key in _selectedTweetData)
    {
        // Load tweet user would like to save
        NSDictionary *tweet = [_selectedTweetData objectForKey:key];
        
        // Create a new managed object
        NSManagedObject *newTweet = [NSEntityDescription insertNewObjectForEntityForName:@"Tweet" inManagedObjectContext:context];
        
        // Save tweet contents and profile pic
        [newTweet setValue:tweet[@"text"] forKey:@"text"];
        [newTweet setValue:[tweet[@"user"]valueForKey: @"profile_image_url"] forKey:@"imageURL"];
        
        NSError *error = nil;
        // Save the object to persistent store
        if (![context save:&error]) {
            NSLog(@"Can't Save! %@ %@", error, [error localizedDescription]);
        }
    }

}

// Core data management handler function
- (NSManagedObjectContext *)managedObjectContext {
    NSManagedObjectContext *context = nil;
    
    id delegate = [[UIApplication sharedApplication] delegate];
    if ([delegate performSelector:@selector(managedObjectContext)]) {
        context = [delegate managedObjectContext];
    }
    
    return context;
}

#pragma mark -
#pragma mark === UITableViewDataSource Delegates ===
#pragma mark -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Setup table. Either the search has returned results, or the table contains once description cell
    NSUInteger count = [self.results count];
    return count > 0 ? count : 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Loading cell is the placeholder cell while the query connects to twitter
    static NSString *LoadCellIdentifier = @"LoadingCell";
    static NSString *ResultCellIdentifier = @"ResultCell";

    
    NSUInteger count = [self.results count];
    if ((count == 0) && (indexPath.row == 0))
    {
        // No search results and first cell. Display connect state
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:LoadCellIdentifier];
        cell.textLabel.text = [self searchMessageForState:self.searchState];
        return cell;
    }
    
    // Populate table with resultant tweet contents
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ResultCellIdentifier];    
    NSDictionary *tweet = (self.results)[indexPath.row];

    // Parse through the tweet for image URL and save to UIImage
    NSURL *url = [NSURL URLWithString:[[tweet[@"user"]valueForKey: @"profile_image_url"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    NSData *data = [NSData dataWithContentsOfURL : url];
    UIImage *image = [UIImage imageWithData: data];
    
    // Setup cell
    cell.textLabel.text = tweet[@"text"];
    cell.imageView.image = image;
    
    if([_selectedTweetData objectForKey:@(indexPath.row).stringValue])
    {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }
    else
        cell.accessoryType = UITableViewCellAccessoryNone;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.backgroundColor = [UIColor whiteColor];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *tweet = (self.results)[indexPath.row];
    
    // Check if first time this run through
    if(_firstSearch == false)
    {
        // Display alert message explaining the UI
        UIAlertView *messageAlert = [[UIAlertView alloc]
                                 initWithTitle:@"Tweet Saved" message:@"Select tweets you want to save for later!" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    
        [messageAlert show];
        _firstSearch = true;
    }
    
    // Load appropriate cell user touched
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    
    // Cell does has not been touched yet
    if(cell.accessoryType != UITableViewCellAccessoryCheckmark)
    {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        
        if([_selectedTweetData objectForKey:@(indexPath.row).stringValue])
        {
            // Tweet is already saved
        }
        else
        {
            // Add tweet to MutableArray to save into core data stack at transition
            [_selectedTweetData setObject:tweet forKey:@(indexPath.row).stringValue];
        }
        
    }
    else
    {
        // Deselect tweet and remove
        cell.accessoryType = UITableViewCellAccessoryNone;
        
        if([_selectedTweetData objectForKey:@(indexPath.row).stringValue])
        {
            // Remove from MutableArray
            [_selectedTweetData removeObjectForKey:@(indexPath.row).stringValue];
        }

        
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Set cell height to handle larges tweet size. Plus the uniformity looks better
    return 84;
}

#pragma mark -
#pragma mark === Private methods ===
#pragma mark -

#define RESULTS_PERPAGE @"100"

- (void)loadQuery
{
    // Set searchState and begin twitter query
    self.searchState = UYLTwitterSearchStateLoading;
    NSString *encodedQuery = [self.query stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    ACAccountType *accountType = [self.accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    [self.accountStore requestAccessToAccountsWithType:accountType
                                               options:NULL
                                            completion:^(BOOL granted, NSError *error)
     {
         if (granted)
         {
             // User is logged in/has internet. load twitter search url and begin tweet search
             NSURL *url = [NSURL URLWithString:@"https://api.twitter.com/1.1/search/tweets.json"];
             NSDictionary *parameters = @{@"count" : RESULTS_PERPAGE,
                                          @"q" : encodedQuery};
             
             SLRequest *slRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter
                                                     requestMethod:SLRequestMethodGET
                                                               URL:url
                                                        parameters:parameters];
             
             NSArray *accounts = [self.accountStore accountsWithAccountType:accountType];
             slRequest.account = [accounts lastObject];             
             NSURLRequest *request = [slRequest preparedURLRequest];
             dispatch_async(dispatch_get_main_queue(), ^{
                 self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
                 [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
             });
         }
         else
         {
             // Twitter search unsuccesful, update search state and reload
             self.searchState = UYLTwitterSearchStateRefused;
             dispatch_async(dispatch_get_main_queue(), ^{
                 [self.tableView reloadData];
             });
         }
     }];
}

// Connection response functions from twitter search completion handler
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    self.buffer = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    
    [self.buffer appendData:data];
}

// Connection completed.
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    self.connection = nil;
    
    NSError *jsonParsingError = nil;
    NSDictionary *jsonResults = [NSJSONSerialization JSONObjectWithData:self.buffer options:0 error:&jsonParsingError];
    
    // Save statuses for table use
    self.results = jsonResults[@"statuses"];
    if ([self.results count] == 0)
    {
        // Search Unsuccessful. Update search state variable
        NSArray *errors = jsonResults[@"errors"];
        if ([errors count])
        {
            self.searchState = UYLTwitterSearchStateFailed;
        }
        else
        {
            self.searchState = UYLTwitterSearchStateNotFound;
        }
    }
    
    // Reset and reload regardless of success/failure
    self.buffer = nil;
    [self.refreshControl endRefreshing];
    [self.tableView reloadData];
    [self.tableView flashScrollIndicators];
}

// Connection failed. Set search state and reset connection variables
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    self.connection = nil;
    self.buffer = nil;
    [self.refreshControl endRefreshing];
    self.searchState = UYLTwitterSearchStateFailed;
    
    [self handleError:error];
    [self.tableView reloadData];
}

// Notify user of the issue
- (void)handleError:(NSError *)error
{
    NSString *errorMessage = [error localizedDescription];
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Connection Error"                              
                                                        message:errorMessage
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
    [alertView show];
}

- (void)cancelConnection
{
    if (self.connection != nil)
    {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        [self.connection cancel];
        self.connection = nil;
        self.buffer = nil;
    }    
}

@end

