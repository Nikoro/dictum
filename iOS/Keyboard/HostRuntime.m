#import "HostRuntime.h"
#import <objc/runtime.h>
#import <TargetConditionals.h>

static BOOL installed = NO;

static Class ArbiterClass(void) {
    return NSClassFromString(@"_UIKeyboardArbiterClient") ?: NSClassFromString(@"UIKeyboardArbiterClient");
}

static void ActivateArbiter(void) {
#if TARGET_OS_SIMULATOR
    return;
#endif
    if (installed) return;
    Class cls = ArbiterClass();
    if (!cls) return;
    Method method = class_getClassMethod(cls, NSSelectorFromString(@"enabled"));
    if (!method || method_getNumberOfArguments(method) != 2) return;
    char result[8] = {0};
    method_getReturnType(method, result, sizeof(result));
    if (strcmp(result, @encode(BOOL)) != 0) return;
    method_setImplementation(method, imp_implementationWithBlock(^BOOL(id receiver) { return YES; }));
    installed = YES;
}

__attribute__((constructor)) static void ActivateAtLoad(void) { ActivateArbiter(); }

@implementation DictumHostRuntime
+ (void)activate { ActivateArbiter(); }
+ (NSObject *)client {
    Class cls = ArbiterClass();
    SEL selector = NSSelectorFromString(@"automaticSharedArbiterClient");
    if (!cls || ![cls respondsToSelector:selector]) return nil;
    IMP implementation = [cls methodForSelector:selector];
    return ((id (*)(id, SEL))implementation)(cls, selector);
}
+ (id)read:(NSString *)key from:(NSObject *)object {
    if (![object respondsToSelector:NSSelectorFromString(key)]) return nil;
    @try { return [object valueForKey:key]; }
    @catch (NSException *exception) { return nil; }
}
@end
