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
@dynamic inputTest;
@dynamic outputTest;

@dynamic outputWidth;
@dynamic outputHeight;
@dynamic outputPositionX;
@dynamic outputPositionY;
@dynamic outputFaceDetected;

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
		
		/** allocation here */
		// IplImage for the frame (just the struct, whose pointers/data members
		// we will set as necessary in the style of CVOCV
		ocvImage = (IplImage*)malloc(sizeof(IplImage));
		
		// IplImage for downsampling?
		/* ??? */
		
		// CvClassifierCascade
		NSBundle * pluginBundle = [NSBundle bundleForClass:[self class]];
		NSString * cascadeFile = [pluginBundle pathForResource:@"haarcascade_frontalface_alt2"
														ofType:@"xml"];		
		NSLog(@"%@, %@", pluginBundle, cascadeFile);
		
		cascade = (CvHaarClassifierCascade*)cvLoad([cascadeFile UTF8String],
												   0, 0, 0);
		
		// CvMemStorage
		storage = cvCreateMemStorage(0);
	}
	
	return self;
}

- (void) finalize
{
	/*
	Release any non garbage collected resources created in -init.
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

	[super finalize];
}

- (void) dealloc
{
	/*
	Release any resources created in -init.
	*/
	
	[super dealloc];
}


#define MAX_TOTAL_PIXELS 50000

-(CGRect)detectFirstFace:(IplImage*)frameImage
{
	CGRect featRect = CGRectNull;
	IplImage * grayImage;
	IplImage * workingImage;
	IplImage *resizedImage = NULL;
	CGFloat detectionScale = 0;
	CGSize detectionSize;

	/* convert to grayscale */
	grayImage = cvCreateImage(cvSize(frameImage->width, frameImage->height),
							  IPL_DEPTH_8U, 1);
	cvCvtColor(frameImage, grayImage, CV_BGR2GRAY);
	
	/* we don't want to run the feature detector on more pixels than our limit */
	if ((frameImage->width * frameImage->height) > MAX_TOTAL_PIXELS) {
		detectionSize = [self resize:CGSizeMake(frameImage->width,
											   frameImage->height)
					 forTotalPixels:MAX_TOTAL_PIXELS];
		
		resizedImage = cvCreateImage(cvSize(detectionSize.width, detectionSize.height),
									 IPL_DEPTH_8U, 1);
		cvResize(grayImage, resizedImage, CV_INTER_LINEAR);
		cvReleaseImage(&grayImage);
		workingImage = resizedImage;
		detectionScale = frameImage->width / detectionSize.width;
	}
	else {
		workingImage = grayImage;
		detectionSize = CGSizeMake(frameImage->width, frameImage->height);
		detectionScale = 1;
	}
		
	CvSeq* features = cvHaarDetectObjects(workingImage, cascade, storage,
										1.1, 2, CV_HAAR_DO_CANNY_PRUNING,
										cvSize (30, 30));
	
	cvReleaseImage(&workingImage);
	
	int i;
	for (i = 0; i < (features ? features->total : 0); i++)
	{
		CvRect* r = (CvRect*) cvGetSeqElem (features, i);
		featRect = CGRectMake(r->x, r->y, r->width, r->height);
		/*
		NSLog(@"face found at { {%f, %f}, {%f, %f} }",
			  featRect.origin.x, featRect.origin.y,
			  featRect.size.width, featRect.size.height);
		 */
		break; /* only get the first one */
	}
	
	cvClearMemStorage(storage);
	
	/* flip coordinates for bottom-left origin */
	CGRect flippedRect = [self flipCoordinates:featRect withinSize:detectionSize];

	/* transform coordinates if the image was resized */
	if (detectionScale != 1) {
		/* is there a better way to apply this scale transform?? */
		flippedRect.size.width *= detectionScale;
		flippedRect.size.height *= detectionScale;
		flippedRect.origin.x *= detectionScale;
		flippedRect.origin.y *= detectionScale;
	}

	return flippedRect;
}

/* calculates a new CGSize having an area of the given number of pixels and
   preserving the aspect ratio
 */
-(CGSize)resize:(CGSize)origSize forTotalPixels:(int)pixels
{
	CGFloat aspect = origSize.width / origSize.height;
	return CGSizeMake(sqrt(pixels * aspect), sqrt(pixels / aspect));
}


/* convert a rectangle that uses a top-left origin, +x downward coord system to
   one that uses a bottom-left origin, +x upward coords
 */
-(CGRect)flipCoordinates:(CGRect)r withinSize:(CGSize)s
{
	return CGRectMake(r.origin.x, s.height - (r.size.height + r.origin.y), 
					  r.size.width, r.size.height);
}

@end

@implementation QCFaceDetectionPlugIn (Execution)

- (BOOL) startExecution:(id<QCPlugInContext>)context
{
	/*
	Called by Quartz Composer when rendering of the composition starts: perform any required setup for the plug-in.
	Return NO in case of fatal failure (this will prevent rendering of the composition to start).
	*/

	return YES;
}

- (void) enableExecution:(id<QCPlugInContext>)context
{
	/*
	Called by Quartz Composer when the plug-in instance starts being used by Quartz Composer.
	*/
}

- (BOOL)execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
	/*
	Called by Quartz Composer whenever the plug-in instance needs to execute.
	Only read from the plug-in inputs and produce a result (by writing to the plug-in outputs or rendering to the destination OpenGL context) within that method and nowhere else.
	Return NO in case of failure during the execution (this will prevent rendering of the current frame to complete).
	
	The OpenGL context for rendering can be accessed and defined for CGL macros using:
	CGLContextObj cgl_ctx = [context CGLContextObj];
	*/
	
	BOOL opstatus = YES;
	id<QCPlugInInputImageSource>	qcImage = self.inputImage;

	NSString*						pixelFormat = nil;
	CGColorSpaceRef					colorSpace = nil;
	CGRect faceRect = CGRectNull;
	
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
		/* Use monochrome pixel format anyway */
		//pixelFormat = QCPlugInPixelFormatI8;
		//NSLog(@"kCGColorSpaceModelRGB will it convert?");
		/**/
		#if __BIG_ENDIAN__
		pixelFormat = QCPlugInPixelFormatARGB8;
		#else
		pixelFormat = QCPlugInPixelFormatBGRA8;
		#endif
		/**/
	}
	else {
		return NO;
	}
	
	// NSLog(@"trying %@", pixelFormat);
	
	opstatus = [qcImage lockBufferRepresentationWithPixelFormat:pixelFormat
													 colorSpace:[qcImage imageColorSpace]
													  forBounds:[qcImage imageBounds]];
	// NSLog(@"return status was %@", opstatus ? @"YES" : @"NO" );
	if (!opstatus) { return NO; }

	
	/* vvv copy-paste from CVOCV */
	//Fill in the OpenCV image struct with the data from the buffer.
    ocvImage->nSize       = sizeof(IplImage);
    ocvImage->ID          = 0;
    ocvImage->nChannels   = 4;  // BGRA
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
	

	faceRect = [self detectFirstFace:ocvImage];
	
	if (CGRectIsNull(faceRect)) {
		self.outputFaceDetected = NO;
	}
	else {
		self.outputPositionX = faceRect.origin.x;
		self.outputPositionY = faceRect.origin.y;
		self.outputWidth = faceRect.size.width;
		self.outputHeight = faceRect.size.height;
		self.outputFaceDetected = YES;
	}
	 
	if (lastTest == NO && self.inputTest == YES) {
		lastTest = self.inputTest;
		NSLog(@"booltest");
	}
	lastTest = self.inputTest;
	self.outputTest = self.inputTest;
		
	
	[qcImage unlockBufferRepresentation];

	return opstatus;
}

- (void) disableExecution:(id<QCPlugInContext>)context
{
	/*
	Called by Quartz Composer when the plug-in instance stops being used by Quartz Composer.
	*/
}

- (void) stopExecution:(id<QCPlugInContext>)context
{
	/*
	Called by Quartz Composer when rendering of the composition stops: perform any required cleanup for the plug-in.
	*/
}

@end
