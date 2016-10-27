//
//  ImageRender.h
//  
//
//  Created by John Weaver on 10/22/2016.
//
//

#import <Cordova/CDVPlugin.h>

@interface ImageRender : CDVPlugin < UINavigationControllerDelegate, UIScrollViewDelegate>

@property (copy)   NSString* callbackId;
@property (nonatomic, retain) IBOutlet UIWebView *webView;
@property (strong, nonatomic) UIView* rootView; 
@property (strong, nonatomic) NSURL* localURL;
@property (strong, nonatomic) UIImage* imageOverlay; 

@property(readwrite, nonatomic) int pixelDensity;

@property(readwrite, nonatomic) float loadDelay;

@property(readwrite, nonatomic) int imageType;
@property(readwrite, nonatomic) int imageWidth;
@property(readwrite, nonatomic) int imageHeight;

@property(readwrite, nonatomic) int quality;

@property(readwrite, nonatomic) int numberOfFramesTotal;
@property(readwrite, nonatomic) int numberOfFramesToUse; 

@property (readwrite, nonatomic) CDVPluginResult* pluginResult; 
@property (readwrite, nonatomic) NSMutableDictionary* jsonResults; 

- (void)run:(CDVInvokedUrlCommand *)command;

@end
