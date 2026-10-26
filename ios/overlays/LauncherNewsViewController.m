#import "LauncherNewsViewController.h"
#import "LauncherProfilesViewController.h"
#import "LauncherPreferencesViewController.h"
#import "installer/ModpackInstallViewController.h"
#import "LauncherMenuViewController.h"
#import "ios_uikit_bridge.h"
#import "utils.h"

@implementation LauncherNewsViewController
- (instancetype)init {self=[super init];if(self)self.title=@"GCL";return self;}
- (NSString *)imageName {return @"MenuNews";}
- (void)viewDidLoad {
    [super viewDidLoad];self.view.backgroundColor=UIColor.systemGroupedBackgroundColor;
    UIScrollView *scroll=[UIScrollView new];scroll.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:scroll];
    UIStackView *stack=[UIStackView new];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=20;stack.translatesAutoresizingMaskIntoConstraints=NO;[scroll addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[[scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],[scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],[scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],[scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],[stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:28],[stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-28],[stack.leadingAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.leadingAnchor constant:24],[stack.trailingAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.trailingAnchor constant:-24]]];
    UIImageView *icon=[[UIImageView alloc]initWithImage:[UIImage imageNamed:@"GCLIcon.png"]];icon.contentMode=UIViewContentModeScaleAspectFit;[icon.heightAnchor constraintEqualToConstant:94].active=YES;[stack addArrangedSubview:icon];
    UILabel *heading=[self label:@"你的世界，\n从这里开始。" size:34 weight:UIFontWeightBold];[stack addArrangedSubview:heading];
    [stack addArrangedSubview:[self label:@"GCL 0.3.0 · iPhone / iPad 开发版\nJava 游戏引擎基于 Amethyst / Pojav 开源组件。" size:14 weight:UIFontWeightRegular]];
    NSArray *titles=@[@"游戏版本与实例",@"下载模组与整合包",@"启动与控制设置"];
    NSArray *symbols=@[@"square.stack.3d.up.fill",@"shippingbox.fill",@"slider.horizontal.3"];
    for(NSInteger i=0;i<titles.count;i++){
        UIBlurEffect *effect=[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];UIVisualEffectView *card=[[UIVisualEffectView alloc]initWithEffect:effect];card.layer.cornerRadius=25;card.clipsToBounds=YES;
        if(@available(iOS 26.0,*)){UIGlassEffect *glass=[UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular];glass.interactive=YES;card.effect=glass;}
        UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];button.translatesAutoresizingMaskIntoConstraints=NO;button.tag=i;[button setTitle:titles[i] forState:UIControlStateNormal];[button setImage:[UIImage systemImageNamed:symbols[i]] forState:UIControlStateNormal];button.tintColor=UIColor.systemBlueColor;button.titleLabel.font=[UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];[button addTarget:self action:@selector(openCard:) forControlEvents:UIControlEventTouchUpInside];[card.contentView addSubview:button];
        [NSLayoutConstraint activateConstraints:@[[button.leadingAnchor constraintEqualToAnchor:card.contentView.leadingAnchor constant:18],[button.trailingAnchor constraintEqualToAnchor:card.contentView.trailingAnchor constant:-18],[button.topAnchor constraintEqualToAnchor:card.contentView.topAnchor constant:18],[button.bottomAnchor constraintEqualToAnchor:card.contentView.bottomAnchor constant:-18],[card.heightAnchor constraintGreaterThanOrEqualToConstant:76]]];[stack addArrangedSubview:card];
    }
    [stack addArrangedSubview:[self label:@"启动前需完成侧载签名，并按设备条件启用 JIT。\n游戏版本、Java、渲染器和设备内存需要匹配；不是 App Store 安装包，也不保证任意设备可运行。\n\n在底部选择版本并点 Play。旧版游戏、Forge 与不同整合包的兼容性取决于底层引擎，尚未完成真机验证。\n\nGCL · Aaron-CNSD\nGPL-3.0 · 底层及第三方许可见应用内 GCL-LICENSES 与源码仓库。" size:13 weight:UIFontWeightRegular]];
    self.navigationItem.leftBarButtonItem=self.splitViewController.displayModeButtonItem;self.navigationItem.leftItemsSupplementBackButton=YES;self.navigationItem.rightBarButtonItem=[sidebarViewController drawAccountButton];
}
- (UILabel *)label:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight {UILabel *label=[UILabel new];label.text=text;label.numberOfLines=0;label.font=[UIFont systemFontOfSize:size weight:weight];label.textColor=UIColor.labelColor;return label;}
- (void)openCard:(UIButton *)sender {UIViewController *controller=sender.tag==0?[LauncherProfilesViewController new]:sender.tag==1?[ModpackInstallViewController new]:[LauncherPreferencesViewController new];[self.navigationController pushViewController:controller animated:!UIAccessibilityIsReduceMotionEnabled()];}
@end
