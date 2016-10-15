//
//  PilotSpiralHelper.m
//  pilot
//
//  Created by 段昊宇 on 16/10/15.
//  Copyright © 2016年 DJI. All rights reserved.
//

#import "PilotSpiralHelper.h"
#import <CoreMotion/CoreMotion.h>

@interface PilotSpiralHelper()

@property (nonatomic, strong) CMMotionManager *motionManager;

@end

@implementation PilotSpiralHelper

- (void)setBlock:(directionBlock)callBlock {
    self.callBlock = callBlock;
}

- (void)startPilotSpiralUpdateResult {
    __block double xb = 100, yb = 100, zb = 100;
    self.motionManager.accelerometerUpdateInterval = 0.01;
    
    [self.motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable error) {
        double xn = motion.rotationRate.x;
        double yn = motion.rotationRate.y;
        double zn = motion.rotationRate.z;
        
        if (fabs(xn - xb) > 0.1 && fabs(yn - yb) > 0.1 && fabs(zn - zb) > 0.05) {
            if (fabs(xn - xb) < 10 && fabs(yn - yb) < 10) {
                self.callBlock(self, xn, yn);
            }
            xb = xn;
            yb = yn;
            zb = zn;
        }
    }];
}

- (CMMotionManager *)motionManager {
    if (!_motionManager) {
        _motionManager = [[CMMotionManager alloc] init];
    }
    return _motionManager;
}

@end
