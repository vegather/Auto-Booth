//
//  VSTLocationManager.m
//  Vegard Solheim Theriault
//
//  Created by Vegard Solheim Theriault on 10/04/14.
//  Copyright (c) 2014 Vegard Solheim Theriault. All rights reserved.
//

#import "VSTLocationManager.h"


#define DISTANCE_BETWEEN_LOCATION_UPDATES 30.0

@interface VSTLocationManager () <CLLocationManagerDelegate>
@property (strong, nonatomic, readwrite) CLLocation *lastKnownLocation;
@property (strong, nonatomic) CLLocationManager *locationManager;
@end

@implementation VSTLocationManager


//////////////////////////
#pragma mark - Initializer
//////////////////////////

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.locationManager = [[CLLocationManager alloc]init];
        self.locationManager.distanceFilter = DISTANCE_BETWEEN_LOCATION_UPDATES;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        [self.locationManager requestWhenInUseAuthorization];
        self.locationManager.delegate = self;
        [self.locationManager startUpdatingLocation];
    }
    
    return self;
}



////////////////////////////////////////
#pragma mark - Location Manager Delegate
////////////////////////////////////////

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    self.lastKnownLocation = [locations firstObject];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    self.lastKnownLocation = nil;
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        [self.locationManager startUpdatingLocation];
    }
    else {
        self.lastKnownLocation = nil;
        [self.locationManager stopUpdatingLocation];
    }
}


@end
