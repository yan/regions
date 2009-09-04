#import <Foundation/Foundation.h>
#import <mach/mach_traps.h>
#import <mach/vm_map.h>
#import <mach/mach_error.h>
#import <mach/shared_region.h> 
#include <mach/mach_vm.h>

#include "VMAddressSpace.h"


void
macosx_debug_regions (task_t task, mach_vm_address_t address, int max)
{
	kern_return_t kret;
	vm_region_basic_info_data_64_t info, prev_info;
	//vm_region_submap_info_data_t info, prev_info;
	mach_vm_address_t prev_address;
	mach_vm_size_t size, prev_size;
	
	mach_port_t object_name;
	mach_msg_type_number_t count;
	
	int nsubregions = 0;
	int num_printed = 0;
	
	count = VM_REGION_BASIC_INFO_COUNT_64;
	//count = VM_REGION_SUBMAP_INFO_COUNT_64;
	kret = mach_vm_region (task, &address, &size, VM_REGION_BASIC_INFO_64,
						   (vm_region_info_t) &info, &count, &object_name);
	if (kret != KERN_SUCCESS)
    {
		printf ("No memory regions.");
		return;
    }

	
	memcpy (&prev_info, &info, sizeof (prev_info));
	prev_address = address;
	prev_size = size;
	nsubregions = 1;
	
	for (;;)
    {
		int print = 0;
		int done = 0;
		

		address = prev_address + prev_size;
		
		/* Check to see if address space has wrapped around. */
		if (address == 0)
			print = done = 1;
		
		if (!done)
        {
			count = VM_REGION_BASIC_INFO_COUNT_64;
			kret =
            mach_vm_region (task, &address, &size, VM_REGION_BASIC_INFO_64,
							(vm_region_info_t) &info, &count, &object_name);
			if (kret != KERN_SUCCESS)
            {
				size = 0;
				print = done = 1;
            }
        }
		

		
		if (address != prev_address + prev_size)
			print = 1;
		
		if ((info.protection != prev_info.protection)
			|| (info.max_protection != prev_info.max_protection)
			|| (info.inheritance != prev_info.inheritance)
			|| (info.shared != prev_info.reserved)
			|| (info.reserved != prev_info.reserved))
			print = 1;
		
		if (print)
        {
			if (num_printed == 0)
				printf ("Region ");
			else
				printf ("   ... ");
		
			printf("From %x -> %x\n",(uint32_t)address, (uint32_t)size);
// ????			vm_map_page_query();

		/*	printf ("from 0x%s to 0x%s (%s, max %s; %s, %s, %s)",
							  (prev_address),
							  (prev_address + prev_size),
							  (prev_info.protection),
							  (prev_info.max_protection),
							  (prev_info.inheritance),
							 prev_info.shared ? "shared" : "private",
							 prev_info.reserved ? "reserved" : "not-reserved");*/
			
//			if (nsubregions > 1)
//				printf (" (%d sub-regions)", nsubregions);
//			
//			printf ("\n");
			
			prev_address = address;
			prev_size = size;
			memcpy (&prev_info, &info, sizeof (vm_region_basic_info_data_64_t));
			nsubregions = 1;
			
			num_printed++;
        }
		else
        {
			prev_size += size;
			nsubregions++;
        }
		
		if ((max > 0) && (num_printed >= max))
			done = 1;
		
		if (done)
			break;
    }
}

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    // insert code here...
	kern_return_t rt;
	mach_port_t p;
//	page_address_array_t *arr;
//	mach_msg_type_number_t *i;
	
	rt = task_for_pid(mach_task_self(), getpid(), &p);
	if (rt != KERN_SUCCESS)
		exit(1);

//	macosx_debug_regions(mach_task_self(), 0, -1);
	//rt = vm_mapped_pages_info((vm_map_t)mach_task_self(), arr, i);
	//if (rt != KERN_SUCCESS) {
//		mach_error("failed: ", rt);
//		exit(2);
//	}

	
//	NSLog(@"Success so far %@", h);

	VMAddressSpace *as = [VMAddressSpace addressSpaceWithTask:p];
	
	[as test];
	
    [pool drain];
    return 0;
}
