//
//  ViewController.h
//  EffectiveOC
//
//  Created by Thinkive on 2018/2/24.
//  Copyright © 2018年 Teo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

@interface ViewController : UIViewController


@end



//1.为了说明消息转发机制的意义，下面实例以动态方法解析来实现@dynamic属性
@interface TTDictionary : NSObject

@property (nonatomic, copy) NSString *string;
@property (nonatomic, copy) NSNumber *number;
@property (nonatomic, copy) NSDate *date;
@property (nonatomic, strong) id opaqueObject;

@end


//2.对外不使用可变对象
@interface TTPerson : NSObject

@property (nonatomic, copy, readonly) NSString *firstName;
@property (nonatomic, copy, readonly) NSString *lastName;
@property (nonatomic, copy, readonly) NSSet *friends;

- (id)initWithFirstName:(NSString *)firstName
            andLastName:(NSString *)lastName;

- (void)addFriend:(TTPerson *)person;

- (void)removeFriend:(TTPerson *)person;

@end


//3.用handler块降低代码分散程度
@class TTNetworkFetcher;

@protocol TTNetworkFetcherDelegate <NSObject>
- (void)networkFetcher:(TTNetworkFetcher *)networkFetcher
     didFinishWithData:(NSData *)data;
@end

typedef void(^TTNetworkFetcherCompletionHandler)(NSData *data);

@interface TTNetworkFetcher : NSObject
@property (nonatomic, weak) id <TTNetworkFetcherDelegate> delegate;
- (id)initWithURL:(NSURL *)url;
- (void)start;
- (void)startWithCompletionHandler:(TTNetworkFetcherCompletionHandler)handle;

@end



