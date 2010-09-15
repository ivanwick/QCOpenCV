//
//  QCFaceDetectionPlugIn.h
//  QCFaceDetection
//
//  Created by Ivan Wick on 8/23/10.
//  Copyright (c) 2010 __MyCompanyName__. All rights reserved.
//

#import <Quartz/Quartz.h>
#import <OpenCV/OpenCV.h>

@interface QCFaceDetectionPlugIn : QCPlugIn
{
	IplImage * ocvImage;
	CvHaarClassifierCascade *cascade;
	CvMemStorage *storage;
	
	BOOL lastTest;
}

/*
Declare here the Obj-C 2.0 properties to be used as input and output ports for the plug-in e.g.
@property double inputFoo;
@property(assign) NSString* outputBar;
You can access their values in the appropriate plug-in methods using self.inputFoo or self.inputBar
*/

@property(assign /*dynamic*/) id<QCPlugInInputImageSource> inputImage;

@property(assign) BOOL inputTest;
@property(assign) double outputTest;
@property(assign) double outputWidth;
@property(assign) double outputHeight;
@property(assign) double outputPositionX;
@property(assign) double outputPositionY;
@property(assign) double outputFaceDetected;


-(CGSize)resize:(CGSize)origSize forTotalPixels:(int)pixels;
-(CGRect)detectFirstFace:(IplImage*)frameImage;

@end
