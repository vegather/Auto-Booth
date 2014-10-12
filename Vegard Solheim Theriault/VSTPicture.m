//
//  VSTPicture.m
//  Vegard Solheim Theriault
//
//  Created by Vegard Solheim Theriault on 09/04/14.
//  Copyright (c) 2014 Vegard Solheim Theriault. All rights reserved.
//

#import "VSTPicture.h"
#import "VSTImageFilter.h"
@import AssetsLibrary;
@import ImageIO;

@interface VSTPicture ()
@property (strong, nonatomic) UIImage *originalImage;
@property (strong, nonatomic) NSMutableDictionary *metadata;
@property (strong, nonatomic) VSTImageFilter *imageFilter;
@property (strong, nonatomic) ALAssetsLibrary *assetsLibrary;
@property (strong, nonatomic) CLLocation *pictureLocation;
@end

@implementation VSTPicture



/////////////////////////////
#pragma mark - Public Methods
/////////////////////////////

- (instancetype)initWithSampleBuffer:(CMSampleBufferRef)buffer andPhotoLocation:(CLLocation *)location
{
    self = [super init];
    if (self) {
        NSData *jpegData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:buffer]; // This line causes unbounded memory growth.
        _originalImage = [UIImage imageWithData:jpegData];
        
        CFDictionaryRef metadataRef = CMCopyDictionaryOfAttachments(NULL, buffer, kCMAttachmentMode_ShouldPropagate);
        _metadata = [[NSMutableDictionary alloc]initWithDictionary:(__bridge NSDictionary *)metadataRef];
        CFRelease(metadataRef);
        
        _filterIndex = 0;
        
        if (location) {
            _pictureLocation = location;
            [_metadata setValue:[self gpsDataFromLocation:location] forKey:(NSString *)kCGImagePropertyGPSDictionary];
        }
    }
    return self;
}

- (UIImage *)filteredImage
{
    UIImage *image = [self.originalImage copy];
    [self.imageFilter applyFilterAtIndex:self.filterIndex
                                forImage:&image];
    return image;
}

- (void)saveImageToDisk
{
    [self.assetsLibrary writeImageToSavedPhotosAlbum:[self filteredImage].CGImage
                                            metadata:self.metadata
                                     completionBlock:^(NSURL *assetURL, NSError *error) {
                                         if (!error) {
                                             [[[UIAlertView alloc]initWithTitle:@"Picture Saved"
                                                                        message:@"The picture was successfully saved to your Picture Library."
                                                                       delegate:nil
                                                              cancelButtonTitle:nil
                                                              otherButtonTitles:@"OK", nil]show];
                                         }
                                         else {
                                             [[[UIAlertView alloc]initWithTitle:@"Could Not Save Picture"
                                                                        message:[NSString stringWithFormat:@"Error: %@", [error localizedDescription]]
                                                                       delegate:nil
                                                              cancelButtonTitle:nil
                                                              otherButtonTitles:@"OK", nil]show];
                                         }
                                     }];
}



//////////////////////
#pragma mark - Getters
//////////////////////

- (VSTImageFilter *)imageFilter
{
    if (!_imageFilter) {
        _imageFilter = [[VSTImageFilter alloc]init];
    }
    return _imageFilter;
}

- (ALAssetsLibrary *)assetsLibrary
{
    if (!_assetsLibrary) {
        _assetsLibrary = [[ALAssetsLibrary alloc]init];
    }
    return _assetsLibrary;
}

- (NSString *)pictureName
{
    NSDateFormatter *timeFormatter = [[NSDateFormatter alloc] init];
    [timeFormatter setDateFormat:@"yyyy:MM:dd - HH.mm.ss"];
    
    NSString *name = [NSString stringWithFormat:@"%@ (%@).jpg",
                      [timeFormatter stringFromDate:self.pictureLocation.timestamp],
                      [VSTImageFilter availableFilters][self.filterIndex]];
    return name;
}



//////////////////////////////
#pragma mark - Private Methods
//////////////////////////////

- (NSDictionary *)gpsDataFromLocation:(CLLocation *)location
{
    NSDateFormatter *timeFormatter = [[NSDateFormatter alloc] init];
    [timeFormatter setDateFormat:@"HH:mm:ss.SSSSS"];
    [timeFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy:MM:dd"];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
    
    return @{(NSString *)kCGImagePropertyGPSDateStamp       : [dateFormatter stringFromDate:location.timestamp],
             (NSString *)kCGImagePropertyGPSLatitudeRef     : ((location.coordinate.latitude >= 0) ? @"N" : @"S"),
             (NSString *)kCGImagePropertyGPSLatitude        : [NSNumber numberWithDouble:fabs(location.coordinate.latitude)],
             (NSString *)kCGImagePropertyGPSLongitudeRef    : ((location.coordinate.longitude >= 0) ? @"E" : @"W"),
             (NSString *)kCGImagePropertyGPSLongitude       : [NSNumber numberWithDouble:fabs(location.coordinate.longitude)],
             (NSString *)kCGImagePropertyGPSAltitudeRef     : ((location.altitude >= 0) ? @0 : @1),
             (NSString *)kCGImagePropertyGPSAltitude        : [NSNumber numberWithFloat:fabs(location.altitude)],
             (NSString *)kCGImagePropertyGPSTimeStamp       : [timeFormatter stringFromDate:location.timestamp],
             (NSString *)kCGImagePropertyGPSDOP             : [NSNumber numberWithFloat:fabs(location.horizontalAccuracy)],
             (NSString *)kCGImagePropertyGPSSpeedRef        : @"K",
             (NSString *)kCGImagePropertyGPSSpeed           : [NSNumber numberWithFloat:fabs(location.speed * 3.6)], // m/s to km/h
             (NSString *)kCGImagePropertyGPSTrackRef        : @"T",
             (NSString *)kCGImagePropertyGPSTrack           : [NSNumber numberWithFloat:location.course] };
}

@end
