//
//  PilotSpiralHelper.h
//  pilot
//
//  Created by 段昊宇 on 16/10/15.
//  Copyright © 2016年 DJI. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PilotSpiralHelper;
typedef void (^directionBlock)(PilotSpiralHelper *cls, double horizontal, double vertical);

@interface PilotSpiralHelper : NSObject

@property (nonatomic, strong) directionBlock callBlock;

- (void)setBlock:(directionBlock)callBlock;
- (void)startPilotSpiralUpdateResult;

@end
