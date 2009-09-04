//
//  VMAddressSpace.m
//  regions
//
//  Created by Yan Ivnitskiy on 8/26/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "VMAddressSpace.h"

#import <mach/mach_vm.h>
#import <mach/mach_error.h>
#import <mach-o/loader.h>
#import <mach-o/dyld_images.h>
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
#import <malloc/malloc.h>
#import "vmutils/NSMachOTaskImage.h"
#import "vmutils/NSMachOHeader.h"

	
static BOOL collapseRegions(NSMutableArray *srtd)
{
	for (int i = 0; i < [srtd count]-1; ++i) {
		VMRegion *r1, *r2;
		
		r1 = [srtd objectAtIndex:i];
		r2 = [srtd objectAtIndex:i+1];
		
		if (r1.region.location + r1.region.length == r2.region.location) {
			VMRegion *collapsed = [[VMRegion alloc] initWithRange:NSMakeRange(r1.region.location, r1.region.length + r2.region.length)];
			
			if ([r1.label isEqualToString:r2.label])
				collapsed.label = r1.label;
			
			if ([r1.path isEqualToString:r2.path])
				collapsed.path = r1.path;
			else if (!r1.path ^ !r2.path) {
				collapsed.path = r2.path ? r2.path : r1.path;
			}
					  
			
			[srtd removeObjectAtIndex:i+1];
			[srtd replaceObjectAtIndex:i withObject:collapsed];
			[collapsed release];
			
			i = i - 1; //terrible..
		}
	}
	return YES;
}

@implementation VMAddressSpace
@synthesize _regions;

-(id) init
{
	if (self = [super init])
	{
		_regions = [[NSMutableArray alloc] init];
		_task = 0;
	}
	return self;
}


-(void) addRegion:(VMRegion*)region
{
	[_regions addObject:region];
}

-(VMRegion*)getRegionWithRange:(NSRange)range
{
	// TODO: Rename VMRegion's 'region' member
	for (VMRegion *region in _regions)
		if (region.region.location == range.location && region.region.length == range.length) 
			return region;
	return nil;
}

-(void) test
{
	// Create and start actual 'vmmap' task
	NSTask *vmmap = [[NSTask alloc] init];
	[vmmap setLaunchPath:@"/usr/bin/vmmap"];
	[vmmap setArguments:[NSArray arrayWithObjects:@"-w", @"-interleaved", [[NSNumber numberWithInt:getpid()] stringValue], nil]];
	
	NSPipe *stdOutPipe = [[NSPipe alloc] init];
	[vmmap setStandardOutput:stdOutPipe];
	[vmmap setStandardError:stdOutPipe];
	
	[vmmap launch];
	
	// Grab output and release task
	NSFileHandle *stdOutFh = [stdOutPipe fileHandleForReading];
	NSData *contents = [stdOutFh readDataToEndOfFile];

	[stdOutPipe release];
	[vmmap release];
	
	// Parse output
	NSArray *output = [[[[NSString alloc] initWithData:contents encoding:NSASCIIStringEncoding] autorelease] componentsSeparatedByString:@"==== "];
	NSMutableArray *regions = [NSMutableArray arrayWithCapacity:[_regions count]];
	[regions addObjectsFromArray:[[output objectAtIndex:1] componentsSeparatedByString:@"\n"]];
	[regions removeObjectAtIndex:0];
	
	NSMutableArray *_actual_regions = [[NSMutableArray alloc] init];
	
	for(NSString *s in regions) {
		unsigned long long from, to;
		if ([s length] < 24)
			continue;
	
		(void) [[NSScanner scannerWithString:[s substringWithRange:NSMakeRange(23, 8)]] scanHexLongLong:&from]; // address
		(void) [[NSScanner scannerWithString:[s substringWithRange:NSMakeRange(32, 8)]] scanHexLongLong:&to]; // to address

		VMRegion *r = [[VMRegion alloc] initWithRange:NSMakeRange(from, to-from)];
		NSString *path = [s substringFromIndex:66];
		if (!path || [path isEqualToString:@""])
			r.path = nil; // path
		else
			r.path = path;

		r.label = [[s substringToIndex:22] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]; // label

		[_actual_regions addObject:[r autorelease]];

	}

#if 1
	NSArray *enumerateRegions = [NSArray arrayWithArray:_actual_regions];
	for (VMRegion *region in enumerateRegions)
		[_actual_regions removeObject:[self getRegionWithRange:region.region]];

	NSLog(@"%@", _actual_regions);
#endif
	

	
	[_actual_regions release];
}

-(BOOL) collectRegions:(task_t)task
{
	return
		[self collectMachVMRegions:task] && 
		[self collectDyldSections:task] &&
		[self collectMallocZones:task];
}

static kern_return_t mr(task_t remota_task, vm_address_t remote_address, vm_size_t size, void **localmemory)
{
	return 0;
	
}

-(BOOL) collectMallocZones:(task_t)task
{
	malloc_zone_t *mz;
	mz = malloc_default_zone();
	
//	malloc_zone_print(NULL, YES);
	return YES;
}

-(BOOL) collectMachVMRegions:(task_t) task
{
	kern_return_t kret;

	struct vm_region_submap_info_64 info;
	mach_vm_address_t address;
	mach_vm_size_t size;
	mach_msg_type_number_t count;
	natural_t depth;
	int tmp = 0;
	
	// Set up for mach_vm_region_recurse()
	address = 0;
	depth = 0;
	
	for (;;) {
		while (1) {
			count = VM_REGION_SUBMAP_INFO_COUNT_64;
			kret =	mach_vm_region_recurse(task, &address, &size, &depth, (vm_region_recurse_info_t)&info, &count);
			if (KERN_SUCCESS != kret) 
				break;
			
			if (address + size > VM_MAX_ADDRESS)
				break;
			
			if (info.is_submap) {
				depth++;
				continue;
			} else {
				break;
			}
		}
		
		// Catch the failure
		if (KERN_SUCCESS != kret)
			break;
		
		VMRegion *region = [[VMRegion alloc] initWithRange:NSMakeRange(address, size)];
		[self addRegion:[region autorelease]];
		
		address += size;
		++tmp;
	}
	
	return YES;
}

- (BOOL) collectDyldSections:(task_t) task
{
	const struct mach_header *header = NULL;
	const char *img_name = NULL;
	
	for (int i = 0; i < _dyld_image_count(); ++i) {
		header = _dyld_get_image_header(i);
		img_name = _dyld_get_image_name(i);
		struct load_command *lc = (struct load_command*)(header+1);
		
		uint32_t size_of_cmds = header->sizeofcmds;
		while (size_of_cmds > 0) {
			switch (lc->cmd) {
				case LC_SEGMENT: 
				{
					struct segment_command *seg = (struct segment_command*) lc;

					// We might have already got this section from mach_vm_region_recurse, so if we
					// come across it again, just get the info about the label and path
					[_regions enumerateObjectsWithOptions:NSEnumerationConcurrent
											   usingBlock:
					 ^(id obj, NSUInteger idx, BOOL *stop) {
						 VMRegion *region = (VMRegion*)obj;
						 if (region.region.location == seg->vmaddr && region.region.length == seg->vmsize) {
							 region.path = [NSString stringWithCString:img_name encoding:NSASCIIStringEncoding];
							 region.label = [NSString stringWithCString:seg->segname encoding:NSASCIIStringEncoding];
							 *stop = YES;
					   }
					}];
					
					// We don't want __LINKEDIT segments since vmmap doesn't include them
					if (strcmp(seg->segname, SEG_LINKEDIT) == 0)
						break;
					
					VMRegion *r = [[VMRegion alloc] initWithRange:NSMakeRange(seg->vmaddr, seg->vmsize)];
					r.path = [NSString stringWithCString:img_name encoding:NSASCIIStringEncoding];
					r.label = [NSString stringWithCString:seg->segname encoding:NSASCIIStringEncoding];
					
					[self addRegion:[r autorelease]];
				}
					break;
				default:
					NSLog(@"%x ", lc->cmd);
					break;
			}
			
			size_of_cmds -= lc->cmdsize;
			lc = (void*)((char*) lc + lc->cmdsize);
		}
	}
	return YES;
}	
	
+(id) addressSpaceWithTask:(task_t)task
{
	VMAddressSpace *addressSpace = [[VMAddressSpace alloc] init];
	[addressSpace collectRegions:task];

	return [addressSpace autorelease];

}
-(NSUInteger) count
{
	return [_regions count];
}

@end
