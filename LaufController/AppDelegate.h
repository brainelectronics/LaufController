//
//  AppDelegate.h
//  LaufController
//
//  Created by Jonas Scharpf on 07.11.12.
//  Copyright (c) 2012 Jonas Scharpf. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/serial/IOSerialKeys.h>
#include <IOKit/IOBSD.h>
#include <IOKit/serial/ioss.h>
#include <sys/ioctl.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
    //IBOutlet NSView *drawVictorView;
	IBOutlet NSPopUpButton *serialListPullDown; //Dropdown Menü der Ports
	IBOutlet NSTextView *serialOutputArea;  //Anzeige der Input Daten
	IBOutlet NSTextField *serialInputField; //Inputfeld für die Übertragung
	IBOutlet NSTextField *baudInputField;   //Eingabe der Baudrate
	int serialFileDescriptor; // file handle to the serial port
	struct termios gOriginalTTYAttrs; // Hold the original termios attributes so we can reset them on quit ( best practice )
	bool readThreadRunning;
	NSTextStorage *storage;
    NSTextField *neuesTestFeld;
    
    NSURL *selectedOpenDirectoryURL;
    NSURL *selectedOpenFileURL;
    NSString *loadedTextFile;
    
    IBOutlet NSPanel *theSheet;
    IBOutlet NSPanel *errorReportSheet;
    
    NSTimer *nsTimer;
}
//@property (assign) IBOutlet NSView *drawVictorView;
//@property (assign) IBOutlet NSWindow *drawVictorWindow;
//@property (assign) IBOutlet NSView *customViewVictor;

@property (assign) IBOutlet NSWindow *window;
//@property (assign) IBOutlet NSWindow *buttonControl;
//@property (assign) IBOutlet NSWindow *logWindow;
/*
@property (retain) NSString *aString;
@property (retain) NSString *echoString;
@property (retain) NSString *defaultValue;

@property int valueHufteL;
@property int valueHufteR;
@property int valueKnieL;
@property int valueKnieR;
@property int valueFussL;
@property int valueFussR;
*/

@property (retain) NSAttributedString* attrString;
@property (retain) NSTextStorage *textStorage;
@property (retain) NSString *defaultValue;  //String beim Start 90°

@property int valueArmL;  //Wert des linken Arms
@property int valueArmR;  //Wert des rechten Arms
@property int valueHufteL;  //Wert der linken Hüfte
@property int valueHufteR;  //Wert der rechten Hüfte
@property int valueKnieL;   //wert des linken Knie
@property int valueKnieR;   //Wert des rechten Knie
@property int valueFussL;   //Wert des linken Fuß
@property int valueFussR;   //Wert des rechten Fuß

- (IBAction)endTheSheet:(id)sender;

- (IBAction)armUpL:(id)sender;
- (IBAction)armUpR:(id)sender;
- (IBAction)armDownL:(id)sender;
- (IBAction)armDownR:(id)sender;
- (IBAction)hufteUpL:(id)sender;
- (IBAction)hufteUpR:(id)sender;
- (IBAction)hufteDownL:(id)sender;
- (IBAction)hufteDownR:(id)sender;
- (IBAction)knieUpL:(id)sender;
- (IBAction)knieUpR:(id)sender;
- (IBAction)knieDownL:(id)sender;
- (IBAction)knieDownR:(id)sender;
- (IBAction)fussUpL:(id)sender;
- (IBAction)fussUpR:(id)sender;
- (IBAction)fussDownL:(id)sender;
- (IBAction)fussDownR:(id)sender;
- (IBAction)fussQuerUpR:(id)sender;
- (IBAction)fussQuerUpL:(id)sender;
- (IBAction)fussQuerDownL:(id)sender;
- (IBAction)fussQuerDownR:(id)sender;



@property (assign) IBOutlet NSButton *fussQuerUpR;
//- (IBAction)openButtonWindow:(id)sender;
//- (IBAction)openOK:(id)sender;


@property (assign) IBOutlet NSTextField *labelArmDownL;
@property (assign) IBOutlet NSTextField *labelArmDownR;
@property (assign) IBOutlet NSTextField *labelHufteDownL;
@property (assign) IBOutlet NSTextField *labelHufteDownR;
@property (assign) IBOutlet NSTextField *labelKnieDownL;
@property (assign) IBOutlet NSTextField *labelKnieDownR;
@property (assign) IBOutlet NSTextField *labelFussDownL;
@property (assign) IBOutlet NSTextField *labelFussDownR;
@property (assign) IBOutlet NSTextField *labelFussDownQuerR;
@property (assign) IBOutlet NSTextField *labelFussDownQuerL;

@property (assign) IBOutlet NSTextField *labelDauerWert;
@property (assign) IBOutlet NSTextField *labelEinzelWert;

@property (assign) IBOutlet NSTextField *savingStatus;

//@property (assign) IBOutlet NSTextField *inputLogField;
//@property (assign) IBOutlet NSScrollView *scrollViewLog;

//@property (assign) IBOutlet NSTextField *errorReportLabel;


@property (assign) IBOutlet NSTextField *huefteLinksField;
@property (assign) IBOutlet NSTextField *knieLinksField;
@property (assign) IBOutlet NSTextField *fussLinksField;
@property (assign) IBOutlet NSTextField *huefteRechtsField;
@property (assign) IBOutlet NSTextField *knieRechtsField;
@property (assign) IBOutlet NSTextField *fussRechtsField;

@property (assign) IBOutlet NSSlider *huefteSliderLinks;
@property (assign) IBOutlet NSSlider *knieSliderLinks;
@property (assign) IBOutlet NSSlider *fussSliderLinks;
@property (assign) IBOutlet NSSlider *huefteSliderRechts;
@property (assign) IBOutlet NSSlider *knieSliderRechts;
@property (assign) IBOutlet NSSlider *fussSliderRechts;

- (IBAction)huefteSliderLinks:(id)sender;
- (IBAction)knieSliderLinks:(id)sender;
- (IBAction)fussSliderLinks:(id)sender;
- (IBAction)huefteSliderRechts:(id)sender;
- (IBAction)knieSliderRechts:(id)sender;
- (IBAction)fussSliderRechts:(id)sender;

//@property (assign) IBOutlet NSTextField *labelArmDownL;
//@property (assign) IBOutlet NSTextField *labelArmDownR;
//@property (assign) IBOutlet NSTextField *labelHufteDownL;
//@property (assign) IBOutlet NSTextField *labelHufteDownR;
//@property (assign) IBOutlet NSTextField *labelKnieDownL;
//@property (assign) IBOutlet NSTextField *labelKnieDownR;
//@property (assign) IBOutlet NSTextField *labelFussDownL;
//@property (assign) IBOutlet NSTextField *labelFussDownR;

- (NSString *) openSerialPort: (NSString *)serialPortFile baud: (speed_t)baudRate;
- (void)appendToIncomingText: (id) text;
- (void)incomingTextUpdateThread: (NSThread *) parentThread;
- (void) refreshSerialList: (NSString *) selectedText;
- (void) writeString: (NSString *) str;
- (void) writeByte: (uint8_t *) val;
- (IBAction) serialPortSelected: (id) cntrl;
- (IBAction) baudAction: (id) cntrl;
- (IBAction) refreshAction: (id) cntrl;
- (IBAction) sendText: (id) cntrl;
- (IBAction) sliderChange: (NSSlider *) sldr;
- (IBAction) hitAButton: (NSButton *) btn;
- (IBAction) hitBButton: (NSButton *) btn;
- (IBAction) hitCButton: (NSButton *) btn;
- (IBAction) resetButton: (NSButton *) btn;
- (IBAction)logSpeichernButton:(id)sender;
- (IBAction)logLadenButton:(id)sender;
- (IBAction)startpositionEinstellen:(id)sender;
- (IBAction)aktuelleLageSpeichern:(id)sender;
- (IBAction)gespeicherteLageLaden:(id)sender;

-(void)addTextToLogView:(NSString*)anhaengen;

-(void)changeArmLinks:(int)wert;
-(void)changeHuefteLinks:(int)wert;
-(void)changeKnieLinks:(int)wert;
-(void)changeFussLinks:(int)wert;
-(void)changeFussQuerLinks:(int)wert;

-(void)changeArmRechts:(int)wert;
-(void)changeHuefteRechts:(int)wert;
-(void)changeKnieRechts:(int)wert;
-(void)changeFussRechts:(int)wert;
-(void)changeFussQuerRechts:(int)wert;

-(void)showSuccessfulSaving;


@end
