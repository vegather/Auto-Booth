//
//  VSTViewController.m
//  Vegard Solheim Theriault
//
//  Created by Vegard Solheim Theriault on 03/04/14.
//  Copyright (c) 2014 Vegard Solheim Theriault. All rights reserved.
//

#import "VSTViewController.h"
#import "VSTPictureViewerVC.h"
#import "VSTPicture.h"
#import "VSTValueIndicator.h"
#import "VSTLocationManager.h"

@import AVFoundation;
@import CoreLocation;


typedef NS_ENUM(NSInteger, SmileDetectorState)
{
    SmileDetectorStateCheckingForSmile,         // The detector is checking for the first smile
    SmileDetectorStateDoubleCheckingForSmile,   // The detector is checking for the second smile
};

#define TIME_BETWEEN_SMILE_CHECKS         1.0           // The amount of seconds between smile checks
#define TIME_BEFORE_DOUBLE_CHECK          0.2           // The amount of seconds before double checking that we actually go a smile
#define PICTURES_PER_SESSION              5             // The number of pictures before switching to the picture viewer


// used for KVO observation of the @"capturingStillImage" property to perform flash bulb animation
static const NSString *AVCaptureStillImageIsCapturingStillImageContext = @"AVCaptureStillImageIsCapturingStillImageContext";

@interface VSTViewController () <AVCaptureVideoDataOutputSampleBufferDelegate, VSTPictureViewerDelegate>//, CLLocationManagerDelegate>

#pragma mark Outlets
@property (weak, nonatomic) IBOutlet UIView *previewView;

#pragma mark AV Capture
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) AVCaptureStillImageOutput *stillImageOutput;
@property (nonatomic, strong) AVCaptureDeviceInput *deviceInput;
@property (nonatomic, strong) UIView *flashView;

#pragma mark Misc
@property (nonatomic, strong) CIDetector *faceDetector;
@property (strong, nonatomic) NSMutableArray *pictures;
@property (nonatomic)         dispatch_queue_t processQ;
@property (strong, nonatomic) NSDate *timeSinceLastSmileTest;
@property (nonatomic)         SmileDetectorState smileDetectorState;
@property (strong, nonatomic) VSTLocationManager *locationManager;
@property (nonatomic)         BOOL readyToCheckForSmile;
@property (weak, nonatomic) IBOutlet VSTValueIndicator *picturesTakenIndicator;

@end

@implementation VSTViewController



/////////////////////////////////////////
#pragma mark - View Controller Life Cycle
/////////////////////////////////////////

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.readyToCheckForSmile = YES;
	[self setupAVCapture];
    self.locationManager = [[VSTLocationManager alloc]init];
    self.picturesTakenIndicator.maxValue = PICTURES_PER_SESSION;
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}


//////////////////////
#pragma mark - Getters
//////////////////////

//AV Capture
- (AVCaptureSession *)session
{
    if (!_session) {
        _session = [[AVCaptureSession alloc]init];
    }
    return _session;
}
- (AVCaptureVideoDataOutput *)videoDataOutput
{
    if (!_videoDataOutput) {
        _videoDataOutput = [[AVCaptureVideoDataOutput alloc]init];
    }
    return _videoDataOutput;
}
- (AVCaptureStillImageOutput *)stillImageOutput
{
    if (!_stillImageOutput) {
        _stillImageOutput = [[AVCaptureStillImageOutput alloc]init];
        [_stillImageOutput addObserver:self
                            forKeyPath:@"capturingStillImage"
                               options:NSKeyValueObservingOptionNew
                               context:(__bridge void *)(AVCaptureStillImageIsCapturingStillImageContext)];
    }
    return _stillImageOutput;
}
- (AVCaptureDeviceInput *)deviceInput
{
    
    if (!_deviceInput) {
        AVCaptureDevice *device;
        
        // Find the desired camera
        for (AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
            if ([d position] == AVCaptureDevicePositionFront) {
                device = d;
                break;
            }
        }
        
        // Fall back to the default camera.
        if(!device) {
            device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        }
        
        [self configureCameraForHighestFrameRate:device];
        
        //Set the input device
        NSError *deviceInputCreationError;
        _deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&deviceInputCreationError];
        if (deviceInputCreationError) {
            NSLog(@"Error getting deviceInput");
            return nil;
        }
    }
    return _deviceInput;
}
- (UIView *)flashView
{
    if (!_flashView) {
        _flashView = [[UIView alloc]initWithFrame:[self.view frame]];
        _flashView.backgroundColor = [UIColor whiteColor];
    }
    return _flashView;
}

//Misc
- (CIDetector *)faceDetector
{
    if (!_faceDetector) {
        // Need the performance of low accuracy, but having problems with it not detecting smiles properly
        // Detection to capture delay: low (~100ms), high(~300ms)
        NSDictionary *detectorOptions = @{CIDetectorAccuracy: CIDetectorAccuracyHigh};
        _faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:detectorOptions];
    }
    return _faceDetector;
}
- (NSMutableArray *)pictures
{
    if (!_pictures) {
        _pictures = [[NSMutableArray alloc]initWithCapacity:PICTURES_PER_SESSION];
    }
    return _pictures;
}
- (dispatch_queue_t)processQ
{
    if (!_processQ) {
        _processQ = dispatch_queue_create("Image Processing Queue", NULL);
    }
    return _processQ;
}
- (NSDate *)timeSinceLastSmileTest
{
    if (!_timeSinceLastSmileTest) {
        _timeSinceLastSmileTest = [[NSDate alloc]initWithTimeIntervalSince1970:0];
    }
    return _timeSinceLastSmileTest;
}



/////////////////////////////////
#pragma mark - Setup and TearDown
/////////////////////////////////

- (void)setupAVCapture
{
    self.smileDetectorState = SmileDetectorStateCheckingForSmile;
    
    [self.session setSessionPreset:AVCaptureSessionPresetPhoto];
    
    // add the input to the session
    if ( [self.session canAddInput:self.deviceInput] ) {
        [self.session addInput:self.deviceInput];
    }
    
    if ([self.session canAddOutput:self.stillImageOutput]) {
        [self.session addOutput:self.stillImageOutput];
    }
    
    // we want BGRA, both CoreGraphics and OpenGL work well with 'BGRA'
    NSDictionary *rgbOutputSettings = @{(id)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithInt:kCVPixelFormatType_32BGRA]};
    [self.videoDataOutput setVideoSettings:rgbOutputSettings];
    [self.videoDataOutput setAlwaysDiscardsLateVideoFrames:YES]; // discard if the data output queue is blocked
    
    // create a serial dispatch queue used for the sample buffer delegate
    // a serial dispatch queue must be used to guarantee that video frames will be delivered in order
    dispatch_queue_t videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
    [self.videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];
    
    if ([self.session canAddOutput:self.videoDataOutput]) {
        [self.session addOutput:self.videoDataOutput];
    }
    
    // get the output for doing face detection.
    [[self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];
    
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    self.previewLayer.backgroundColor = [[UIColor blackColor] CGColor];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    CALayer *rootLayer = [self.previewView layer];
    [rootLayer setMasksToBounds:YES];
    [self.previewLayer setFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height - 77)];//[rootLayer frame]];
    [rootLayer addSublayer:self.previewLayer];
    
    // Setting up the capture session will block, don't want this on the main queue
    dispatch_queue_t setupQ = dispatch_queue_create("Setup Queue", NULL);
    dispatch_async(setupQ, ^{
        [self.session startRunning];
    });
}

// From WWDC13
- (void)configureCameraForHighestFrameRate:(AVCaptureDevice *)device
{
    AVCaptureDeviceFormat *bestFormat = nil;
    AVFrameRateRange *bestFrameRateRange = nil;
    for ( AVCaptureDeviceFormat *format in [device formats] ) {
        for ( AVFrameRateRange *range in format.videoSupportedFrameRateRanges ) {
            if ( range.maxFrameRate > bestFrameRateRange.maxFrameRate ) {
                bestFormat = format;
                bestFrameRateRange = range;
            }
        }
    }
    if ( bestFormat ) {
        if ( [device lockForConfiguration:NULL] == YES ) {
            device.activeFormat = bestFormat;
            device.activeVideoMinFrameDuration = bestFrameRateRange.minFrameDuration;
            device.activeVideoMaxFrameDuration = bestFrameRateRange.minFrameDuration;
            [device unlockForConfiguration];
        }
    }
}

- (void)tearDownAVCapture
{
    [self.session stopRunning];
    self.readyToCheckForSmile = NO;
    
    // There appears to be a bug with featuresInImage:options: that generates an unbounded memory growth problem.
    // This will clean that up, and lazy instantiation will recreate the detector when we need it.
    self.faceDetector = nil;
}

- (void)reloadAVCapture
{
    [self.session startRunning];
    [self.pictures removeAllObjects];
    self.picturesTakenIndicator.value = 0;
    self.smileDetectorState = SmileDetectorStateCheckingForSmile;
    self.readyToCheckForSmile = YES;
}



//////////////////////////////
#pragma mark - Capture Session
//////////////////////////////

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    BOOL checkingForFirstSmile = (self.smileDetectorState == SmileDetectorStateCheckingForSmile &&
                                  ABS([self.timeSinceLastSmileTest timeIntervalSinceNow]) >= (TIME_BETWEEN_SMILE_CHECKS));
    BOOL checkingForSecondSmile = (self.smileDetectorState == SmileDetectorStateDoubleCheckingForSmile &&
                                   ABS([self.timeSinceLastSmileTest timeIntervalSinceNow]) >= TIME_BEFORE_DOUBLE_CHECK);
    
    // If it's time to check for a smile again
    if ((checkingForFirstSmile || checkingForSecondSmile) && self.readyToCheckForSmile) //|| checkingForSmileWhileCapturing)
    {
        self.readyToCheckForSmile = NO;
        self.timeSinceLastSmileTest = [NSDate date];
        
        // get the image
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CIImage *ciImage = [CIImage imageWithCVPixelBuffer:imageBuffer];
        
        dispatch_async(self.processQ, ^{
            [self processImage:ciImage];
        });
    }
}


///////////////////////////////
#pragma mark - Image Processing
///////////////////////////////

- (void)processImage:(CIImage *)image
{
    NSDictionary *imageOptions = @{CIDetectorImageOrientation   : @6, // Right, top (due to how the camera is placed inside the iPhone)
                                   CIDetectorSmile              : [NSNumber numberWithBool:YES],
                                   CIDetectorEyeBlink           : [NSNumber numberWithBool:YES]};
    
    NSArray *features = [self.faceDetector featuresInImage:image
                                                   options:imageOptions];
    
    if ([features count] == 1) {
        
        CIFaceFeature *faceFeature = (CIFaceFeature *)[features firstObject];
        
        if ([faceFeature hasSmile]       == YES &&
            [faceFeature leftEyeClosed]  == NO  &&
            [faceFeature rightEyeClosed] == NO)
        {
            //Got a perfect smile
            switch (self.smileDetectorState) {
                case SmileDetectorStateCheckingForSmile:
                    self.smileDetectorState = SmileDetectorStateDoubleCheckingForSmile;
                    self.readyToCheckForSmile = YES;
                    break;
                case SmileDetectorStateDoubleCheckingForSmile:
                    self.smileDetectorState = SmileDetectorStateCheckingForSmile;
                    [self takePicture];
                    break;
                default: break;
            }
        }
        else {
            //Not a perfect smile
            self.smileDetectorState = SmileDetectorStateCheckingForSmile;
            self.readyToCheckForSmile = YES;
        }
    }
    else {
        self.readyToCheckForSmile = YES;
    }
}



//////////////////////////////
#pragma mark - Taking Pictures
//////////////////////////////

- (void)takePicture
{
    if ([self.pictures count] < PICTURES_PER_SESSION && self.presentedViewController == nil) {
        // Tell the still image output.
        AVCaptureConnection *stillImageConnection = [self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
        
        // set the appropriate pixel format / image type output setting for writing a jpeg to the camera roll
        [self.stillImageOutput setOutputSettings:@{AVVideoCodecKey: AVVideoCodecJPEG}];
        
        [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:stillImageConnection
                                                           completionHandler: ^(CMSampleBufferRef imageDataSampleBuffer, NSError *error)
         {
             if (error) {
                 NSLog(@"Failed taking picture with error: %@", [error localizedDescription]);
             }
             else
             {
                 VSTPicture *picture = [[VSTPicture alloc]initWithSampleBuffer:imageDataSampleBuffer
                                                              andPhotoLocation:self.locationManager.lastKnownLocation];
                 
                 [self.pictures addObject:picture];
                 dispatch_async(dispatch_get_main_queue(), ^{
                     self.picturesTakenIndicator.value = [self.pictures count];
                     if ([self.pictures count] >= PICTURES_PER_SESSION) {
                         [self performSegueWithIdentifier:@"Show Picture Viewer Segue"
                                                   sender:self];
                         [self tearDownAVCapture];
                     }
                 });
             }
             self.readyToCheckForSmile = YES;
         }];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ( context == (__bridge void *)(AVCaptureStillImageIsCapturingStillImageContext) )
    {
		BOOL isCapturingStillImage = [change[NSKeyValueChangeNewKey] boolValue];
		
		if ( isCapturingStillImage ) {
			// do flash bulb like animation
			[self.flashView setAlpha:.0f];
			[[[self view] window] addSubview:self.flashView];
			
			[UIView animateWithDuration:.4f
							 animations:^{
								 [self.flashView setAlpha:1.f];
							 }
			 ];
		}
		else {
			[UIView animateWithDuration:.4f
							 animations:^{
								 [self.flashView setAlpha:0.f];
							 }
							 completion:^(BOOL finished){
								 [self.flashView removeFromSuperview];
							 }
			 ];
		}
	}
}



////////////////////
#pragma mark - Segue
////////////////////

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Making sure the segue is in the state we're expecting it to be
    if ([segue.identifier isEqualToString:@"Show Picture Viewer Segue"]) {
        if ([sender isEqual:self]) {
            if ([segue.destinationViewController isKindOfClass:[UINavigationController class]]) {
                UINavigationController *navController = (UINavigationController *)segue.destinationViewController;
                if ([navController.viewControllers[0] isKindOfClass:[VSTPictureViewerVC class]]) {
                    // All good
                    VSTPictureViewerVC *pictureViewerVC = navController.viewControllers[0];
                    [pictureViewerVC setPictures:self.pictures];
                    [pictureViewerVC setDelegate:self];
                }
            }
        }
    }
}



//////////////////////////////////////////
#pragma mark - VST Picture Viewer Delegate
//////////////////////////////////////////

- (void)pictureViewerDidFinish
{
    [self dismissViewControllerAnimated:YES completion:^{
        [self reloadAVCapture];
    }];
}

@end
