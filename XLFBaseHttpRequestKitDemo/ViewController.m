//
//  ViewController.m
//  XLFBaseHttpRequestKitDemo
//
//  Created by Marke Jave on 16/4/26.
//  Copyright © 2016年 Marike Jave. All rights reserved.
//

#import "ViewController.h"

#import <XLFBaseHttpRequestKit/XLFBaseHttpRequestKit.h>

@interface ViewController ()

@property(nonatomic, strong) UILabel *evlbRequestUrl;

@property(nonatomic, strong) UIButton *evbtnRequest;

@property(nonatomic, strong) UITextView *evtxvResponse;

@end

@implementation ViewController

- (void)loadView{
    [super loadView];
    
    [[self view] addSubview:[self evlbRequestUrl]];
    [[self view] addSubview:[self evbtnRequest]];
    [[self view] addSubview:[self evtxvResponse]];
}

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
        
        _evlbRequestUrl = [[UILabel alloc] initWithFrame:CGRectMake(10, 40, CGRectGetWidth([[UIScreen mainScreen] bounds]) - 20, 40)];
        
        [_evlbRequestUrl setText:@"http://www.cocoachina.com"];
    }
    
    return _evlbRequestUrl;
}

- (UIButton *)evbtnRequest{
    
    if (!_evbtnRequest) {
        _evbtnRequest = [[UIButton alloc] initWithFrame:CGRectMake(10, 100, CGRectGetWidth([[UIScreen mainScreen] bounds]) - 20, 40)];
        [_evbtnRequest setTitle:@"加载" forState:UIControlStateNormal];
        [_evbtnRequest setBackgroundColor:[UIColor lightGrayColor]];
        [_evbtnRequest addTarget:self action:@selector(didClickStartRequest:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _evbtnRequest;
}

- (UITextView *)evtxvResponse{
    
    if (!_evtxvResponse) {
        
        _evtxvResponse = [[UITextView alloc] initWithFrame:CGRectMake(10, 150, CGRectGetWidth([[UIScreen mainScreen] bounds]) - 20, CGRectGetHeight([[UIScreen mainScreen] bounds]) - 150 - 20)];
    }
    return _evtxvResponse;
}

#pragma mark - actions

- (IBAction)didClickStartRequest:(id)sender{
    
    XLFHttpParameter *etHttpParameter = [[XLFHttpParameter alloc] init];
    [etHttpParameter setMethod:@"GET"];
    [etHttpParameter setRequestURL:[NSURL URLWithString:[[self evlbRequestUrl] text]]];
    
    XLFHttpRequestManager *etManager = [XLFHttpRequestManager shareManager];
    
    NSURLSessionTask *etTask = [etManager taskWithParameters:etHttpParameter tag:0 success:^(id task, id result) {
        
        [[self evtxvResponse] setText:[result description]];
        
    } failure:^(id task, NSError *error) {
        
        [[self evtxvResponse] setText:[error description]];
    }];
    
    [etTask startAsynchronous];
}

@end
