//
//  BLEDemoConnectViewController.m
//  BLESerialDemo
//
//  Created by Shawn Chain on 13-7-26.
//  Copyright (c) 2013年 JoyLabs. All rights reserved.
//

#import "BLEDemoSendReceiveViewController.h"

#import "BLESerialService.h"


@interface BLEDemoSendReceiveViewController ()<UIAlertViewDelegate,UITextFieldDelegate>
@property(nonatomic,assign) BLESerialService *serialService;
@end

@implementation BLEDemoSendReceiveViewController

- (id) initWithSerialService:(BLESerialService*)service;
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        // Custom initialization
        self.serialService = service;
        service.dataReceivedBlock = ^(BLESerialService *service, NSData *data){
            NSString *strRecv = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            self.textView.text = [NSString stringWithFormat:@"%@< %@\n",self.textView.text,strRecv];
            [strRecv release];
        };
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    UIBarButtonItem *disconnectBtn = [[[UIBarButtonItem alloc] initWithTitle:@"Disconnect" style:UIBarButtonItemStyleDone target:self action:@selector(onDisconnect:)] autorelease];
    self.navigationItem.leftBarButtonItem = disconnectBtn;
    self.navigationController.navigationBarHidden = NO;
    self.navigationItem.hidesBackButton = YES;
    
    [_sendTextField becomeFirstResponder];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)dealloc{
    self.serialService.dataReceivedBlock = nil;
    [super dealloc];
}

-(IBAction)onDisconnect:(id)sender{
    UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Disconnect" message:@"Are U sure to disconnect and quit?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Disconnect", nil] autorelease];
    [alert show];
}

-(IBAction)onSend:(id)sender{
    if([_sendTextField.text length] == 0){
        return;
    }
    
    NSData *data = [_sendTextField.text dataUsingEncoding:[NSString defaultCStringEncoding]];
    [_serialService send:data];
    _textView.text = [NSString stringWithFormat:@"%@> %@\n",_textView.text,_sendTextField.text];
    _sendTextField.text = nil;
}

#pragma mark - UIAletView delegate
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex{
    if(buttonIndex == 1){
        [_serialService disconnect:nil];
        [self.navigationController popViewControllerAnimated:YES];
    }
}

#pragma mark - UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    // send the message when <return> key pressed
    [self onSend:nil];
    return YES;
}
@end
