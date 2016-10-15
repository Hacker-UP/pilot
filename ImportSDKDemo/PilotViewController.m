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
#import <DJISDK/DJISDK.h>
#import <VideoPreviewer/VideoPreviewer.h>


@interface PilotViewController () <DJICameraDelegate, DJISimulatorDelegate>

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

@property (assign, nonatomic) float mYaw;
@property (assign, nonatomic) BOOL isSimulatorOn;
@property (weak, nonatomic) IBOutlet UILabel *simulatorStateLabel;

@property(atomic) float rotationAngleVelocity;
@property(atomic) DJIGimbalRotateDirection rotationDirection;


@property(nonatomic, assign) BOOL needToSetMode;

- (IBAction)onLeftButtonClicked:(id)sender;
- (IBAction)onRightButtonClicked:(id)sender;

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
    
    DJIFlightController* fc = [DemoUtility fetchFlightController];
    if (fc && fc.simulator) {
        self.isSimulatorOn = fc.simulator.isSimulatorStarted;
        [self updateSimulatorUI];
        
        [fc.simulator addObserver:self forKeyPath:@"isSimulatorStarted" options:NSKeyValueObservingOptionNew context:nil];
        [fc.simulator setDelegate:self];
    }

    [self toggleSimulator];
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
    
    DJIFlightController* fc = [DemoUtility fetchFlightController];
    if (fc && fc.simulator) {
        [fc.simulator removeObserver:self forKeyPath:@"isSimulatorStarted"];
        [fc.simulator setDelegate:nil];
    }
    
    [self exitVirtualStickControl];
    [self toggleSimulator];
}

- (IBAction)onLeftButtonClicked:(id)sender {
    [self rotateLeft];
}

- (IBAction)onRightButtonClicked:(id)sender {
    [self rotateRight];
}


- (void)rotateLeft {
    float yawAngle = 90.0;
    [self rotate:yawAngle];
}

- (void)rotateRight {
    float yawAngle = -90.0;
    [self rotate:yawAngle];
}


- (void)rotate:(float)yawAngle {
    //    DJIVirtualStickFlightControlData ctrlData = {0};
    //    ctrlData.yaw = -0.5 * 30;
    //    DJIFlightController* fc = [DemoUtility fetchFlightController];
    //
    //    if (fc && fc.isVirtualStickControlModeAvailable) {
    //        [fc sendVirtualStickFlightControlData:ctrlData withCompletion:nil];
    //    }
    
    if (yawAngle > DJIVirtualStickYawControlMaxAngle) { //Filter the angle between -180 ~ 0, 0 ~ 180
        yawAngle = yawAngle - 360;
    }
    
    NSTimer *timer =  [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(rotateDrone:) userInfo:@{@"YawAngle":@(yawAngle)} repeats:YES];
    [timer fire];
    
    [[NSRunLoop currentRunLoop]addTimer:timer forMode:NSDefaultRunLoopMode];
    [[NSRunLoop currentRunLoop]runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
    
    [timer invalidate];
    timer = nil;
}

- (void)rotateDrone:(NSTimer *)timer {
    NSDictionary *dict = [timer userInfo];
    float yawAngle = [[dict objectForKey:@"YawAngle"] floatValue];
    
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

- (void)toggleSimulator {
    
    DJIFlightController* fc = [DemoUtility fetchFlightController];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
    if (fc && fc.simulator) {
        if (!self.isSimulatorOn) {
            // The initial aircraft's position in the simulator.
            CLLocationCoordinate2D location = CLLocationCoordinate2DMake(22, 113);
            [fc.simulator startSimulatorWithLocation:location updateFrequency:20 GPSSatellitesNumber:10 withCompletion:^(NSError * _Nullable error) {
                if (error) {
                    [DemoUtility showAlertViewWithTitle:nil message:[NSString stringWithFormat:@"Start Simulator error: %@", error.description] cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
                } else {
                    [DemoUtility showAlertViewWithTitle:nil message:@"Start Simulator succeeded." cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
                }
            }];
        } else {
            [fc.simulator stopSimulatorWithCompletion:^(NSError * _Nullable error) {
                if (error) {
                    [DemoUtility showAlertViewWithTitle:nil message:[NSString stringWithFormat:@"Stop Simulator error: %@", error.description] cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
                } else {
                    [DemoUtility showAlertViewWithTitle:nil message:@"Stop Simulator succeeded." cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
                }
            }];
        }
    }
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"isSimulatorStarted"]) {
        self.isSimulatorOn = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
        [self updateSimulatorUI];
    }
}

-(void) updateSimulatorUI {
    if (!self.isSimulatorOn) {
        NSLog(@"Simulator stopped");
    } else {
        NSLog(@"Simulator running");
    }
}


#pragma mark - DJI Simulator Delegate

-(void)simulator:(DJISimulator *)simulator updateSimulatorState:(DJISimulatorState *)state {
    [self.simulatorStateLabel setHidden:NO];
    self.simulatorStateLabel.text = [NSString stringWithFormat:@"Yaw: %0.2f Pitch: %0.2f Roll: %0.2f\n PosX: %0.2f PosY: %0.2f PosZ: %0.2f", state.yaw, state.pitch, state.roll, state.positionX, state.positionY, state.positionZ];
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

- (void)
resetRotation {
    self.rotationAngleVelocity = 0.0;
    self.rotationDirection = DJIGimbalRotateDirectionClockwise;
}

@end
