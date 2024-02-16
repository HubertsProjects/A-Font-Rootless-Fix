@interface WKUserContentController
-(void)addScriptMessageHandler:(id)arg1 name:(id)arg2 ;
- (void)removeScriptMessageHandlerForName:(NSString *)name;
@end
@interface WKWebViewConfiguration
@property (nonatomic,retain) WKUserContentController * userContentController;
@end
@interface WKWebView
@property (assign) BOOL loaded;
@property (nonatomic,copy,readonly) WKWebViewConfiguration * configuration;
@property (nonatomic,copy,readonly) NSURL* URL;
-(void)evaluateJavaScript:(id)arg1 completionHandler:(id)arg2 ;
@end
@interface WKScriptMessage
@property (nonatomic,copy,readonly) id body;
@property (nonatomic,copy,readonly) NSString * name;
@end
