#include "AFPBlackListController.h"
#import <spawn.h>
#define PREFERENCE_IDENTIFIER @"/var/mobile/Library/Preferences/com.rpgfarm.afontprefs.plist"
NSMutableDictionary *prefs;

@interface LSApplicationProxy
-(NSString *)bundleIdentifier;
-(NSString *)localizedName;
@end

@interface LSApplicationWorkspace : NSObject
+(id)defaultWorkspace;
-(id)allInstalledApplications;
- (void)enumerateApplicationsOfType:(NSUInteger)type block:(void (^)(LSApplicationProxy*))block;
@end

@interface UIImage (Icon)
+(id)_applicationIconImageForBundleIdentifier:(id)arg1 format:(int)arg2 scale:(double)arg3;
@end

NSArray *getAllInstalledApplications() {
	LSApplicationWorkspace *workspace = [LSApplicationWorkspace defaultWorkspace];
	if(![workspace respondsToSelector:@selector(enumerateApplicationsOfType:block:)]) return [workspace allInstalledApplications];

	NSMutableArray* installedApplications = [NSMutableArray new];
	[workspace enumerateApplicationsOfType:0 block:^(LSApplicationProxy* appProxy) {
		[installedApplications addObject:appProxy];
	}];
	[workspace enumerateApplicationsOfType:1 block:^(LSApplicationProxy* appProxy) {
		[installedApplications addObject:appProxy];
	}];
	return installedApplications;
}

@implementation AFPBlackListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		[self getPreference];
		NSMutableArray *specifiers = [[NSMutableArray alloc] init];
		[specifiers addObject:[PSSpecifier preferenceSpecifierNamed:@"A-Font Settings" target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil]];
		NSArray *applications = getAllInstalledApplications();
		NSArray *sortDescriptor = @[[NSSortDescriptor sortDescriptorWithKey:@"localizedName" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)]];
		applications = [applications sortedArrayUsingDescriptors:sortDescriptor];
		for (LSApplicationProxy *application in applications) {
			UIImage* icon = [UIImage _applicationIconImageForBundleIdentifier:application.bundleIdentifier format:0 scale:[UIScreen mainScreen].scale];
			PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:application.localizedName target:self set:@selector(setSwitch:forSpecifier:) get:@selector(getSwitch:) detail:nil cell:PSSwitchCell edit:nil];
			[specifier.properties setValue:application.bundleIdentifier forKey:@"displayIdentifier"];
			if (icon) [specifier setProperty:icon forKey:@"iconImage"];
			[specifiers addObject:specifier];
		}

		_specifiers = [specifiers copy];
	}

	return _specifiers;
}

-(void)setSwitch:(NSNumber *)value forSpecifier:(PSSpecifier *)specifier {
	if(!prefs[@"blacklist"]) prefs[@"blacklist"] = [[NSMutableDictionary alloc] init];
	prefs[@"blacklist"][[specifier propertyForKey:@"displayIdentifier"]] = [NSNumber numberWithBool:[value boolValue]];
	[[prefs copy] writeToFile:PREFERENCE_IDENTIFIER atomically:FALSE];
}
-(NSNumber *)getSwitch:(PSSpecifier *)specifier {
	return [prefs[@"blacklist"][[specifier propertyForKey:@"displayIdentifier"]] isEqual:@1] ? @1 : @0;
}
-(void)getPreference {
	if(![[NSFileManager defaultManager] fileExistsAtPath:PREFERENCE_IDENTIFIER]) prefs = [[NSMutableDictionary alloc] init];
	else prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:PREFERENCE_IDENTIFIER];
}
@end
