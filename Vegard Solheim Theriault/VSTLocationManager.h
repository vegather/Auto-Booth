//
//  VSTLocationManager.h
//  Vegard Solheim Theriault
//
//  Created by Vegard Solheim Theriault on 10/04/14.
//  Copyright (c) 2014 Vegard Solheim Theriault. All rights reserved.
//

#import <Foundation/Foundation.h>
@import CoreLocation;

@interface VSTLocationManager : NSObject

@property (strong, nonatomic, readonly) CLLocation *lastKnownLocation;

@end
