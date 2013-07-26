//
//  BLEDemoViewController.m
//  BLESerialDemo
//
//  Created by Shawn Chain on 13-7-26.
//  Copyright (c) 2013年 JoyLabs. All rights reserved.
//

#import "BLEDemoViewController.h"
#import "BLEDemoSendReceiveViewController.h"
#import "BLESerialService.h"

@interface BLEDemoViewController ()
@property (nonatomic,strong)BLESerialService *serialService;
@end

@implementation BLEDemoViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.navigationController.navigationBarHidden = YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


-(IBAction)onConnect:(id)sender{
    [self updateUI:YES];
    
    self.serialService = [[[BLESerialService alloc] init] autorelease];
    [_serialService connect:^(BLESerialService *service, NSError *error){
        [self updateUI:NO];
        if(!error){
            BLEDemoSendReceiveViewController *vc = [[[BLEDemoSendReceiveViewController alloc] initWithSerialService:_serialService] autorelease];
            [self.navigationController pushViewController:vc animated:YES];
        }else{
            UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Connect failed" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
            [alert show];
        }
    }];
}

-(void)updateUI:(BOOL)connect{
    if(connect){
        self.connectButton.hidden = YES;
        self.connectIndicator.hidden = NO;
        [self.connectIndicator startAnimating];
    }else{
        [self.connectIndicator stopAnimating];
        self.connectIndicator.hidden = YES;
        self.connectButton.hidden = NO;
    }
}

-(void)dealloc{
    self.serialService = nil;
    [super dealloc];
}
@end
