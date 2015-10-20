//
//  TweetSearch
//  Created by John Mikelich on 7/29/15
//

#import "ViewController.h"
#import "SearchViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField.text)
    {
        // If the user has typed any text, begin transition to SearchViewController
        [self performSegueWithIdentifier:@"SegueSearchView" sender:textField];
    }
    
    //Textfield removes keyboard
    [textField resignFirstResponder];
    return YES;
}

//
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"SegueSearchView"])
    {
        // Save user textfield as twitter search term and segue
        UITextField *textField = sender;
        SearchViewController *viewController = segue.destinationViewController;
        viewController.query = [NSString stringWithFormat:@"%@", textField.text];
    }
}

@end
