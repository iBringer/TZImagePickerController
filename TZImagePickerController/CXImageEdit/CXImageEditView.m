//
//  CXImageEditVC.m
//  ImageEditDemo
//
//  Created by zhoujie on 2021/5/31.
//

#import "CXImageEditView.h"
#import "CXCropCase.h"
#import "CXEditModel.h"
#import "CXImageEditConfig.h"
#import "CXCropFunctionBar.h"
#import "TZImagePickerController.h"

#define kAlphaAnimationDuration 0.15

#define CXBottomToolHeight 44

#define kCropScale (CGFloat)(1.0 - (30 / kScreenWidth))

@interface CXImageEditView ()<UIScrollViewDelegate>
//用于处理缩放
@property(nonatomic, strong) UIScrollView *scrollVi;
//需要编辑的图片
@property(nonatomic, strong) UIImageView *editIgv;
//适配后的图片大小
@property(nonatomic, assign) CGSize editImageSize;
//图片横竖向
@property(nonatomic, assign) BOOL isHorizontal;

@property(nonatomic, strong) UIView *editIgvContainer;

//剪裁功能底部按钮
@property(nonatomic, strong) CXCropFunctionBar *cropFunctionBar;
//是否为编辑模式
@property(nonatomic, assign) BOOL isEditMode;
//剪裁框
@property(nonatomic, strong) CXCropCase *cropCase;

@property(nonatomic, strong) CXEditModel *editModel;
//记录scroll初始化的scale
@property(nonatomic, assign) CGFloat initialZoomScale;
//记录开始剪裁之前的旋转方向
@property(nonatomic, assign) CXCropViewRotationDirection directionBeforeCrop;

@property(nonatomic, assign) CATransform3D scrollInitialTransform;
@end

@implementation CXImageEditView

- (void)dealloc {
    NSLog(@"CXImageEditVC - dealloc");
}

- (instancetype)initWithEditImage:(UIImage *)image {
    if (self = [super initWithFrame:CGRectZero]) {
        self.frame = CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, UIScreen.mainScreen.bounds.size.height);
        [self configUI];
        self.editImage = image;
        
        //进入编辑模式
        [self _changeScrollIntoCropMode];
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

#pragma mark ********* SetUp *********
- (void)configUI {
    self.backgroundColor = [UIColor blackColor];
    
    //初始化记录编辑操作的model
    _editModel = [CXEditModel new];
    
    //默认非编辑模式
    _isEditMode = NO;
    
    //初始化scrollView
    self.scrollVi.bounds = CGRectMake(0, 0, kScreenHeight, kScreenHeight);
    self.scrollVi.center = CGPointMake(kScreenWidth / 2, kScreenHeight / 2);
    [self addSubview:self.scrollVi];
    _scrollInitialTransform = self.scrollVi.layer.transform;
    
    self.editIgvContainer = [UIView new];
    [self.editIgvContainer addSubview:self.editIgv];
    [self.scrollVi addSubview:self.editIgvContainer];
    
    //初始化工具栏
    
    [self addSubview:self.cropFunctionBar];
}

- (CXCropFunctionBar *)cropFunctionBar {
    if (!_cropFunctionBar) {
        CGFloat w = [UIScreen mainScreen].bounds.size.width;
        CGFloat h = 44 + [TZCommonTools tz_safeAreaInsets].bottom;
        CGFloat y = [UIScreen mainScreen].bounds.size.height - h;
        _cropFunctionBar = [[CXCropFunctionBar alloc] initWithFrame:CGRectMake(0, y, w, h)];
    }
    return _cropFunctionBar;
}

- (void)setEditImage:(UIImage *)editImage {
    _editImage = [self _compressHDImage:editImage];
    
    self.scrollVi.minimumZoomScale = kMinZoomScale;
    self.scrollVi.maximumZoomScale = kMaxZoomScale;
    self.scrollVi.zoomScale = 1;
    self.initialZoomScale = self.scrollVi.zoomScale;
    
    //计算图片适配后的大小
    [self _caculateImageSize];
    self.editIgvContainer.transform = CGAffineTransformIdentity;
    self.editIgvContainer.frame = CGRectMake(0, 0, _editImageSize.width, _editImageSize.height);
    self.editIgvContainer.layer.mask = nil;
    self.editIgv.image = _editImage;
    self.editIgv.frame = CGRectMake(0, 0, _editImageSize.width, _editImageSize.height);
    
    //设置contentSize
    self.scrollVi.contentSize = _editImageSize;
    //调整inset使图片居中显示
    [self _adjustEditImageViewToCenter];
}

#pragma mark ********* UIScrollViewDelegate *********
- (nullable UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.editIgvContainer;
}

//调整inset保证图片缩放后居中
- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    
    if (_editModel.cropModel && !_isEditMode) {
        [self _updateContentInsetAfterCrop];
        return;
    }
    
    //剪裁模式不在此方法调整其contentInset
    if (_isEditMode) {
        return;
    }
    
    //此方法只在编辑初始页调整contentInset使其居中
    if (_isHorizontal) {
        if (self.scrollVi.contentSize.height > kScreenHeight) {
            //图片高大于屏幕高
            self.scrollVi.contentInset = UIEdgeInsetsZero;
        }else {
            //图片高小于屏幕高
            self.scrollVi.contentInset = UIEdgeInsetsMake((self.scrollVi.frame.size.height - self.scrollVi.contentSize.height) / 2, (self.scrollVi.frame.size.width - kScreenWidth) / 2, (self.scrollVi.frame.size.height - self.scrollVi.contentSize.height) / 2, (self.scrollVi.frame.size.width - kScreenWidth) / 2);
        }
    } else {
        if (self.scrollVi.contentSize.width > kScreenWidth) {
            //图片宽大于屏幕宽
            self.scrollVi.contentInset = UIEdgeInsetsZero;
        } else {
            //图片宽小于屏幕宽
            self.scrollVi.contentInset = UIEdgeInsetsMake((self.scrollVi.frame.size.height - kScreenHeight) / 2, (self.scrollVi.frame.size.width - self.scrollVi.contentSize.width) / 2  , (self.scrollVi.frame.size.height - kScreenHeight) / 2, (self.scrollVi.frame.size.width - self.scrollVi.contentSize.width) / 2);
        }
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    NSLog(@"scrollViewWillBeginDragging");
    [self.cropCase beginImageresizer];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    NSLog(@"scrollViewDidEndDecelerating");
    [self.cropCase endedImageresizer];
}

//结束拖动后无加速度
- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    if (CGPointEqualToPoint(velocity, CGPointZero)) {
        NSLog(@"scrollViewWillEndDragging");
        [self.cropCase endedImageresizer];
    }
}

- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(nullable UIView *)view {
    NSLog(@"scrollViewWillBeginZooming");
    [self.cropCase beginImageresizer];
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(CGFloat)scale {
    NSLog(@"scrollViewDidEndZooming");
    [self.cropCase endedImageresizer];
}

#pragma mark ********* CropButtonClicked *********
//进入编辑模式
- (void)_changeScrollIntoCropMode {
    
    _isEditMode = YES;
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    if (_editModel.cropModel) {
        _directionBeforeCrop = _editModel.cropModel.rotationDirection;
        //曾经编辑过
        //缩小scroll的倍数
        CGFloat cropScale = self.initialZoomScale * [self _caculateCropImageScale];
        if (cropScale < self.scrollVi.minimumZoomScale) {
            self.scrollVi.minimumZoomScale = cropScale;
        }
        
        UIViewAnimationOptions options = UIViewAnimationOptionCurveLinear | UIViewAnimationOptionBeginFromCurrentState;
        [UIView animateWithDuration:0.25 delay:0 options:options animations:^{
            [self.scrollVi setZoomScale:cropScale animated:NO];
            self.editIgvContainer.layer.mask = nil;
            self.scrollVi.contentInset = self.editModel.cropModel.contentInset;
            self.scrollVi.contentOffset = self.editModel.cropModel.contentOffset;
            //[self _adjustEditImageViewToCenter];
        } completion:^(BOOL finished) {
            self.cropCase = [[CXCropCase alloc]initWithFrame:self.scrollVi.frame scrollVi:self.scrollVi imageView:self.editIgv cropModel:self.editModel.cropModel cropScale:[self _caculateCropImageScale]];
            [self insertSubview:self.cropCase belowSubview:self.cropFunctionBar];
        }];
        
    } else {
        _directionBeforeCrop = CXCropViewRotationDirectionUp;
        //未编辑过
        //缩小scroll的倍数
        CGFloat cropScale = self.initialZoomScale * [self _caculateCropImageScale];
        if (cropScale < self.scrollVi.minimumZoomScale) {
            self.scrollVi.minimumZoomScale = cropScale;
        }
        
        UIViewAnimationOptions options = UIViewAnimationOptionCurveLinear | UIViewAnimationOptionBeginFromCurrentState;
        [UIView animateWithDuration:0.25 delay:0 options:options animations:^{
            [self.scrollVi setZoomScale:cropScale animated:NO];
            [self _adjustEditImageViewToCenter];
        } completion:^(BOOL finished) {
            self.cropCase = [[CXCropCase alloc]initWithFrame:self.scrollVi.frame scrollVi:self.scrollVi imageView:self.editIgv cropScale:[self _caculateCropImageScale]];
            [self insertSubview:self.cropCase belowSubview:self.cropFunctionBar];
        }];
    }
}

- (void)_afterCropAdjustScrollWithEditedImage:(UIImage *)editedImage {
    //_editImage = editedImage;
    CGFloat editScale = self.editModel.cropModel.zoomScale;
    //放大动画
    CGFloat scale = 1 / [self _caculateCropImageScale];
    scale *= editScale;
    self.scrollVi.minimumZoomScale = scale;
    if (scale > self.scrollVi.maximumZoomScale) {
        self.scrollVi.maximumZoomScale = scale;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIViewAnimationOptions options = UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState;
        [UIView animateWithDuration:0.25 delay:0 options:options animations:^{
            [self.scrollVi setZoomScale:scale animated:NO];
            [self _updateContentInsetAfterCrop];
        } completion:^(BOOL finished) {
            self.initialZoomScale = self.scrollVi.zoomScale;
        }];
    });
    
}

#pragma mark ********* EventResponse *********
//点击图片
- (void)clickEditImage {
    if (_isEditMode) {
        return;
    }
}

//点击返回
- (void)clickBack {
    //清除编辑操作
    _editModel.words = nil;
    _editModel.cropModel = nil;
    self.scrollVi.layer.transform = CATransform3DIdentity;
    
    if (self.customBackAction) {
        self.customBackAction();
        return;
    }
    [self removeFromSuperview];
}

#pragma mark ********* Router *********
- (void)routerWithEventName:(NSString *)eventName DataInfo:(NSDictionary *)dataInfo {
    //点击了剪裁功能的取消按钮
    if ([eventName isEqualToString:kCXCropFunctionBar_CloseBtn_Clicked]) {
        //退出编辑模式
        _isEditMode = NO;
        [self.cropCase cancelDelayHandle];
        [self.cropCase removeFromSuperview];
        self.cropCase = nil;
        [self clickBack];
        return;
    }
    
    //点击剪裁功能的还原按钮
    if ([eventName isEqualToString:kCXCropFunctionBar_RecoveryBtn_Clicked]) {
        [self.cropCase recovery];
        return;
    }
    
    //剪裁工具栏的还原按钮是否能点击
    if ([eventName isEqualToString:kCXCropCase_IsCanRecovery]) {
        BOOL isCanRecovery = [dataInfo[@"isCanRecovery"] boolValue];
        [self.cropFunctionBar isCanRecovery:isCanRecovery];
        return;
    }
    
    //点击剪裁功能的旋转按钮
    if ([eventName isEqualToString:kCXCropFunctionBar_RotationBtn_Clicked]) {
        [self.cropCase rotation];
        return;
    }
    
    //点击了剪裁功能的完成按钮
    if ([eventName isEqualToString:kCXCropFunctionBar_FinishBtn_Clicked]) {
        __weak typeof(self) weakSelf = self;
        [self.cropCase cropImageWithComplete:^(UIImage * _Nonnull image, CXCropModel *cropModel) {
            weakSelf.editModel.cropModel = cropModel;
            //退出编辑模式
            weakSelf.isEditMode = NO;
            [self.cropCase cancelDelayHandle];
            [weakSelf.cropCase removeFromSuperview];
            weakSelf.cropCase = nil;
            
            [weakSelf _afterCropAdjustScrollWithEditedImage:image];
            
            UIImage *result;
            if (!weakSelf.editModel.cropModel) {
                //没有编辑过
                result = weakSelf.editImage;
            } else {
                //编辑过
                result = [weakSelf _generateImage];
            }
            if (weakSelf.completeEdit) {
                weakSelf.completeEdit(result);
            }
        }];
        return;
    }
    [super routerWithEventName:eventName DataInfo:dataInfo];
}

#pragma mark ********* WordGesture *********
//计算当前展示图片部分的中心
- (CGPoint)_caculateEditIgvCenter {
    CGPoint center = CGPointZero;
    if (_editModel.cropModel) {
        CGFloat x = self.editIgv.frame.origin.x;
        CGFloat y = self.editIgv.frame.origin.y;
        CGFloat width = self.editIgv.frame.size.width;
        CGFloat height = self.editIgv.frame.size.height;
        CGFloat horizontalShowRatio = 1 - _editModel.cropModel.cropToImagePercentEdge.left - _editModel.cropModel.cropToImagePercentEdge.right;
        CGFloat verticalShowRatio = 1 - _editModel.cropModel.cropToImagePercentEdge.top - _editModel.cropModel.cropToImagePercentEdge.bottom;
        CGFloat showWidth = width * horizontalShowRatio;
        CGFloat showHeight = height * verticalShowRatio;
        CGFloat showX = width * _editModel.cropModel.cropToImagePercentEdge.left + x;
        CGFloat showY = height * _editModel.cropModel.cropToImagePercentEdge.top + y;
        CGRect showRect = CGRectMake(showX, showY, showWidth, showHeight);
        center = CGPointMake(CGRectGetMidX(showRect), CGRectGetMidY(showRect));
    } else {
        center = self.editIgv.center;
    }
    return center;
}

#pragma mark ********* PublicMethod *********
- (void)clearAllEditHandle {
    //清除编辑操作
    [_editModel.words removeAllObjects];
    _editModel.cropModel = nil;
    self.scrollVi.layer.transform = CATransform3DIdentity;
}

#pragma mark ********* PrivateMethod *********
//计算当前图片适配后占比屏幕的缩放比
- (CGFloat)_caculateCropImageScale {
    
    NSLog(@"%s",__FUNCTION__);
    NSLog(@"----CGRectGetHeight(self.editIgv.frame) = %.f----",CGRectGetHeight(self.editIgv.frame));
    if (CGRectGetHeight(self.editIgv.frame) + CXBottomToolHeight < kScreenHeight) {
        return kCropScale;
    }
    
    return 0.7;
}

//计算图片适配后大小
- (void)_caculateImageSize {
    if (!_editImage) return;
    CGFloat imageWidth = _editImage.size.width;
    CGFloat imageHeight = _editImage.size.height;
    CGFloat screenRatio = kScreenWidth / kScreenHeight;
    CGFloat imageRatio = imageWidth / imageHeight;
    _isHorizontal = (imageRatio >= screenRatio);
    if (_isHorizontal) {
        _editImageSize = CGSizeMake(kScreenWidth, imageHeight * (kScreenWidth / imageWidth));
    }else {
        _editImageSize = CGSizeMake(imageWidth * (kScreenHeight / imageHeight), kScreenHeight);
    }
}

//生成合成图片
- (UIImage *)_generateImage {
    CGFloat scale = _editImage.size.width / _editIgv.frame.size.width;
    NSInteger imageWidth = floor(self.editIgv.frame.size.width);
    NSInteger imageHeight = floor(self.editIgv.frame.size.height);
    CGSize contextSize = CGSizeMake(imageWidth, imageHeight);
    UIGraphicsBeginImageContextWithOptions(contextSize, NO, scale);
    [self.editIgvContainer.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *resultImg = UIGraphicsGetImageFromCurrentImageContext();
    CGRect cropRect;
    if (_editModel.cropModel) {
        CGFloat x = resultImg.size.width * resultImg.scale * _editModel.cropModel.cropToImagePercentEdge.left;
        CGFloat y = resultImg.size.height * resultImg.scale * _editModel.cropModel.cropToImagePercentEdge.top;
        CGFloat width = resultImg.size.width * resultImg.scale * (1 - _editModel.cropModel.cropToImagePercentEdge.left - _editModel.cropModel.cropToImagePercentEdge.right);
        CGFloat height = resultImg.size.height * resultImg.scale * (1 - _editModel.cropModel.cropToImagePercentEdge.top - _editModel.cropModel.cropToImagePercentEdge.bottom);
        cropRect = CGRectMake(x, y, width, height);
    } else {
        cropRect = CGRectMake(0, 0, resultImg.size.width * resultImg.scale, resultImg.size.height * resultImg.scale);
    }
    
    CGImageRef imageRefRect = CGImageCreateWithImageInRect(resultImg.CGImage, cropRect);
    UIImage *sendImage = [[UIImage alloc] initWithCGImage:imageRefRect];
    if (_editModel.cropModel) {
        sendImage = [self _getTargetDirectionImage:sendImage];
    }
    CGImageRelease(imageRefRect);
    UIGraphicsEndImageContext();
    return sendImage;
}

//根据方向获取正确的图片
- (UIImage *)_getTargetDirectionImage:(UIImage *)image {
    UIImageOrientation orientation;
    switch (_editModel.cropModel.rotationDirection) {
        case CXCropViewRotationDirectionLeft:
            orientation = UIImageOrientationLeft;
            break;
            
        case CXCropViewRotationDirectionDown:
            orientation = UIImageOrientationDown;
            break;
            
        case CXCropViewRotationDirectionRight:
            orientation = UIImageOrientationRight;
            break;
            
        default:
            orientation = UIImageOrientationUp;
            break;
    }
    return [UIImage imageWithCGImage:image.CGImage scale:image.scale orientation:orientation];
}

//生成全屏的合成图片
- (UIImage *)_generateFullScreenImage {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(kScreenWidth, kScreenHeight), YES, 0);
    CGSize imageSize = self.editIgv.bounds.size;
    CGFloat x = (kScreenWidth - imageSize.width) / 2;
    CGFloat y = (kScreenHeight - imageSize.height) / 2;
    [self.editIgv drawViewHierarchyInRect:CGRectMake(x, y, imageSize.width, imageSize.height) afterScreenUpdates:YES];
    UIImage *resultImg = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return resultImg;
}

//将图片调整至居中
- (void)_adjustEditImageViewToCenter {
    self.scrollVi.contentInset = UIEdgeInsetsMake((CGRectGetHeight(self.scrollVi.frame) - CGRectGetHeight(self.editIgvContainer.frame)) / 2,
                                                  (CGRectGetWidth(self.scrollVi.frame) - CGRectGetWidth(self.editIgvContainer.frame)) / 2,
                                                  (CGRectGetHeight(self.scrollVi.frame) - CGRectGetHeight(self.editIgvContainer.frame)) / 2,
                                                  (CGRectGetWidth(self.scrollVi.frame) - CGRectGetWidth(self.editIgvContainer.frame)) / 2);
}

//根据剪裁框来更新scroll的内间距
- (void)_updateContentInsetAfterCrop {
    CGFloat showWidth = CGRectGetWidth(self.editIgvContainer.frame) * (1 - _editModel.cropModel.cropToImagePercentEdge.left - _editModel.cropModel.cropToImagePercentEdge.right);
    CGFloat showHeight = CGRectGetHeight(self.editIgvContainer.frame) * (1 - _editModel.cropModel.cropToImagePercentEdge.top - _editModel.cropModel.cropToImagePercentEdge.bottom);
    CGFloat left = (CGRectGetWidth(self.scrollVi.frame) - showWidth) / 2 - _editModel.cropModel.cropToImagePercentEdge.left * CGRectGetWidth(self.editIgvContainer.frame);
    CGFloat right = (CGRectGetWidth(self.scrollVi.frame) - showWidth) / 2 - _editModel.cropModel.cropToImagePercentEdge.right * CGRectGetWidth(self.editIgvContainer.frame);
    //超出屏幕部分可滑动
    if (showWidth > kScreenWidth) {
        CGFloat shouldMoveSpacing = (showWidth - kScreenWidth) * 0.5;
        left += shouldMoveSpacing;
        right+= shouldMoveSpacing;
    }
    CGFloat top = (CGRectGetHeight(self.scrollVi.frame) - showHeight) / 2 - _editModel.cropModel.cropToImagePercentEdge.top * CGRectGetHeight(self.editIgvContainer.frame);
    CGFloat bottom = (CGRectGetHeight(self.scrollVi.frame) - showHeight) / 2 - _editModel.cropModel.cropToImagePercentEdge.bottom * CGRectGetHeight(self.editIgvContainer.frame);
    //超出屏幕部分可滑动
    if (showHeight > kScreenHeight) {
        CGFloat shouldMoveSpacing = (showHeight - kScreenHeight) * 0.5;
        top += shouldMoveSpacing;
        bottom+= shouldMoveSpacing;
    }
    UIEdgeInsets contentInset = UIEdgeInsetsMake(top, left, bottom, right);
    self.scrollVi.contentInset = contentInset;
}

//压缩高清图片
- (UIImage *)_compressHDImage:(UIImage *)image {
    if (image.size.width < 5000 && image.size.height < 5000) {
        return image;
    }
    CGFloat imageRatio = image.size.width / image.size.height;
    CGFloat width = 1024;
    CGFloat height = 1024 / imageRatio;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, height), YES, 0);
    [image drawInRect:CGRectMake(0, 0, width, height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

- (void)_rotationScrollWithDiretion:(CXCropViewRotationDirection)direction {
    CGFloat scale = 0;
    if (direction == CXCropViewRotationDirectionLeft ||
        direction == CXCropViewRotationDirectionRight) {
        scale = kScreenWidth / self.scrollVi.bounds.size.height;
    }else {
        scale = self.scrollVi.bounds.size.height / kScreenWidth;
    }
    CGFloat angle = -M_PI / 2;
    
    switch (direction) {
        case CXCropViewRotationDirectionUp:
            angle = 0;
            break;
        case CXCropViewRotationDirectionLeft:
            angle = -M_PI / 2;
            break;
        case CXCropViewRotationDirectionDown:
            angle = -M_PI;
            break;
        case CXCropViewRotationDirectionRight:
            angle = -3 * M_PI / 2;
            break;
            
        default:
            break;
    }
    
    UIViewAnimationOptions options = UIViewAnimationOptionCurveLinear | UIViewAnimationOptionBeginFromCurrentState;
    [UIView animateWithDuration:0.25 delay:0 options:options animations:^{
        self.scrollVi.layer.transform = CATransform3DRotate(self.scrollInitialTransform, angle, 0, 0, 1);
    } completion:^(BOOL finished) {
        
    }];
}

//更新editIgvContainer的遮罩
- (void)_updateImageContainerMaskLayer {
    CAShapeLayer *layer = [CAShapeLayer layer];
    UIBezierPath *path;
    if (_editModel.cropModel) {
        //剪裁过
        path = [UIBezierPath bezierPathWithRect:self.editIgvContainer.bounds];
    }else {
        //没有剪裁过
        path = [UIBezierPath bezierPathWithRect:self.editIgvContainer.bounds];
    }
    layer.path = path.CGPath;
    self.editIgvContainer.layer.mask = layer;
}

#pragma mark ********* Getter *********
- (UIScrollView *)scrollVi {
    if (!_scrollVi) {
        _scrollVi = [[UIScrollView alloc]init];
        _scrollVi.delegate = self;
        _scrollVi.maximumZoomScale = 4.0;
        _scrollVi.minimumZoomScale = 1;
        _scrollVi.showsVerticalScrollIndicator = NO;
        _scrollVi.showsHorizontalScrollIndicator = NO;
        if (@available(iOS 11.0, *)) {
            _scrollVi.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        }
    }
    return _scrollVi;
}

- (UIImageView *)editIgv {
    if (!_editIgv) {
        _editIgv = [UIImageView new];
        _editIgv.contentMode = UIViewContentModeScaleAspectFit;
        _editIgv.userInteractionEnabled = YES;
        _editIgv.clipsToBounds = YES;
    }
    return _editIgv;
}

@end
