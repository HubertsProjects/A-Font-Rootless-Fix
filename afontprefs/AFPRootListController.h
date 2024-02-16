#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSListItemsController.h>

@interface LSApplicationProxy : NSObject
+(id)applicationProxyForIdentifier:(id)arg1 ;
-(NSURL *)dataContainerURL;
@end

@interface AFPRootListController : PSListController

@end
