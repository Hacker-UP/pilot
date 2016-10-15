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
#import "DJIGimbal+CapabilityCheck.h"
#import <DJISDK/DJISDK.h>
#import <VideoPreviewer/VideoPreviewer.h>


@interface PilotViewController () <DJICameraDelegate>

@property(nonatomic, weak) IBOutlet UIView* fpvView;
@property (weak, nonatomic) IBOutlet UIView *fpvTemView;
@property (weak, nonatomic) IBOutlet UISwitch *fpvTemEnableSwitch;
@property (weak, nonatomic) IBOutlet UILabel *fpvTemperatureData;

@property (assign, nonatomic) DJIGimbalAngleRotation pitchRotation;
@property (assign, nonatomic) DJIGimbalAngleRotation yawRotation;
@property (assign, nonatomic) DJIGimbalAngleRotation rollRotation;

// gimbal button
@property (weak, nonatomic) IBOutlet UIButton *upButton;
@property (weak, nonatomic) IBOutlet UIButton *downButton;
@property (weak, nonatomic) IBOutlet UIButton *leftButton;
@property (weak, nonatomic) IBOutlet UIButton *rightButton;

@property(strong,nonatomic) NSTimer* gimbalSpeedTimer;

@property (assign, nonatomic) float currentYaw;
@property (assign, nonatomic) BOOL isSimulatorOn;
@property (weak, nonatomic) IBOutlet UILabel *simulatorStateLabel;

@property(atomic) float rotationAngleVelocity;
@property(atomic) DJIGimbalRotateDirection rotationDirection;
@property (strong, nonatomic) PilotSpiralHelper *pilotSpiralHelper;

@property(nonatomic, assign) BOOL needToSetMode;

- (IBAction)onLeftButtonClicked:(id)sender;
- (IBAction)onRightButtonClicked:(id)sender;

@end

@implementation PilotViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.currentYaw = 0.0;
    
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
    DJIGimbal* gimbal = [DemoComponentHelper fetchGimbal];
    NSInteger min = [[gimbal getParamMin:DJIGimbalParamAdjustYaw] integerValue];
    NSInteger max = [[gimbal getParamMax:DJIGimbalParamAdjustYaw] integerValue];
    
    [self.pilotSpiralHelper setBlock:^(PilotSpiralHelper *cls, double horizontal, double vertical) {
        if (horizontal > 0) {
            _yawRotation.direction = DJIGimbalRotateDirectionCounterClockwise;
            if (_yawRotation.angle - horizontal * 40 >= min && _yawRotation.angle - horizontal * 40 <= max) {
                _yawRotation.angle -= horizontal * 40;
            }
            [weakSelf rotateRight];
        } else {
            _yawRotation.direction = DJIGimbalRotateDirectionCounterClockwise;
            if (_yawRotation.angle - horizontal * 40 >= min && _yawRotation.angle - horizontal * 40 <= max) {
                _yawRotation.angle -= horizontal * 40;
            }
            [weakSelf rotateLeft];
        }
        
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
    
    [self setupRotationStructs];
    [self enablePitchExtensionIfPossible];
}

-(void) setupRotationStructs {
    DJIGimbal* gimbal = [DemoComponentHelper fetchGimbal];
    _pitchRotation.enabled = [gimbal isFeatureSupported:DJIGimbalParamAdjustPitch];
    _yawRotation.enabled = [gimbal isFeatureSupported:DJIGimbalParamAdjustYaw];
    _rollRotation.enabled = [gimbal isFeatureSupported:DJIGimbalParamAdjustRoll];
}

-(void) enablePitchExtensionIfPossible {
    DJIGimbal* gimbal = [DemoComponentHelper fetchGimbal];
    if (gimbal == nil) {
        return;
    }
    BOOL isPossible = [gimbal isFeatureSupported:DJIGimbalParamPitchRangeExtensionEnabled];
    if (isPossible) {
        [gimbal setPitchRangeExtensionEnabled:YES withCompletion:nil];
    }
}

-(void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[VideoPreviewer instance] setView:self.fpvView];
    
    [self updateThermalCameraUI];
    
    // rotate
    [self resetRotation];
    [self enterVirtualStickControl];
}

-(void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // Call unSetView during exiting to release the memory.
    [[VideoPreviewer instance] unSetView];
    
    if (self.gimbalSpeedTimer) {
        [self.gimbalSpeedTimer invalidate];
        self.gimbalSpeedTimer = nil;
    }
    
    [self exitVirtualStickControl];
}

- (IBAction)onLeftButtonClicked:(id)sender {
    DJIGimbal* gimbal = [DemoComponentHelper fetchGimbal];
    NSInteger max = [[gimbal getParamMax:DJIGimbalParamAdjustYaw] integerValue];
    
    _yawRotation.direction = DJIGimbalRotateDirectionCounterClockwise;
    if (_yawRotation.angle + 10 <= (double)max) {
        _yawRotation.angle += 10;
    }
    [self rotateLeft];
}

- (IBAction)onRightButtonClicked:(id)sender {
    DJIGimbal* gimbal = [DemoComponentHelper fetchGimbal];
    NSInteger min = [[gimbal getParamMin:DJIGimbalParamAdjustYaw] integerValue];
    
    _yawRotation.direction = DJIGimbalRotateDirectionCounterClockwise;
    if (_yawRotation.angle - 10 >= (double)min) {
        _yawRotation.angle -= 10;
    }
    [self rotateRight];
}


- (void)rotateLeft {
    
    DJIGimbal* gimbal = [DemoComponentHelper fetchGimbal];
    [gimbal rotateGimbalWithAngleMode:DJIGimbalAngleModeAbsoluteAngle pitch:self.pitchRotation roll:self.rollRotation yaw:self.yawRotation withCompletion:^(NSError * _Nullable error) {
        if (error) {
//             ShowResult(@"rotateGimbalWithAngleMode failed: %@", error.description);
        }
    }];
}

- (void)rotateRight {
    DJIGimbal* gimbal = [DemoComponentHelper fetchGimbal];
    [gimbal rotateGimbalWithAngleMode:DJIGimbalAngleModeAbsoluteAngle pitch:self.pitchRotation roll:self.rollRotation yaw:self.yawRotation withCompletion:^(NSError * _Nullable error) {
        if (error) {
//            ShowResult(@"rotateGimbalWithAngleMode failed: %@", error.description);
        }
    }];
}


- (void)rotate:(float)yawAngle {
    if (yawAngle > DJIVirtualStickYawControlMaxAngle) { //Filter the angle between -180 ~ 0, 0 ~ 180
        yawAngle = yawAngle - 360;
    }
    
    [self rotateDrone: nil];
}

- (void)rotateDrone:(NSTimer *)timer {

    float yawAngle = 30;
    
    DJIFlightController *flightController = [DemoUtility fetchFlightController];
    DJIVirtualStickFlightControlData vsFlightCtrlData;
    vsFlightCtrlData.pitch = 0;
    vsFlightCtrlData.roll = 0;
    vsFlightCtrlData.verticalThrottle = 0;
    vsFlightCtrlData.yaw = yawAngle;
    
    [flightController sendVirtualStickFlightControlData:vsFlightCtrlData withCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"Send FlightControl Data Failed %@", error.description);
        }
    }];
    
}

- (void)enterVirtualStickControl {
    DJIFlightController* fc = [DemoUtility fetchFlightController];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
    
    if (fc) {
        
//        fc.yawControlMode = DJIVirtualStickYawControlModeAngularVelocity;
//        fc.rollPitchControlMode = DJIVirtualStickRollPitchControlModeVelocity;
        
        [fc setYawControlMode:DJIVirtualStickYawControlModeAngle];
        [fc setRollPitchCoordinateSystem:DJIVirtualStickFlightCoordinateSystemGround];
        
        [fc enableVirtualStickControlModeWithCompletion:^(NSError *error) {
            if (error) {
                [DemoUtility showAlertViewWithTitle:nil message:[NSString stringWithFormat:@"Enter Virtual Stick Mode: %@", error.description] cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
            } else {
                [DemoUtility showAlertViewWithTitle:nil message:@"Enter Virtual Stick Mode:Succeeded" cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
            }
        }];
    } else {
        [DemoUtility showAlertViewWithTitle:nil message:@"Component not exist." cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
    }
}

- (void)exitVirtualStickControl {
    DJIFlightController* fc = [DemoUtility fetchFlightController];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
    
    if (fc) {
        [fc disableVirtualStickControlModeWithCompletion:^(NSError * _Nullable error) {
            if (error){
                [DemoUtility showAlertViewWithTitle:nil message:[NSString stringWithFormat:@"Exit Virtual Stick Mode: %@", error.description] cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
            } else {
                [DemoUtility showAlertViewWithTitle:nil message:@"Exit Virtual Stick Mode:Succeeded" cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
            }
        }];
    } else {
        [DemoUtility showAlertViewWithTitle:nil message:@"Component not exist." cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
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
