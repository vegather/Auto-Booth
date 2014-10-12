//
//  VSTImageFilter.m
//  Vegard Solheim Theriault
//
//  Created by Vegard Solheim Theriault on 08/04/14.
//  Copyright (c) 2014 Vegard Solheim Theriault. All rights reserved.
//


#define FILTER_NORMAL           @"Normal"
#define FILTER_SEPIA            @"Sepia"
#define FILTER_TWIRL            @"Twirl"
#define FILTER_WWDC14           @"WWDC14"
#define FILTER_VIGNETTE         @"Vignette"
#define FILTER_ENHANCE          @"Enhance"
#define FILTER_FADE             @"Fade"
#define FILTER_INSTANT          @"Instant"
#define FILTER_PROCESS          @"Process"
#define FILTER_NOIR             @"Noir"
#define FILTER_BLOOM            @"Bloom"
#define FILTER_GLOOM            @"Gloom"
#define FILTER_TRANSFER         @"Transfer"
#define FILTER_TONAL            @"Tonal"

#import "VSTImageFilter.h"
@import CoreImage;
@import ImageIO;

@interface VSTImageFilter ()
@property (strong, nonatomic) CIContext *context;
@end

@implementation VSTImageFilter


/////////////////////////////
#pragma mark - Public Methods
/////////////////////////////

+ (NSArray *)availableFilters
{
    return @[FILTER_NORMAL,
             FILTER_ENHANCE,
             FILTER_FADE,
             FILTER_INSTANT,
             FILTER_PROCESS,
             FILTER_TRANSFER,
             FILTER_SEPIA,
             FILTER_NOIR,
             FILTER_TONAL,
             FILTER_BLOOM,
             FILTER_GLOOM,
             FILTER_VIGNETTE,
             FILTER_TWIRL];
//             FILTER_WWDC14];
}

- (void)applyFilterAtIndex:(NSUInteger)filterIndex
                  forImage:(UIImage **)source;
{
    if (filterIndex < [[[self class] availableFilters] count] && *source != nil) {
        
        NSString *filterName = [[self class] availableFilters][filterIndex];
        
        if ([filterName isEqualToString:FILTER_SEPIA]) {
            [self applyOneFilterNamed:@"CISepiaTone" toImage:source withParameters:nil];
        }
        else if ([filterName isEqualToString:FILTER_TWIRL]) {
            CGRect faceRect = [self faceRectInImage:*source];
            CGPoint faceCenter = CGPointMake(faceRect.origin.x + (faceRect.size.width / 2.0),
                                             faceRect.origin.y + (faceRect.size.height / 2.0));
            NSDictionary *parameters = @{kCIInputCenterKey     : [CIVector vectorWithX:faceCenter.x Y:faceCenter.y],
                                         kCIInputRadiusKey     : [NSNumber numberWithFloat:(faceRect.size.width / 2.0)],
                                         kCIInputAngleKey      : [NSNumber numberWithFloat:1.3]};
            [self applyOneFilterNamed:@"CITwirlDistortion" toImage:source withParameters:parameters];
        }
        else if ([filterName isEqualToString:FILTER_VIGNETTE]) {
            CGRect faceRect = [self faceRectInImage:*source];
            CGPoint faceCenter = CGPointMake(faceRect.origin.x + (faceRect.size.width / 2.0),
                                             faceRect.origin.y + (faceRect.size.height / 2.0));
            NSDictionary *parameters = @{kCIInputCenterKey     : [CIVector vectorWithX:(faceCenter.x * 0.95) Y:faceCenter.y],
                                         kCIInputRadiusKey     : [NSNumber numberWithFloat:(faceRect.size.width / 2.0)],
                                         kCIInputIntensityKey  : @0.7};
            [self applyOneFilterNamed:@"CIVignetteEffect" toImage:source withParameters:parameters];
        }
//        else if ([filterName isEqualToString:FILTER_WWDC14]) {
//            [self applyWWDC14FilterToImage:source];
//        }
        else if ([filterName isEqualToString:FILTER_ENHANCE]) {
            [self applyAutoEnhanceFilterToImage:source];
        }
        else if ([filterName isEqualToString:FILTER_FADE]) {
            [self applyOneFilterNamed:@"CIPhotoEffectFade" toImage:source withParameters:nil];
        }
        else if ([filterName isEqualToString:FILTER_INSTANT]) {
            [self applyOneFilterNamed:@"CIPhotoEffectInstant" toImage:source withParameters:nil];
        }
        else if ([filterName isEqualToString:FILTER_PROCESS]) {
            [self applyOneFilterNamed:@"CIPhotoEffectProcess" toImage:source withParameters:nil];
        }
        else if ([filterName isEqualToString:FILTER_NOIR]) {
            [self applyOneFilterNamed:@"CIPhotoEffectNoir" toImage:source withParameters:nil];
        }
        else if ([filterName isEqualToString:FILTER_TONAL]) {
            [self applyOneFilterNamed:@"CIPhotoEffectTonal" toImage:source withParameters:nil];
        }
        else if ([filterName isEqualToString:FILTER_TRANSFER]) {
            [self applyOneFilterNamed:@"CIPhotoEffectTransfer" toImage:source withParameters:nil];
        }
        else if ([filterName isEqualToString:FILTER_BLOOM]) {
            NSDictionary *parameters = @{kCIInputRadiusKey      : @10.0,
                                         kCIInputIntensityKey   : @1.0};
            [self applyOneFilterNamed:@"CIBloom" toImage:source withParameters:parameters];
        }
        else if ([filterName isEqualToString:FILTER_GLOOM]) {
            NSDictionary *parameters = @{kCIInputRadiusKey      : @10.0,
                                         kCIInputIntensityKey   : @1.0};
            [self applyOneFilterNamed:@"CIGloom" toImage:source withParameters:parameters];
        }
    }
}



//////////////////////
#pragma mark - Getters
//////////////////////

- (CIContext *)context
{
    if (!_context) {
        _context = [CIContext contextWithOptions:nil];
    }
    return _context;
}



//////////////////////////////
#pragma mark - Private Methods
//////////////////////////////

- (void)applyOneFilterNamed:(NSString *)actualFilterName
                    toImage:(UIImage **)imageToFilter
             withParameters:(NSDictionary *)parameters
{
    CGImageRef cgImage = [*imageToFilter CGImage];
    CIImage *inputImage = [CIImage imageWithCGImage:cgImage];
//    CFRelease(cgImage);
    
    if (inputImage) {
        CIFilter *filter = [CIFilter filterWithName:actualFilterName];
        [filter setValue:inputImage forKey:kCIInputImageKey];
        //Set parameters
        if (parameters) {
            [parameters enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                [filter setValue:obj forKey:key];
            }];
        }
        
        CIImage *outputImage = [filter valueForKey:kCIOutputImageKey];
        if (outputImage) {
            CGImageRef renderedImage = [self.context createCGImage:outputImage fromRect:outputImage.extent];
            *imageToFilter = [UIImage imageWithCGImage:renderedImage scale:1.0 orientation:UIImageOrientationRight];
            CFRelease(renderedImage);
        }
    }
}

- (void)applyAutoEnhanceFilterToImage:(UIImage **)imageToFilter
{
    CGImageRef cgImage = [*imageToFilter CGImage];
    CIImage *inputImage = [CIImage imageWithCGImage:cgImage];
//    CFRelease(cgImage);
    
    if (inputImage) {
        NSDictionary *options = @{ CIDetectorImageOrientation :  @6};
        NSArray *adjustments = [inputImage autoAdjustmentFiltersWithOptions:options];
        for (CIFilter *filter in adjustments) {
            [filter setValue:inputImage forKey:kCIInputImageKey];
            inputImage = filter.outputImage;
        }
        
        CGImageRef renderedImage = [self.context createCGImage:inputImage fromRect:inputImage.extent];
        *imageToFilter = [UIImage imageWithCGImage:renderedImage
                                             scale:1.0
                                       orientation:UIImageOrientationRight];
        CFRelease(renderedImage);
    }
}

//- (void)applyWWDC14FilterToImage:(UIImage **)imageToFilter
//{
//    CGImageRef cgImage = [*imageToFilter CGImage];
//    CIImage *inputImage = [CIImage imageWithCGImage:cgImage];
////    CFRelease(cgImage);
//    
//    if (inputImage) {
//        CIFilter *dotScreenFilter = [CIFilter filterWithName:@"CIDotScreen"];
//        [dotScreenFilter setValue:inputImage forKey:kCIInputImageKey];
//        [dotScreenFilter setValue:@20        forKey:kCIInputWidthKey];
//        [dotScreenFilter setValue:@1.0       forKey:kCIInputSharpnessKey];
//        [dotScreenFilter setValue:[NSNumber numberWithDouble:M_PI_4] forKey:kCIInputAngleKey];
//        
//        CIImage *gradient = [CIImage imageWithContentsOfURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"WWDC Gradient"
//                                                                                                                   ofType:@"jpg"]]];
//        
//        CIFilter *blendingFilter = [CIFilter filterWithName:@"CIScreenBlendMode"];
//        [blendingFilter setValue:[dotScreenFilter outputImage] forKey:kCIInputBackgroundImageKey];
//        [blendingFilter setValue:gradient forKey:kCIInputImageKey];
//
//        
//        CIImage *outputImage = [blendingFilter valueForKey:kCIOutputImageKey];
//        if (outputImage) {
//            CGImageRef renderedImage = [self.context createCGImage:outputImage fromRect:outputImage.extent];
//            *imageToFilter = [UIImage imageWithCGImage:renderedImage scale:1.0 orientation:UIImageOrientationRight];
//            CFRelease(renderedImage);
//        }
//    }
//}

- (CGRect)faceRectInImage:(UIImage *)imageWithFace
{
    CGRect returnValue = CGRectZero;
    NSDictionary *detectorOptions = @{CIDetectorAccuracy : CIDetectorAccuracyHigh};
    CIDetector *faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace
                                                  context:self.context
                                                  options:detectorOptions];
    
    CIImage *image = [CIImage imageWithCGImage:[imageWithFace CGImage]];
    NSArray *features = [faceDetector featuresInImage:image
                                              options:@{CIDetectorImageOrientation : @6}];
    for (CIFeature *feature in features) {
        if ([feature isKindOfClass:[CIFaceFeature class]]) {
            returnValue = feature.bounds;
            break;
        }
    }
    
    return returnValue;
}

@end
