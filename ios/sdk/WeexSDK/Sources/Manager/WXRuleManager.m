/**
 * Created by Weex.
 * Copyright (c) 2016, Alibaba, Inc. All rights reserved.
 *
 * This source code is licensed under the Apache Licence 2.0.
 * For the full copyright and license information,please view the LICENSE file in the root directory of this source tree.
 */

#import "WXRuleManager.h"
#import "WXThreadSafeMutableDictionary.h"
#import "WXUtility.h"
#import "WXUtility.h"

@interface WXRuleManager()
@property (nonatomic, strong) WXThreadSafeMutableDictionary *fontStorage;
@end

@implementation WXRuleManager

static WXRuleManager *_sharedInstance = nil;

+ (WXRuleManager *)sharedInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!_sharedInstance) {
            _sharedInstance = [[self alloc] init];
            _sharedInstance.fontStorage = [[WXThreadSafeMutableDictionary alloc] init];
        }
    });
    return _sharedInstance;
}

- (void)addRule:(NSString*)type rule:(NSDictionary *)rule {
    
    if ([type isEqualToString:@"fontFace"] && [rule[@"src"] isKindOfClass:[NSString class]]) {
        if (rule[@"src"] && rule[@"fontFamily"]) {
            NSUInteger start = [rule[@"src"] rangeOfString:@"url('"].location + @"url('".length;
            NSUInteger end  = [rule[@"src"] rangeOfString:@"')" options:NSBackwardsSearch].location;
            if (end <= start) {
                WXLogWarning(@"font url is not specified");
                return;
            }
            NSString *fontSrc = [rule[@"src"] substringWithRange:NSMakeRange(start, end-start)];
            NSMutableDictionary * fontFamily = [self.fontStorage objectForKey:rule[@"fontFamily"]];
            if (fontFamily || fontFamily[fontSrc]) {
                return;
            }
            if (!fontFamily) {
                fontFamily = [NSMutableDictionary dictionary];
            }
            NSURL *fontURL = [NSURL URLWithString:fontSrc];
            [fontFamily setObject:fontSrc forKey:@"src"];
            if ([fontURL isFileURL]) {
                // local font file will be added directly if existed
                if ([WXUtility isFileExist:[fontURL path]]) {
                    [fontFamily setObject:fontURL forKey:@"localSrc"];
                }else {
                    WXLogWarning(@"font file %@ is not exist", fontSrc);
                }
                return;
            }
            // remote font file
            NSString* fontfile = [[WXUtility documentDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@",WX_FONT_DOWNLOAD_DIR,[WXUtility md5:[NSURL URLWithString:fontSrc].path]]];
            if ([WXUtility isFileExist:fontfile]) {
                // if has been cached, load directly
                [fontFamily setObject:[NSURL fileURLWithPath:fontfile] forKey:@"localSrc"];
                [_fontStorage setObject:fontFamily forKey:rule[@"fontFamily"]];
                return;
            }
            
            [_fontStorage setObject:fontFamily forKey:rule[@"fontFamily"]];
            
            __weak typeof(self) weakSelf = self;
            [WXUtility getIconfont:fontURL completion:^(NSURL * _Nonnull url, NSError * _Nullable error) {
                if (!error) {
                    NSMutableDictionary * dictForFontFamily = [weakSelf.fontStorage objectForKey:rule[@"fontFamily"]];
                    [dictForFontFamily setObject:url forKey:@"localSrc"];
                    [weakSelf.fontStorage setObject:url forKey: dictForFontFamily];
                } else {
                    WXLogError(@"load font failed %@",error.description);
                }
            }];
        }
    }
}

- (WXThreadSafeMutableDictionary *)getRule:(NSString *)type {
    
    if ([type isEqualToString:@"fontFace"]) {
        return _fontStorage;
    }
    
    return nil;
}

@end