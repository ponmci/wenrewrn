// Executor.mm - Simple UI for the script executor
// Uses native UIKit (no ImGui dependency needed for basic version)

#import "Executor.h"
#import "LuaVMHook.h"
#import <UIKit/UIKit.h>

static NSMutableArray *outputLog = nil;
static BOOL menuVisible = NO;
static UIWindow *overlayWindow = nil;

// ============================================================
// EXECUTOR VIEW CONTROLLER
// ============================================================

@interface ExecutorViewController : UIViewController <UITextViewDelegate>
@property (nonatomic, strong) UITextView *scriptEditor;
@property (nonatomic, strong) UITextView *outputView;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation ExecutorViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];

    // Title bar
    UIView *titleBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 44)];
    titleBar.backgroundColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.2 alpha:1.0];
    [self.view addSubview:titleBar];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 200, 24)];
    titleLabel.text = @"Roblox Executor";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [titleBar addSubview:titleLabel];

    // Close button
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(self.view.frame.size.width - 50, 8, 40, 28);
    [closeBtn setTitle:@"X" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [closeBtn addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
    [titleBar addSubview:closeBtn];

    // Script editor
    UILabel *editorLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 54, 100, 20)];
    editorLabel.text = @"Script:";
    editorLabel.textColor = [UIColor cyanColor];
    editorLabel.font = [UIFont systemFontOfSize:12];
    [self.view addSubview:editorLabel];

    CGFloat editorY = 76;
    self.scriptEditor = [[UITextView alloc] initWithFrame:CGRectMake(10, editorY,
        self.view.frame.size.width - 20, self.view.frame.size.height * 0.4)];
    self.scriptEditor.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.15 alpha:1.0];
    self.scriptEditor.textColor = [UIColor greenColor];
    self.scriptEditor.font = [UIFont fontWithName:@"Menlo" size:13];
    self.scriptEditor.layer.borderColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.4 alpha:1.0].CGColor;
    self.scriptEditor.layer.borderWidth = 1.0;
    self.scriptEditor.autocorrectionType = UITextAutocorrectionTypeNo;
    self.scriptEditor.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.scriptEditor.text = @"-- Roblox Executor\n-- Write your Lua script here\n\nprint(\"Hello from executor!\")\n\n-- Example: WalkSpeed\nlocal p = game:GetService(\"Players\").LocalPlayer\nif p and p.Character then\n    local h = p.Character:FindFirstChild(\"Humanoid\")\n    if h then\n        h.WalkSpeed = 100\n        print(\"WalkSpeed set to 100\")\n    end\nend\n";
    [self.view addSubview:self.scriptEditor];

    // Buttons
    CGFloat btnY = editorY + self.view.frame.size.height * 0.4 + 8;
    UIButton *execBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    execBtn.frame = CGRectMake(10, btnY, 120, 36);
    [execBtn setTitle:@"Execute" forState:UIControlStateNormal];
    [execBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    execBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.2 alpha:1.0];
    execBtn.layer.cornerRadius = 5;
    [execBtn addTarget:self action:@selector(executeScript) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:execBtn];

    UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    clearBtn.frame = CGRectMake(140, btnY, 120, 36);
    [clearBtn setTitle:@"Clear Output" forState:UIControlStateNormal];
    [clearBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    clearBtn.backgroundColor = [UIColor colorWithRed:0.6 green:0.3 blue:0.2 alpha:1.0];
    clearBtn.layer.cornerRadius = 5;
    [clearBtn addTarget:self action:@selector(clearOutput) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:clearBtn];

    // Status
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(270, btnY + 8, 50, 20)];
    self.statusLabel.text = @"Ready";
    self.statusLabel.textColor = [UIColor grayColor];
    self.statusLabel.font = [UIFont systemFontOfSize:11];
    [self.view addSubview:self.statusLabel];

    // Output
    UILabel *outputLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, btnY + 44, 100, 20)];
    outputLabel.text = @"Output:";
    outputLabel.textColor = [UIColor cyanColor];
    outputLabel.font = [UIFont systemFontOfSize:12];
    [self.view addSubview:outputLabel];

    CGFloat outputY = btnY + 66;
    self.outputView = [[UITextView alloc] initWithFrame:CGRectMake(10, outputY,
        self.view.frame.size.width - 20, self.view.frame.size.height - outputY - 10)];
    self.outputView.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.08 alpha:1.0];
    self.outputView.textColor = [UIColor lightGrayColor];
    self.outputView.font = [UIFont fontWithName:@"Menlo" size:11];
    self.outputView.editable = NO;
    self.outputView.layer.borderColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.3 alpha:1.0].CGColor;
    self.outputView.layer.borderWidth = 1.0;
    [self.view addSubview:self.outputView];

    outputLog = [NSMutableArray array];
    [outputLog addObject:@"[Executor] Initialized"];
    [outputLog addObject:[NSString stringWithFormat:@"[Executor] VM: %@", g_vmFound ? @"Connected" : @"Not found"]];
    [outputLog addObject:[NSString stringWithFormat:@"[Executor] State: %@", g_L ? [NSString stringWithFormat:@"%p", g_L] : @"None"]];
}

- (void)executeScript {
    NSString *script = self.scriptEditor.text;
    if (!script || script.length == 0) return;

    [outputLog addObject:@"[Executor] Executing script..."];
    [self updateOutput];

    self.statusLabel.text = @"Running...";
    self.statusLabel.textColor = [UIColor yellowColor];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int result = ExecuteScript(script.UTF8String, "@executor");

        dispatch_async(dispatch_get_main_queue(), ^{
            if (result == 0) {
                [outputLog addObject:@"[Executor] Script executed successfully"];
                self.statusLabel.text = @"Success";
                self.statusLabel.textColor = [UIColor greenColor];
            } else {
                [outputLog addObject:[NSString stringWithFormat:@"[Executor] Script failed: %d", result]];
                self.statusLabel.text = @"Failed";
                self.statusLabel.textColor = [UIColor redColor];
            }
            [self updateOutput];
        });
    });
}

- (void)clearOutput {
    [outputLog removeAllObjects];
    [outputLog addObject:@"[Executor] Output cleared"];
    [self updateOutput];
}

- (void)updateOutput {
    self.outputView.text = [outputLog componentsJoinedByString:@"\n"];
    [self.outputView scrollRangeToVisible:NSMakeRange(self.outputView.text.length, 0)];
}

- (void)closeMenu {
    menuVisible = NO;
    overlayWindow.hidden = YES;
}

@end

// ============================================================
// FLOATING BUTTON
// ============================================================

static UIButton *floatingBtn = nil;

void ToggleExecutorMenu() {
    if (menuVisible) {
        overlayWindow.hidden = YES;
        menuVisible = NO;
    } else {
        overlayWindow.hidden = NO;
        menuVisible = YES;
    }
}

static void addButtonToWindow() {
    UIWindow *keyWindow = nil;

    // Find the key window (Roblox's window)
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow) {
            keyWindow = window;
            break;
        }
    }

    if (!keyWindow) {
        keyWindow = [UIApplication sharedApplication].windows.firstObject;
    }

    if (!keyWindow) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        // Floating button
        floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        floatingBtn.frame = CGRectMake(10, 100, 44, 44);
        floatingBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:0.9 alpha:0.9];
        floatingBtn.layer.cornerRadius = 22;
        [floatingBtn setTitle:@"EX" forState:UIControlStateNormal];
        floatingBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        [floatingBtn addTarget:[ExecutorViewController class]
                        action:@selector(toggleMenu)
              forControlEvents:UIControlEventTouchUpInside];

        // Make button draggable
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
            initWithTarget:[ExecutorViewController class] action:@selector(dragButton:)];
        [floatingBtn addGestureRecognizer:pan];

        [keyWindow addSubview:floatingBtn];

        // Overlay window for the executor menu
        overlayWindow = [[UIWindow alloc] initWithFrame:keyWindow.bounds];
        overlayWindow.windowLevel = UIWindowLevelAlert + 100;
        overlayWindow.backgroundColor = [UIColor clearColor];
        overlayWindow.rootViewController = [[ExecutorViewController alloc] init];
        overlayWindow.hidden = YES;
        overlayWindow.clipsToBounds = YES;
    });
}

// Button handlers as class methods
@implementation ExecutorViewController (ButtonHandlers)

+ (void)toggleMenu {
    ToggleExecutorMenu();
}

+ (void)dragButton:(UIPanGestureRecognizer *)gesture {
    UIView *view = gesture.view;
    CGPoint translation = [gesture translationInView:view.superview];

    view.center = CGPointMake(view.center.x + translation.x, view.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:view.superview];

    // Keep within screen bounds
    if (gesture.state == UIGestureRecognizerStateEnded) {
        CGRect frame = view.frame;
        CGRect bounds = view.superview.bounds;

        if (frame.origin.x < 0) frame.origin.x = 0;
        if (frame.origin.y < 44) frame.origin.y = 44;
        if (frame.origin.x + frame.size.width > bounds.size.width)
            frame.origin.x = bounds.size.width - frame.size.width;
        if (frame.origin.y + frame.size.height > bounds.size.height)
            frame.origin.y = bounds.size.height - frame.size.height;

        [UIView animateWithDuration:0.2 animations:^{
            view.frame = frame;
        }];
    }
}

@end

// ============================================================
// PUBLIC API
// ============================================================

void SetupExecutorUI() {
    NSLog(@"[RobloxExecutor] Setting up executor UI...");
    addButtonToWindow();
    NSLog(@"[RobloxExecutor] Executor button added!");
}
