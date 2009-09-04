//
//  VMRegion.h
//  regions
//
//  Created by Yan Ivnitskiy on 8/26/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface VMRegion : NSObject {
	NSRange region;
	NSString *path;
	NSString *label;
}

@property (assign,readonly) NSRange region;
@property (copy) NSString *path;
@property (copy) NSString *label;

-(id) initWithRange:(NSRange)range;
-(NSString*) description;
-(NSComparisonResult)compare:(VMRegion*)aRegion;
-(BOOL)isEqual:(VMRegion*)aRegion;
-(NSUInteger)hash;
@end
