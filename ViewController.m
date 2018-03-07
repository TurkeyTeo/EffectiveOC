//
//  ViewController.m
//  EffectiveOC
//
//  Created by Thinkive on 2018/2/24.
//  Copyright © 2018年 Teo. All rights reserved.
//

#import "ViewController.h"
#import <objc/runtime.h>

@interface ViewController ()<TTNetworkFetcherDelegate>

@property (nonatomic, copy) NSString *someString;
@property (nonatomic, copy) NSString *someString2;

@end

@implementation ViewController
{
    TTNetworkFetcher *_fetcher1;
    TTNetworkFetcher *_fetcher2;
    dispatch_queue_t _syncQueue;
    dispatch_queue_t _syncQ;
}

@synthesize someString = _someString;
@synthesize someString2 = _someString2;

- (void)viewDidLoad {
    [super viewDidLoad];

    //1.TTDictionary
    NSMutableDictionary *dic1 = [NSMutableDictionary dictionaryWithObjectsAndKeys:@102,@2,@105,@5, nil];
    NSMutableDictionary *dic2 = [dic1 mutableCopy];
    dic2[@2] = @100;
    NSLog(@"dic1:%@   \n  dic2%@",dic1,dic2);
    
    //2.不加copy为栈block；  加上copy为堆block
    void (^block)(void);
    if (1) {
        block = [^{
            NSLog(@"block A");
        } copy];
    }else{
        block = [^{
            NSLog(@"block B");
        } copy];
    }
    block();
    
    
    //全局block
    void (^globalBlock)() = ^{
        NSLog(@"globalBlock");
    };
    
    
    //3.用handler块降低代码分散程度
    NSURL *url = [[NSURL alloc] initWithString:@"XXX"];
    TTNetworkFetcher *fetcher = [[TTNetworkFetcher alloc] initWithURL:url];
    fetcher.delegate = self;
    [fetcher start];
    
    [fetcher startWithCompletionHandler:^(NSData *data) {
        
    }];
    
    
    NSURL *url1 = [[NSURL alloc] initWithString:@"XXX"];
    _fetcher1 = [[TTNetworkFetcher alloc] initWithURL:url1];
    _fetcher1.delegate = self;
    [_fetcher1 start];
    
    NSURL *url2 = [[NSURL alloc] initWithString:@"XXX"];
    _fetcher2 = [[TTNetworkFetcher alloc] initWithURL:url2];
    _fetcher2.delegate = self;
    [_fetcher2 start];
    
    
    //4.多用派发队列，少用同步锁
    _syncQueue = dispatch_queue_create("com.turkeyteo.syncQueue", NULL);
    _syncQ = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
}


- (NSString *)someString{
    __block NSString *localSomeString;
    dispatch_sync(_syncQueue, ^{
        localSomeString = _someString;
    });
    return localSomeString;
}

- (void)setSomeString:(NSString *)someString{
    //设置方法并不一定非得同步，这里可使用异步能提高执行速度。注意：如果只是执行很简单的操作，改用异步不见得会比同步快，因为执行异步派发时，需要拷贝块，拷贝也是需要花费时间的。
    dispatch_async(_syncQueue, ^{
        _someString = someString;
    });
}


- (NSString *)someString2{
    __block NSString *localSomeString;
    dispatch_sync(_syncQ, ^{
        localSomeString = _someString2;
    });
    return localSomeString;
}

- (void)setSomeString2:(NSString *)someString2{
    dispatch_barrier_async(_syncQ, ^{
        _someString2 = someString2;
    });
}


- (void)networkFetcher:(TTNetworkFetcher *)networkFetcher didFinishWithData:(NSData *)data{
    if (networkFetcher == _fetcher1) {
        //XXX = data;
        _fetcher1 = nil;
    }
    else if (networkFetcher == _fetcher2){
        //data handler
        _fetcher2 = nil;
    }
    //etc.
}

@end



//1.为了说明消息转发机制的意义，下面实例以动态方法解析来实现@dynamic属性
@interface TTDictionary ()

@property (nonatomic, strong) NSMutableDictionary *backingStore;

@end

//id autoDictionaryGetter(id self, SEL _cmd);
//void autoDictionarySetter(id self, SEL _cmd, id value);

id autoDictionaryGetter(id self, SEL _cmd) {
    TTDictionary *typedSelf = (TTDictionary *)self;
    NSMutableDictionary *backingStore = typedSelf.backingStore;
    NSString *key = NSStringFromSelector(_cmd);
    return [backingStore objectForKey:key];
}

void autoDictionarySetter(id self, SEL _cmd, id value) {
    //get the backing store from the object
    TTDictionary *typedSelf = (TTDictionary *)self;
    
    //the selector will be for example. "setOpaqueObject:"  we need to remove the "set",":" and lowercase the first letter of the remainder
    NSMutableDictionary *backingStore = typedSelf.backingStore;
    NSString *selectorString = NSStringFromSelector(_cmd);
    NSMutableString *key = [selectorString mutableCopy];
    
    //remove the ':' at the end
    [key deleteCharactersInRange:NSMakeRange(key.length-1, 1)];
    
    //remove the 'set' prefix
    [key deleteCharactersInRange:NSMakeRange(0, 3)];
    
    //lowercase the first character
    NSString *lowercaseFirstChar = [[key substringToIndex:1] lowercaseString];
    [key replaceCharactersInRange:NSMakeRange(0, 1) withString:lowercaseFirstChar];
    
    if (value) {
        [backingStore setObject:value forKey:key];
    }else{
        [backingStore removeObjectForKey:key];
    }
}

@implementation TTDictionary

@dynamic string,number,date,opaqueObject;

- (id)init{
    if (self = [super init]) {
        _backingStore = [NSMutableDictionary new];
    }
    return self;
}

+ (BOOL)resolveInstanceMethod:(SEL)sel{
    NSString *selectorString = NSStringFromSelector(sel);
    if ([selectorString hasPrefix:@"set"]) {
        class_addMethod(self, sel, (IMP)autoDictionarySetter, "v@:@");
    }
    else{
        class_addMethod(self, sel, (IMP)autoDictionaryGetter, "@@:");
    }
    return YES;
}

- (NSString *)description{
    return [NSString stringWithFormat:@"%@",_backingStore];
}

- (NSString *)debugDescription{
    return [NSString stringWithFormat:@"<%@: %p, %@>",[self class],self,_backingStore];
}

@end



//2.对外不使用可变对象
@interface TTPerson ()<NSCopying>
@property (nonatomic, copy, readwrite) NSString *firstName;
@property (nonatomic, copy, readwrite) NSString *lastName;
@end

@implementation TTPerson {
    NSMutableSet *_internalFriends;
}

- (NSSet *)friends{
    return [_internalFriends copy];
}

- (void)addFriend:(TTPerson *)person{
    [_internalFriends addObject:person];
}

- (void)removeFriend:(TTPerson *)person{
    [_internalFriends removeObject:person];
}

- (id)initWithFirstName:(NSString *)firstName andLastName:(NSString *)lastName{
    if (self = [super init]) {
        _firstName = firstName;
        _lastName = lastName;
        _internalFriends = [NSMutableSet new];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone{
    TTPerson *copy = [[[self class] allocWithZone:zone] initWithFirstName:_firstName andLastName:_lastName];
    return copy;
}

@end

@implementation TTNetworkFetcher

@end
