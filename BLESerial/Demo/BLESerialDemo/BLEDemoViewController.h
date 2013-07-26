//
//  BLEDemoViewController.h
//  BLESerialDemo
//
//  Created by Shawn Chain on 13-7-26.
//  Copyright (c) 2013年 JoyLabs. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BLEDemoViewController : UIViewController

@property(nonatomic,assign) IBOutlet UIActivityIndicatorView *connectIndicator;
@property(nonatomic,assign) IBOutlet UIButton *connectButton;

-(IBAction)onConnect:(id)sender;
@end
