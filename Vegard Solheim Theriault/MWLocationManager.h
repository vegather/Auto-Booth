//
//  MWLocationManager.h
//  MOON Atlas
//
//  Created by Vegard Solheim Theriault on 14/09/14.
//  Copyright (c) 2014 MOON Wearables. All rights reserved.
//

#import <Foundation/Foundation.h>
@class CLLocation;

@interface MWLocationManager : NSObject

// This would ideally be a class method, but I'm not sure that would work.
// I think someone needs to retain this.
- (void)getCurrentLocationWithTimeout:(NSTimeInterval)timeout
                withCompletionHandler:(void (^)(CLLocation *location, NSError *locationError))completionHandler;

@end
