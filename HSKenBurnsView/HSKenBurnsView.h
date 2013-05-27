//
//  HSKenBurnsView.h
//  KenBurnsView
//
//  Created by Stephen O'Connor on 5/26/13.
//  Copyright (c) 2013 Stephen O'Connor. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this
//  software and associated documentation files (the "Software"), to deal in the Software
//  without restriction, including without limitation the rights to use, copy, modify, merge,
//  publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
//  to whom the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies
//  or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
//  INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
//  PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
//  FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
//  ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
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

- (void)setImageURLs:(NSArray *)imageURLs;  // allowable types, NSString (filenames), NSURL (fileURL, remote, or assets library)

- (IBAction)startAnimating;  // starts from a fresh state
- (IBAction)pauseAnimating;
- (IBAction)resumeAnimating;
- (IBAction)stopAnimating;  // basically resets the view

@end


