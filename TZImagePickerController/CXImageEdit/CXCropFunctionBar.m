//
//  CXCropFunctionBar.m
//  chengxun
//
//  Created by zhoujie on 2021/8/5.
//

#import "CXCropFunctionBar.h"
#import "CXImageEditConfig.h"
#import "TZImagePickerController/TZImagePickerController.h"

@interface CXCropFunctionBar()

@property(nonatomic, strong) UIView *container;
//关闭按钮
@property(nonatomic, strong) UIButton *closeBtn;
//还原按钮
@property(nonatomic, strong) UIButton *restoreBtn;
//完成按钮
@property(nonatomic, strong) UIButton *finishBtn;
//旋转按钮
@property(nonatomic, strong) UIButton *rotateBtn;

@end

@implementation CXCropFunctionBar

- (instancetype)init {
    self = [super init];
    if (self) {
        [self configUI];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self configUI];
    }
    return self;
}

//初始化底部功能按钮
- (void)configUI {
    //[TZCommonTools tz_safeAreaInsets].bottom
    _container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, 44)];
    [self addSubview:self.container];
    
    UIView *topLine = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, 1)];
    topLine.backgroundColor = CXUIColorFromRGBA(0xFFFFFF, 0.2);
    [self addSubview:topLine];
    
    //关闭
    _closeBtn = [self buttonWithImageName:@"crop_close" action:@selector(clickClose)];
    //还原
    _restoreBtn = [self buttonWithImageName:@"crop_restore" action:@selector(clickRestore)];
    _restoreBtn.alpha = 0.4;
    _restoreBtn.enabled = NO;
    _restoreBtn.titleLabel.textColor = [UIColor whiteColor];
    //旋转
    _rotateBtn = [self buttonWithImageName:@"crop_rotate" action:@selector(clickRotate)];
    //完成
    _finishBtn = [self buttonWithImageName:@"crop_finish" action:@selector(clickFinish)];
    
    CGFloat top = 10;
    CGFloat wh = 24;
    CGFloat space = (kScreenWidth - 24 * 2 - wh * 4) / 3;
    _closeBtn.frame = CGRectMake(24, top, wh, wh);
    _restoreBtn.frame = CGRectMake(CGRectGetMaxX(_closeBtn.frame) + space, top, wh, wh);
    _rotateBtn.frame = CGRectMake(CGRectGetMaxX(_restoreBtn.frame) + space, top, wh, wh);
    _finishBtn.frame = CGRectMake(CGRectGetMaxX(_rotateBtn.frame) + space, top, wh, wh);
    
    [_container addSubview:_closeBtn];
    [_container addSubview:_restoreBtn];
    [_container addSubview:_rotateBtn];
    [_container addSubview:_finishBtn];
}

- (UIButton *)buttonWithImageName:(NSString *)imageName action:(SEL)action {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn setImage:[UIImage tz_imageNamedFromMyBundle:imageName] forState:UIControlStateNormal];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

#pragma mark ********* EventResponse *********
//关闭
- (void)clickClose {
    [self hide];
    [self routerWithEventName:kCXCropFunctionBar_CloseBtn_Clicked DataInfo:nil];
}

//还原
- (void)clickRestore {
    [self routerWithEventName:kCXCropFunctionBar_RecoveryBtn_Clicked DataInfo:nil];
    _restoreBtn.enabled = NO;
    _restoreBtn.alpha = 0.4;
}

//完成
- (void)clickFinish {
    [self hide];
    [self routerWithEventName:kCXCropFunctionBar_FinishBtn_Clicked DataInfo:nil];
}

//旋转
- (void)clickRotate {
    [self routerWithEventName:kCXCropFunctionBar_RotationBtn_Clicked DataInfo:nil];
}

- (void)isCanRecovery:(BOOL)isCanRecovery {
    self.restoreBtn.enabled = isCanRecovery ? YES : NO;
    self.restoreBtn.alpha = isCanRecovery ? 1.0 : 0.4;
}

- (void)show {
    self.alpha = 0;
    UIViewAnimationOptions options = UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveLinear;
    [UIView animateWithDuration:0.25 delay:0 options:options animations:^{
        self.alpha = 1;
    } completion:^(BOOL finished) {
        
    }];
}

- (void)hide {
    [self isCanRecovery:NO];
    self.alpha = 1;
    UIViewAnimationOptions options = UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveLinear;
    [UIView animateWithDuration:0.25 delay:0 options:options animations:^{
        self.alpha = 0;
    } completion:^(BOOL finished) {
        
    }];
}

@end
