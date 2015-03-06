//
//  VSTPicture.h
//  Vegard Solheim Theriault
//
//  Created by Vegard Solheim Theriault on 09/04/14.
//  Copyright (c) 2014 Vegard Solheim Theriault. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AVFoundation;
@import CoreLocation;


@interface VSTPicture : NSObject

@property (nonatomic) NSUInteger filterIndex;
@property (strong, nonatomic, readonly) NSString *pictureName;

- (instancetype)initWithSampleBuffer:(CMSampleBufferRef)buffer
                    andPhotoLocation:(CLLocation *)location;
- (UIImage *)filteredImage;
- (void)saveImageToDiskWithCompletionHandler:(void (^)(NSError *error))completionHandler;

@end
