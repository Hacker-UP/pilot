//
//  ViewController.m
//  pilot
//
//  Created by UP on 15/10/2016.
//  Copyright © 2016 UP. All rights reserved.
//

#import "PilotViewController.h"
#import "DemoUtility.h"
#import <DJISDK/DJISDK.h>
#import <VideoPreviewer/VideoPreviewer.h>


@interface PilotViewController () <DJICameraDelegate>

@property(nonatomic, weak) IBOutlet UIView* fpvView;
@property (weak, nonatomic) IBOutlet UIView *fpvTemView;
@property (weak, nonatomic) IBOutlet UISwitch *fpvTemEnableSwitch;
@property (weak, nonatomic) IBOutlet UILabel *fpvTemperatureData;

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
}

-(void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[VideoPreviewer instance] setView:self.fpvView];
    
    [self updateThermalCameraUI];
}

-(void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // Call unSetView during exiting to release the memory.
    [[VideoPreviewer instance] unSetView];
}


/**
 *  VideoPreviewer is used to decode the video data and display the decoded frame on the view. VideoPreviewer provides both software
 *  decoding and hardware decoding. When using hardware decoding, for different products, the decoding protocols are different and the hardware decoding is only supported by some products.
 */
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
/**
 *  This video data is received through this method. Then the data is passed to VideoPreviewer.
 */
- (void)camera:(DJICamera *)camera didReceiveVideoData:(uint8_t *)videoBuffer length:(size_t)size {
    if(![[[VideoPreviewer instance] dataQueue] isFull]){
        [[VideoPreviewer instance] push:videoBuffer length:(int)size];
    }
}

/**
 *  DJICamera will send the live stream only when the mode is in DJICameraModeShootPhoto or DJICameraModeRecordVideo. Therefore, in order
 *  to demonstrate the FPV (first person view), we need to switch to mode to one of them.
 */
-(void)camera:(DJICamera *)camera didUpdateSystemState:(DJICameraSystemState *)systemState {
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

-(void)camera:(DJICamera *)camera didUpdateTemperatureData:(float)temperature {
    self.fpvTemperatureData.text = [NSString stringWithFormat:@"%f", temperature];
}

@end
