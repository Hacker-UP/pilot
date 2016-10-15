//
//  DJIRootViewController.m
//
//  Created by DJI on 8/6/2016.
//  Copyright © 2016 DJI. All rights reserved.
//

#import "RootViewController.h"
#import <DJISDK/DJISDK.h>
#import "DemoUtility.h"
#import "PilotSpiralHelper.h"

static BOOL IS_RUN_ANIMATION = false;

@interface RootViewController ()<DJISDKManagerDelegate>

@property(nonatomic, weak) DJIBaseProduct* product;
@property (weak, nonatomic) IBOutlet UILabel *connectStatusLabel;
@property (weak, nonatomic) IBOutlet UILabel *modelNameLabel;
@property (weak, nonatomic) IBOutlet UIButton *connectButton;
@property (weak, nonatomic) IBOutlet UIButton *warnButton;
@property (assign) BOOL isShowWarning;

- (IBAction)onConnectButtonClicked:(id)sender;

@property (strong, nonatomic) PilotSpiralHelper *pilotSpiralHelper;

@end

@implementation RootViewController

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    NSString* appKey = @"b634fbc68a968a880a969786"; 
    
    if ([appKey length] == 0) {
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
        [DemoUtility showAlertViewWithTitle:nil message:@"Please enter your App Key" cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
    }
    else
    {
        [DJISDKManager registerApp:appKey withDelegate:self];
    }
    
    if(self.product){
        [self updateStatusBasedOn:self.product];
    }
}

- (void)viewDidLoad {
    
    [super viewDidLoad];
    [self initUI];
    
    
}

- (void)initUI
{
    self.isShowWarning = NO;
    self.title = @"DJISimulator Demo";
    self.modelNameLabel.hidden = NO;
    //Disable the connect button by default
    [self.connectButton setEnabled:NO];
    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:3
                     animations:^{
                         self.connectButton.alpha = 0;
                     }
                     completion:^(BOOL finished) {
                         IS_RUN_ANIMATION = YES;
                         [weakSelf warningAnimationStart];
                     }];
}

- (void)warningAnimationStart {
    [UIView animateKeyframesWithDuration:3
                                   delay:0
                                 options:UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionRepeat | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionAutoreverse
                              animations:^{
                                  self.warnButton.alpha = 0;
                              }
                              completion:^(BOOL finished) {
                                  
                              }];
}

- (void)stopWarningAnimationStart {
    [UIView animateWithDuration:0.1
                          delay:0
                        options:UIViewAnimationCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         self.warnButton.alpha = 0;
                     }
                     completion:^(BOOL finished) {
                         
                     }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - DJISDKManager Delegate Methods

- (void)sdkManagerDidRegisterAppWithError:(NSError *)error
{
    if (!error) {
        
        [DJISDKManager startConnectionToProduct];
        
    }else
    {
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
        [DemoUtility showAlertViewWithTitle:nil message:[NSString stringWithFormat:@"Registration Error:%@", error] cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
        
        [self.connectButton setEnabled:NO];
    }
    
}

- (void)sdkManagerProductDidChangeFrom:(DJIBaseProduct *)oldProduct to:(DJIBaseProduct *)newProduct
{
    if (newProduct) {
        self.product = newProduct;
        
        [self.connectButton setEnabled:YES];
        self.warnButton.hidden = YES;
        [self stopWarningAnimationStart];
        [UIView animateWithDuration:3 animations:^{
            self.connectButton.alpha = 1;
        }];
        
    } else {
        
        NSString* message = [NSString stringWithFormat:@"Connection lost. Back to root."];
        
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
        UIAlertAction *backAction = [UIAlertAction actionWithTitle:@"Back" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            if (![self.navigationController.topViewController isKindOfClass:[RootViewController class]]) {
                [self.navigationController popToRootViewControllerAnimated:NO];
            }
        }];
        [DemoUtility showAlertViewWithTitle:nil message:message cancelAlertAction:cancelAction defaultAlertAction:backAction viewController:self];

        [self.connectButton setEnabled:NO];
        self.product = nil;
    }
    
    [self updateStatusBasedOn:newProduct];
}

- (IBAction)onConnectButtonClicked:(id)sender {
    NSLog(@"hello");
}

-(void) updateStatusBasedOn:(DJIBaseProduct* )newConnectedProduct {
    if (newConnectedProduct){
        self.connectStatusLabel.text = NSLocalizedString(@"Status: Product Connected", @"");
        self.modelNameLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Model: \%@", @""),newConnectedProduct.model];
        self.modelNameLabel.hidden = NO;
        
    } else {
        self.connectStatusLabel.text = NSLocalizedString(@"Status: Product Not Connected", @"");
        self.modelNameLabel.text = NSLocalizedString(@"Model: Unknown", @"");
    }
}


@end
