#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface TestFairy: NSObject

/**
 * Initialize a TestFairy session.
 *
 * @param appToken Your key as given to you in your TestFairy account
 */
+ (void)begin:(NSString *)appToken;

/**
 * Initialize a TestFairy session with options.
 *
 * @param appToken Your key as given to you in your TestFairy account
 * @param options A dictionary of options controlling the current session
 */
+ (void)begin:(NSString *)appToken withOptions:(NSDictionary *)options;

/**
 * Returns SDK version (x.x.x) string
 *
 * @return version
 */
+ (NSString *)version;

/**
 * Hides a specific view from appearing in the video generated.
 *
 * @param view The specific view you wish to hide from screenshots
 *
 */
+ (void)hideView:(UIView *)view;

/**
 * Pushes the feedback view controller. Hook a button
 * to this method to allow users to provide feedback about the current
 * session. All feedback will appear in your build report page, and in
 * the recorded session page.
 *
 */
+ (void)pushFeedbackController;

/**
 * Send a feedback on behalf of the user. Call when using a in-house
 * feedback view controller with a custom design and feel. Feedback will
 * be associated with the current session.
 *
 * @param feedbackString Feedback text
 */
+ (void)sendUserFeedback:(NSString *)feedbackString;

/**
 * Proxy didUpdateLocation delegate values and these
 * locations will appear in the recorded sessions. Useful for debugging
 * actual long/lat values against what the user sees on screen.
 *
 * @param locations Array of CLLocation. The first object of the array will determine the user location
 */
+ (void)updateLocation:(NSArray *)locations;

/**
 * Marks a checkpoint in session. Use this text to tag a session
 * with a checkpoint name. Later you can filter sessions where your
 * user passed through this checkpoint, for bettering understanding
 * user experience and behavior.
 *
 * @param name The checkpoint name
 */
+ (void)checkpoint:(NSString *)name;

/**
 * Sets a correlation identifier for this session. This value can
 * be looked up via web dashboard. For example, setting correlation
 * to the value of the user-id after they logged in. Can be called
 * only once per session (subsequent calls will be ignored.)
 *
 * @param correlationId Id for the current session
 */
+ (void)setCorrelationId:(NSString *)correlationId;

/**
 * Sets a correlation identifier for this session. This value can
 * be looked up via web dashboard. For example, setting correlation
 * to the value of the user-id after they logged in. Can be called
 * only once per session (subsequent calls will be ignored.)
 *
 * @param correlationId Id for the current session
 */
+ (void)identify:(NSString *)correlationId;

/**
 * Sets a correlation identifier for this session. This value can
 * be looked up via web dashboard. For example, setting correlation
 * to the value of the user-id after they logged in. Can be called
 * only once per session (subsequent calls will be ignored.)
 *
 * @param correlationId Id for the current session
 * @param traits Attributes and custom attributes to be associated with this session
 */
+ (void)identify:(NSString *)correlationId traits:(NSDictionary *)traits;

/**
 * Pauses the current session. This method stops recoding of
 * the current session until resume has been called.
 *
 * @see resume
 */
+ (void)pause;

/**
 * Resumes the recording of the current session. This method
 * resumes a session after it was paused.
 *
 * @see pause
 */
+ (void)resume;

/**
 * Returns the address of the recorded session on testfairy's
 * developer portal. Will return nil if recording not yet started.
 *
 * @return session URL
 */
+ (NSString *)sessionUrl;

/**
 * Takes a screenshot.
 *
 */
+ (void)takeScreenshot;

/**
 * Remote logging, use TFLog as you would use printf. These logs will be sent to the server,
 * but will not appear in the console.
 */
#if __cplusplus
extern "C" {
#endif
	
	void TFLog(NSString *format, ...) __attribute__((format(__NSString__, 1, 2)));
	void TFLogv(NSString *format, va_list arg_list);
	
#if __cplusplus
}
#endif

@end

extern NSString *const TFSDKIdentityTraitNameKey;
extern NSString *const TFSDKIdentityTraitEmailAddressKey;
extern NSString *const TFSDKIdentityTraitBirthdayKey;
extern NSString *const TFSDKIdentityTraitGenderKey;
extern NSString *const TFSDKIdentityTraitPhoneNumberKey;
extern NSString *const TFSDKIdentityTraitWebsiteAddressKey;
extern NSString *const TFSDKIdentityTraitAgeKey;
extern NSString *const TFSDKIdentityTraitSignupDateKey;

