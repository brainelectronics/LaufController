//
//  AppDelegate.m
//  LaufController
//
//  Created by Jonas Scharpf on 07.11.12.
//  Copyright (c) 2012 Jonas Scharpf. All rights reserved.
//

#import "AppDelegate.h"


@implementation AppDelegate

@synthesize drawDelegateFile;

@synthesize defaultValue;   //Nur am Anfang für die Labels genutzt, default 90°
@synthesize attrString;
@synthesize textStorage;

@synthesize labelArmDownL;
@synthesize labelArmDownR;
@synthesize labelHufteDownL;
@synthesize labelHufteDownR;
@synthesize labelKnieDownL;
@synthesize labelKnieDownR;
@synthesize labelFussDownL;
@synthesize labelFussDownR;
@synthesize labelDauerWert;
@synthesize labelEinzelWert;

@synthesize valueArmL;
@synthesize valueArmR;
@synthesize valueHufteL;
@synthesize valueHufteR;
@synthesize valueKnieL;
@synthesize valueKnieR;
@synthesize valueFussL;
@synthesize valueFussR;

@synthesize savingStatus;
@synthesize scrollViewLog;
@synthesize errorReportLabel;

@synthesize inputLogField;
@synthesize savedWindow = _savedWindow;
@synthesize buttonControl = _buttonControl;
@synthesize window;
@synthesize logWindow;

@synthesize huefteSliderLinks;
@synthesize knieSliderLinks;
@synthesize fussSliderLinks;

// executes after everything in the xib/nib is initiallized
- (void)awakeFromNib
{
	// we don't have a serial port open yet
	serialFileDescriptor = -1;
	readThreadRunning = FALSE;
	
	[self refreshSerialList:@"Select a Serial Port"];   //Liste der Ports erneuern
	
	//[serialInputField becomeFirstResponder];  //Setzt Cursor in Textfeld, ungünstig bei Steuerung über Tastatur
	
    defaultValue = @"90°";
    
    //Alle Labels werden mit "90°" versehen
    [labelArmDownL setStringValue:defaultValue];
    [labelArmDownR setStringValue:defaultValue];
    
    [labelHufteDownL setStringValue:defaultValue];
    [labelHufteDownR setStringValue:defaultValue];
    
    [labelKnieDownL setStringValue:defaultValue];
    [labelKnieDownR setStringValue:defaultValue];
    
    [labelFussDownL setStringValue:defaultValue];
    [labelFussDownR setStringValue:defaultValue];
    
    [labelDauerWert setStringValue:defaultValue];
    [labelEinzelWert setStringValue:defaultValue];
    
    //Die Anfangswerte der Servos werden gesetzt
    valueArmL = 90;
    valueArmR = 90;
    valueHufteL = 90;
    valueHufteR = 90;
    valueKnieL = 90;
    valueKnieR = 90;
    valueFussL = 90;
    valueFussR = 90;
}

// open the serial port
//   - nil is returned on success
//   - an error message is returned otherwise
- (NSString *) openSerialPort: (NSString *)serialPortFile baud: (speed_t)baudRate
{
	int success;
    
	// close the port if it is already open
	if (serialFileDescriptor != -1)
    {
		close(serialFileDescriptor);
		serialFileDescriptor = -1;
		
		// wait for the reading thread to die
		while(readThreadRunning);
		
		// re-opening the same port REALLY fast will fail spectacularly... better to sleep a sec
		sleep(0.5);
	}
	const char *bsdPath = [serialPortFile cStringUsingEncoding:NSUTF8StringEncoding];   //Konvertiert den Portstring in C um verwendbar zu machen
	
	// Hold the original termios attributes we are setting
	struct termios options;
	
	unsigned long mics = 3; //Verzögert den Input und zeigt erst dann den gesamten Sting an
	
	NSMutableString *errorMessage = nil;
	// open the port
	//     O_NONBLOCK causes the port to open without any delay (we'll block with another call)
	serialFileDescriptor = open(bsdPath, O_RDWR | O_NOCTTY | O_NONBLOCK );
	
    
	if (serialFileDescriptor == -1) //Fehler beim Öffnen des Ports
    {
        errorMessage = [NSMutableString stringWithString:@"Error: couldn't open serial port"];
    }
    else    //Erfolgreich geöffnet
    {
		// TIOCEXCL causes blocking of non-root processes on this serial-port
		success = ioctl(serialFileDescriptor, TIOCEXCL);
		if ( success == -1)
        {
            errorMessage = [NSMutableString stringWithString:@"Error: couldn't obtain lock on serial port"];
		}
        else
        {
			success = fcntl(serialFileDescriptor, F_SETFL, 0);
			if ( success == -1)
            {
                errorMessage = [NSMutableString stringWithString:@"Error: couldn't obtain lock on serial port"];
				// clear the O_NONBLOCK flag; all calls from here on out are blocking for non-root processes
				//errorMessage = @"Error: couldn't obtain lock on serial port";
			}
            else
            {
				// Get the current options and save them so we can restore the default settings later.
				success = tcgetattr(serialFileDescriptor, &gOriginalTTYAttrs);
				if ( success == -1)
                {
                    errorMessage = [NSMutableString stringWithString:@"Error: couldn't get serial attributes"];
					//errorMessage = @"Error: couldn't get serial attributes";
				}
                else
                {
					// copy the old termios settings into the current
					//   you want to do this so that you get all the control characters assigned
					options = gOriginalTTYAttrs;
                    
					/*
					 cfmakeraw(&options) is equivilent to:
					 options->c_iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON);
					 options->c_oflag &= ~OPOST;
					 options->c_lflag &= ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
					 options->c_cflag &= ~(CSIZE | PARENB);
					 options->c_cflag |= CS8;
					 */
					cfmakeraw(&options);
					
					// set tty attributes (raw-mode in this case)
					success = tcsetattr(serialFileDescriptor, TCSANOW, &options);
					if ( success == -1)
                    {
                        errorMessage = [NSMutableString stringWithString:@"Error: coudln't set serial attributes"];
						//errorMessage = @"Error: coudln't set serial attributes";
					}
                    else
                    {
						// Set baud rate (any arbitrary baud rate can be set this way)
						success = ioctl(serialFileDescriptor, IOSSIOSPEED, &baudRate);
						if ( success == -1)
                        {
                            errorMessage = [NSMutableString stringWithString:@"Error: Baud Rate out of bounds"];
							//errorMessage = @"Error: Baud Rate out of bounds";
						}
                        else
                        {
							// Set the receive latency (a.k.a. don't wait to buffer data)
							success = ioctl(serialFileDescriptor, IOSSDATALAT, &mics);
							if ( success == -1)
                            {
                                errorMessage = [NSMutableString stringWithString:@"Error: coudln't set serial latency"];
								//errorMessage = @"Error: coudln't set serial latency";
							}
						}
					}
				}
			}
		}
	}
    
	if ((serialFileDescriptor != -1) && (errorMessage != nil))  //Port öffen aber Problem, wird Port geschlossen
    {
		close(serialFileDescriptor);    //Schließt den Port
		serialFileDescriptor = -1;  //Erzeugt Fehler beim erneuten Durchlauf
	}
	
	return errorMessage;    //Gibt entsprechenden Fehler aus
}


- (void)appendToIncomingText: (id) text //Fügt zu aktuellem text den neuen übergebenen hinzu
{
    attrString = [[NSMutableAttributedString alloc] initWithString: text];  //Der zu hinzufügende String
    textStorage = [serialOutputArea textStorage];
	[textStorage beginEditing]; //beginnt den vorhandenen text zu ändern
	[textStorage appendAttributedString:attrString];    //Indem er den attrString hinzufügt
	[textStorage endEditing];   //Beendet das Editieren des Textes
	[attrString release];   //Löscht den Inhalt des angehängten Textes
	
	// scroll to the bottom
	NSRange myRange;
	myRange.length = 1;
	myRange.location = [textStorage length];
	[serialOutputArea scrollRangeToVisible:myRange];
}

// This selector/function will be called as another thread...
//  this thread will read from the serial port and exits when the port is closed
- (void)incomingTextUpdateThread: (NSThread *) parentThread
{
	
	// create a pool so we can use regular Cocoa stuff
	//   child threads can't re-use the parent's autorelease pool
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// mark that the thread is running
	readThreadRunning = TRUE;
	
	const int BUFFER_SIZE = 100;
	char byte_buffer[BUFFER_SIZE]; // buffer for holding incoming data
	int numBytes=0; // number of bytes read during read
	NSString *text; // incoming text from the serial port
	
	// assign a high priority to this thread
	[NSThread setThreadPriority:1.0];
	
	// this will loop unitl the serial port closes
	while(TRUE)
    {
		// read() blocks until some data is available or the port is closed
		numBytes = read(serialFileDescriptor, byte_buffer, BUFFER_SIZE); // read up to the size of the buffer
		if(numBytes>0)
        {
			// create an NSString from the incoming bytes (the bytes aren't null terminated)
			text = [NSString stringWithCString:byte_buffer length:numBytes];
			
			// this text can't be directly sent to the text area from this thread
			//  BUT, we can call a selctor on the main thread.
			[self performSelectorOnMainThread:@selector(appendToIncomingText:)
                                   withObject:text
                                waitUntilDone:YES];
		}
        else
        {
			break; // Stop the thread if there is an error
		}
	}
	
	// make sure the serial port is closed
	if (serialFileDescriptor != -1)
    {
		close(serialFileDescriptor);
		serialFileDescriptor = -1;
	}
	
	// mark that the thread has quit
	readThreadRunning = FALSE;
	
	// give back the pool
	[pool release];
}

- (void) refreshSerialList: (NSString *) selectedText
{
	io_object_t serialPort;
	io_iterator_t serialPortIterator;
	
	// remove everything from the pull down list
	[serialListPullDown removeAllItems];
	
	// ask for all the serial ports
	IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching(kIOSerialBSDServiceValue), &serialPortIterator);
	
	// loop through all the serial ports and add them to the array
	while (serialPort = IOIteratorNext(serialPortIterator))
    {
		[serialListPullDown addItemWithTitle:
         (NSString*)IORegistryEntryCreateCFProperty(serialPort, CFSTR(kIOCalloutDeviceKey),  kCFAllocatorDefault, 0)];
		IOObjectRelease(serialPort);
	}
	
	[serialListPullDown insertItemWithTitle:selectedText atIndex:0];    //Ändert den Text des Feldes zu dem des Ports
	[serialListPullDown selectItemAtIndex:0];
	
	IOObjectRelease(serialPortIterator);
}

#pragma mark - Send to port
// send a string to the serial port
- (void) writeString: (NSString *) str
{
	if(serialFileDescriptor!=-1)    //Es gibt kein Porblem mit dem Port
    {
		write(serialFileDescriptor, [str cStringUsingEncoding:NSUTF8StringEncoding], [str length]); //Schreibt an serialFileDescriptor die Daten [str cString...] der Länge [str length]
	}
    else
    {
		[self appendToIncomingText:@"\n ERROR:  Select a Serial Port from the pull-down menu\n"];
	}
}

- (void) writeByte: (uint8_t *) val
{
	if(serialFileDescriptor!=-1)    //Es gibt kein Problem mit dem Port
    {
		write(serialFileDescriptor, val, 1);
	}
    else
    {
		[self appendToIncomingText:@"\n ERROR:  Select a Serial Port from the pull-down menu\n"];
	}
}

#pragma mark - Input Log View
-(void)addTextToLogView:(NSString*)anhaengen
{
    NSString *aString = [[NSString alloc] init];
    aString = @"Hallo";
    
    [inputLogField setStringValue:aString];
    //[inputLogView setString:aString];
}

#pragma mark - Button
- (IBAction) serialPortSelected: (id) cntrl
{
    
	// open the serial port
	NSString *error = [self openSerialPort: [serialListPullDown titleOfSelectedItem] baud:[baudInputField intValue]];
	
	if(error!=nil)
    {
		[self refreshSerialList:error];
		[self appendToIncomingText:error];
	}
    else
    {
		[self refreshSerialList:[serialListPullDown titleOfSelectedItem]];
		[self performSelectorInBackground:@selector(incomingTextUpdateThread:) withObject:[NSThread currentThread]];
	}
}

// action from baud rate change
- (IBAction) baudAction: (id) cntrl
{
	if (serialFileDescriptor != -1)
    {
		speed_t baudRate = [baudInputField intValue];
		
		// if the new baud rate isn't possible, refresh the serial list
		//   this will also deselect the current serial port
		if(ioctl(serialFileDescriptor, IOSSIOSPEED, &baudRate)==-1) {
			[self refreshSerialList:@"Error: Baud Rate out of bounds"];
			[self appendToIncomingText:@"Error: Baud Rate out of bounds"];
		}
	}
}

// action from refresh button
- (IBAction) refreshAction: (id) cntrl
{
	[self refreshSerialList:@"Select a Serial Port"];
	
	// close serial port if open
	if (serialFileDescriptor != -1)
    {
		close(serialFileDescriptor);
		serialFileDescriptor = -1;
	}
}

// action from send button and on return in the text field
- (IBAction) sendText: (id) cntrl
{
	// send the text to the Arduino
	[self writeString:[serialInputField stringValue]];
	
	// blank the field
	//[serialInputField setTitleWithMnemonic:@""];
    [serialInputField setStringValue:@""];
}

// action from send button and on return in the text field
- (IBAction) sliderChange: (NSSlider *) sldr
{
	//uint8_t val = [sldr intValue];
    //[self writeByte:&val];

    NSString *newValue = [[NSString alloc] initWithFormat:@"%ld", [sldr integerValue]];  //Macht einen String aus dem Wert
    
    NSLog(@"Slider Value: %@",newValue);
    [labelDauerWert setStringValue:[[[NSString alloc] initWithString:newValue] stringByAppendingString:@"°"]];
    NSString *newString = [[[NSString alloc] initWithString:@"XX"] stringByAppendingString:newValue];
    [self writeString:newString];
}


// action from the A button
- (IBAction) hitAButton: (NSButton *) btn
{
	[self writeString:@"A"];
}

// action from the B button
- (IBAction) hitBButton: (NSButton *) btn
{
	[self writeString:@"B"];
}

// action from the C button
- (IBAction) hitCButton: (NSButton *) btn
{
	[self writeString:@"C"];
}

// action from the reset button
- (IBAction) resetButton: (NSButton *) btn
{
	// set and clear DTR to reset an arduino
	struct timespec interval = {0,100000000}, remainder;
	if(serialFileDescriptor!=-1)
    {
		ioctl(serialFileDescriptor, TIOCSDTR);
		nanosleep(&interval, &remainder); // wait 0.1 seconds
		ioctl(serialFileDescriptor, TIOCCDTR);
	}
}

#pragma mark - Read/Save Methods
- (IBAction)logSpeichernButton:(id)sender
{
    NSLog(@"Speichern…");
    
    NSString *dateString = [[NSString alloc] initWithString:[[NSDate date] descriptionWithCalendarFormat:@"%H:%M:%S Uhr %d-%m-%Y" timeZone:nil locale:nil]];
    NSLog(@"Datestring = %@", dateString);
    
    //NSString *string = [[NSString alloc] initWithString:[NSString stringWithFormat:@"Hallo Du"]];
    //NSLog(@"String = %@", string);
    
    NSString *myString = [NSString stringWithFormat:@"%@\n%@",dateString, textStorage];
    NSLog(@"%@",myString);
    
    NSSavePanel *savePanel	= [[NSSavePanel alloc] init];
    
    if ([savePanel runModal] == NSOKButton)
    {
        NSURL *selectedFileURL = [savePanel URL];
        NSURL *selectedDirectoryURL = [savePanel directoryURL];
        NSLog(@"File Name = %@", selectedFileURL);
        NSLog(@"Directory Name = %@", selectedDirectoryURL);
        
        NSError *error;
        BOOL writeResult = [myString writeToURL:selectedFileURL atomically:YES encoding:NSASCIIStringEncoding error:&error];
        if (! writeResult)
        {
            NSLog(@"Saving to Disk failed with error = %@", error);
        }
    }
    else if ([savePanel runModal] == NSCancelButton)
    {
        NSLog(@"Canceled");
    }
    else
    {
        NSLog(@"Unknown");
    }
}

- (IBAction)logLadenButton:(id)sender
{
    NSLog(@"Laden…");
    NSOpenPanel *openPanel = [[NSOpenPanel alloc] init];
    
    NSString *dateString = [[NSString alloc] initWithString:[[NSDate date] descriptionWithCalendarFormat:@"%H:%M:%S Uhr %d-%m-%Y" timeZone:nil locale:nil]];

    NSArray * arrayOfAllowedEnding = [NSArray arrayWithObject:@"txt"];
    [openPanel setAllowedFileTypes:arrayOfAllowedEnding];
    
    if ([openPanel runModal] == NSOKButton)
    {
        NSURL *selectedFileURL = [openPanel URL];
        NSURL *selectedDirectoryURL = [openPanel directoryURL];
        NSLog(@"File Name = %@", selectedFileURL);
        NSLog(@"Directory Name = %@", selectedDirectoryURL);
        
        //NSError *error;
        loadedTextFile = [NSString stringWithContentsOfURL:selectedFileURL encoding:NSASCIIStringEncoding error:NULL];
        NSLog(@"Content of text file =\n%@",loadedTextFile);

        NSString *stringLoadedMark = [[[[NSString alloc] initWithString:@"\n\n\nLoading File…\nFile Loaded successfully @"] stringByAppendingString:dateString] stringByAppendingString:@"\nThis file was saved "];
        [self appendToIncomingText:[stringLoadedMark stringByAppendingString:loadedTextFile]];
    }
    else if ([openPanel runModal] == NSCancelButton)
    {
        NSLog(@"Canceled");
    }
    else
    {
        NSLog(@"Unknown");
    }
}

- (IBAction)startpositionEinstellen:(id)sender
{
    valueArmL = 1;
    NSLog(@"Value Arm Links: 1");
    [self changeArmLinks:1];
    //[labelArmDownL setStringValue:[[NSString alloc] initWithString:@"1°"]];
    
    valueArmR = 178;
    NSLog(@"Value Arm Rechts: 178");
    [self changeArmRechts:178];
    //[labelArmDownR setStringValue:[[NSString alloc] initWithString:@"178°"]];
    
    valueHufteL = 41;
    NSLog(@"Value Hüfte Links: 41");
    [self changeHuefteLinks:41];
    //[labelHufteDownL setStringValue:[[NSString alloc] initWithString:@"41°"]];
    
    valueHufteR = 147;
    NSLog(@"Value Hüfte Rechts: 147");
    [self changeHuefteRechts:147];
    //[labelHufteDownR setStringValue:[[NSString alloc] initWithString:@"147°"]];
    
    valueKnieL = 39;
    NSLog(@"Value Knie Links: 39");
    [self changeKnieLinks:39];
    //[labelKnieDownL setStringValue:[[NSString alloc] initWithString:@"39°"]];
    
    valueKnieR = 149;
    NSLog(@"Value Knie Rechts: 149");
    [self changeKnieRechts:149];
    //[labelKnieDownR setStringValue:[[NSString alloc] initWithString:@"149°"]];
    
    valueFussL = 179;
    NSLog(@"Value Fuss Links: 179");
    [self changeFussLinks:179];
    //[labelFussDownL setStringValue:[[NSString alloc] initWithString:@"179°"]];
    
    valueFussR = 1;
    NSLog(@"Value Fuss Rechts: 1");
    [self changeFussRechts:1];
    //[labelFussDownR setStringValue:[[NSString alloc] initWithString:@"1°"]];
    
    /*
    NSString *stringArmLinks = [[NSString alloc] initWithString:@"LA1"];
    NSString *stringArmRechts = [[NSString alloc] initWithString:@"RA179"];
    NSString *stringHuefteLinks = [[NSString alloc] initWithString:@"LH41"];
    NSString *stringHuefteRechts = [[NSString alloc] initWithString:@"RH147"];
    NSString *stringKnieLinks = [[NSString alloc] initWithString:@"LK39"];
    NSString *stringKnieRechts = [[NSString alloc] initWithString:@"RK149"];
    NSString *stringFussLinks = [[NSString alloc] initWithString:@"LF179"];
    NSString *stringFussRechts = [[NSString alloc] initWithString:@"RF1"];    
    
    
    [self writeString:stringArmLinks];
    [self writeString:stringArmRechts];
    [self writeString:stringHuefteLinks];
    [self writeString:stringHuefteRechts];
    [self writeString:stringKnieLinks];
    [self writeString:stringKnieRechts];
    [self writeString:stringFussLinks];
    [self writeString:stringFussRechts];
     */
}

- (IBAction)aktuelleLageSpeichern:(id)sender
{
    NSLog(@"Aktuelle Lage Speichern…");
    
    NSString *dateString = [[NSString alloc] initWithString:[[NSDate date] descriptionWithCalendarFormat:@"%d-%m-%Y-%H-%M-%S" timeZone:nil locale:nil]];
    NSLog(@"Datestring = %@", dateString);
    
    //NSString *string = [[NSString alloc] initWithString:[NSString stringWithFormat:@"Hallo Du"]];
    //NSLog(@"String = %@", string);
    
    NSArray *stringArray = [[NSArray alloc] initWithObjects:[labelArmDownL stringValue], [labelArmDownR stringValue],[labelHufteDownL stringValue], [labelHufteDownR stringValue], [labelKnieDownL stringValue], [labelKnieDownR stringValue], [labelFussDownL stringValue], [labelFussDownR stringValue], nil];
    /*
    NSString *stringArmLinks = [[NSString alloc] init];
    stringArmLinks = [labelArmDownL stringValue];
    */
    
    NSString *content = [[NSString alloc] init];
    for (int i = 0; i<8; i++)
    {
        content = [[content stringByAppendingString:@"\n"]stringByAppendingString:[stringArray objectAtIndex:i]];
    }
    
    NSLog(@"gesamter String %@", content);
    
    //NSString *content = [NSString stringWithFormat:@"%@",dateString];
    //NSLog(@"%@",content);
    
    NSString *directroyString = [[NSString alloc] initWithString:@"file://localhost/Users/Jones/Documents/VICTOR/Aktuelle%20Lage/"];
    NSURL *savingDirectory = [[NSURL alloc] initWithString:[[[NSString alloc] initWithString:directroyString] stringByAppendingString:[dateString stringByAppendingString:@".txt"]]];
    //NSURL *savingDirectory = [[NSURL alloc] initWithString:@"file://localhost/Users/Jones/Documents/VICTOR/Aktuelle%20Lage/peter.txt"];
    NSLog(@"Directroy & Name = %@", savingDirectory);
    
    NSError *error;
    BOOL writeResult = [content writeToURL:savingDirectory atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (! writeResult)
    {
        NSLog(@"Saving to Disk failed with error = %@", error);
        NSString *errorString = [[NSString alloc] initWithFormat:@"%@",error];
        [savingStatus setStringValue:[[[NSString alloc] initWithString:@"Saving failed with error: %"]stringByAppendingString:errorString]];
    }
    [savingStatus setStringValue:@"Position successfully saved!"];
    [self showSuccessfulSaving];
}


- (IBAction)gespeicherteLageLaden:(id)sender
{
    NSLog(@"Aktulle Position Laden…");
    NSOpenPanel *openPanel = [[NSOpenPanel alloc] init];
        
    NSArray * arrayOfAllowedEnding = [NSArray arrayWithObject:@"txt"];
    [openPanel setAllowedFileTypes:arrayOfAllowedEnding];
    
    if ([openPanel runModal] == NSOKButton)
    {
        selectedOpenFileURL = [openPanel URL];
        selectedOpenDirectoryURL = [openPanel directoryURL];
        NSLog(@"File Name = %@", selectedOpenFileURL);
        NSLog(@"Directory Name = %@", selectedOpenDirectoryURL);
        
        NSError *error = [[NSError alloc] init];
        loadedTextFile = [NSString stringWithContentsOfURL:selectedOpenFileURL encoding:NSUTF8StringEncoding error:&error];
        //NSLog(@"Content of text file =\n%@",loadedTextFile);
    }
    else if ([openPanel runModal] == NSCancelButton)
    {
        NSLog(@"Loading Canceled");
    }
    else
    {
        NSLog(@"Unknown Error");
        NSLog(@"Consult Your Dealer");
        
    }
    

    NSArray *arrayOfNewLine = [[NSArray alloc] initWithArray:[loadedTextFile componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]];
    //allLinedStrings = [loadedTextFile componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    //NSLog(@"Seperated String 0: %@",[arrayOfNewLine objectAtIndex:0]);
    for (int i = 0; i <9; i++)
    {
        NSLog(@"Seperated String %i: %@", i, [arrayOfNewLine objectAtIndex:i]);
    }
    /*
     0  Arm Links
     1  Arm Rechts
     2  Hüfte Links
     3  Hüfte Rechts
     4  Knie Links
     5  Knie Rechts
     6  Fuß Links
     7  Fuß Rechts
     */
    
    int valueArmLinks = [[arrayOfNewLine objectAtIndex:1]intValue];
    [self changeArmLinks:valueArmLinks];
    
    int valueArmRechts = [[arrayOfNewLine objectAtIndex:2] intValue];
    [self changeArmRechts:valueArmRechts];
    
    int valueHuefteLinks = [[arrayOfNewLine objectAtIndex:3] intValue];
    [self changeHuefteLinks:valueHuefteLinks];
    
    int valueHuefteRechts = [[arrayOfNewLine objectAtIndex:4] intValue];
    [self changeHuefteRechts:valueHuefteRechts];
    
    int valueKnieLinks = [[arrayOfNewLine objectAtIndex:5] intValue];
    [self changeKnieLinks:valueKnieLinks];
    
    int valueKnieRechts = [[arrayOfNewLine objectAtIndex:6] intValue];
    [self changeKnieRechts:valueKnieRechts];
    
    int valueFussLinks = [[arrayOfNewLine objectAtIndex:7] intValue];
    [self changeFussLinks:valueFussLinks];
    
    int valueFussRechts = [[arrayOfNewLine objectAtIndex:8] intValue];
    [self changeFussRechts:valueFussRechts];
}


/*
- (IBAction)saveFile:(id)sender
{
    NSString *detPfad = @"/Users/Jones/Documents/Arduino Serial Jufo Log.txt";
    NSString *myString = [NSString alloc];
    NSString* dateString = [[NSDate date] descriptionWithCalendarFormat:@"%H:%M:%S Uhr %d-%m-%Y" timeZone:nil locale:nil];
    //NSLog(@"%@", dateString);
    myString = [NSString stringWithFormat:@"\n\n\n%@\n%@",dateString, textStorage];
    
    NSData *myData = [myString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSFileHandle *ausgabeDatei = [NSFileHandle fileHandleForWritingAtPath:detPfad];//fileHandleForUpdatingAtPath
    [ausgabeDatei seekToEndOfFile];
    [ausgabeDatei writeData:myData];
    [ausgabeDatei closeFile];
}
*/


#pragma mark - Linke Roboter Seite
#pragma mark - Arm


- (IBAction)armUpL:(id)sender
{
    if (valueArmL == 179) //Stoppt den Servo bei 179
    {
        NSBeep();   //Warnt den Benutzer
        valueArmL = 179;
    }
    else
    {
        valueArmL = valueArmL+1;    //Erhöht den Wert von valueArmL
        /*
        NSString *newValue = [[NSString alloc] initWithFormat:@"%d", valueArmL];  //Macht einen String aus dem Wert
        
        NSLog(@"Value Arm Links: %@",newValue);
        [labelArmDownL setStringValue:[[[NSString alloc] initWithString:newValue] stringByAppendingString:@"°"]];
        NSString *newString = [[[NSString alloc] initWithString:@"LA"] stringByAppendingString:newValue];
        [self writeString:newString];
         */
        [self changeArmLinks:valueArmL];
    }
}

- (IBAction)armDownL:(id)sender
{
    if (valueArmL == 0)
    {
        NSBeep();
        valueArmL = 0;
    }
    else
    {
        valueArmL = valueArmL-1;
        
        [self changeArmLinks:valueArmL];
    }
}

-(void)changeArmLinks:(int)wert
{
    NSString *newValue = [[NSString alloc] initWithFormat:@"%d", wert];  //Macht einen String aus dem Wert
    
    NSLog(@"Value Arm Links: %@",newValue);
    [labelArmDownL setStringValue:[[[NSString alloc] initWithString:newValue] stringByAppendingString:@"°"]];
    NSString *newString = [[[NSString alloc] initWithString:@"LA"] stringByAppendingString:newValue];
    [self writeString:newString];
}

#pragma mark - Hüfte
- (IBAction)hufteUpL:(id)sender
{
    if (valueHufteL == 179) //Stoppt den Servo bei 179
    {
        NSBeep();   //Warnt den Benutzer
        valueHufteL = 179;
    }
    else
    {
        valueHufteL = valueHufteL+1;    //Erhöht den Wert von valueHufteL
        /*
        NSString *newValue = [[NSString alloc] initWithFormat:@"%d", valueHufteL];  //Macht einen String aus dem Wert
        
        NSLog(@"Value Hüfte Links: %@",newValue);
        [labelHufteDownL setStringValue:[[[NSString alloc] initWithString:newValue] stringByAppendingString:@"°"]];
        NSString *newString = [[[NSString alloc] initWithString:@"LH"] stringByAppendingString:newValue];
        [self writeString:newString];
         */
        [self changeHuefteLinks:valueHufteL];
    }
}

- (IBAction)hufteDownL:(id)sender
{
    if (valueHufteL == 0)
    {
        NSBeep();
        valueHufteL = 0;
    }
    else
    {
        valueHufteL = valueHufteL-1;
        
        [self changeHuefteLinks:valueHufteL];
    }
}

-(void)changeHuefteLinks:(int)wert
{
    NSString *newValue = [[NSString alloc] initWithFormat:@"%d", wert];
    
    NSLog(@"Value Hüfte Links: %@",newValue);
    [labelHufteDownL setStringValue:[[[NSString alloc] initWithString:newValue] stringByAppendingString:@"°"]];
    NSString *newString = [[[NSString alloc] initWithString:@"LH"] stringByAppendingString:newValue];
    [self writeString:newString];

}

#pragma mark - Knie
- (IBAction)knieUpL:(id)sender
{
    if (valueKnieL == 179) //Stoppt den Servo bei 179
    {
        NSBeep();   //Warnt den Benutzer
        valueKnieL = 179;
    }
    else
    {
        valueKnieL = valueKnieL+1;    //Erhöht den Wert von valueKnieL
        /*
         NSString *newValue = [[NSString alloc] initWithFormat:@"%d", valueKnieL];
         
         NSLog(@"Value Knie Links: %@",newValue);
         [labelKnieDownL setStringValue:[[[NSString alloc] initWithString:newValue] stringByAppendingString:@"°"]];
         NSString *newString = [[[NSString alloc] initWithString:@"LK"] stringByAppendingString:newValue];
         [self writeString:newString];
         */
        [self changeKnieLinks:valueKnieL];
    }
    
}

- (IBAction)knieDownL:(id)sender
{
    if (valueKnieL == 0)
    {
        NSBeep();
        valueKnieL = 0;
    }
    else
    {
        valueKnieL = valueKnieL-1;
        
        [self changeKnieLinks:valueKnieL];
    }
}

-(void)changeKnieLinks:(int)wert
{
    NSString *newValue = [[NSString alloc] initWithFormat:@"%d", wert];
    
    NSLog(@"Value Knie Links: %@",newValue);
    [labelKnieDownL setStringValue:[[[NSString alloc] initWithString:newValue] stringByAppendingString:@"°"]];
    NSString *newString = [[[NSString alloc] initWithString:@"LK"] stringByAppendingString:newValue];
    [self writeString:newString];
}

#pragma mark - Fuß
- (IBAction)fussUpL:(id)sender
{
    if (valueFussL == 179) //Stoppt den Servo bei 179
    {
        NSBeep();   //Warnt den Benutzer
        valueFussL = 179;
    }
    else
    {
        valueFussL = valueFussL+1;    //Erhöht den Wert von valueHufteL
        /*
        NSString *newValue = [[NSString alloc] initWithFormat:@"%d", valueFussL];  //Macht einen String aus dem Wert
        
        NSLog(@"Value Fuß Links: %@",newValue);
        [labelFussDownL setStringValue:[[[NSString alloc] initWithString:newValue] stringByAppendingString:@"°"]];
        NSString *newString = [[[NSString alloc] initWithString:@"LF"] stringByAppendingString:newValue];
        [self writeString:newString];
         */
        [self changeFussLinks:valueFussL];
    }
}

- (IBAction)fussDownL:(id)sender
{
    if (valueFussL == 0)
    {
        NSBeep();
        valueFussL = 0;
    }
    else
    {
        valueFussL = valueFussL-1;
        
        [self changeFussLinks:valueFussL];
    }
}

-(void)changeFussLinks:(int)wert
{
    NSString *newValue = [[NSString alloc] initWithFormat:@"%d", wert];
    
    NSLog(@"Value Fuß Links: %@",newValue);
    [labelFussDownL setStringValue:[[[NSString alloc] initWithString:newValue] stringByAppendingString:@"°"]];
    NSString *newString = [[[NSString alloc] initWithString:@"LF"] stringByAppendingString:newValue];
    [self writeString:newString];
}



#pragma mark - Rechte Roboter Seite
#pragma mark - Arm
- (IBAction)armUpR:(id)sender
{
    if (valueArmR == 179) //Stoppt den Servo bei 179
    {
        NSBeep();   //Warnt den Benutzer
        valueArmR = 179;
    }
    else
    {
        valueArmR = valueArmR+1;    //Erhöht den Wert von valueArmR
        /*
        NSString *newValue = [[NSString alloc] initWithFormat:@"%d", valueArmR];  //Macht einen String aus dem Wert
        
        NSLog(@"Value Arm Rechts: %@",newValue);
        [labelArmDownR setStringValue:[[[NSString alloc] initWithString:newValue] stringByAppendingString:@"°"]];
        NSString *newString = [[[NSString alloc] initWithString:@"RA"] stringByAppendingString:newValue];
        [self writeString:newString];
         */
        [self changeArmRechts:valueArmR];
    }
}

- (IBAction)armDownR:(id)sender
{
    if (valueArmR == 0)
    {
        NSBeep();
        valueArmR = 0;
    }
    else
    {
        valueArmR = valueArmR-1;
        [self changeArmRechts:valueArmR];
    }
}

-(void)changeArmRechts:(int)wert
{
    NSString *newValue = [[NSString alloc] initWithFormat:@"%d", wert];  //Macht einen String aus dem Wert
    
    NSLog(@"Value Arm Rechts: %@",newValue);
    [labelArmDownR setStringValue:[[[NSString alloc] initWithString:newValue] stringByAppendingString:@"°"]];
    NSString *newString = [[[NSString alloc] initWithString:@"RA"] stringByAppendingString:newValue];
    [self writeString:newString];
}

#pragma mark - Hüfte
- (IBAction)hufteUpR:(id)sender
{
    if (valueHufteR == 179) //Stoppt den Servo bei 179
    {
        NSBeep();   //Warnt den Benutzer
        valueHufteR = 179;
    }
    else
    {
        valueHufteR = valueHufteR+1;    //Erhöht den Wert von valueHufteR
        /*
        NSString *newValue = [[NSString alloc] initWithFormat:@"%d", valueHufteR];  //Macht einen String aus dem Wert
        
        NSLog(@"Value Hüfte rechts: %@",newValue);
        [labelHufteDownR setStringValue:[[[NSString alloc] initWithString:newValue] stringByAppendingString:@"°"]];
        NSString *newString = [[[NSString alloc] initWithString:@"RH"] stringByAppendingString:newValue];
        [self writeString:newString];
         */
        [self changeHuefteRechts:valueHufteR];
    }
}

- (IBAction)hufteDownR:(id)sender
{
    if (valueHufteR == 0)
    {
        NSBeep();
        valueHufteR = 0;
    }
    else
    {
        valueHufteR = valueHufteR-1;
        [self changeHuefteRechts:valueHufteR];
    }
}

-(void)changeHuefteRechts:(int)wert
{
    NSString *newValue = [[NSString alloc] initWithFormat:@"%d", wert];  //Macht einen String aus dem Wert
    
    NSLog(@"Value Hüfte rechts: %@",newValue);
    [labelHufteDownR setStringValue:[[[NSString alloc] initWithString:newValue] stringByAppendingString:@"°"]];
    NSString *newString = [[[NSString alloc] initWithString:@"RH"] stringByAppendingString:newValue];
    [self writeString:newString];
}

#pragma mark - Knie
- (IBAction)knieUpR:(id)sender
{
    if (valueKnieR == 179) //Stoppt den Servo bei 179
    {
        NSBeep();   //Warnt den Benutzer
        valueKnieR = 179;
    }
    else
    {
        valueKnieR = valueKnieR+1;    //Erhöht den Wert von valueKnieR
        /*
        NSString *newValue = [[NSString alloc] initWithFormat:@"%d", valueKnieR];  //Macht einen String aus dem Wert
        
        NSLog(@"Value Knie rechts: %@",newValue);
        [labelKnieDownR setStringValue:[[[NSString alloc] initWithString:newValue] stringByAppendingString:@"°"]];
        NSString *newString = [[[NSString alloc] initWithString:@"RK"] stringByAppendingString:newValue];
        [self writeString:newString];
         */
        [self changeKnieRechts:valueKnieR];
    }
    
}

- (IBAction)knieDownR:(id)sender
{
    if (valueKnieR == 0)
    {
        NSBeep();
        valueKnieR = 0;
    }
    else
    {
        valueKnieR = valueKnieR-1;
        [self changeKnieRechts:valueKnieR];
    }
}

-(void)changeKnieRechts:(int)wert
{
    NSString *newValue = [[NSString alloc] initWithFormat:@"%d", wert];
    
    NSLog(@"Value Knie rechts: %@",newValue);
    [labelKnieDownR setStringValue:[[[NSString alloc] initWithString:newValue] stringByAppendingString:@"°"]];
    NSString *newString = [[[NSString alloc] initWithString:@"RK"] stringByAppendingString:newValue];
    [self writeString:newString];
}

#pragma mark - Fuß
- (IBAction)fussUpR:(id)sender
{
    if (valueFussR == 179) //Stoppt den Servo bei 179
    {
        NSBeep();   //Warnt den Benutzer
        valueFussR = 179;
    }
    else
    {
        valueFussR = valueFussR+1;    //Erhöht den Wert von valueHufteL
        /*
        NSString *newValue = [[NSString alloc] initWithFormat:@"%d", valueFussR];  //Macht einen String aus dem Wert
        
        NSLog(@"Value Fuß rechts: %@",newValue);
        [labelFussDownR setStringValue:[[[NSString alloc] initWithString:newValue] stringByAppendingString:@"°"]];
        NSString *newString = [[[NSString alloc] initWithString:@"RF"] stringByAppendingString:newValue];
        [self writeString:newString];
         */
        [self changeFussRechts:valueFussR];
    }
    
}

- (IBAction)fussDownR:(id)sender
{
    if (valueFussR == 0)
    {
        NSBeep();
        valueFussR = 0;
    }
    else
    {
        valueFussR = valueFussR-1;
        [self changeFussRechts:valueFussR];
    }
}

-(void)changeFussRechts:(int)wert
{
    NSString *newValue = [[NSString alloc] initWithFormat:@"%d", wert];  //Macht einen String aus dem Wert
    
    NSLog(@"Value Fuß rechts: %@",newValue);
    [labelFussDownR setStringValue:[[[NSString alloc] initWithString:newValue] stringByAppendingString:@"°"]];
    NSString *newString = [[[NSString alloc] initWithString:@"RF"] stringByAppendingString:newValue];
    [self writeString:newString];
}
/*
- (IBAction)openButtonWindow:(id)sender
{
    //NSWindowController *controllerWindow = [[NSWindowController alloc] initWithWindowNibName:@"ButtonControl"];
    NSWindowController *controllerWindow  = [[NSWindowController alloc] initWithWindow:@"ButtonControl"];
    [controllerWindow showWindow:self];

    NSWindowController* yourWindowController = [[NSWindowController alloc] initWithWindowNibName:@"ButtonControl"];
    [yourWindowController showWindow:self];

    NSWindowController *yourWindowController = [NSWindowController alloc];
    //[yourWindowController showWindow:self];
    [yourWindowController showWindow:_buttonControl];
}
*/
/*
- (IBAction)saveArduinoOutput:(id)sender
{
    
}
 */

- (IBAction)endTheSheet:(id)sender
{
    [NSApp endSheet:theSheet];
    [theSheet orderOut:sender];
}

-(void)showSuccessfulSaving
{
    [NSApp beginSheet:theSheet modalForWindow:(NSWindow*)_savedWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
}
/*
-(void)showErrorReport
{
    [NSApp beginSheet:errorReportSheet modalForWindow:<#(NSWindow *)#> modalDelegate:<#(id)#> didEndSelector:<#(SEL)#> contextInfo:<#(void *)#>]
}
*/
@end









/*
@implementation AppDelegate

@synthesize aString;
@synthesize echoString;
@synthesize defaultValue;

@synthesize labelHufteDownL;
@synthesize labelHufteDownR;
@synthesize labelKnieDownL;
@synthesize labelKnieDownR;
@synthesize labelFussDownL;
@synthesize labelFussDownR;

@synthesize valueHufteL;
@synthesize valueHufteR;
@synthesize valueKnieL;
@synthesize valueKnieR;
@synthesize valueFussL;
@synthesize valueFussR;

- (void)dealloc
{
    [super dealloc];
    
    [labelHufteDownL release];
    [labelHufteDownR release];
    [labelKnieDownL release];
    [labelKnieDownR release];
    [labelFussDownL release];
    [labelFussDownR release];
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    defaultValue = @"90°";
    [labelHufteDownL setStringValue:defaultValue];
    [labelHufteDownR setStringValue:defaultValue];
    
    [labelKnieDownL setStringValue:defaultValue];
    [labelKnieDownR setStringValue:defaultValue];
    
    [labelFussDownL setStringValue:defaultValue];
    [labelFussDownR setStringValue:defaultValue];
    
    aString = [[NSString alloc] initWithString:@" > /dev/tty.usbmodem1411"];   //Pfad ändern
    echoString = [[NSString alloc] initWithString:@"echo"];
    valueHufteL = 90;
    valueHufteR = 90;
    valueKnieL = 90;
    valueKnieR = 90;
    valueFussL = 90;
    valueFussR = 90;
}

- (IBAction)hufteUpL:(id)sender
{
    if (valueHufteL == 179) //Stoppt den Servo bei 179
    {
        NSBeep();   //Warnt den Benutzer
        valueHufteL = 179;
    }
    else
    {
        valueHufteL = valueHufteL+1;    //Erhöht den Wert von valueHufteL
        NSString *newValue = [[NSString alloc] initWithFormat:@"%d", valueHufteL];  //Macht einen String aus dem Wert
    
        NSLog(@"Value Hüfte Links: %@",newValue);
        [labelHufteDownL setStringValue:[[[NSString alloc] initWithString:newValue] stringByAppendingString:@"°"]];
    
        NSString *toSend = [[[[NSString alloc] initWithString:@"echo LH"]
                         stringByAppendingString:newValue]
                            stringByAppendingString:aString];
    
        const char *toCSend =[toSend UTF8String];  //Konvertiert NSString zu UTF8String, verwendbar mit popen()
        popen(toCSend, "r");
        NSLog(@"Gesendet: %s", toCSend);
    }
}

- (IBAction)hufteUpR:(id)sender
{
    if (valueHufteR == 179) //Stoppt den Servo bei 179
    {
        NSBeep();   //Warnt den Benutzer
        valueHufteR = 179;
    }
    else
    {
        valueHufteR = valueHufteR+1;    //Erhöht den Wert von valueHufteR
        NSString *newValue = [[NSString alloc] initWithFormat:@"%d", valueHufteR];  //Macht einen String aus dem Wert
        
        NSLog(@"Value Hüfte rechts: %@",newValue);
        [labelHufteDownR setStringValue:[[[NSString alloc] initWithString:newValue] stringByAppendingString:@"°"]];
        
        NSString *toSend = [[[[NSString alloc] initWithString:@"echo RH"]
                             stringByAppendingString:newValue]
                            stringByAppendingString:aString];
        
        const char *toCSend =[toSend UTF8String];  //Konvertiert NSString zu UTF8String, verwendbar mit popen()
        popen(toCSend, "r");
        NSLog(@"Gesendet: %s", toCSend);
    }
}

- (IBAction)hufteDownL:(id)sender
{
    if (valueHufteL == 0)
    {
        NSBeep();
        valueHufteL = 0;
    }
    else
    {
        valueHufteL = valueHufteL-1;
        NSString *newValue = [[NSString alloc] initWithFormat:@"%d", valueHufteL];
        
        NSLog(@"Value Hüfte Links: %@",newValue);
        [labelHufteDownL setStringValue:[[[NSString alloc] initWithString:newValue] stringByAppendingString:@"°"]];
        
        NSString *toSend = [[[[NSString alloc] initWithString:@"echo LH"]
                             stringByAppendingString:newValue]
                                stringByAppendingString:aString];
        
        const char *toCSend =[toSend UTF8String];  //Konvertiert NSString zu UTF8String, verwendbar mit popen()
        popen(toCSend, "r");
        NSLog(@"Gesendet: %s", toCSend);
    }
}

- (IBAction)hufteDownR:(id)sender
{
    if (valueHufteR == 0)
    {
        NSBeep();
        valueHufteR = 0;
    }
    else
    {
        valueHufteR = valueHufteR-1;
        NSString *newValue = [[NSString alloc] initWithFormat:@"%d", valueHufteR];
        
        NSLog(@"Value Hüfte rechts: %@",newValue);
        [labelHufteDownR setStringValue:[[[NSString alloc] initWithString:newValue] stringByAppendingString:@"°"]];
        
        NSString *toSend = [[[[NSString alloc] initWithString:@"echo RH"]
                             stringByAppendingString:newValue]
                            stringByAppendingString:aString];
        
        const char *toCSend =[toSend UTF8String];  //Konvertiert NSString zu UTF8String, verwendbar mit popen()
        popen(toCSend, "r");
        NSLog(@"Gesendet: %s", toCSend);
    }
}

- (IBAction)knieUpL:(id)sender
{
    if (valueKnieL == 179) //Stoppt den Servo bei 179
    {
        NSBeep();   //Warnt den Benutzer
        valueKnieL = 179;
    }
    else
    {
        valueKnieL = valueKnieL+1;    //Erhöht den Wert von valueKnieL
        NSString *newValue = [[NSString alloc] initWithFormat:@"%d", valueKnieL];  //Macht einen String aus dem Wert
        
        NSLog(@"Value Knie Links: %@",newValue);
        [labelKnieDownL setStringValue:[[[NSString alloc] initWithString:newValue] stringByAppendingString:@"°"]];
        
        NSString *toSend = [[[[NSString alloc] initWithString:@"echo LK"]
                             stringByAppendingString:newValue]
                            stringByAppendingString:aString];
        
        const char *toCSend =[toSend UTF8String];  //Konvertiert NSString zu UTF8String, verwendbar mit popen()
        popen(toCSend, "r");
        NSLog(@"Gesendet: %s", toCSend);
    }

}

- (IBAction)knieUpR:(id)sender
{
    if (valueKnieR == 179) //Stoppt den Servo bei 179
    {
        NSBeep();   //Warnt den Benutzer
        valueKnieR = 179;
    }
    else
    {
        valueKnieR = valueKnieR+1;    //Erhöht den Wert von valueKnieR
        NSString *newValue = [[NSString alloc] initWithFormat:@"%d", valueKnieR];  //Macht einen String aus dem Wert
        
        NSLog(@"Value Knie rechts: %@",newValue);
        [labelKnieDownR setStringValue:[[[NSString alloc] initWithString:newValue] stringByAppendingString:@"°"]];
        
        NSString *toSend = [[[[NSString alloc] initWithString:@"echo RK"]
                             stringByAppendingString:newValue]
                            stringByAppendingString:aString];
        
        const char *toCSend =[toSend UTF8String];  //Konvertiert NSString zu UTF8String, verwendbar mit popen()
        popen(toCSend, "r");
        NSLog(@"Gesendet: %s", toCSend);
    }
}

- (IBAction)knieDownL:(id)sender
{
    if (valueKnieL == 0)
    {
        NSBeep();
        valueKnieL = 0;
    }
    else
    {
        valueKnieL = valueKnieL-1;
        NSString *newValue = [[NSString alloc] initWithFormat:@"%d", valueKnieL];
        
        NSLog(@"Value Knie Links: %@",newValue);
        [labelKnieDownL setStringValue:[[[NSString alloc] initWithString:newValue] stringByAppendingString:@"°"]];
        
        NSString *toSend = [[[[NSString alloc] initWithString:@"echo LK"]
                             stringByAppendingString:newValue]
                            stringByAppendingString:aString];
        
        const char *toCSend =[toSend UTF8String];  //Konvertiert NSString zu UTF8String, verwendbar mit popen()
        popen(toCSend, "r");
        NSLog(@"Gesendet: %s", toCSend);
    }
}

- (IBAction)knieDownR:(id)sender
{
    if (valueKnieR == 0)
    {
        NSBeep();
        valueKnieR = 0;
    }
    else
    {
        valueKnieR = valueKnieR-1;
        NSString *newValue = [[NSString alloc] initWithFormat:@"%d", valueKnieR];
        
        NSLog(@"Value Knie rechts: %@",newValue);
        [labelKnieDownR setStringValue:[[[NSString alloc] initWithString:newValue] stringByAppendingString:@"°"]];
        
        NSString *toSend = [[[[NSString alloc] initWithString:@"echo RK"]
                             stringByAppendingString:newValue]
                            stringByAppendingString:aString];
        
        const char *toCSend =[toSend UTF8String];  //Konvertiert NSString zu UTF8String, verwendbar mit popen()
        popen(toCSend, "r");
        NSLog(@"Gesendet: %s", toCSend);
    }
}

- (IBAction)fussUpL:(id)sender
{
    if (valueFussL == 179) //Stoppt den Servo bei 179
    {
        NSBeep();   //Warnt den Benutzer
        valueFussL = 179;
    }
    else
    {
        valueFussL = valueFussL+1;    //Erhöht den Wert von valueHufteL
        NSString *newValue = [[NSString alloc] initWithFormat:@"%d", valueFussL];  //Macht einen String aus dem Wert
        
        NSLog(@"Value Fuß Links: %@",newValue);
        [labelFussDownL setStringValue:[[[NSString alloc] initWithString:newValue] stringByAppendingString:@"°"]];
        
        NSString *toSend = [[[[NSString alloc] initWithString:@"echo LF"]
                             stringByAppendingString:newValue]
                            stringByAppendingString:aString];
        
        const char *toCSend =[toSend UTF8String];  //Konvertiert NSString zu UTF8String, verwendbar mit popen()
        popen(toCSend, "r");
        NSLog(@"Gesendet: %s", toCSend);
    }

}

- (IBAction)fussUpR:(id)sender
{
    if (valueFussR == 179) //Stoppt den Servo bei 179
    {
        NSBeep();   //Warnt den Benutzer
        valueFussR = 179;
    }
    else
    {
        valueFussR = valueFussR+1;    //Erhöht den Wert von valueHufteL
        NSString *newValue = [[NSString alloc] initWithFormat:@"%d", valueFussR];  //Macht einen String aus dem Wert
        
        NSLog(@"Value Fuß rechts: %@",newValue);
        [labelFussDownR setStringValue:[[[NSString alloc] initWithString:newValue] stringByAppendingString:@"°"]];
        
        NSString *toSend = [[[[NSString alloc] initWithString:@"echo RF"]
                             stringByAppendingString:newValue]
                            stringByAppendingString:aString];
        
        const char *toCSend =[toSend UTF8String];  //Konvertiert NSString zu UTF8String, verwendbar mit popen()
        popen(toCSend, "r");
        NSLog(@"Gesendet: %s", toCSend);
    }

}

- (IBAction)fussDownL:(id)sender
{
    if (valueFussL == 0)
    {
        NSBeep();
        valueFussL = 0;
    }
    else
    {
        valueFussL = valueFussL-1;
        NSString *newValue = [[NSString alloc] initWithFormat:@"%d", valueFussL];
        
        NSLog(@"Value Fuß Links: %@",newValue);
        [labelFussDownL setStringValue:[[[NSString alloc] initWithString:newValue] stringByAppendingString:@"°"]];
        
        NSString *toSend = [[[[NSString alloc] initWithString:@"echo LF"]
                             stringByAppendingString:newValue]
                            stringByAppendingString:aString];
        
        const char *toCSend =[toSend UTF8String];  //Konvertiert NSString zu UTF8String, verwendbar mit popen()
        popen(toCSend, "r");
        NSLog(@"Gesendet: %s", toCSend);
    }
}

- (IBAction)fussDownR:(id)sender
{
    if (valueFussR == 0)
    {
        NSBeep();
        valueFussR = 0;
    }
    else
    {
        valueFussR = valueFussR-1;
        NSString *newValue = [[NSString alloc] initWithFormat:@"%d", valueFussR];
        
        NSLog(@"Value Fuß rechts: %@",newValue);
        [labelFussDownR setStringValue:[[[NSString alloc] initWithString:newValue] stringByAppendingString:@"°"]];
        
        NSString *toSend = [[[[NSString alloc] initWithString:@"echo RF"]
                             stringByAppendingString:newValue]
                            stringByAppendingString:aString];
        
        const char *toCSend =[toSend UTF8String];  //Konvertiert NSString zu UTF8String, verwendbar mit popen()
        popen(toCSend, "r");
        NSLog(@"Gesendet: %s", toCSend);
    }
}


@end
 */
