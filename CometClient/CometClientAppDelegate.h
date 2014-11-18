//
//  CometClientAppDelegate.h
//  CometClient
//
//  Created by Dave Dunkin on 3/12/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MainViewController;

@interface CometClientAppDelegate : NSObject <UIApplicationDelegate>

@property (nonatomic, strong) IBOutlet UIWindow *window;

@property (nonatomic, strong) IBOutlet MainViewController *mainViewController;

@end
