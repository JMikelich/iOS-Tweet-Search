//
//  TweetSearch
//  Created by John Mikelich on 7/29/15
//
//  TweetViewController loads the saved user tweets from core data and
//  allows the user to delete them using the swipe/delete UI.
//  The core data stack is updated after each deletion to ensure accuracy.
//


#import "TweetViewController.h"
#import <CoreData/CoreData.h>

@interface TweetViewController ()

// Table array loaded from core data
@property (nonatomic, strong) NSMutableArray *tweets;


@end

@implementation TweetViewController

#pragma mark -
#pragma mark === View Setup ===
#pragma mark -

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Load core data 'tweet' entities
    NSManagedObjectContext *managedObjectContext = [self managedObjectContext];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Tweet"];
    self.tweets = [[managedObjectContext executeFetchRequest:fetchRequest error:nil] mutableCopy];
    
    // Disable for slide/delete interface
    self.tableView.allowsMultipleSelectionDuringEditing = NO;
    
    [self.tableView reloadData];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
#pragma mark === Table View Setup ===
#pragma mark -


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {

    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

    if(self.tweets.count == 0)
    {
    // Display a message when the table is empty
    UILabel *messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height)];
    
    messageLabel.text = @"You have no saved tweets";
    messageLabel.textColor = [UIColor blackColor];
    messageLabel.numberOfLines = 0;
    messageLabel.textAlignment = NSTextAlignmentCenter;
    messageLabel.font = [UIFont fontWithName:@"System" size:20];
    [messageLabel sizeToFit];
    
    self.tableView.backgroundView = messageLabel;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    }
    
    // Atleast one tweet saved, return count for table setup
    return self.tweets.count;

}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *EmptyCellIdentifier = @"EmptyCell";
    static NSString *ResultCellIdentifier = @"ResultCell";

    
    NSUInteger count = [self.tweets count];
    if ((count == 0) && (indexPath.row == 0))
    {
        // Placeholder cell. No data loaded, or the table has been deleted until empty
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:EmptyCellIdentifier];
        cell.textLabel.text = @"No Tweets Saved";
        return cell;
    }
    
    // Configure the cell
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ResultCellIdentifier];
    NSManagedObject *individualTweet = [self.tweets objectAtIndex:indexPath.row];
    
    // Parse through the tweet for image URL
    NSURL *url = [NSURL URLWithString:[[individualTweet valueForKey: @"imageURL"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    NSData *data = [NSData dataWithContentsOfURL : url];
    UIImage *image = [UIImage imageWithData: data];
    
    // Setup cell
    [cell.textLabel setText:[NSString stringWithFormat:@"%@", [individualTweet valueForKey:@"text"]]];
    cell.imageView.image = image;
    return cell;
    
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Returning YES to enable slide/delete
    return YES;
}


- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 84;
}

#pragma mark -
#pragma mark === Core Data Handlers ===
#pragma mark -


// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        
        // Remove from core data stack
         NSManagedObjectContext *context = [self managedObjectContext];
        
        // Delete object from database
        [context deleteObject:[_tweets objectAtIndex:indexPath.row]];
        
        NSError *error = nil;
        if (![context save:&error]) {
            NSLog(@"Can't Delete! %@ %@", error, [error localizedDescription]);
            return;
        }
        
        // Remove from loaded array
        [_tweets removeObjectAtIndex:indexPath.row];
        

        // Remove from displayed table
        [tableView beginUpdates];
        [tableView deleteRowsAtIndexPaths:[[NSArray alloc] initWithObjects:indexPath, nil] withRowAnimation:UITableViewRowAnimationFade];
        [tableView endUpdates];
        
    }
}

- (NSManagedObjectContext *)managedObjectContext
{
    NSManagedObjectContext *context = nil;
    
    id delegate = [[UIApplication sharedApplication] delegate];
    if ([delegate performSelector:@selector(managedObjectContext)]) {
        context = [delegate managedObjectContext];
    }
    
    return context;
}


@end
