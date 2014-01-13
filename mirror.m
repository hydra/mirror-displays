/*
 *  mirror.m
 *  mirror
 *
 *  Created by Fabian Canas on 2/4/09.
 *  Copyright 2009 Fabián Cañas. All rights reserved.
 *
 *  This program is free software: you can redistribute it and/or modify	
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *  
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *  
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
 History:
 
 v1.0 - Initial release by Fabian Canas
 
 v2.0 - Dominic Clifton <me@dominicclifton.name>
      + Added support for more than 2 monitors.
      + Removed much of the duplicated logic and code.
      + Updated naming of methods and variables to improve code readability.
*/

#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>

#define MAX_SUPPORTED_DISPLAYS 10
#define MAX_OTHER_DISPLAYS (MAX_SUPPORTED_DISPLAYS - 1)

int otherDisplayCount = 0;
CGDirectDisplayID otherDisplays[MAX_OTHER_DISPLAYS];

void showHelp(void) {
    printf("Mirror Displays version 1.03\nCopyright 2009, Fabián Cañas\n");
    printf("usage: mirror [option]\tPassing more than one option produces undefined behavior.");
    printf("\n  -h\t\tPrint this usage and exit.");
    printf("\n  -t\t\tToggle mirroring (default behavior)");
    printf("\n  -on\t\tTurn Mirroring On");
    printf("\n  -off\t\tTurn Mirroring Off");
    printf("\n  -q\t\tQuery the Mirroring state and write \"on\" or \"off\" to stdout");
    printf("\n");
}
void addOtherDisplay(CGDirectDisplayID otherDisplay) {
    for (unsigned int otherDisplayIndex = 0; otherDisplayIndex < otherDisplayCount; otherDisplayIndex++) {
        if (otherDisplays[otherDisplayIndex] == otherDisplay) {
            return;
        }
    }
    otherDisplays[otherDisplayCount++] = otherDisplay;
}

void buildOtherDisplayList(
                           CGDirectDisplayID mainDisplay,
                           CGDirectDisplayID activeDspys[],
                           CGDisplayCount numberOfActiveDspys,
                           CGDirectDisplayID onlineDspys[],
                           CGDisplayCount numberOfOnlineDspys
                           ) {
    for (CGDisplayCount displayIndex = 0; displayIndex < numberOfActiveDspys; displayIndex++) {
        CGDirectDisplayID otherDisplay = activeDspys[displayIndex];
        if (otherDisplay != mainDisplay) {
            addOtherDisplay(otherDisplay);
        }
    }
    
    for (CGDisplayCount displayIndex = 0; displayIndex < numberOfOnlineDspys; displayIndex++) {
        CGDirectDisplayID otherDisplay = onlineDspys[displayIndex];
        if (otherDisplay != mainDisplay) {
            addOtherDisplay(otherDisplay);
        }
    }
}

CGError mirror(CGDisplayConfigRef configRef, CGDirectDisplayID mainDisplay, CGDirectDisplayID otherDisplays[], unsigned int otherDisplaysCount) {
    
    CGError err = 0;
    unsigned int otherDisplayIndex = 0;

    while (otherDisplayIndex < otherDisplaysCount && err == 0) {
        err = CGConfigureDisplayMirrorOfDisplay (configRef, otherDisplays[otherDisplayIndex++], mainDisplay);
    };
    return err;
}

CGError unmirror(CGDisplayConfigRef configRef, CGDirectDisplayID otherDisplays[], unsigned int otherDisplaysCount) {
    CGError err = 0;
    unsigned int otherDisplayIndex = 0;
    
    while (otherDisplayIndex < otherDisplaysCount && err == 0) {
        err = CGConfigureDisplayMirrorOfDisplay (configRef, otherDisplays[otherDisplayIndex++], kCGNullDirectDisplay);
    };
    return err;
}

enum MirrorMode {
    help,
    on,
    off,
    toggle,
    query
} mode;

enum MirrorMode determineMode() {
	NSArray *args = [[NSProcessInfo processInfo] arguments];
    NSCountedSet *cset = [[NSCountedSet alloc] initWithArray:args];
    NSArray *sorted_args = [[cset allObjects]
							sortedArrayUsingSelector:@selector(compare:)];
    NSEnumerator *enm = [sorted_args objectEnumerator];
    id word;
    
	mode = toggle;
	
    while (word = [enm nextObject]) {
		if (strcmp([word UTF8String], "-h")==0){
			mode = help;
			break;
		}
		if (strcmp([word UTF8String], "-t")==0){
			mode = toggle;
			break;
		}
		if (strcmp([word UTF8String], "-on")==0){
			mode = on;
			break;
		}
		if (strcmp([word UTF8String], "-off")==0){
			mode = off;
			break;
		}
		if (strcmp([word UTF8String], "-q")==0){
			mode = query;
			break;
		}
    }
    
    [cset release];

    return mode;
}

int process(enum MirrorMode mode) {
	CGDisplayCount numberOfActiveDspys;
	CGDisplayCount numberOfOnlineDspys;
	
	CGDisplayCount numberOfTotalDspys = MAX_SUPPORTED_DISPLAYS; // The number of total displays I'm interested in
	
	CGDirectDisplayID activeDspys[MAX_SUPPORTED_DISPLAYS];
	CGDirectDisplayID onlineDspys[MAX_SUPPORTED_DISPLAYS];
	CGDirectDisplayID mainDisplay;
	
	CGDisplayErr activeError = CGGetActiveDisplayList (numberOfTotalDspys, activeDspys, &numberOfActiveDspys);
	
	if (activeError!=0) NSLog(@"Error in obtaining active diplay list: %d\n",activeError);
	
	CGDisplayErr onlineError = CGGetOnlineDisplayList (numberOfTotalDspys, onlineDspys, &numberOfOnlineDspys);
	
	if (onlineError!=0) NSLog(@"Error in obtaining online diplay list: %d\n",onlineError);
    
    mainDisplay = CGMainDisplayID();
    
    buildOtherDisplayList(mainDisplay, activeDspys, numberOfActiveDspys, onlineDspys, numberOfOnlineDspys);
    
    CGDisplayConfigRef configRef;
    CGError err = CGBeginDisplayConfiguration (&configRef);
    if (err != 0) NSLog(@"Error with CGBeginDisplayConfiguration: %d\n",err);
    
    BOOL isMirroringActive = !(numberOfActiveDspys == numberOfOnlineDspys);
    
    switch (mode) {
        case toggle:
            if (isMirroringActive) {
                err = unmirror(configRef, otherDisplays, otherDisplayCount);
            } else {
                err = mirror(configRef, mainDisplay, otherDisplays, otherDisplayCount);
            }
            break;
        case on:
            err = mirror(configRef, mainDisplay, otherDisplays, otherDisplayCount);
            break;
        case off:
            err = unmirror(configRef, otherDisplays, otherDisplayCount);
            break;
        case query:
            printf("%s\n", isMirroringActive ? "on" : "off");
            break;
        default:
            break;
    }
    if (err != 0) NSLog(@"Error with the switch commands!: %d\n",err);
    
    // Apply the changes
    err = CGCompleteDisplayConfiguration (configRef,kCGConfigurePermanently);
    if (err != 0) NSLog(@"Error with CGCompleteDisplayConfiguration: %d\n",err);
}


int main (int argc, const char * argv[]) {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
		
	mode = determineMode();
    
	[pool drain];
	// Ending Objective-C code. Don't need a pool anymore?

	if (mode == help){
        showHelp();
		return 0;
	}
	
    int result = process(mode);
    
    return result;
}

