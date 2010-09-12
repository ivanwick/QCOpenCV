//
//  QCFaceDetectionPlugIn.m
//  QCFaceDetection
//
//  Created by Ivan Wick on 8/23/10.
//  Copyright (c) 2010 __MyCompanyName__. All rights reserved.
//

/* It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering */
#import <OpenGL/CGLMacro.h>

#import "QCFaceDetectionPlugIn.h"

#define	kQCPlugIn_Name				@"QCFaceDetection"
#define	kQCPlugIn_Description		@"QCFaceDetection description"

@implementation QCFaceDetectionPlugIn

/*
Here you need to declare the input / output properties as dynamic as Quartz Composer will handle their implementation
@dynamic inputFoo, outputBar;
*/

@dynamic inputImage;

+ (NSDictionary*) attributes
{
	/*
	Return a dictionary of attributes describing the plug-in (QCPlugInAttributeNameKey, QCPlugInAttributeDescriptionKey...).
	*/
	
	return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey, kQCPlugIn_Description, QCPlugInAttributeDescriptionKey, nil];
}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
	/*
	Specify the optional attributes for property based ports (QCPortAttributeNameKey, QCPortAttributeDefaultValueKey...).
	*/
	
	return nil;
}

+ (QCPlugInExecutionMode) executionMode
{
	/*
	Return the execution mode of the plug-in: kQCPlugInExecutionModeProvider, kQCPlugInExecutionModeProcessor, or kQCPlugInExecutionModeConsumer.
	*/
	
	return kQCPlugInExecutionModeProcessor;
}

+ (QCPlugInTimeMode) timeMode
{
	/*
	Return the time dependency mode of the plug-in: kQCPlugInTimeModeNone, kQCPlugInTimeModeIdle or kQCPlugInTimeModeTimeBase.
	*/
	
	return kQCPlugInTimeModeNone;
}

- (id) init
{
	if(self = [super init]) {
		/*
		Allocate any permanent resource required by the plug-in.
		*/
	}
	
	return self;
}

- (void) finalize
{
	/*
	Release any non garbage collected resources created in -init.
	*/
	
	[super finalize];
}

- (void) dealloc
{
	/*
	Release any resources created in -init.
	*/
	
	[super dealloc];
}

@end

@implementation QCFaceDetectionPlugIn (Execution)

- (BOOL) startExecution:(id<QCPlugInContext>)context
{
	/*
	Called by Quartz Composer when rendering of the composition starts: perform any required setup for the plug-in.
	Return NO in case of fatal failure (this will prevent rendering of the composition to start).
	*/
	
	/** allocation here */
	// IplImage for the frame (just the struct, whose pointers to image data we
	// will set as necessary.
    ocvImage = (IplImage*)malloc(sizeof(IplImage));
	
	// IplImage for downsampling?
	/* ??? */
	
	// CvClassifierCascade
	cascade = (CvHaarClassifierCascade*)cvLoad(
		"/usr/local/share/opencv/haarcascades/haarcascade_frontalface_alt2.xml"
		 , 0, 0, 0);

	// CvMemStorage
	storage = cvCreateMemStorage(0);
	
	/**/
	
	return YES;
}

- (void) enableExecution:(id<QCPlugInContext>)context
{
	/*
	Called by Quartz Composer when the plug-in instance starts being used by Quartz Composer.
	*/
}

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
	/*
	Called by Quartz Composer whenever the plug-in instance needs to execute.
	Only read from the plug-in inputs and produce a result (by writing to the plug-in outputs or rendering to the destination OpenGL context) within that method and nowhere else.
	Return NO in case of failure during the execution (this will prevent rendering of the current frame to complete).
	
	The OpenGL context for rendering can be accessed and defined for CGL macros using:
	CGLContextObj cgl_ctx = [context CGLContextObj];
	*/
	
	BOOL opstatus;
	id<QCPlugInInputImageSource>	qcImage = self.inputImage;

	NSString*						pixelFormat;
	CGColorSpaceRef					colorSpace;
	
	
	/* Make sure we have a new image */
	if(![self didValueForInputKeyChange:@"inputImage"] ||
	   !qcImage) {
		return YES;
	}

	/* Figure out pixel format and colorspace to use */
	colorSpace = [qcImage imageColorSpace];
	if(CGColorSpaceGetModel(colorSpace) == kCGColorSpaceModelMonochrome) {
		pixelFormat = QCPlugInPixelFormatI8;
	}
	else if(CGColorSpaceGetModel(colorSpace) == kCGColorSpaceModelRGB) {
		NSLog(@"kCGColorSpaceModelRGB will it convert?");
		/*
		#if __BIG_ENDIAN__
		pixelFormat = QCPlugInPixelFormatARGB8;
		#else
		pixelFormat = QCPlugInPixelFormatBGRA8;
		#endif
		 */
	}
	else {
		return NO;
	}
	
	/* Get a buffer representation from the image in its native colorspace */
	if(![qcImage lockBufferRepresentationWithPixelFormat:pixelFormat colorSpace:colorSpace forBounds:[qcImage imageBounds]])
		return NO;
	
	
	opstatus = [qcImage lockBufferRepresentationWithPixelFormat:QCPlugInPixelFormatI8
														colorSpace:kCGColorSpaceModelMonochrome
														 forBounds:[qcImage imageBounds]];
	if (!opstatus) { return NO; }

	
	/* vvv copy-paste from CVOCV */
	//Fill in the OpenCV image struct from the data from CoreVideo.
    ocvImage->nSize       = sizeof(IplImage);
    ocvImage->ID          = 0;
    ocvImage->nChannels   = 1;
    ocvImage->depth       = IPL_DEPTH_8U;
    ocvImage->dataOrder   = 0;
    ocvImage->origin      = 0; //Top left origin.
    ocvImage->width       = [qcImage bufferPixelsWide]; //CVPixelBufferGetWidth((CVPixelBufferRef)videoFrame);
    ocvImage->height      = [qcImage bufferPixelsHigh]; //CVPixelBufferGetHeight((CVPixelBufferRef)videoFrame);
    ocvImage->roi         = NULL; //Region of interest. (struct IplROI).
    ocvImage->maskROI     = 0;
    ocvImage->imageId     = 0;
    ocvImage->tileInfo    = 0;
    ocvImage->imageSize   = [qcImage bufferBytesPerRow] * [qcImage bufferPixelsHigh];
    ocvImage->imageData   = (char*)[qcImage bufferBaseAddress];
    ocvImage->widthStep   = [qcImage bufferBytesPerRow];
    ocvImage->imageDataOrigin = (char*)[qcImage bufferBaseAddress];
	/* ^^^ copy-paste from CVOCV */
	
	// rect = [self detectFirstFace];
	
	[qcImage unlockBufferRepresentation];

	return opstatus;
}

- (void) disableExecution:(id<QCPlugInContext>)context
{
	/*
	Called by Quartz Composer when the plug-in instance stops being used by Quartz Composer.
	*/
	
	/** allocation here */
	// IplImage for the frame
	free(&ocvImage);
	
	// IplImage for downsampling?
	/* ??? nothing yet */
	
	// CvMemStorage
	cvReleaseMemStorage(&storage);
	
	// CvClassifierCascade
	cvReleaseHaarClassifierCascade(&cascade);
	/**/	
}

- (void) stopExecution:(id<QCPlugInContext>)context
{
	/*
	Called by Quartz Composer when rendering of the composition stops: perform any required cleanup for the plug-in.
	*/
}

@end
