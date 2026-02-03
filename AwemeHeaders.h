/* 
 * Tweak Name: FuckGif
 * Target App: com.ss.iphone.ugc.Aweme
 * Dev: @c00kiec00k 曲奇的坏品味🍻
 * iOS Version: 16.5
 */
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>

typedef NS_ENUM(NSInteger, MediaType) {
    MediaTypeVideo,
    MediaTypeImage,
    MediaTypeAudio,
    MediaTypeHeic
};

@interface AWEURLModel : NSObject
- (NSArray *)originURLList;
- (id)URI;
@end

@interface DUXToast : NSObject
+ (void)showText:(NSString *)text;
@end

@interface AWECommentLongPressPanelContext : NSObject
- (id)selectdComment;
- (id)params;
@end

@interface AWECommentLongPressPanelParam : NSObject
- (id)selectdComment;
@end

@interface AWECommentModel : NSObject
- (id)sticker;
- (NSString *)content;
@end

@interface AWEIMStickerModel : NSObject
- (AWEURLModel *)staticURLModel;
@end

@interface _TtC33AWECommentLongPressPanelSwiftImpl37CommentLongPressPanelSaveImageElement : NSObject
- (AWECommentLongPressPanelContext *)commentPageContext;
@end 