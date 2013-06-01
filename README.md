README.txt
==========

I was inspired by JBKenBurnsView on github (https://github.com/jberlana/iOSKenBurns), but looked at the code and decided it needed a bit of a rewrite (it was using non-ARC and NSThread).  I also wanted to play around with CoreAnimation on my own.

The idea is the same:  You provide some imageURLs (or imageNames with file extensions), and set up the slideshow parameters, and call startAnimating

```objc
//
//  HSKenBurnsView.h
//  KenBurnsView
//
//  Created by Stephen O'Connor on 5/26/13.
//  Copyright (c) 2013 Stephen O'Connor. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>


@interface HSKenBurnsView : UIView

// SLIDESHOW settings
@property (nonatomic, assign) CGFloat transitionTime;  // time it takes to fade between 2 views. defaults to 1.6 seconds
@property (nonatomic, assign) CGFloat waitBeforeMoveTime;  // defaults to 1.6
@property (nonatomic, assign) CGFloat movementTime;  // how long the views move before beginning a transition.  defaults to 6.5 seconds
@property (nonatomic, assign) CGFloat waitAfterMove;  // before triggering a new load.  Defaults to 1.6 secs
@property (nonatomic, assign) BOOL usesCrossfadeTransition;  // or just fade one out to background, fade next in, or crossfade.  Defaults to YES
@property (nonatomic, assign) BOOL randomSelection;  // defaults to NO.  will randomly going through the set before repeating

@property (nonatomic, strong, readonly) NSArray *imageURLs;  // no matter which two of the setImage... methods, these will be calculated
@property (nonatomic, readonly) NSUInteger currentImageIndex;  // will correspond the one displaying or currently fading in.

- (void)setImageURLs:(NSArray *)imageURLs;  // allowable types, NSString (filenames), NSURL (fileURL or remote)

- (IBAction)startAnimating;  // starts from a fresh state
- (IBAction)pauseAnimating;
- (IBAction)resumeAnimating;
- (IBAction)stopAnimating;  // basically resets the view

@end
```

Features

* Simple API
* You can provide local image names (i.e. @"myProjectImage.jpg")
* You can provide remote image URLs (i.e. @"http://...")  (AFNetworking as dependency)
* You can provide fileURLs from the assets library  (i.e. @"assets-library://..." )  (AssetsLibrary as dependency)
* You can tell it to randomly select images from your source array (and it will cycle through them all before starting again)
* Either crossfade the transition or fade one out, then the next one in.
* Supports Start, Stop, Pause, Resume.
* Provides a memory cache for images

Areas for Improvement

* Implement image size 'clamping' in case you download really large images
* Have disk caching for resized source images.
* Allow addSubview: 
* Improve performance via animation callbacks and unloading content when not required.
* prefetch next image while current animation is playing.  Currently it will start fetching them after an animation has finished.
This means the transitions aren't as quick until the image is cached locally.

Known Issues

* I wrote this in 8 hours.
* I cheated a bit and disallow adding subviews.  Please add subviews to a common superview.
* Not tested with images from the Assets Library.  Borrowed old functioning code from somewhere else.
* Haven't profiled yet, so don't know how efficient this all is.
* something weird happens with the beginning of an animation from time to time.  like it 'jumps'  have to investigate.
* doesn't deal with Errors yet very well.  Have to add this in the error blocks.
* Isn't yet a CocoaPod :-(

Installation

* Clone this demo project
* uses Cocoapods, so please make sure you've installed that www.cocoapods.org
* Depends on Pods listed in Podfile, so be sure to run 'pod install' from a terminal window
* open the project from the workspace file created by CocoaPods, not the project.




