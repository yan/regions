//
//  VMRegion.m
//  regions
//
//  Created by Yan Ivnitskiy on 8/26/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "VMRegion.h"


@implementation VMRegion
@synthesize region, path, label;

-(id) initWithRange:(NSRange)range
{
	if (self=[super init])
	{
		region = range;
	}
	return self;
}

-(NSString*)description
{
	// autoreleased
	return [NSString stringWithFormat:@"%08x-%08x [%@] [%@]", region.location, region.location+region.length, label, path];
}

-(NSComparisonResult)compare:(VMRegion*)aRegion
{
	NSComparisonResult result;
	if (region.location < aRegion.region.location)
		result = NSOrderedAscending;
	else if (region.location > aRegion.region.location)
		result = NSOrderedDescending;
	else
		result = NSOrderedSame;
	
	return result;
}

-(BOOL)isEqual:(VMRegion*)aRegion
{
	return aRegion.region.location == region.location && aRegion.region.length == region.length;
}

-(NSUInteger)hash
{
	return region.location | (region.length >>10);
}

	
@end