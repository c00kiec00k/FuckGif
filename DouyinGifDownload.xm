/**
 * DouyinGifDownload v1.0
 *
 * Author: cookieodd
 * Homepage: https://github.com/cookieodd
 */
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import "AwemeHeaders.h"
#import "DouyinGifDownloadManager.h"

static BOOL isDownloadFlied = NO;
static NSMutableSet *downloadingURLs;
static dispatch_queue_t downloadQueue;
static NSUInteger activeDownloads = 0;
static const NSUInteger MAX_CONCURRENT_DOWNLOADS = 3;
static NSLock *downloadCountLock;

%ctor {
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"DYYYFourceDownloadEmotion"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    downloadingURLs = [NSMutableSet new];
    downloadQueue = dispatch_queue_create("com.cookieodd.douyingifdownload.download_queue", DISPATCH_QUEUE_SERIAL);
    downloadCountLock = [[NSLock alloc] init];
}

static void incrementActiveDownloads(void) {
    [downloadCountLock lock];
    activeDownloads++;
    [downloadCountLock unlock];
}

static void decrementActiveDownloads(void) {
    [downloadCountLock lock];
    if (activeDownloads > 0) {
        activeDownloads--;
    }
    [downloadCountLock unlock];
}

static NSUInteger getActiveDownloads(void) {
    [downloadCountLock lock];
    NSUInteger count = activeDownloads;
    [downloadCountLock unlock];
    return count;
}

static void downloadStickerIfNeeded(AWEIMStickerModel *sticker) {
    if (!sticker) return;
    
    @autoreleasepool {
        AWEURLModel *staticURLModel = [sticker staticURLModel];
        if (!staticURLModel) return;
        
        NSArray *originURLList = [staticURLModel originURLList];
        if (!originURLList || originURLList.count == 0) return;
        
        NSString *urlString = originURLList[0];
        
        @synchronized(downloadingURLs) {
            if ([downloadingURLs containsObject:urlString]) {
                return;
            }
            [downloadingURLs addObject:urlString];
        }
        
        dispatch_async(downloadQueue, ^{
            while (getActiveDownloads() >= MAX_CONCURRENT_DOWNLOADS) {
                [NSThread sleepForTimeInterval:0.1];
            }
            
            incrementActiveDownloads();
            
            NSURL *heifURL = [NSURL URLWithString:urlString];
            
            [DouyinGifDownloadManager downloadMedia:heifURL mediaType:MediaTypeHeic completion:^{
                @synchronized(downloadingURLs) {
                    [downloadingURLs removeObject:urlString];
                }
                decrementActiveDownloads();
            }];
        });
    }
}

%hook _TtC33AWECommentLongPressPanelSwiftImpl37CommentLongPressPanelSaveImageElement

-(BOOL)elementShouldShow {
    @autoreleasepool {
        AWECommentLongPressPanelContext *commentPageContext = [self commentPageContext];
        if (!commentPageContext) {
            return %orig;
        }
        
        AWECommentModel *selectdComment = [commentPageContext selectdComment];
        if(!selectdComment) {
            AWECommentLongPressPanelParam *params = [commentPageContext params];
            if (params) {
                selectdComment = [params selectdComment];
            }
        }
        
        if (!selectdComment) {
            return %orig;
        }
        
        AWEIMStickerModel *sticker = [selectdComment sticker];
        if(sticker) {
            AWEURLModel *staticURLModel = [sticker staticURLModel];
            if (staticURLModel) {
                NSArray *originURLList = [staticURLModel originURLList];
                if (originURLList && originURLList.count > 0) {
                    return YES;
                }
            }
        }
        return %orig;
    }
}

-(void)elementTapped {
    @autoreleasepool {
        AWECommentLongPressPanelContext *commentPageContext = [self commentPageContext];
        if (!commentPageContext) {
            %orig;
            return;
        }
        
        AWECommentModel *selectdComment = [commentPageContext selectdComment];
        if(!selectdComment) {
            AWECommentLongPressPanelParam *params = [commentPageContext params];
            if (params) {
                selectdComment = [params selectdComment];
            }
        }
        
        if (!selectdComment) {
            %orig;
            return;
        }
        
        AWEIMStickerModel *sticker = [selectdComment sticker];
        if(sticker) {
            downloadStickerIfNeeded(sticker);
            return;
        }
        %orig;
    }
}
%end

%hook _TtC33AWECommentLongPressPanelSwiftImpl32CommentLongPressPanelCopyElement

-(void)elementTapped {
    %orig;
}
%end

%hook AWEIMStickerModel

- (void)didTap {
    %orig;
    
    @autoreleasepool {
        downloadStickerIfNeeded(self);
    }
}

%end
