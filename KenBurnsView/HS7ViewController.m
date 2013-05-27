//
//  HS7ViewController.m
//  KenBurnsView
//
//  Created by Stephen O'Connor on 5/26/13.
//  Copyright (c) 2013 Stephen O'Connor. All rights reserved.
//

#import "HS7ViewController.h"
#import "HSKenBurnsView.h"

@interface HS7ViewController ()
{
    NSArray *_imageNames;
    NSArray *_imageURLs;
    __weak NSArray *_imageSourceArray;
}
@property (weak, nonatomic) IBOutlet HSKenBurnsView *burnsView;
@end

@implementation HS7ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    self.burnsView.randomSelection = YES;
    self.burnsView.usesCrossfadeTransition = YES;

    
    _imageNames = @[
                    @"puppy01.jpg",
                    @"puppy02.jpg",
                    @"puppy03.jpg",
                    @"puppy04.jpg",
                    @"puppy05.jpg"
                    ];
    
    
    _imageURLs = @[
                   [NSURL URLWithString:@"http://images2.fanpop.com/image/photos/9700000/Moraine-Lake-canada-9727405-1024-768.jpg"],
                   [NSURL URLWithString:@"http://sponsoringaspousetocanada.ca/wp-content/uploads/2011/02/Sponsoring-a-Spouse-to-Canada-6.jpg"],
                   [NSURL URLWithString:@"http://gocanada.org/wp-content/uploads/2012/05/skyline-canada-toronto-night-scenery-1080x19201.jpg"],
                   [NSURL URLWithString:@"http://www.sec-canada.com/images/switcher1.jpg"],
                   ];
    
    _imageSourceArray = _imageNames;
    
    [self.burnsView setImageURLs: _imageSourceArray];
    
}
- (IBAction)pressedToggle:(UIButton *)sender {
    
    if (_imageSourceArray == _imageURLs) {
        _imageSourceArray = _imageNames;
        [sender setTitle:@"Src: Local" forState:UIControlStateNormal];
    }
    else
    {
        _imageSourceArray = _imageURLs;
        [sender setTitle:@"Src: Remote" forState:UIControlStateNormal];
    }
    
    [self.burnsView setImageURLs: _imageSourceArray];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
