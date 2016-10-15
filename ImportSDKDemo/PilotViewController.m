//
//  ViewController.m
//  pilot
//
//  Created by UP on 15/10/2016.
//  Copyright © 2016 UP. All rights reserved.
//

#import "PilotViewController.h"
#import "DemoUtility.h"
#import "DemoComponentHelper.h"
#import "PilotSpiralHelper.h"
#import <DJISDK/DJISDK.h>
#import <VideoPreviewer/VideoPreviewer.h>


@interface PilotViewController () <DJICameraDelegate>

@property(nonatomic, weak) IBOutlet UIView* fpvView;
@property (weak, nonatomic) IBOutlet UIView *fpvTemView;
@property (weak, nonatomic) IBOutlet UISwitch *fpvTemEnableSwitch;
@property (weak, nonatomic) IBOutlet UILabel *fpvTemperatureData;

// gimbal button
@property (weak, nonatomic) IBOutlet UIButton *upButton;
@property (weak, nonatomic) IBOutlet UIButton *downButton;
@property (weak, nonatomic) IBOutlet UIButton *leftButton;
@property (weak, nonatomic) IBOutlet UIButton *rightButton;

@property(strong,nonatomic) NSTimer* gimbalSpeedTimer;

@property(atomic) float rotationAngleVelocity;
@property(atomic) DJIGimbalRotateDirection rotationDirection;
@property (strong, nonatomic) PilotSpiralHelper *pilotSpiralHelper;

@property(nonatomic, assign) BOOL needToSetMode;

@end

@implementation PilotViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.fpvTemEnableSwitch setOn:YES];
    
    DJICamera* camera = [DemoComponentHelper fetchCamera];
    if (camera) {
        camera.delegate = self;
    }
    
    self.needToSetMode = YES;
    
    [[VideoPreviewer instance] start];
    [[VideoPreviewer instance] setDecoderWithProduct:[DemoComponentHelper fetchProduct] andDecoderType:VideoPreviewerDecoderTypeSoftwareDecoder];
    
    self.pilotSpiralHelper = [[PilotSpiralHelper alloc] init];
    __weak typeof(self) weakSelf = self;
    [self.pilotSpiralHelper setBlock:^(PilotSpiralHelper *cls, double horizontal, double vertical) {
        NSLog(@"%lf %lf", horizontal, vertical);
        if (vertical > 0) {
            weakSelf.rotationAngleVelocity = vertical * 40;
            weakSelf.rotationDirection = DJIGimbalRotateDirectionClockwise;
            [weakSelf onUpdateGimbalSpeedTick:nil];
        } else {
            weakSelf.rotationAngleVelocity = -vertical * 40;
            weakSelf.rotationDirection = DJIGimbalRotateDirectionCounterClockwise;
            [weakSelf onUpdateGimbalSpeedTick:nil];
        }
    }];
    [self.pilotSpiralHelper startPilotSpiralUpdateResult];
}

-(void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[VideoPreviewer instance] setView:self.fpvView];
    
    [self updateThermalCameraUI];
    
    // rotate
    [self resetRotation];
    
    
//    if (self.gimbalSpeedTimer == nil) {
//        self.gimbalSpeedTimer = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(onUpdateGimbalSpeedTick:) userInfo:nil repeats:YES];
//    }
}

-(void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // Call unSetView during exiting to release the memory.
    [[VideoPreviewer instance] unSetView];
    
    if (self.gimbalSpeedTimer) {
        [self.gimbalSpeedTimer invalidate];
        self.gimbalSpeedTimer = nil;
    }
    
    
}


-(IBAction) onSegmentControlValueChanged:(UISegmentedControl*)sender {
    if (sender.selectedSegmentIndex == 0) {
        [[VideoPreviewer instance] setDecoderWithProduct:[DemoComponentHelper fetchProduct] andDecoderType:VideoPreviewerDecoderTypeSoftwareDecoder];
    } else {
        BOOL result = [[VideoPreviewer instance] setDecoderWithProduct:[DemoComponentHelper fetchProduct] andDecoderType:VideoPreviewerDecoderTypeHardwareDecoder];
        if (!result) {
            NSLog(@"Not suitable hardware decoder for the current product. ");
        }
    }
}

- (IBAction)onThermalTemperatureDataSwitchValueChanged:(id)sender {
    DJICamera* camera = [DemoComponentHelper fetchCamera];
    if (camera) {
        DJICameraThermalMeasurementMode mode = ((UISwitch*)sender).on ? DJICameraThermalMeasurementModeSpotMetering : DJICameraThermalMeasurementModeDisabled;
        [camera setThermalMeasurementMode:mode withCompletion:^(NSError * _Nullable error) {
            if (error) {
                ShowResult(@"Failed to set the measurement mode: %@", error.description);
            }
        }];
    }
}

- (void)updateThermalCameraUI {
    DJICamera* camera = [DemoComponentHelper fetchCamera];
    if (camera && [camera isThermalImagingCamera]) {
        [self.fpvTemView setHidden:NO];
        WeakRef(target);
        [camera getThermalMeasurementModeWithCompletion:^(DJICameraThermalMeasurementMode mode, NSError * _Nullable error) {
            WeakReturn(target);
            if (error) {
                ShowResult(@"Failed to get the measurement mode status: %@", error.description);
            }
            else {
                BOOL enabled = mode != DJICameraThermalMeasurementModeDisabled ? YES : NO;
                [target.fpvTemEnableSwitch setOn:enabled];
            }
        }];
    }
    else {
        [self.fpvTemView setHidden:YES];
    }
}

#pragma mark - DJICameraDelegate
- (void)camera:(DJICamera *)camera didReceiveVideoData:(uint8_t *)videoBuffer length:(size_t)size {
    if(![[[VideoPreviewer instance] dataQueue] isFull]){
        [[VideoPreviewer instance] push:videoBuffer length:(int)size];
    }
}

- (void)camera:(DJICamera *)camera didUpdateSystemState:(DJICameraSystemState *)systemState {
    if (systemState.mode == DJICameraModePlayback ||
        systemState.mode == DJICameraModeMediaDownload) {
        if (self.needToSetMode) {
            self.needToSetMode = NO;
            WeakRef(obj);
            [camera setCameraMode:DJICameraModeShootPhoto withCompletion:^(NSError * _Nullable error) {
                if (error) {
                    WeakReturn(obj);
                    obj.needToSetMode = YES;
                }
            }];
        }
    }
}

- (void)camera:(DJICamera *)camera didUpdateTemperatureData:(float)temperature {
    self.fpvTemperatureData.text = [NSString stringWithFormat:@"%f", temperature];
}

- (void)onUpdateGimbalSpeedTick:(id)timer {
    __weak DJIGimbal* gimbal = [DemoComponentHelper fetchGimbal];
    if (gimbal) {
        DJIGimbalSpeedRotation pitchRotation;
        pitchRotation.angleVelocity = self.rotationAngleVelocity;
        pitchRotation.direction = self.rotationDirection;
        
        DJIGimbalSpeedRotation stopRotation;
        stopRotation.angleVelocity = 0.0;
        stopRotation.direction = DJIGimbalRotateDirectionClockwise;
        
        [gimbal rotateGimbalBySpeedWithPitch:pitchRotation roll:stopRotation yaw:stopRotation withCompletion:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"ERROR: rotateGimbalInSpeed. %@", error.description);
            }
        }];
    }
}


- (IBAction)onUpButtonClicked:(id)sender {
    self.rotationAngleVelocity = 10.0;
    self.rotationDirection = DJIGimbalRotateDirectionClockwise;
    [self onUpdateGimbalSpeedTick:nil];
}

- (IBAction)onDownButtonClicked:(id)sender {
    self.rotationAngleVelocity = 10.0;
    self.rotationDirection = DJIGimbalRotateDirectionCounterClockwise;
    [self onUpdateGimbalSpeedTick:nil];
}

- (void)resetRotation {
    self.rotationAngleVelocity = 0.0;
    self.rotationDirection = DJIGimbalRotateDirectionClockwise;
}

@end
