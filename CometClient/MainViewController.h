
#import "DDCometClient.h"

@interface MainViewController : UIViewController <UITextFieldDelegate, DDCometClientDelegate>

@property (nonatomic, weak) IBOutlet UITextView *textView;
@property (nonatomic, weak) IBOutlet UITextField *textField;

@end
