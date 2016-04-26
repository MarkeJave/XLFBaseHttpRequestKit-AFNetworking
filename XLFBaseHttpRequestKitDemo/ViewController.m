//
//  ViewController.m
//  XLFBaseHttpRequestKitDemo
//
//  Created by Marke Jave on 16/4/26.
//  Copyright © 2016年 Marike Jave. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@property(nonatomic, strong) UILabel *evlbRequestUrl;

@property(nonatomic, strong) UIButton *evbtnRequest;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - accessory

- (UILabel *)evlbRequestUrl{
    
    if (!_evlbRequestUrl) {
        
        _evlbRequestUrl = [[UILabel alloc] initWithFrame:CGRectMake(10, 20, CGRectGetWidth([[UIScreen mainScreen] bounds]) - 20, 40)];
        
        [_evlbRequestUrl setText:@"http://www.baidu.com"];
    }
    
    return _evlbRequestUrl;
}

- (UIButton *)evbtnRequest{
    
    if (!_evbtnRequest) {
        _evbtnRequest = [[UIButton alloc] initWithFrame:CGRectMake(10, 100, CGRectGetWidth([[UIScreen mainScreen] bounds]) - 20, 40)];
        [_evbtnRequest setBackgroundColor:[UIColor lightGrayColor]];
        [_evbtnRequest addTarget:self action:@selector(didClickStartRequest:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _evbtnRequest;
}

#pragma mark - actions

- (IBAction)didClickStartRequest:(id)sender{
    
    
}

@end
