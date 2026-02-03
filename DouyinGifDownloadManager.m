/**
 * DouyinGifDownload v1.0
 *
 * Author: cookieodd
 * Homepage: https://github.com/cookieodd
 */
#import "DouyinGifDownloadManager.h"
#import <Photos/Photos.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <ImageIO/ImageIO.h>

#ifndef kUTTypeGIF
#define kUTTypeGIF ((__bridge CFStringRef)@"com.compuserve.gif")
#endif

@implementation DouyinGifDownloadManager

static DouyinGifDownloadManager *_sharedInstance = nil;
static UILabel *_currentToastLabel = nil;
static BOOL _isProcessing = NO;

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[DouyinGifDownloadManager alloc] init];
    });
    return _sharedInstance;
}

+ (UIWindow *)getActiveWindow {
    UIWindow *window = nil;
    
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *win in windowScene.windows) {
                    if (win.isKeyWindow) {
                        return win;
                    }
                }
                for (UIWindow *win in windowScene.windows) {
                    if (win.isUserInteractionEnabled && win.alpha > 0 && !win.hidden) {
                        window = win; break;
                    }
                }
                if (window) break;
            }
        }
    } else {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        window = [UIApplication sharedApplication].keyWindow;
        #pragma clang diagnostic pop
    }
    
    return window;
}

+ (void)showToast:(NSString *)text {
    if (!text || text.length == 0) return;
    
    Class toastClass = NSClassFromString(@"DUXToast");
    if (toastClass && [toastClass respondsToSelector:@selector(showText:)]) {
        [toastClass performSelector:@selector(showText:) withObject:text];
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_currentToastLabel) {
            [_currentToastLabel removeFromSuperview];
            _currentToastLabel = nil;
        }
        
        UIWindow *window = [self getActiveWindow];
        if (!window) return;
        
        UILabel *toastLabel = [[UILabel alloc] init];
        toastLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
        toastLabel.textColor = [UIColor whiteColor];
        toastLabel.textAlignment = NSTextAlignmentCenter;
        toastLabel.font = [UIFont systemFontOfSize:14];
        toastLabel.text = text;
        toastLabel.alpha = 0;
        toastLabel.layer.cornerRadius = 8;
        toastLabel.clipsToBounds = YES;
        
        CGFloat safeAreaBottomInset = 0;
        if (@available(iOS 11.0, *)) {
            safeAreaBottomInset = window.safeAreaInsets.bottom;
        }
        
        [toastLabel sizeToFit];
        CGFloat width = MIN(280, MAX(120, toastLabel.frame.size.width + 40));
        CGFloat height = toastLabel.frame.size.height + 15;
        toastLabel.frame = CGRectMake((window.frame.size.width - width) / 2,
                                    window.frame.size.height - 120 - safeAreaBottomInset,
                                    width, height);
        
        toastLabel.isAccessibilityElement = YES;
        toastLabel.accessibilityLabel = text;
        toastLabel.accessibilityTraits = UIAccessibilityTraitStaticText;

        [window addSubview:toastLabel];
        _currentToastLabel = toastLabel;
        
        [UIView animateWithDuration:0.3 animations:^{
            toastLabel.alpha = 1;
        } completion:^(BOOL finished) {
            if (!finished) return;
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (_currentToastLabel == toastLabel) {
                    [UIView animateWithDuration:0.3 animations:^{
                        toastLabel.alpha = 0;
                    } completion:^(BOOL finished) {
                        if (!finished) return;
                        [toastLabel removeFromSuperview];
                        if (_currentToastLabel == toastLabel) {
                            _currentToastLabel = nil;
                        }
                    }];
                }
            });
        }];
    });
}


+ (void)saveHeicToGif:(NSURL *)heicURL completion:(void (^)(void))completion {
    if (_isProcessing) {
        [self showToast:@"已有表情包正在处理中"];
        if (completion) completion();
        return;
    }
    
    _isProcessing = YES;
    
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (status == PHAuthorizationStatusAuthorized) {
            [self convertHeicToGif:heicURL completion:^(NSURL *gifURL, BOOL success) {
                if (success && gifURL) {
                    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                        NSData *gifData = [NSData dataWithContentsOfURL:gifURL options:NSDataReadingMappedIfSafe error:nil];
                        
                        if (!gifData || gifData.length == 0) return;
                        
                        PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
                        PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
                        options.uniformTypeIdentifier = @"com.compuserve.gif"; 
                        [request addResourceWithType:PHAssetResourceTypePhoto data:gifData options:options];  
                    } completionHandler:^(BOOL success, NSError * _Nullable error) {
                        _isProcessing = NO;
                        
                        if (success) {
                            [self showToast:@"表情包已保存到相册"];
                            if (completion) completion();
                        } else {
                            NSString *errorMsg = error ? error.localizedDescription : @"未知错误";
                            [self showToast:[NSString stringWithFormat:@"保存失败: %@", errorMsg]];
                            if (completion) completion();
                        }
                        
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                            [[NSFileManager defaultManager] removeItemAtPath:heicURL.path error:nil];
                            [[NSFileManager defaultManager] removeItemAtPath:gifURL.path error:nil];
                        });
                    }];
                } else {
                    _isProcessing = NO;
                    [self showToast:@"转换失败"];
                    [[NSFileManager defaultManager] removeItemAtPath:heicURL.path error:nil];
                    if (completion) completion();
                }
            }];
        } else {
            _isProcessing = NO;
            
            NSString *authMessage;
            if (status == PHAuthorizationStatusDenied) {
                authMessage = @"请在设置中允许访问相册";
            } else if (status == PHAuthorizationStatusRestricted) {
                authMessage = @"相册访问受到限制";
            } else {
                authMessage = @"无法访问相册，请检查权限设置";
            }
            
            [self showToast:authMessage];
            if (completion) completion();
        }
    }];
}

+ (void)convertHeicToGif:(NSURL *)heicURL completion:(void (^)(NSURL *gifURL, BOOL success))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        CGImageSourceRef heicSource = CGImageSourceCreateWithURL((__bridge CFURLRef)heicURL, NULL);
        if (!heicSource) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, NO);
            });
            return;
        }
        
        size_t count = CGImageSourceGetCount(heicSource);
        if (count == 0) {
            CFRelease(heicSource);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, NO);
            });
            return;
        }
        
        BOOL isAnimated = (count > 1);
        
        NSString *gifFileName = [[heicURL.lastPathComponent stringByDeletingPathExtension] stringByAppendingPathExtension:@"gif"];
        NSURL *gifURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:gifFileName]];
        
        NSDictionary *gifProperties = @{
            (__bridge NSString *)kCGImagePropertyGIFDictionary: @{
                (__bridge NSString *)kCGImagePropertyGIFLoopCount: @0,
                (__bridge NSString *)kCGImagePropertyGIFHasGlobalColorMap: @YES
            }
        };
        
        CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)gifURL, kUTTypeGIF, isAnimated ? count : 1, NULL);
        if (!destination) {
            CFRelease(heicSource);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, NO);
            });
            return;
        }
        
        CGImageDestinationSetProperties(destination, (__bridge CFDictionaryRef)gifProperties);
        
        NSDictionary *options = @{
            (__bridge NSString *)kCGImageSourceShouldCache: @YES
        };
        
        BOOL conversionSuccess = YES;
        
        if (isAnimated) {
            for (size_t i = 0; i < count && conversionSuccess; i++) {
                @autoreleasepool {
                    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(heicSource, i, (__bridge CFDictionaryRef)options);
                    if (!imageRef) {
                        conversionSuccess = NO;
                        continue;
                    }
                    
                    float delayTime = 0.1f;
                    CFDictionaryRef propsDict = CGImageSourceCopyPropertiesAtIndex(heicSource, i, NULL);
                    if (propsDict) {
                        CFDictionaryRef heicDict = CFDictionaryGetValue(propsDict, kCGImagePropertyHEICSDictionary);
                        if (heicDict) {
                            CFNumberRef delayTimeRef = CFDictionaryGetValue(heicDict, kCGImagePropertyHEICSDelayTime);
                            if (delayTimeRef && !CFNumberGetValue(delayTimeRef, kCFNumberFloatType, &delayTime)) {
                                delayTime = 0.1f;
                            }
                        }
                        CFRelease(propsDict);
                    }
                    
                    if (delayTime < 0.02f) delayTime = 0.1f;
                    
                    NSDictionary *frameProperties = @{
                        (__bridge NSString *)kCGImagePropertyGIFDictionary: @{
                            (__bridge NSString *)kCGImagePropertyGIFDelayTime: @(delayTime),
                            (__bridge NSString *)kCGImagePropertyGIFUnclampedDelayTime: @(delayTime)
                        }
                    };
                    
                    CGImageDestinationAddImage(destination, imageRef, (__bridge CFDictionaryRef)frameProperties);
                    CGImageRelease(imageRef);
                }
            }
        } else {
            @autoreleasepool {
                CGImageRef imageRef = CGImageSourceCreateImageAtIndex(heicSource, 0, (__bridge CFDictionaryRef)options);
                if (!imageRef) {
                    conversionSuccess = NO;
                } else {
                    NSDictionary *frameProperties = @{
                        (__bridge NSString *)kCGImagePropertyGIFDictionary: @{
                            (__bridge NSString *)kCGImagePropertyGIFDelayTime: @0.1f
                        }
                    };
                    
                    CGImageDestinationAddImage(destination, imageRef, (__bridge CFDictionaryRef)frameProperties);
                    CGImageRelease(imageRef);
                }
            }
        }
        
        BOOL finalizeSuccess = conversionSuccess ? CGImageDestinationFinalize(destination) : NO;
        
        CFRelease(heicSource);
        CFRelease(destination);
        
        BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:gifURL.path];
        BOOL isValid = fileExists && finalizeSuccess;
        
        if (isValid) {
            NSError *attributesError = nil;
            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:gifURL.path error:&attributesError];
            if (!attributesError) {
                unsigned long long fileSize = [attributes fileSize];
                if (fileSize == 0) isValid = NO;
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(isValid ? gifURL : nil, isValid);
        });
    });
}


+ (void)downloadMedia:(NSURL *)url mediaType:(MediaType)mediaType completion:(void (^)(void))completion {
    if (!url) {
        [self showToast:@"无效的表情包URL"];
        if (completion) completion();
        return;
    }
    
    if (mediaType != MediaTypeHeic) {
        [self showToast:@"仅支持表情包格式"];
        if (completion) completion();
        return;
    }
    
    [self showToast:@"开始获取表情包..."];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSError *error = nil;
        NSData *data = nil;
        
        if ([url isFileURL]) {
            data = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:&error];
        } 
        else {
            NSString *fileName = url.lastPathComponent;
            if (fileName.length == 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showToast:@"无效的表情包数据"];
                    if (completion) completion();
                });
                return;
            }
            
            NSArray *searchPaths = @[
                NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject,
                NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject,
                NSTemporaryDirectory()
            ];
            
            for (NSString *directory in searchPaths) {
                if (!directory) continue;
                
                NSString *filePath = [directory stringByAppendingPathComponent:fileName];
                if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
                    data = [NSData dataWithContentsOfFile:filePath options:NSDataReadingMappedIfSafe error:&error];
                    if (data && !error) break;
                }
            }
        }
        
        if (error || !data || data.length == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showToast:@"获取表情包数据失败"];
                if (completion) completion();
            });
            return;
        }
        
        NSString *fileName = [NSString stringWithFormat:@"%@.heic", [[NSUUID UUID] UUIDString]];
        NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
        NSURL *fileURL = [NSURL fileURLWithPath:tempPath];
        
        if ([data writeToURL:fileURL options:NSDataWritingAtomic error:nil]) {
            [self saveHeicToGif:fileURL completion:completion];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showToast:@"保存文件失败"];
                if (completion) completion();
            });
        }
    });
}

+ (void)saveMedia:(NSURL *)mediaURL mediaType:(MediaType)mediaType completion:(void (^)(void))completion {
    if (mediaType == MediaTypeHeic) {
        [self saveHeicToGif:mediaURL completion:completion];
    } else {
        [self showToast:@"仅支持表情包"];
        if (completion) completion();
    }
}

@end
