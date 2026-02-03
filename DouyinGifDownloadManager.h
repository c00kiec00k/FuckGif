/**
 * DouyinGifDownload v1.0
 *
 * Author: cookieodd
 * Homepage: https://github.com/cookieodd
 */
#import <UIKit/UIKit.h>
#import "AwemeHeaders.h"

@interface DouyinGifDownloadManager : NSObject
  
+ (instancetype)shared;
+ (void)showToast:(NSString *)text;
+ (void)saveMedia:(NSURL *)mediaURL mediaType:(MediaType)mediaType completion:(void (^)(void))completion;
+ (void)downloadMedia:(NSURL *)url mediaType:(MediaType)mediaType completion:(void (^)(void))completion;

@end
