//
//  DemoUtility.h
//  DJISimulatorDemo
//
//  Created by DJI on 8/6/2016.
//  Copyright © 2016 DJI. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define WeakRef(__obj) __weak typeof(self) __obj = self
#define WeakReturn(__obj) if(__obj ==nil)return;

#ifndef DemoUtility_h
#define DemoUtility_h

#import "DemoUtilityMacro.h"
#import "DemoUtilityMethod.h"
#import "DemoAlertView.h"
#import "DemoComponentHelper.h"
#import "DemoGetSetViewController.h"
#import "DemoPushInfoViewController.h"
#import "DemoSettingItem.h"
#import "DemoTableViewController.h"
#import "MBProgressHUD.h"

#endif /* DemoUtility_h */

@class DJIBaseProduct;
@class DJIAircraft;
@class DJIGimbal;
@class DJIFlightController;

@interface DemoUtility : NSObject

+(DJIBaseProduct*) fetchProduct;
+(DJIAircraft*) fetchAircraft;
+(DJIFlightController*) fetchFlightController;
+ (void)showAlertViewWithTitle:(NSString *)title message:(NSString *)message cancelAlertAction:(UIAlertAction*)cancelAlert defaultAlertAction:(UIAlertAction*)defaultAlert viewController:(UIViewController *)viewController;

@end
