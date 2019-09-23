//
//  ViewController.m
//  JSCoreDemo
//
//  Created by HaiguangHuang on 2019/6/17.
//  Copyright © 2019 HaiguangHuang. All rights reserved.
//

#import "ViewController.h"
#import <JavaScriptCore/JavaScriptCore.h>
#import "Animal.h"
#import "JSCoreEngine.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //创建JSContext
    JSContext *context = [[JSContext alloc] init];
    //声明一个js变量a, 并赋值
    context[@"a"] = @"Hello ";
    //声明变量有两种方式，还可以通过js的方式来声明变量
    [context evaluateScript:@"var b = 'JS';"];
    //声明一个js方法fun，在OC中则是一个匿名函数block
    context[@"fun"] = ^() {
        //获取方法入参
        NSArray *args = [JSContext currentArguments];
        for (JSValue *value in args) {
//            NSLog(@"%@", [value toObject]);
        }
    };
    //执行js方法fun
    [context evaluateScript:@"fun(a, b)"];
    
    //获取js的变量，并转成OC对象
    JSValue *value = context[@"a"];
//    NSLog(@"%@",[value toObject]);
    
    [[JSCoreEngine sharedInstance] startEngine];
    Animal *animal = [[Animal alloc] init];
    [animal test];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self testExport];
}

- (void)testExport
{
    Animal *animal = [[Animal alloc] init];
    animal.name = @"bird";
    
    JSContext *context = [[JSContext alloc] init];
    context[@"animal"] = animal;
    //not work
    [context evaluateScript:@"animal.sayWithoutExport()"];
    //work
    [context evaluateScript:@"animal.sayWithExport()"];
        
    context.exceptionHandler = ^(JSContext *context, JSValue *exception) {
        NSLog(@"%@", [exception toObject]);
    };
}


@end
