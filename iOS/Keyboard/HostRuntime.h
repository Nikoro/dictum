#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface DictumHostRuntime : NSObject
+ (void)activate;
+ (nullable NSObject *)client;
+ (nullable id)read:(NSString *)key from:(NSObject *)object;
@end
NS_ASSUME_NONNULL_END
