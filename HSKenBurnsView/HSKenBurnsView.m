//
//  HSKenBurnsView.m
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


#import "HSKenBurnsView.h"
#import "UIImage+ProportionalFill.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "AFNetworking.h"

#pragma mark HSKBImageCache

@interface HSKBImageCache : NSCache

- (UIImage*)cachedImageForURL:(NSURL*)url;
- (UIImage*)cachedImageForURL:(NSURL*)url size:(CGSize)size;

- (void)cacheImage:(UIImage*)image forURL:(NSURL*)url;
- (void)cacheImage:(UIImage*)image forURL:(NSURL*)url size:(CGSize)size;

@end

#pragma mark HSKBLayer

@interface HSKBLayer : CALayer
@property (nonatomic, assign) NSUInteger imageIndex;
@end


#pragma mark - Constants, Tuning Values

static NSString * const HSKBAnimationKey = @"KenBurnsAnimationKey";
static NSString * const HSKBAnimationImageIndexKey = @"HSKBAnimationImageIndexKey";

// TUNING CONSTANTS

// i.e. for every change 1.0 in scale, how much delta z in points would that be?  Easier to think from 0.5 -> 1.5
static CGFloat const HSKBAnimationZScaleToDistance = 400.0f;  // used in vector calculations
static CGFloat const HSKBAnimationMaxZoomScale = 1.3f;
static CGFloat const HSKBAnimationMaxDeltaZoomScale = 0.4f;
static CGFloat const HSKBAnimationMaxMoveDistance = 400.f;  // must tune this


#pragma mark - Math Helpers

typedef struct {
    CGFloat x;
    CGFloat y;
    CGFloat z;
} HSKBVector;

CGFloat hsvlen(HSKBVector v)
{
    return sqrtf(v.x*v.x + v.y*v.y + v.z*v.z);
}

HSKBVector hsvnormalize(HSKBVector v){
    CGFloat length = hsvlen(v);
    
    HSKBVector u;
    u.x = v.x / length;
    u.y = v.y / length;
    u.z = v.z / length;
    
    return u;
}

#define ARC4RANDOM_MAX      0x100000000
double Random0to1(){
    return (double)arc4random() / ARC4RANDOM_MAX;  // should be between 0...1
}

BOOL RandomBOOL(){
    double      factor = Random0to1();
    if(factor >= 0.5)
        return YES;
    return NO;
}

NSInteger OneOrMinusOne(){
    BOOL positive = RandomBOOL();
    
    return positive ? 1 : -1;
}

CGFloat RandomInRange(CGFloat location, CGFloat length)
{
    return location + length * Random0to1();
}

NSInteger direction(CGFloat p)
{
    if (p >= 0) {
        return 1;
    }
    else
        return -1;
}

NSInteger invdirection(CGFloat p)
{
    if (p < 0) {
        return 1;
    }
    else
        return -1;
}

#pragma mark -
#pragma mark - Ken Burns View

@interface HSKenBurnsView()
{
    CALayer *_layerOne;
    CALayer *_layerTwo;
    
    __weak CALayer *_currentLayer;
    __weak CALayer *_nextLayer;
    
    NSMutableArray *_imageURLs;  // can be NSStrings (i.e. [UIImage imageNamed: ] or NSURL  (file or remote)
    NSUInteger _nextImageIndex;
    
    NSMutableArray *_unselectedImageIndices;
}
@property (nonatomic, weak, readonly) CALayer *currentLayer;
@property (nonatomic, weak, readonly) CALayer *nextLayer;
@property (nonatomic, assign) NSUInteger nextImageIndex;

@end



@implementation HSKenBurnsView

// lazy load to prevent a lot of initialization on app start
+ (NSOperationQueue *)kSharedImageRequestOperationQueue {
    static NSOperationQueue *kSharedImageRequestOperationQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kSharedImageRequestOperationQueue = [[NSOperationQueue alloc] init];
        [kSharedImageRequestOperationQueue setMaxConcurrentOperationCount:NSOperationQueueDefaultMaxConcurrentOperationCount];
    });
    
    return kSharedImageRequestOperationQueue;
}

// lazy load to prevent a lot of initialization on app start
+ (HSKBImageCache *)kImageCache {
    static HSKBImageCache *kImageCache = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        kImageCache = [[HSKBImageCache alloc] init];
    });
    
    return kImageCache;
}

+ (ALAssetsLibrary*)kAssetsLibrary
{
    static ALAssetsLibrary *kAssetsLibrary = nil;
    static dispatch_once_t onceAssets;
    dispatch_once(&onceAssets, ^{
        kAssetsLibrary = [[ALAssetsLibrary alloc] init];
    });
    
    return kAssetsLibrary;
}


- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self initializeView];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder: aDecoder];
    if (self) {
        [self initializeView];
    }
    return self;
}

- (void)initializeView
{
    _movementTime = 6.5f;
    _transitionTime = 1.6f;
    _waitBeforeMoveTime = 1.6f;
    _waitAfterMove = 1.6f;
    _randomSelection = NO;
    _nextImageIndex = NSNotFound;
    self.userInteractionEnabled = NO;
}

- (void)addSubview:(UIView *)view
{
    [NSException raise: NSInternalInconsistencyException format:@"Adding subviews to this view has unpredictable behaviour! Please use a parent container view.  (Yes, it's slightly silly behaviour, but I'm working with CALayers and am a bit lazy to make it THAT robust"];
}

// local image names.  include extension!, or fileURLs or remote URLs
- (void)setImageURLs:(NSArray *)imageURLs
{
    NSMutableArray *newImages = [NSMutableArray arrayWithCapacity:imageURLs.count];
    
    // have to check if these images exist, then add to namesArray
    NSString *filepath = nil;
    for (id imURL in imageURLs) {
        
        if ([imURL isKindOfClass: [NSString class]]) {
            
            filepath = [[NSBundle mainBundle] pathForResource: (NSString*)imURL ofType: nil];
            if (!filepath) {
                NSLog(@"WARNING: Could not locate image with name: %@.  Did you forget the file extension?", (NSString*)imURL);
            }
            else{
                NSURL *fileURL = [NSURL fileURLWithPath: filepath];
                [newImages addObject: fileURL];
            }

        }
        else if ([imURL isKindOfClass:[NSURL class]]){
            
            NSURL *imageURL = (NSURL*)imURL;
            [newImages addObject: imageURL];
        }
    }
    
    [self resetRandomSelections];
    
    _nextImageIndex = NSNotFound;
    
    _imageURLs = newImages;
    
}

- (NSUInteger)currentImageIndex
{
    return [(HSKBLayer*)_currentLayer imageIndex];
}

#pragma mark - File Fetchers

- (void)fetchImageWithURL:(NSURL*)aURL
               completion:(void(^)(UIImage *image))completion
                  failure:(void(^)(NSError *error))failure
{
    if ([aURL.scheme hasPrefix:@"http"]) {
        // need AFNetworking
        [self fetchRemoteImageWithURL: aURL
                          completion: completion
                             failure: failure];
    }
    else if ([aURL.scheme hasPrefix:@"asset"]){
        // is in the assets library
        [self fetchImageFromLibraryWithURL: aURL
                                completion: completion
                                   failure: failure];
    }
    else if ([aURL.scheme hasPrefix:@"file"]){
        // can fetch from main bundle
        [self fetchLocalImageWithURL: aURL
                          completion: completion
                             failure: failure];
        
    }
}

- (void)fetchLocalImageWithURL:(NSURL*)aURL
                    completion:(void(^)(UIImage *image))completion
                       failure:(void(^)(NSError *error))failure
{
    
    
    CGSize desiredSize = CGSizeZero;
    
    UIImage *cachedImage = nil;
    cachedImage = [[[self class] kImageCache] cachedImageForURL: aURL size: desiredSize];
    
    if (cachedImage != nil) {
        if (completion) {
            completion(cachedImage);
        }
        return;
    }

    dispatch_queue_t _queue = dispatch_queue_create("com.horseshoe7.kenburnsview.queue", 0);
    dispatch_async(_queue, ^{
        
        UIImage *image = nil;
        NSError *error = nil;
        
        NSData *imageData = nil;
        
        if (!image) {
            imageData = [NSData dataWithContentsOfURL: aURL options: 0 error: &error];
        }
        
        if (!error && imageData && !image) {
            CGFloat scale = [[UIScreen mainScreen] scale];
            if ([aURL.absoluteString rangeOfString:@"@2x"].location == NSNotFound) {
                scale = 1.0;
            }
            
            image = [UIImage imageWithData:imageData scale: scale];
            
            if (desiredSize.width > 0 && desiredSize.height > 0) {
                // TODO:  Implement resizing for desiredSize?
                image = [image imageToFitSize: desiredSize method:MGImageResizeCrop];
            }
            
        }
        
        
        dispatch_async(dispatch_get_main_queue(), ^{
        
            if (image) {
                [[[self class] kImageCache] cacheImage: image forURL: aURL size: desiredSize];
            }
        
            if (!image && error && failure) {
                failure(error);
                return;
            }
            
            if (completion) {
                completion(image);
            }
        });
    });

}

- (void)fetchImageFromLibraryWithURL:(NSURL*)assetURL
                          completion:(void(^)(UIImage *image))completion
                             failure:(void(^)(NSError *error))failure
{
    if (assetURL == nil && failure) {
        NSError *error = [NSError errorWithDomain: @"HSKenBurnsViewErrorDomain" code: 0 userInfo:@{NSLocalizedDescriptionKey: @"No URL provided!"}];
        failure(error);
        return;
    }
    
    UIImage *image = nil;
    CGSize desiredSize = CGSizeZero;
    
    // get image from mem cache
    image = [[[self class] kImageCache] cachedImageForURL: assetURL size: desiredSize];
    if (image != nil) {
        if (completion) {
            completion(image);
        }
        return;
    }
    
    // get the image from the assets lib via its url
    if (!image) {
        
        [[[self class] kAssetsLibrary] assetForURL: assetURL resultBlock:^(ALAsset *asset) {
            // code to handle the asset here
            ALAssetRepresentation *rep = [asset defaultRepresentation];
            
            // get the image from the asset
            UIImage *fetchedImage = [UIImage imageWithCGImage: rep.fullScreenImage scale: rep.scale orientation: UIImageOrientationUp];
            //weakself.aspectRatio = fetchedImage.size.width/fetchedImage.size.height;
            
            if (desiredSize.width > 0 && desiredSize.height > 0) {
                fetchedImage = [fetchedImage imageToFitSize: desiredSize method:MGImageResizeCrop];
            }
            
            if (fetchedImage) {
                [[[self class] kImageCache] cacheImage: fetchedImage forURL: assetURL size: desiredSize];
            }
            
            // call on main thread
            if (completion) {
                completion(fetchedImage);
            }
            
        } failureBlock:^(NSError *error) {
            // error handling
            
            // dispatch to main thread
            
            if (failure) {
                failure(error);
            }
            
        }];
    }
}

- (void)fetchRemoteImageWithURL:(NSURL*)aURL
                    completion:(void(^)(UIImage *image))completion
                       failure:(void(^)(NSError *error))failure
{
    
    if (aURL == nil && failure) {
        NSError *error = [NSError errorWithDomain: @"HSKenBurnsViewErrorDomain" code: 0 userInfo:@{NSLocalizedDescriptionKey: @"No URL provided!"}];
        failure(error);
        return;
    }
    
    UIImage *image = nil;
    CGSize desiredSize = CGSizeZero;
    
    // get image from mem cache
    image = [[[self class] kImageCache] cachedImageForURL: aURL size: desiredSize];
    if (image != nil) {
        if (completion) {
            completion(image);
        }
        return;
    }
    
    __weak HSKenBurnsView *weakself = self;
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:aURL];
    [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];
    
    AFImageRequestOperation *requestOperation = [[AFImageRequestOperation alloc] initWithRequest:request];
    [requestOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        UIImage *responseImage = (UIImage*)responseObject;
        
        if (desiredSize.width > 0 && desiredSize.height > 0) {
            responseImage = [responseImage imageToFitSize: desiredSize method:MGImageResizeCrop];
        }
        
        if (responseImage) {
            [[[weakself class] kImageCache] cacheImage:responseImage forURL: aURL size: desiredSize];
        }
        
        if (completion) {
            completion(responseImage);
        }
        
        
    }failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        
        NSString *requestURLString = operation.request.URL.absoluteString;
        NSLog(@"failed to download image for url: %@\nreason: %@", requestURLString, error.localizedDescription);
        
        if (failure) {
            failure(error);
        }
    }];
    
    [[[self class] kSharedImageRequestOperationQueue] addOperation: requestOperation];
    
    
}
#pragma mark - Helper Methods

- (void)resetRandomSelections
{
    // when you change the image sources, any disqualified
    _unselectedImageIndices = [NSMutableArray arrayWithCapacity: _imageURLs.count];
    for (int i = 0; i < _imageURLs.count; i++) {
        [_unselectedImageIndices addObject: @(i)];
    }
}

- (NSUInteger)getNextImageIndex
{
    if (_imageURLs.count == 0) {
        return NSNotFound;
    }
    
    if (self.randomSelection == NO) {
        
        if (_nextImageIndex == NSNotFound) {
            _nextImageIndex = 0;
        }
        else{
            _nextImageIndex++;
            _nextImageIndex %= _imageURLs.count;
        }
    }
    else
    {
        NSUInteger selection;
        NSUInteger selectedIndex;
        
        do {
            selection = MIN((NSUInteger)(Random0to1() * _unselectedImageIndices.count), _unselectedImageIndices.count-1);
            selectedIndex = [(NSNumber*)[_unselectedImageIndices objectAtIndex: selection] unsignedIntegerValue];
            // don't choose the same one twice in a row, unless there's no other option
        } while (selectedIndex == _nextImageIndex && _unselectedImageIndices.count > 1);
        
        
        [_unselectedImageIndices removeObjectAtIndex:selection];
        
        if (_unselectedImageIndices.count == 0) {
            [self resetRandomSelections];
        }
        
        _nextImageIndex = selectedIndex;
    }
    
    return _nextImageIndex;
}

- (void)setupLayers
{
    [_layerOne removeFromSuperlayer];
    _layerOne = nil;
    [_layerTwo removeFromSuperlayer];
    _layerTwo = nil;
    
    HSKBLayer *picLayer    = [HSKBLayer layer];
    picLayer.anchorPoint = CGPointMake(0.5, 0.5);
    picLayer.imageIndex = NSNotFound;
    _layerOne = picLayer;
    
    picLayer    = [HSKBLayer layer];
    picLayer.anchorPoint = CGPointMake(0.5, 0.5);
    picLayer.imageIndex = NSNotFound;
    _layerTwo = picLayer;
    
    // inserting ensures any views added to this view will cooperate and that these 2 views stay at the bottom
    [self.layer insertSublayer:_layerOne atIndex:0];
    [self.layer insertSublayer:_layerTwo atIndex:0];
    
    _currentLayer = _layerOne;
    _nextLayer = _layerTwo;
    
}

#pragma mark - Geometry Helpers

- (CGSize)scaledToAspectFillSizeForImageSize:(CGSize)imageSize frameSize:(CGSize)frameSize oversizeFactor:(CGFloat)oFactor;
{
    NSAssert(oFactor >= 1.0, @"To overscale, you have to provide a value more than 1");
    CGSize newSize = imageSize;
    CGFloat imageAR = imageSize.width/imageSize.height;
    
    // fit one dimension while maintaining aspect ratio, if required
    if (newSize.width < frameSize.width) {
        newSize.width = frameSize.width;
        newSize.height = newSize.width/imageAR;
    }
    
    // now fit the other side
    if (newSize.height < frameSize.height) {
        newSize.height = frameSize.height;
        newSize.width = newSize.height * imageAR;
    }
    
    // if the resized frame is big enough for our purposes
    if (newSize.width - frameSize.width > (oFactor - 1)*frameSize.width ||
        newSize.height - frameSize.height > (oFactor - 1)*frameSize.height) {
        return newSize;
    }
    
    // then figure out what kind of oFactor is necessary to meet the oFactor
    CGFloat newFactorX = 1.f + (newSize.width - frameSize.width)/frameSize.width;
    CGFloat newFactorY = 1.f + (newSize.height - frameSize.height)/frameSize.height;
    
    // we use the greater of the two
    CGFloat currentFactor = MAX(newFactorX, newFactorY);
    
    newSize.width = newSize.width * oFactor/currentFactor;
    newSize.height = newSize.height * oFactor/currentFactor;
    
    return newSize;
}

- (CGFloat)minimumScaleToFitImageSize:(CGSize)imageSize inFrameSize:(CGSize)frameSize
{
    CGFloat zoomX = frameSize.width / imageSize.width;
    CGFloat zoomY = frameSize.height / imageSize.height;
    
    return MAX(zoomX, zoomY);
}

- (CGSize)translationRangeForImageSize:(CGSize)imageSize inFrameSize:(CGSize)frameSize zoomScale:(CGFloat)zoomScale
{
    CGSize zoomedImageSize = imageSize;
    zoomedImageSize.height *= zoomScale;
    zoomedImageSize.width *= zoomScale;
    
    return CGSizeMake(MAX(0, zoomedImageSize.width - frameSize.width),
                      MAX(0, zoomedImageSize.height - frameSize.height));
    
}


#pragma mark - Animation Methods

- (IBAction)startAnimating
{
    if (_imageURLs.count == 0) {
        return; // nothing to do
    }
    
    [self stopAnimating];
    [self setupLayers];
    [self fetchImageForNextLayerThenAnimate];
    
}

// http://stackoverflow.com/a/3003922/421797
- (IBAction)pauseAnimating
{
    [self pauseLayer:_currentLayer];
    [self pauseLayer:_nextLayer];
}

- (IBAction)resumeAnimating
{    
    [self resumeLayer: _currentLayer];
    [self resumeLayer: _nextLayer];
}

-(void)pauseLayer:(CALayer*)layer
{
    CFTimeInterval pausedTime = [layer convertTime:CACurrentMediaTime() fromLayer:nil];
    layer.speed = 0.0;
    layer.timeOffset = pausedTime;
}

-(void)resumeLayer:(CALayer*)layer
{
    CFTimeInterval pausedTime = [layer timeOffset];
    layer.speed = 1.0;
    layer.timeOffset = 0.0;
    layer.beginTime = 0.0;
    CFTimeInterval timeSincePause = [layer convertTime:CACurrentMediaTime() fromLayer:nil] - pausedTime;
    layer.beginTime = timeSincePause;
}

- (IBAction)stopAnimating
{
    // can I trigger a stop animation?
    [_currentLayer removeAllAnimations];
    [_nextLayer removeAllAnimations];
    
    [self resetRandomSelections];    
}

#pragma mark - Animation Helpers

- (void)fetchImageForNextLayerThenAnimate
{
    _nextImageIndex = [self getNextImageIndex];
    
    if (_nextImageIndex == NSNotFound) {
        return;
    }
    
    __weak HSKenBurnsView *weakself = self;
    [self fetchImageWithURL: _imageURLs[MIN(_nextImageIndex, _imageURLs.count-1)] /* Better safe than sorry for now */
                 completion:^(UIImage *image) {
                     
                     CGRect myFrame = weakself.frame;
                     
                     CGSize newSize = [weakself scaledToAspectFillSizeForImageSize: image.size
                                                                         frameSize: myFrame.size
                                                                    oversizeFactor: 1.2];
                     
                     weakself.nextLayer.bounds      = CGRectMake(0, 0, newSize.width, newSize.height);
                     weakself.nextLayer.position    = CGPointMake(CGRectGetMidX(myFrame), CGRectGetMidY(myFrame));
                     weakself.nextLayer.contents = (id)image.CGImage;
                     
                    [weakself animateLayer: weakself.nextLayer withImageIndex: weakself.nextImageIndex];
                     
                 } failure:^(NSError *error) {
                     
                 }];
}

- (void)animateLayer:(CALayer *)layerToAnimate withImageIndex:(NSUInteger)imageIndex {
    
    // Remove existing animations before stating new animation
    [layerToAnimate removeAllAnimations];
    
    [(HSKBLayer*)layerToAnimate setImageIndex: imageIndex];
    
    // NOW SET UP THE ANIMATION PARAMETERS
    CGPoint translationFrom, translationTo;
    CGFloat scaleFrom, scaleTo;
    
    CGFloat minZoomScale = [self minimumScaleToFitImageSize: layerToAnimate.bounds.size inFrameSize: self.frame.size];

    scaleFrom = minZoomScale;
    
    CGSize translationRange = [self translationRangeForImageSize: layerToAnimate.bounds.size
                                                     inFrameSize: self.frame.size
                                                       zoomScale: minZoomScale];
    
    // choose along long axis, random on short axis
    if (translationRange.width > translationRange.height) {
        // x is long axis
        translationFrom.x = OneOrMinusOne() * RandomInRange(translationRange.width/4.f, translationRange.width/4.f);
        translationFrom.y = RandomInRange(-translationRange.height/2.f, translationRange.height);
    }
    else{
        // y is long axis
        translationFrom.x = RandomInRange(-translationRange.width/2.f, translationRange.width);
        translationFrom.y = OneOrMinusOne() * RandomInRange(translationRange.height/4.f, translationRange.height/4.f);

    }
    
    // now calculate toValue
    CGFloat possibleZoomRange = minZoomScale + HSKBAnimationMaxDeltaZoomScale;
    // clamp zoom range to something reasonable
    
    scaleTo = RandomInRange(minZoomScale + possibleZoomRange/4.f, possibleZoomRange*3.f/4.f);
    
    // then get a possible range for that maxZoom
    translationRange = [self translationRangeForImageSize: layerToAnimate.bounds.size
                                              inFrameSize: self.frame.size
                                                zoomScale: scaleTo];
    
    // then choose opposite end of long axis, and random on short axis
    if (translationRange.width > translationRange.height) {
        // x is long axis
        translationTo.x = invdirection(translationFrom.x) * RandomInRange(translationRange.width/4.f, translationRange.width/4.f);
        translationTo.y = RandomInRange(-translationRange.height/2.f, translationRange.height);
    }
    else{
        // y is long axis
        translationTo.x = RandomInRange(-translationRange.width/2.f, translationRange.width);
        translationTo.y = invdirection(translationFrom.y) * RandomInRange(translationRange.height/4.f, translationRange.height/4.f);
    }
    
    HSKBVector delta;
    delta.x = translationTo.x - translationFrom.x;
    delta.y = translationTo.y - translationFrom.y;
    delta.z = (scaleTo - scaleFrom) * HSKBAnimationZScaleToDistance;
    
    // get unit vector now that we have a proposed end point
    HSKBVector unitTo = hsvnormalize(delta);
    
    // calculate end point based on max move distance (or random move distance, up to max)
    HSKBVector toVector;
    toVector.x = translationFrom.x + HSKBAnimationMaxMoveDistance * unitTo.x;
    toVector.y = translationFrom.y + HSKBAnimationMaxMoveDistance * unitTo.y;
    toVector.z = scaleFrom + (HSKBAnimationMaxMoveDistance * unitTo.z)/HSKBAnimationZScaleToDistance;
    
    // now clamp them
    toVector.x = MAX(-translationRange.width/2.f, MIN(translationRange.width/2.f, toVector.x));
    toVector.y = MAX(-translationRange.height/2.f, MIN(translationRange.height/2.f, toVector.y));
    
    translationTo.x = toVector.x;
    translationTo.y = toVector.y;
    scaleTo = toVector.z;
    
    
    // set initial state (must turn off implicit animations or else it will look weird) before animation begins
    [CATransaction begin];
    _nextLayer = layerToAnimate;
    _nextLayer.zPosition = 1;
    _currentLayer.zPosition = 0;
    
    [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
    CATransform3D translateTransform = CATransform3DMakeTranslation(translationFrom.x, translationFrom.y, 1);
    CATransform3D scaleTransform = CATransform3DMakeScale(scaleFrom, scaleFrom, scaleFrom);
    layerToAnimate.transform = CATransform3DConcat(translateTransform, scaleTransform);
    // Make sure view is visible.  Should this go at bottom of method call, or in animation did start??
    layerToAnimate.opacity = 0.0;
    [CATransaction commit];

    
    // now setup the animation object with these values
    CGFloat animationDuration = _transitionTime + _waitBeforeMoveTime + _movementTime + _waitAfterMove;
    NSArray *keyTimes, *values;
    if (self.usesCrossfadeTransition) {
        keyTimes = @[@0, @(_transitionTime/animationDuration)];
        values = @[@0, @1];
    }
    else{
        animationDuration += _transitionTime;
        keyTimes = @[@0,
                     @(_transitionTime/animationDuration),
                     @((_transitionTime + _waitBeforeMoveTime + _movementTime + _waitAfterMove)/animationDuration),
                     @(1 - _transitionTime/animationDuration)
                     ];
        values = @[@0, @1, @1, @0];
    }
    
    // First we fade in
    CAKeyframeAnimation *fadeAnimation = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    fadeAnimation.removedOnCompletion = NO;
    fadeAnimation.fillMode = kCAFillModeForwards;
    fadeAnimation.duration = animationDuration;
    fadeAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    fadeAnimation.keyTimes = keyTimes;
    fadeAnimation.values = values;
    fadeAnimation.beginTime = 0;
    
    
    CABasicAnimation *panAnimation = [CABasicAnimation animationWithKeyPath:@"transform.translation"];
    panAnimation.removedOnCompletion = NO;
    panAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    panAnimation.beginTime = _transitionTime + _waitBeforeMoveTime;
    panAnimation.duration = _movementTime;
    panAnimation.fillMode = kCAFillModeForwards;
    panAnimation.fromValue = [NSValue valueWithCGSize: CGSizeMake(translationFrom.x, translationFrom.y)];
    panAnimation.toValue = [NSValue valueWithCGSize: CGSizeMake(translationTo.x, translationTo.y)];
	
    
        
	// Here you could add other animations to the array
    CABasicAnimation *zoomAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    zoomAnimation.removedOnCompletion = NO;
    zoomAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    zoomAnimation.beginTime = _transitionTime + _waitBeforeMoveTime;
    zoomAnimation.duration = _movementTime;
    zoomAnimation.fillMode = kCAFillModeForwards;
    zoomAnimation.fromValue = @(scaleFrom);
    zoomAnimation.toValue = @(scaleTo);
	
    // Create an animation group to hold the animations
    CAAnimationGroup *theGroup = [CAAnimationGroup animation];
    
    // Set self as the delegate to receive notification when the animation finishes
    theGroup.delegate = self;
    theGroup.duration = animationDuration;
    // CAAnimation-objects support arbitrary Key-Value pairs, we add the UIView tag
    // to identify the animation later when it finishes
	[theGroup setValue: @(imageIndex) forKey: HSKBAnimationImageIndexKey];

    
    // Here you could add other animations to the array
    theGroup.animations = [NSArray arrayWithObjects:fadeAnimation, panAnimation, zoomAnimation, nil];
	theGroup.fillMode = kCAFillModeForwards;
    theGroup.removedOnCompletion = NO;
    // Add the animation group to the layer
    [layerToAnimate addAnimation:theGroup forKey: HSKBAnimationKey];

    _nextLayer = _currentLayer;
    _currentLayer = layerToAnimate;
    
}


-(void)animationDidStart:(CAAnimation *)theAnimation
{
    NSNumber *tag = [theAnimation valueForKey: HSKBAnimationImageIndexKey];
    NSLog(@"Started Animating Page Index %d", tag.unsignedIntegerValue);
    
}


- (void)animationDidStop:(CAAnimation *)theAnimation finished:(BOOL)flag {
    NSNumber *tag = [theAnimation valueForKey: HSKBAnimationImageIndexKey];
    NSLog(@"Stopped Animating Page Index %d", tag.unsignedIntegerValue);
    
    // can I get the toValues of each animation then set them here?
    if (flag) {
        [self fetchImageForNextLayerThenAnimate];
    }
}

@end





#pragma mark - HSKBImageCache

static inline NSString * HSKBImageCacheKeyFromURLAndSize(NSURL *url, CGSize size) {
    
    if (CGSizeEqualToSize(size, CGSizeZero)) {
        return [url absoluteString];
    }
    
    return [[url absoluteString] stringByAppendingString: NSStringFromCGSize(size)];
}

@implementation HSKBImageCache

- (UIImage*)cachedImageForURL:(NSURL*)url {
    
	return [self cachedImageForURL:url size:CGSizeZero];
}

- (UIImage*)cachedImageForURL:(NSURL*)url size:(CGSize)size
{
    return [self objectForKey: HSKBImageCacheKeyFromURLAndSize(url, size)];
}

- (void)cacheImage:(UIImage *)image forURL:(NSURL*)url
{
    [self cacheImage: image forURL: url size: CGSizeZero];
}

- (void)cacheImage:(UIImage *)image forURL:(NSURL *)url size:(CGSize)size
{
    if (image && url) {
        [self setObject:image forKey: HSKBImageCacheKeyFromURLAndSize(url, size)];
    }
}

@end


@implementation HSKBLayer

@end
