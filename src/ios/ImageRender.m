//
//  ImageRender.m
//
//  Created by John Weaver on 10/22/2016
//

#import "ImageRender.h"
#import <Accounts/Accounts.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h> 
#import <ImageIO/ImageIO.h>  
#import <MobileCoreServices/MobileCoreServices.h>
#import "UIImage+animatedGIF.h"

@implementation ImageRender 
@synthesize callbackId;
@synthesize webView;

- (void) cancel:(CDVInvokedUrlCommand *)command 
{
	self.shouldCancel = 1;
}

- (void) run:(CDVInvokedUrlCommand *)command 
{
	///////////////////////////////////////// 
	// SET VARS
	/////////////////////////////////////////

	int intScreenWidth = 0;
	int intScreenHeight = 0;

	NSString * strFileName;
	
	self.imageOverlay = nil;
	self.callbackId = command.callbackId;	

    NSDictionary *options = [command.arguments objectAtIndex: 0];

	///////////////////////////////////////// 
	// GET COMMAND ARGS
	/////////////////////////////////////////
	
	NSString * strLoadDelay = [options objectForKey:@"loadDelay"];

	int intQuality = [[options objectForKey:@"quality"] integerValue];
	int intType = [[options objectForKey:@"type"] integerValue];
		
	self.quality = intQuality;
	self.imageType = intType;

	self.url = [options objectForKey:@"url"];
	self.filter = [options objectForKey:@"filter"];
	self.cssPath =  [options objectForKey:@"cssPath"];
	self.overlayBase64 = [options objectForKey:@"overlayBase64"];
	
	if (strLoadDelay != [NSNull null])		 			
	{
		self.loadDelay = [strLoadDelay floatValue];
	}
	else
	{
		self.loadDelay = 0.0;
	}

	///////////////////////////////////////// 
	// SET ADDITIONAL SELF PROPERTIES
	/////////////////////////////////////////

	self.imageArray = [[NSMutableArray alloc] init];
	self.frameNumber = 0;
	
	///////////////////////////////////////// 
	// SET PIXEL DENSITY
	/////////////////////////////////////////
	
	self.pixelDensity = 2;	
	
	///////////////////////////////////////// 
	// GET SCREEN SIZE
	/////////////////////////////////////////

	intScreenWidth = [[UIScreen mainScreen] bounds].size.width;
	intScreenHeight = [[UIScreen mainScreen] bounds].size.height;

	///////////////////////////////////////// 
	// RESET CANCEL
	/////////////////////////////////////////

	self.shouldCancel = 0;

	///////////////////////////////////////// 
	// SET RESULTS JSON
	/////////////////////////////////////////

	self.jsonResults = [ [NSMutableDictionary alloc]
		initWithObjectsAndKeys :
		nil, @"progress",      
		nil, @"filePath",        
		nil, @"fileSize",        
		nil
	]; 

	///////////////////////////////////////// 
	// SET FILE EXTENSION
	/////////////////////////////////////////

	if (self.imageType == 1)
	{
		self.fileExtension = @"jpg";
	}

	if (self.imageType == 2)
	{
		self.fileExtension = @"gif";
	}

	///////////////////////////////////////// 
	// SET RENDERED IMAGE PATH
	/////////////////////////////////////////

	strFileName = [NSString stringWithFormat:@"rendered.%@", self.fileExtension];	
	self.renderedImagePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:strFileName];
  
	///////////////////////////////////////// 
	// SET ROOT VIEW
	/////////////////////////////////////////
	
	self.rootView = [[[UIApplication sharedApplication] keyWindow] rootViewController].view;
	
	///////////////////////////////////////// 
	// GET SCREEN SIZE
	/////////////////////////////////////////

	self.screenWidth = [[UIScreen mainScreen] bounds].size.width;
	self.screenHeight = [[UIScreen mainScreen] bounds].size.height;

	///////////////////////////////////////// 
	// CREATE WEBVIEW FROM HTML STRING
	// SET POS Y TO SCREEN HEIGHT SO IT SHOWS BELOW THE FOLD
	// TO DEBUG, SET POS Y TO 0
	/////////////////////////////////////////
	
	int intPosY = intScreenHeight;

	self.wkView = [[WKWebView alloc] initWithFrame:CGRectMake(0, intPosY, intScreenWidth, intScreenHeight)]; 			
	self.wkView.opaque = NO;
	self.wkView.navigationDelegate = self;
	
	///////////////////////////////////////// 
	// ADD WEBVIEW TO ROOT VIEW
	/////////////////////////////////////////
	
	[self.rootView addSubview:self.wkView];

	[self.commandDelegate runInBackground:^{
    
		[self download];		
    }];
}

- (void) download 
{	
	///////////////////////////////////////// 
	// SET LOCAL URL TO SAVE FILE FROM REMOTE
	/////////////////////////////////////////

	NSURL* remoteURL = [NSURL URLWithString:self.url];   
	self.localURL = [self saveLocalFileFromRemoteUrl: remoteURL extension:self.fileExtension]; 

	///////////////////////////////////////// 
	// CREATE UIMAGE FROM IMAGE - WORKS WITH ANIMATED GIFs (UIImage+animatedGIF.h)
	/////////////////////////////////////////

	self.imageWithAnimation = [UIImage animatedImageWithAnimatedGIFURL:(NSURL *)self.localURL];

	///////////////////////////////////////// 
	// GET DIMENSIONS
	/////////////////////////////////////////

	self.imageWidth = self.imageWithAnimation.size.width;
	self.imageHeight = self.imageWithAnimation.size.height;

	///////////////////////////////////////// 
	// SET SCALED DIMENSIONS
	/////////////////////////////////////////

	self.imageWidth_Scaled = self.screenWidth;
	
	float fltAspectRatio = (float) self.imageHeight / self.imageWidth;	
	float fltImageHeight_Scaled = self.screenWidth * fltAspectRatio;
	self.imageHeight_Scaled = (int) fltImageHeight_Scaled;

	///////////////////////////////////////// 
	// SET FRAME COUNT
	/////////////////////////////////////////

	self.numberOfFramesTotal = [self.imageWithAnimation.images count];
	self.numberOfFramesToUse = (self.numberOfFramesTotal / 10) + 1;

	NSLog(@"# of Frames: %i; # to use: %i", self.numberOfFramesTotal, self.numberOfFramesToUse);
	NSLog(@"Load Delay: %f", self.loadDelay);
	NSLog(@"Screen Size: %i, %i", self.screenWidth, self.screenHeight);
	NSLog(@"Image Size: %i, %i", self.imageWidth, self.imageHeight);

	///////////////////////////////////////// 
	// GET OVERLAY
	/////////////////////////////////////////

	if (self.overlayBase64 != [NSNull null] && self.overlayBase64 != nil)		 			
	{
		NSData *datOverlayBase64 = [[NSData alloc]initWithBase64EncodedString:self.overlayBase64 options:NSDataBase64DecodingIgnoreUnknownCharacters];	
		self.imageOverlay = [UIImage imageWithData:datOverlayBase64];
	}

	[self render];		
}

- (void) render 
{
	dispatch_async(dispatch_get_main_queue(), ^(void){
		
		NSString * strFrameNumber = [NSString stringWithFormat:@"%i", self.frameNumber];	

		///////////////////////////////////////// 
		// BUILD HTML STRING
		/////////////////////////////////////////

		NSString *HTML_HEADER=@"<HTML><HEAD><link rel='stylesheet' href='#CSS#' type='text/css'></HEAD>";
		NSString *cssFilePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:self.cssPath];		
		NSString* strCSS = [NSString stringWithContentsOfFile:cssFilePath encoding:NSUTF8StringEncoding error:NULL];
		NSString *HTML_HEADER_WITH_CSS = [HTML_HEADER stringByReplacingOccurrencesOfString:@"#CSS#" withString:cssFilePath];
		NSMutableString *html = [NSMutableString stringWithString: @""];		
		[html appendString:@"<html>"];
		[html appendString:@"<head>"];
		[html appendString:@"<title></title>"];
		[html appendString:@"<style>"];
		[html appendString:strCSS];
		[html appendString:@"</style>"];
		[html appendString:@"</head>"];
		[html appendString:@"<body style=\"background:#000; padding:0px; margin:0px;\">"];

		///////////////////////////////////////// 
		// DEBUG: SHOW FRAME NUMBER
		/////////////////////////////////////////
				
		//[html appendString:@"<div><p style='color:#ff0000; font-size: 120px;'>"];			
		//[html appendString:strFrameNumber];
		//[html appendString:@"</p></div>"];	

		if (self.filter != [NSNull null])		 			
		{
			[html appendString:@"<div class='"];
			[html appendString:self.filter];
			[html appendString:@"'>"];
		}
		else
		{
			[html appendString:@"<div>"];
		}		
	
		int intCounter = self.frameNumber * 10;
		
		//NSLog(@"self.frameNumber: %i", self.frameNumber);
		//NSLog(@"intCounter: %i", intCounter);
		
		if (intCounter < self.numberOfFramesTotal)
		{
			UIImage * img = self.imageWithAnimation.images[intCounter];

			//NSLog(@"XXX Image Size: %i, %i", img.size.width, img.size.height);
			//NSLog(@"XXX Image Size: %f, %f", img.size.width, img.size.height);

			//if (self.imageType == 2)
			//{
				//img = self.imageWithAnimation.images[intCounter];
			//}				

			if (img != nil)
			{
				NSString * base64String = [UIImagePNGRepresentation(img) base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
			
				//[html appendString:@"<div width='100%'>"];
				[html appendString:@"<div id='frame_"];
				[html appendString:strFrameNumber];
				[html appendString:@"'"];
				[html appendString:@" style='width:100%;'>"];
				[html appendString:@"<img style='width:100%;' src='data:image/jpeg;base64,"];
				[html appendString:base64String];
				[html appendString:@"'>"];
				[html appendString:@"</div>"];		
			}
		}

		[html appendString:@"</div>"];	

		///////////////////////////////////////// 
		// FINISH BUILDING HTML STRING
		/////////////////////////////////////////

		[html appendString:@"</div>"];	
		[html appendString:@"</body></html>"];

		[self.wkView loadHTMLString:[html description] baseURL:nil];	

	});	
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{	
	//[self add];
	
	if (self.shouldCancel == 1)
	{
		[self destroyWKView];
	}
	else
	{
		if (self.imageType == 1)
		{
			[self performSelector:@selector(webViewLoaded) withObject:nil afterDelay: 1.0];			
		}

		if (self.imageType == 2)
		{
			[self add];

			if (self.frameNumber < self.numberOfFramesToUse)
			{
				[self render];		
				[self progress];	

				self.frameNumber += 1;
			}
			else
			{
				[self draw];	
				[self completionHandler];
				[self destroyWKView];
				//[self preview];
			}			
		}
	}	
}
 
 - (void)webViewLoaded;
 {
	[self add];
	[self draw];	
	[self completionHandler];
	[self destroyWKView];
 }

 -(void *)add;
{
	//CGRect rect = CGRectMake(0, 0, 375, 206);
	CGRect rect = CGRectMake(0, 0, self.imageWidth_Scaled, self.imageHeight_Scaled);
	
	UIGraphicsBeginImageContextWithOptions(rect.size, NO, 1);
	[self.wkView drawViewHierarchyInRect:self.wkView.bounds afterScreenUpdates:YES];
	UIImage *uiImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	[self.imageArray addObject: [UIImage imageWithCGImage:uiImage.CGImage]];

}

 -(void *)progress; 
{
	float fltProgress = (float) self.frameNumber / (float) self.numberOfFramesToUse;
	int intProgress = (int) (fltProgress * 100);
	
	NSString * strProgress = [NSString stringWithFormat:@"%i", intProgress];			
	//NSLog(@"Progress: %@", strProgress); 
		
	self.jsonResults[@"progress"] = strProgress;	
	
	self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:self.jsonResults];	

	[self.pluginResult setKeepCallbackAsBool:YES];
	[self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.callbackId];				
}

 -(void *)draw;
{
	NSUInteger *images = [self.imageArray count];
	NSLog(@"Number of images: %lu", images);

	CGImageDestinationRef imageDestination; 
	NSDictionary *frameProperties;
	NSDictionary *imageProperties;

	int intOutputWidth = self.imageWidth;
	int intOutputHeight = self.imageHeight;

	int intImageWidth_Scaled = 0;
	int intImageHeight_Scaled = 0;
	
	///////////////////////////////////////// 
	// SET QUALITY
	/////////////////////////////////////////
	
	if (self.quality < 100)
	{
		float fltQuality = self.quality / 100.0;
		float fltOutputWidth = self.imageWidth * fltQuality;
		float fltOutputHeight = self.imageHeight * fltQuality;

		intOutputWidth = (int) fltOutputWidth;
		intOutputHeight = (int) fltOutputHeight;		
	}

	///////////////////////////////////////// 
	// SET OUTPUT SIZE
	/////////////////////////////////////////
	
	CGSize scaledSize = CGSizeMake(intOutputWidth, intOutputHeight);
		
	///////////////////////////////////////// 
	// CREATE IMAGE DESTINATION
	/////////////////////////////////////////

	//int intStart = 3;
	int intStart = 0;

	if (self.imageType == 1) // JPEG
	{
		imageDestination = CGImageDestinationCreateWithURL(
		(CFURLRef) [NSURL fileURLWithPath:self.renderedImagePath],
		kUTTypeJPEG,
		self.numberOfFramesToUse, // number of images in this GIF
		NULL);
	}

	if (self.imageType == 2) // GIF
	{
		intStart = 3; // START WITH A LATER FRAME IN ORDER TO AVOID WHITE FLASH AT BEGINNING OF GIF

		imageDestination = CGImageDestinationCreateWithURL(
		(CFURLRef) [NSURL fileURLWithPath:self.renderedImagePath],
		kUTTypeGIF,
		//self.numberOfFramesToUse, // number of images in this GIF
		self.numberOfFramesToUse - intStart, // number of images in this GIF
		//30, // number of images in this GIF
		NULL);
	}	

	///////////////////////////////////////// 
	// SET IMAGE PROPERTIES
	/////////////////////////////////////////

	if (self.imageType == 1) // JPEG
	{
		self.frameProperties = nil;
		self.imageProperties = nil;
	}

	if (self.imageType == 2) // GIF
	{
		//float delayTime = 0.02f;
		//self.frameProperties = [self filePropertiesWithLoopCount:0];
		//self.imageProperties = [self framePropertiesWithDelayTime:delayTime];		

		frameProperties = [NSDictionary dictionaryWithObject:
		[NSDictionary  dictionaryWithObject:[NSNumber numberWithInt:0.0]  
		forKey:(NSString *) kCGImagePropertyGIFDelayTime] 
		forKey:(NSString *) kCGImagePropertyGIFDictionary];

		imageProperties = [NSDictionary dictionaryWithObject:
		[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:0]
		forKey:(NSString *) kCGImagePropertyGIFLoopCount]
		forKey:(NSString *) kCGImagePropertyGIFDictionary];
	}	

	//CGRect rectCrop = CGRectMake(0, 0, 375, 206); // or whatever rectangle
	//CGRect rectCrop = CGRectMake(0, 0, 800, 450); // or whatever rectangle
	CGRect rectCrop = CGRectMake(0, 0, self.imageWidth_Scaled, self.imageHeight_Scaled); // or whatever rectangle
	
	UIImage * imgFiltered;
	UIImage * imgResult;

	//for (int i = 0; i < self.numberOfFramesToUse; i++) 
	for (int i = intStart; i < self.numberOfFramesToUse; i++) 
	{
		imgFiltered = (UIImage *) self.imageArray[i];
		CGImageRef drawImage = CGImageCreateWithImageInRect([imgFiltered CGImage], rectCrop);
		//CGImageRef drawImage = CGImageCreateWithImageInRect([img CGImage], CGRectMake(0, 0, img.size.width, img.size.height));
		//NSLog(@"fileSize: %f, %f", imgFiltered.size.width, imgFiltered.size.height);
		//NSLog(@"fileSize: %i, %i", imgFiltered.size.width, imgFiltered.size.height);

		UIImage *imgFrame = [UIImage imageWithCGImage:drawImage];

		///////////////////////////////////////// 
		// RELEASE IMAGE REF
		/////////////////////////////////////////	

		CGImageRelease(drawImage);

		///////////////////////////////////////// 
		// ADD OVERLAY TO FRAME
		/////////////////////////////////////////	
		
		if (self.imageOverlay != nil)
		{
			imgResult = [self combineImages:self.imageOverlay backgroundImage:imgFrame scaledToSize: scaledSize]; 
			CGImageDestinationAddImage(imageDestination, imgResult.CGImage, (CFDictionaryRef)frameProperties);		
			//NSLog(@"self.imageOverlay");			
		}
		else
		{
			CGImageDestinationAddImage(imageDestination, imgFrame.CGImage, (CFDictionaryRef)frameProperties);					
		}
			
		imgFiltered = nil;
		imgResult = nil;
		imgFrame = nil;

		UIImageView * iv = [[UIImageView alloc] initWithImage:imgFiltered];
		[self.rootView addSubview:iv];

		//CGImageRef imageRef = img.CGImage;
		//CGImageDestinationAddImage(imageDestination, imageRef, (CFDictionaryRef)self.frameProperties);	
		//CGImageRelease(imageRef);	
	}

	if (self.imageType == 2) // GIF
	{
		CGImageDestinationSetProperties(imageDestination, (CFDictionaryRef)imageProperties);
	}
	
	CGImageDestinationFinalize(imageDestination);
	CFRelease(imageDestination);
	self.imageArray = nil;
	imageDestination = nil;
}

 -(void *)completionHandler;
{
	///////////////////////////////////////// 
	// GET FILE SIZE
	/////////////////////////////////////////
	
	unsigned long long fileSize = 0;		
	NSString *strFileSize = nil;

	fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:self.renderedImagePath error:nil] fileSize];
	strFileSize = [NSByteCountFormatter stringFromByteCount:fileSize countStyle:NSByteCountFormatterCountStyleFile]; 

	///////////////////////////////////////// 
	// SEND RESULT BACK TO CORDOVA
	/////////////////////////////////////////

	///////////////////////////////////////// 
	// SET JSON RESULTS
	/////////////////////////////////////////
	
	self.jsonResults[@"filePath"] = self.renderedImagePath;	
	self.jsonResults[@"fileSize"] = strFileSize;	
	self.jsonResults[@"progress"] = @"100";	

	//NSLog(@"filePath: %@", self.renderedImagePath);
	NSLog(@"fileSize: %@", strFileSize);

	self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:self.jsonResults];	

	[self.pluginResult setKeepCallbackAsBool:NO]; // here we tell Cordova not to cleanup the callback id after sendPluginResult()					
	[self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.callbackId];		
}

- (void) destroyWKView;
{
	[self.wkView loadHTMLString:@"" baseURL:nil];
	[self.wkView stopLoading];
	self.wkView.navigationDelegate = nil;
	[self.wkView removeFromSuperview];
	self.wkView = nil;

	self.quality = nil;
	self.imageType = nil;

	self.url = nil;
	self.filter = nil;
	self.cssPath =  nil;
	self.overlayBase64 = nil;
	self.imageOverlay = nil;
	self.imageArray = nil;

	self.shouldCancel = nil;
	self.frameNumber = nil;	
	self.numberOfFramesToUse = nil;

	[[NSURLCache sharedURLCache] removeAllCachedResponses];
    [[NSURLCache sharedURLCache] setDiskCapacity:0];
    [[NSURLCache sharedURLCache] setMemoryCapacity:0];
}


 -(void *)preview;
{
	///////////////////////////////////////// 
	// SEND RESULT BACK TO CORDOVA
	/////////////////////////////////////////

	NSString * strFileName = @"rendered.gif";

	NSString *strRenderedImagePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:strFileName];
  
	UIWebView *preview =[[UIWebView alloc] initWithFrame:CGRectMake(0, 0, self.imageWidth, self.imageHeight)]; 	

	NSMutableString *html = [NSMutableString stringWithString: @""];

	[html appendString:@"<html>"];
	[html appendString:@"<head>"];
	[html appendString:@"<title></title>"];	
	[html appendString:@"</head>"];
	[html appendString:@"<body style=\"background:transparent; padding:0px; margin:0px;\">"];

	[html appendString:@"<img style='width:320px;' src='"];    
	[html appendString:[NSString stringWithFormat:@"file://%@", strRenderedImagePath]];     
	[html appendString:@"'/>"];    	
    [html appendString:@"</body></html>"];

	//NSLog(@"html: %@", html);

	[preview loadHTMLString:[html description] baseURL:nil];
	[self.rootView addSubview:preview];
}

- (NSURL*)saveLocalFileFromRemoteUrl:(NSURL*)url extension:(NSString *)extension
{   
    if (!NSTemporaryDirectory())
    {
       // no tmp dir for the app (need to create one)
    }

    NSURL *tmpDirURL = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    //NSURL *fileURL = [[tmpDirURL URLByAppendingPathComponent:@"temp"] URLByAppendingPathExtension:@"mp4"];
	NSURL *fileURL = [[tmpDirURL URLByAppendingPathComponent:@"temp"] URLByAppendingPathExtension:extension];
    
	NSData *urlData = [NSData dataWithContentsOfURL:url];
    [urlData writeToURL:fileURL options:NSAtomicWrite error:nil];

	NSLog(@"fileURL: %@", [fileURL path]);

	return fileURL;
}


- (UIImage *) combineImages:(UIImage *)foregroundImage backgroundImage:(UIImage *)backgroundImage scaledToSize:(CGSize)scaledSize
{
	UIGraphicsBeginImageContextWithOptions(scaledSize, YES, 1.0); 
	[backgroundImage drawInRect:CGRectMake(0, 0, scaledSize.width, scaledSize.height)];
	[foregroundImage drawInRect:CGRectMake(0, 0, scaledSize.width, scaledSize.height)];
	
	UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	return result;
}

@end
