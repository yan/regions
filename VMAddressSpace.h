//
//  VMAddressSpace.h
//  regions
//
//  Created by Yan Ivnitskiy on 8/26/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "VMRegion.h"

@interface VMAddressSpace : NSObject {
	task_t _task;
	NSMutableArray *_regions;
}
@property (readonly) NSMutableArray *_regions;
-(void) addRegion:(VMRegion*)region;
-(NSUInteger) count;
+(id) addressSpaceWithTask:(task_t)task;
-(void) test;
-(BOOL) collectDyldSections:(task_t) task;
-(BOOL) collectMachVMRegions:(task_t) task;
-(BOOL) collectRegions:(task_t) task;
-(BOOL) collectMallocZones:(task_t)task;
@end
