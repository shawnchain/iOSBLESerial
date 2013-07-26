//
//  BLEDemoConnectViewController.h
//  BLESerialDemo
//
//  Created by Shawn Chain on 13-7-26.
//  Copyright (c) 2013年 JoyLabs. All rights reserved.
//

#import <UIKit/UIKit.h>

@class BLESerialService;
@interface BLEDemoSendReceiveViewController : UIViewController

@property(nonatomic,assign) IBOutlet UITextField *sendTextField;
@property(nonatomic,assign) IBOutlet UITextView *textView;
-(IBAction)onSend:(id)sender;

-(id)initWithSerialService:(BLESerialService*)service;
@end
