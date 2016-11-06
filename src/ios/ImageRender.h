//
//  ImageRender.h
//  
// 
//  Created by John Weaver on 10/22/2016.
//
//

#import <Cordova/CDVPlugin.h>
#import <WebKit/WebKit.h>
#import <ImageIO/ImageIO.h>

@interface ImageRender : CDVPlugin < UINavigationControllerDelegate, UIScrollViewDelegate>

@property (copy)   NSString* callbackId;

@property (copy)NSString* url;
@property (copy)NSString* filter;
@property (copy)NSString* cssPath;
@property (copy)NSString* overlayBase64;
@property (copy)NSString* renderedImagePath;
@property (copy)NSString* fileExtension;

@property (nonatomic, retain) IBOutlet UIWebView *webView;
@property (nonatomic, retain) IBOutlet WKWebView *wkView;
@property (strong, nonatomic) UIView* rootView; 
@property (strong, nonatomic) NSURL* localURL;
@property (strong, nonatomic) UIImage* imageOverlay; 
@property (strong, nonatomic) UIImage* imageWithAnimation; 
//@property CGImageDestinationRef imageDestination; 

@property (strong, nonatomic) NSMutableArray* imageArray;

@property (strong, nonatomic) NSDictionary * frameProperties;
@property (strong, nonatomic) NSDictionary * imageProperties;

@property(readwrite, nonatomic) int shouldCancel;
@property(readwrite, nonatomic) int pixelDensity;

@property(readwrite, nonatomic) float loadDelay;

@property(readwrite, nonatomic) int imageType;
@property(readwrite, nonatomic) int imageWidth;
@property(readwrite, nonatomic) int imageHeight;

@property(readwrite, nonatomic) int imageWidth_Scaled;
@property(readwrite, nonatomic) int imageHeight_Scaled;

@property(readwrite, nonatomic) int screenWidth;
@property(readwrite, nonatomic) int screenHeight;

@property(readwrite, nonatomic) int quality;

@property(readwrite, nonatomic) int frameNumber; 

@property(readwrite, nonatomic) int numberOfFramesTotal;
@property(readwrite, nonatomic) int numberOfFramesToUse; 

@property (readwrite, nonatomic) CDVPluginResult* pluginResult; 
@property (readwrite, nonatomic) NSMutableDictionary* jsonResults; 

- (void)run:(CDVInvokedUrlCommand *)command;
- (void)cancel:(CDVInvokedUrlCommand *)command;

@end
