#include "AFPRootListController.h"
#include "AFPBlackListController.h"
#import <spawn.h>
#import <objc/runtime.h>
NSString *PREFERENCE_IDENTIFIER;
NSFileManager *manager;
NSMutableDictionary *prefs;
NSString *AFontPath;
BOOL isRootless;
NSBundle *localizedBundle;

@interface UIApplication (Private)
- (void)openURL:(NSURL *)url options:(NSDictionary *)options completionHandler:(void (^)(BOOL success))completion;
@end

#define LocalizeString(key) [localizedBundle localizedStringForKey:key value:key table:@"prefs"]

NSString *findBoldFont(NSArray *list, NSString *name) {
	NSString *orig_font = [name stringByReplacingOccurrencesOfString:@" R" withString:@""];
	orig_font = [name stringByReplacingOccurrencesOfString:@"" withString:@""];
	orig_font = [name stringByReplacingOccurrencesOfString:@" Regular" withString:@""];
	orig_font = [name stringByReplacingOccurrencesOfString:@"Regular" withString:@""];
	orig_font = [name stringByReplacingOccurrencesOfString:@"-Regular" withString:@""];
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"R$" options:0 error:nil];
	orig_font = [regex stringByReplacingMatchesInString:orig_font options:0 range:NSMakeRange(0, [orig_font length]) withTemplate:@""];
	orig_font = [orig_font stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

	if([list containsObject:[NSString stringWithFormat:@"%@-Bold", orig_font]]) return [NSString stringWithFormat:@"%@-Bold", orig_font];
	if([list containsObject:[NSString stringWithFormat:@"%@-B", orig_font]]) return [NSString stringWithFormat:@"%@-B", orig_font];
	if([list containsObject:[NSString stringWithFormat:@"%@Bold", orig_font]]) return [NSString stringWithFormat:@"%@Bold", orig_font];
	if([list containsObject:[NSString stringWithFormat:@"%@B", orig_font]]) return [NSString stringWithFormat:@"%@B", orig_font];
	if([list containsObject:[NSString stringWithFormat:@"%@ Bold", orig_font]]) return [NSString stringWithFormat:@"%@ Bold", orig_font];
	if([list containsObject:[NSString stringWithFormat:@"%@ B", orig_font]]) return [NSString stringWithFormat:@"%@ B", orig_font];
	return name;
}

NSArray *getFullFontList() {
	NSArray *fonts = [UIFont familyNames];
	NSMutableArray *fullList = [NSMutableArray new];
	for(NSString *key in fonts) {
		NSArray *fontList = [UIFont fontNamesForFamilyName:key];
		for(NSString *name in fontList) {
			[fullList addObject:name];
		}
	}
	return fullList;
}

NSString *findAppDocumentPath(NSString *appIdentifier) {
	NSString *path = [[[objc_getClass("LSApplicationProxy") applicationProxyForIdentifier:appIdentifier] dataContainerURL] path];

	if([path hasPrefix:@"/private/var"]) {
		NSMutableArray *pathComponents = [NSMutableArray arrayWithArray:[path pathComponents]];
		[pathComponents removeObjectAtIndex:1];
		path = [NSString pathWithComponents:pathComponents];
	}

	return path;
}

BOOL clearDir(NSString *dir) {
	BOOL file;
	if([dir hasSuffix:@"/"]) file = NO;
	else file = YES;
	NSFileManager *manager = [NSFileManager defaultManager];
	if(file) return [manager removeItemAtPath:dir error:nil];

	NSArray *subpaths = [manager contentsOfDirectoryAtPath:dir error:NULL];
	for(NSString *key in subpaths) {
		if(![manager removeItemAtPath:[NSString stringWithFormat:@"%@/%@", dir, key] error:nil]) return NO;
	}
	return YES;
}

@implementation AFPRootListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		[self getPreference];
		NSMutableArray *specifiers = [[NSMutableArray alloc] init];
		[specifiers addObject:({
			PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:LocalizeString(@"Credits") target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
			specifier;
		})];
		[specifiers addObject:({
			PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:@"@BawAppie (Developer)" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
			[specifier setIdentifier:@"BawAppie"];
	    	specifier->action = @selector(openLinks:);
			specifier;
		})];
		[specifiers addObject:({
			PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:@"LICENSE" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
			[specifier setIdentifier:@"license"];
	    	specifier->action = @selector(openLinks:);
			specifier;
		})];

		[specifiers addObject:({
			PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:LocalizeString(@"A-Font Settings") target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
			[specifier.properties setValue:LocalizeString(@"A-Font will load fonts from /Library/A-Font/. If you added a new font, you need to restart the settings app or SpringBoard.") forKey:@"footerText"];
			specifier;
		})];
		[specifiers addObject:({
				PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:LocalizeString(@"Enable") target:self set:@selector(setSwitch:forSpecifier:) get:@selector(getSwitch:) detail:nil cell:PSSwitchCell edit:nil];
				[specifier.properties setValue:@"isEnabled" forKey:@"displayIdentifier"];
			specifier;
		})];
		// [specifiers addObject:({
		// 		PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:LocalizeString(@"Enable UILabel Hook") target:self set:@selector(setSwitch:forSpecifier:) get:@selector(getSwitch:) detail:nil cell:PSSwitchCell edit:nil];
		// 		[specifier.properties setValue:@"useUILabelHook" forKey:@"displayIdentifier"];
		// 	specifier;
		// })];
		PSSpecifier *_fontSpecifier = [PSSpecifier preferenceSpecifierNamed:LocalizeString(@"Font") target:self set:@selector(setFont:forSpecifier:) get:@selector(getFont:) detail:[PSListItemsController class] cell:PSLinkListCell edit:nil];
		[_fontSpecifier.properties setValue:@"valuesSource:" forKey:@"valuesDataSource"];
		[_fontSpecifier.properties setValue:@"valuesSource:" forKey:@"titlesDataSource"];
		[specifiers addObject:_fontSpecifier];
		PSSpecifier *_boldFontSpecifier = [PSSpecifier preferenceSpecifierNamed:LocalizeString(@"Bold Font") target:self set:@selector(setFont:forSpecifier:) get:@selector(getFont:) detail:[PSListItemsController class] cell:PSLinkListCell edit:nil];
		[_boldFontSpecifier.properties setValue:@"valuesSource:" forKey:@"valuesDataSource"];
		[_boldFontSpecifier.properties setValue:@"valuesSource:" forKey:@"titlesDataSource"];
		[specifiers addObject:_boldFontSpecifier];
		[specifiers addObject:[PSSpecifier preferenceSpecifierNamed:LocalizeString(@"Blacklist") target:nil set:nil get:nil detail:[AFPBlackListController class] cell:PSLinkListCell edit:nil]];

		// [specifiers addObject:[PSSpecifier preferenceSpecifierNamed:LocalizeString(@"Browse fonts from online") target:nil set:nil get:nil detail:[AFPBrowseController class] cell:PSLinkListCell edit:nil]];
		[specifiers addObject:({
			PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:LocalizeString(@"Browse fonts from online") target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
			[specifier setIdentifier:@"online"];
	   		 specifier->action = @selector(openLinks:);
			specifier;
		})];
		[specifiers addObject:({
			PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:LocalizeString(@"Open font folder") target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
			[specifier setIdentifier:@"filza"];
	    	specifier->action = @selector(openLinks:);
			specifier;
		})];


		[specifiers addObject:({
			PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:LocalizeString(@"Font Size") target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
			[specifier.properties setValue:LocalizeString(@"Font Size feature can cause unexpected problems. If this is not needed, keep 1.0") forKey:@"footerText"];
			specifier;
		})];
    [specifiers addObject:({
			PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:@"size" target:self set:@selector(setNumber:forSpecifier:) get:@selector(getNumber:) detail:Nil cell:PSSliderCell edit:Nil];
			[specifier setProperty:@"size" forKey:@"displayIdentifier"];
			[specifier setProperty:@1 forKey:@"default"];
			[specifier setProperty:@0.5 forKey:@"min"];
			[specifier setProperty:@1.5 forKey:@"max"];
			[specifier setProperty:@YES forKey:@"isSegmented"];
			[specifier setProperty:@10 forKey:@"segmentCount"];
			[specifier setProperty:@YES forKey:@"showValue"];
			specifier;
		})];


		[specifiers addObject:({
			PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:LocalizeString(@"WebKit Options") target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
			[specifier.properties setValue:LocalizeString(@"If this option is enabled, A-Font injects CSS into WebKit. Some fonts are not available in Safari.") forKey:@"footerText"];
			specifier;
		})];
		[specifiers addObject:({
			PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:LocalizeString(@"Enable in WebKit") target:self set:@selector(setSwitch:forSpecifier:) get:@selector(getSwitch:) detail:nil cell:PSSwitchCell edit:nil];
			[specifier.properties setValue:@"enableSafari" forKey:@"displayIdentifier"];
			specifier;
		})];
		[specifiers addObject:({
			PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:LocalizeString(@"Use !important tag") target:self set:@selector(setSwitch:forSpecifier:) get:@selector(getSwitch:) detail:nil cell:PSSwitchCell edit:nil];
			[specifier.properties setValue:@"WebKitImportant" forKey:@"displayIdentifier"];
			specifier;
		})];

		[specifiers addObject:[PSSpecifier preferenceSpecifierNamed:LocalizeString(@"Recommended") target:self set:nil get:nil detail:nil cell:PSGroupCell edit:nil]];
		[specifiers addObject:({
			PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:LocalizeString(@"Clear font cache and restart SpringBoard") target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
	    	specifier->action = @selector(cacheRespring);
			specifier;
		})];
		[specifiers addObject:({
			PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:LocalizeString(@"Restart SpringBoard") target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
	    	specifier->action = @selector(Respring);
			specifier;
		})];

		_specifiers = [specifiers copy];
	}

	return _specifiers;
}

-(void)setSwitch:(NSNumber *)value forSpecifier:(PSSpecifier *)specifier {
	prefs[[specifier propertyForKey:@"displayIdentifier"]] = [NSNumber numberWithBool:[value boolValue]];
	[[prefs copy] writeToFile:PREFERENCE_IDENTIFIER atomically:FALSE];
}
-(NSNumber *)getSwitch:(PSSpecifier *)specifier {
	return [prefs[[specifier propertyForKey:@"displayIdentifier"]] isEqual:@1] ? @1 : @0;
}

-(void)setNumber:(NSNumber *)value forSpecifier:(PSSpecifier *)specifier {
	prefs[[specifier propertyForKey:@"displayIdentifier"]] = value;
	[[prefs copy] writeToFile:PREFERENCE_IDENTIFIER atomically:FALSE];
}
-(NSNumber *)getNumber:(PSSpecifier *)specifier {
	return prefs[[specifier propertyForKey:@"displayIdentifier"]] ? prefs[[specifier propertyForKey:@"displayIdentifier"]] : @1;
}

- (void)setFont:(NSString *)fontName forSpecifier:(PSSpecifier*)specifier {
	if([fontName hasPrefix:@"Automatic ("]) fontName = @"Automatic";
	if([specifier.name isEqualToString:LocalizeString(@"Bold Font")]) prefs[@"boldfont"] = fontName;
	else prefs[@"font"] = fontName;
	[[prefs copy] writeToFile:PREFERENCE_IDENTIFIER atomically:FALSE];
}
- (NSString *)getFont:(PSSpecifier *)specifier {
	NSArray *fullList = getFullFontList();
	NSString *boldfont;
	if(!prefs[@"font"]) boldfont = @"Please select font.";
	else boldfont = findBoldFont(fullList, prefs[@"font"]);
	if([specifier.name isEqualToString:LocalizeString(@"Bold Font")]) return (![prefs[@"boldfont"] isEqualToString:@"Automatic"] ? prefs[@"boldfont"] : [NSString stringWithFormat:@"Automatic (%@)", boldfont]);
	else return prefs[@"font"];
}
- (NSArray *)valuesSource:(PSSpecifier *)target {
	NSMutableArray *dic = [[[UIFont familyNames] sortedArrayUsingSelector:@selector(compare:)] mutableCopy];
	if(![target.name isEqualToString:LocalizeString(@"Font")]) {
		NSArray *fullList = getFullFontList();
		dic = [[fullList sortedArrayUsingSelector:@selector(compare:)] mutableCopy];
		NSString *boldfont;
		if(!prefs[@"font"]) boldfont = @"Please select font.";
		else boldfont = findBoldFont(fullList, prefs[@"font"]);
		[dic insertObject:[NSString stringWithFormat:@"Automatic (%@)", boldfont] atIndex:0];
	}
	return dic;
}

-(void)openLinks:(PSSpecifier *)specifier {
	NSString *value = specifier.identifier;
	NSString *loc;
	if([value isEqualToString:@"BawAppie"]) loc = @"https://twitter.com/BawAppie";
	if([value isEqualToString:@"filza"]) loc = [NSString stringWithFormat:@"filza://view%@", AFontPath];
	if([value isEqualToString:@"online"]) loc = @"https://a-font.rpgfarm.com";
	if([value isEqualToString:@"license"]) loc = @"https://gitlab.com/Baw-Appie/A-Font/-/blob/master/LICENSE";
	UIApplication *app = [UIApplication sharedApplication];
	[app openURL:[NSURL URLWithString:loc] options:@{} completionHandler:nil];
}
-(void)getPreference {
	manager = [NSFileManager defaultManager];
	isRootless = [manager fileExistsAtPath:@"/var/jb/"];
	localizedBundle = [NSBundle bundleWithPath:isRootless ? @"/var/jb/Library/PreferenceBundles/AFontPrefs.bundle" : @"/Library/PreferenceBundles/AFontPrefs.bundle"];
	if([manager fileExistsAtPath:@"/var/Liy/"]) AFontPath = @"/var/Liy/Library/A-Font/";
	else if([manager fileExistsAtPath:@"/var/jb/"]) AFontPath = @"/var/jb/Library/A-Font/";
	else AFontPath = @"/Library/A-Font/";
	PREFERENCE_IDENTIFIER = isRootless ? @"/var/jb/var/mobile/Library/Preferences/com.rpgfarm.afontprefs.plist" : @"/var/mobile/Library/Preferences/com.rpgfarm.afontprefs.plist";
	if(![manager fileExistsAtPath:PREFERENCE_IDENTIFIER]) prefs = [[NSMutableDictionary alloc] init];
	else prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:PREFERENCE_IDENTIFIER];
}
- (void)Respring {
	pid_t pid;
	const char* args[] = {"killall", "backboardd", NULL};
	posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, (char* const*)args, NULL);
}
- (void)cacheRespring {
	NSString *phoneDir = findAppDocumentPath(@"com.apple.mobilephone");
	NSString *inCallDir = findAppDocumentPath(@"com.apple.InCallService");

	NSArray *dir = @[
		@"/var/mobile/Library/Caches/com.apple.keyboards/",
		@"/var/mobile/Library/Caches/TelephonyUI-7/",
		@"/var/mobile/Library/Caches/TelephonyUI-8/",
		@"/var/mobile/Library/Caches/com.apple.UIStatusBar/",
		@"/var/mobile/Library/SMS/com.apple.messages.geometrycache_v3.plist",
		@"/Library/Caches/TelephonyUI-7/",
		[NSString stringWithFormat:@"%@/Library/Caches/TelephonyUI-7/", phoneDir],
		[NSString stringWithFormat:@"%@/Library/Caches/TelephonyUI-7/", inCallDir],
		[NSString stringWithFormat:@"%@/Library/Caches/TelephonyUI-8/", phoneDir],
		[NSString stringWithFormat:@"%@/Library/Caches/TelephonyUI-8/", inCallDir]
	];

	NSMutableString *dirStr = [NSMutableString string];
	for(NSString* key in dir){
	    if([dirStr length] > 0) [dirStr appendString:@"\n"];
	    [dirStr appendString:key];
	}

	UIAlertController *alert = [UIAlertController alertControllerWithTitle:LocalizeString(@"Clear font cache and restart SpringBoard") message:[NSString stringWithFormat:@"%@\n\n%@", LocalizeString(@"A-Font will delete the following files and restart Springboard.Are you sure?"), dirStr] preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:LocalizeString(@"Cancel") style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
	}]];
	[alert addAction:[UIAlertAction actionWithTitle:LocalizeString(@"Clear cache") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
		for(NSString* key in dir) clearDir(key);
		pid_t pid;
		const char* args[] = {"killall", "backboardd", NULL};
		posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, (char* const*)args, NULL);
	}]];
	[self presentViewController:alert animated:YES completion:nil];
}
@end
