//
//  Animal.m
//  JSCoreDemo
//
//  Created by HaiguangHuang on 2019/6/17.
//  Copyright © 2019 HaiguangHuang. All rights reserved.
//

#import "Animal.h"

@implementation Animal

- (void)sayWithoutExport
{
    NSLog(@"my name is %@", self.name);
}

- (void)sayWithExport
{
    NSLog(@"say in js");
}

- (void)test {
    NSArray *array = [NSArray array];
    array[0];
}
@end
