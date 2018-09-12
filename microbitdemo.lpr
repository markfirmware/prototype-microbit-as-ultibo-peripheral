program MicroBitDemo;
{$mode objfpc}{$modeswitch advancedrecords}{$H+}

uses 
{$ifdef BUILD_RPI } BCM2708,BCM2835, {$endif}
{$ifdef BUILD_RPI2} BCM2709,BCM2836, {$endif}
{$ifdef BUILD_RPI3} BCM2710,BCM2837, {$endif}
GlobalConfig,GlobalConst,GlobalTypes,Platform,Threads,SysUtils,Classes,Console,Logging,Ultibo,
Serial,DWCOTG,FileSystem,MMC,FATFS,Keyboard,bcmfw;

const 
 ScanUnitsPerSecond          = 1600;
 ScanInterval                = 1.000;
 ScanWindow                  = 0.250;

 HCI_COMMAND_PKT             = $01;
 HCI_EVENT_PKT               = $04;
 OGF_HOST_CONTROL            = $03;
 OGF_LE_CONTROL              = $08;
 OGF_VENDOR                  = $3f;
 LL_SCAN_PASSIVE             = $00;
 LL_SCAN_ACTIVE              = $01;

 ADV_IND                     = $00; // Connectable undirected advertising(default)
 ADV_DIRECT_IND_HI           = $01; // Connectable high duty cycle directed advertising
 ADV_SCAN_IND                = $02; // Scannable undirected advertising
 ADV_NONCONN_IND             = $03; // Non connectable undirected advertising
 ADV_DIRECT_IND_LO           = $04; // Connectable low duty cycle directed advertising

 // Advertising Data Types
 ADT_FLAGS                   = $01; // Flags
 ADT_INCOMPLETE_UUID16       = $02; // Incomplete List of 16-bit Service Class UUIDs
 ADT_COMPLETE_UUID16         = $03; // Complete List of 16-bit Service Class UUIDs
 ADT_INCOMPLETE_UUID32       = $04; // Incomplete List of 32-bit Service Class UUIDs
 ADT_COMPLETE_UUID32         = $05; // Complete List of 32-bit Service Class UUIDs
 ADT_INCOMPLETE_UUID128      = $06; // Incomplete List of 128-bit Service Class UUIDs
 ADT_COMPLETE_UUDI128        = $07; // Complete List of 128-bit Service Class UUIDs
 ADT_SHORTENED_LOCAL_NAME    = $08; // Shortened Local name
 ADT_COMPLETE_LOCAL_NAME     = $09; // Complete Local name
 ADT_POWER_LEVEL             = $0A; // Tx Power Level
 ADT_DEVICE_CLASS            = $0D; // Class of Device
 ADT_SERVICE_DATA            = $16; // Service data, starts with service uuid followed by data
 ADT_DEVICE_APPEARANCE       = $19; // Device appearance
 ADT_MANUFACTURER_SPECIFIC   = $FF;

 ManufacturerApple           = $004c;
 ManufacturerEstimote        = $015d;
 ManufacturerFlic            = $030f;
 ManufacturerLogitech        = $01da;
 ManufacturerMicrosoft       = $0006;
 ManufacturerTesting         = $ffff;

 BDADDR_LEN                  = 6;

type 
 TArrayOfByte = Array of Byte;
 PMicroBitPeripheral = ^TMicroBitPeripheral;
 TMicroBitPeripheral = record
  AddressString:String;
  ButtonCounter:Integer;
  ButtonChordStarted:Boolean;
 end;

var 
 MicroBitPeripherals:Array of TMicroBitPeripheral;
 ScanRxCount:Integer;
 BluetoothUartDeviceDescription:String;
 ScanCycleCounter:LongWord;
 ScanIdle:Boolean;
 ScanStartTime:LongWord;
 Margin:LongWord;
 ReadBackLog:Integer;
 LastDeviceStatus:LongWord;
 HciSequenceNumber:Integer = 0;
 ch:char;
 UART0:PSerialDevice = Nil;
 KeyboardLoopHandle:TThreadHandle = INVALID_HANDLE_VALUE;
 ReadByteCounter:Integer;

function ReadByte:Byte; forward;

procedure Log(S:String);
begin
 LoggingOutput(S);
end;

procedure RestoreBootFile(Prefix,FileName:String);
var 
 Source:String;
begin
 Source:=Prefix + '-' + FileName;
 Log(Format('Restoring from %s ...',[Source]));
 while not DirectoryExists('C:\') do
  sleep(500);
 if FileExists(Source) then
  CopyFile(PChar(Source),PChar(FileName),False);
 Log(Format('Restoring from %s done',[Source]));
end;

function ogf(op:Word):byte;
begin
 Result:=(op shr 10) and $3f;
end;

function ocf(op:Word):Word;
begin
 Result:=op and $3ff;
end;

function ErrToStr(code:byte):string;
begin
 case code of 
  $00:Result:='Success';
  $01:Result:='Unknown HCI Command';
  $02:Result:='Unknown Connection Identifier';
  $03:Result:='Hardware Failure';
  $04:Result:='Page Timeout';
  $05:Result:='Authentication Failure';
  $06:Result:='PIN or Key Missing';
  $07:Result:='Memory Capacity Exceeded';
  $08:Result:='Connection Timeout';
  $09:Result:='Connection Limit Exceeded';
  $0A:Result:='Synchronous Connection Limit To A Device Exceeded';
  $0B:Result:='ACL Connection Already Exists';
  $0C:Result:='Command Disallowed';
  $0D:Result:='Connection Rejected due to Limited Resources';
  $0E:Result:='Connection Rejected due To Security Reasons';
  $0F:Result:='Connection Rejected due to Unacceptable BD_ADDR';
  $10:Result:='Connection Accept Timeout Exceeded';
  $11:Result:='Unsupported Feature or Parameter Value';
  $12:Result:='Invalid HCI Command Parameters';
  $13:Result:='Remote User Terminated Connection';
  $14:Result:='Remote Device Terminated Connection due to Low Resources';
  $15:Result:='Remote Device Terminated Connection due to Power Off';
  $16:Result:='Connection Terminated By Local Host';
  $17:Result:='Repeated Attempts';
  $18:Result:='Pairing Not Allowed';
  $19:Result:='Unknown LMP PDU';
  $1A:Result:='Unsupported Remote Feature / Unsupported LMP Feature';
  $1B:Result:='SCO Offset Rejected';
  $1C:Result:='SCO Interval Rejected';
  $1D:Result:='SCO Air Mode Rejected';
  $1E:Result:='Invalid LMP Parameters / Invalid LL Parameters';
  $1F:Result:='Unspecified Error';
  $20:Result:='Unsupported LMP Parameter Value / Unsupported LL Parameter Value';
  $21:Result:='Role Change Not Allowed';
  $22:Result:='LMP Response Timeout / LL Response Timeout';
  $23:Result:='LMP Error Transaction Collision';
  $24:Result:='LMP PDU Not Allowed';
  $25:Result:='Encryption Mode Not Acceptable';
  $26:Result:='Link Key cannot be Changed';
  $27:Result:='Requested QoS Not Supported';
  $28:Result:='Instant Passed';
  $29:Result:='Pairing With Unit Key Not Supported';
  $2A:Result:='Different Transaction Collision';
  $2B:Result:='Reserved';
  $2C:Result:='QoS Unacceptable Parameter';
  $2D:Result:='QoS Rejected';
  $2E:Result:='Channel Classification Not Supported';
  $2F:Result:='Insufficient Security';
  $30:Result:='Parameter Out Of Mandatory Range';
  $31:Result:='Reserved';
  $32:Result:='Role Switch Pending';
  $33:Result:='Reserved';
  $34:Result:='Reserved Slot Violation';
  $35:Result:='Role Switch Failed';
  $36:Result:='Extended Inquiry Response Too Large';
  $37:Result:='Secure Simple Pairing Not Supported By Host';
  $38:Result:='Host Busy - Pairing';
  $39:Result:='Connection Rejected due to No Suitable Channel Found';
  $3A:Result:='Controller Busy';
  $3B:Result:='Unacceptable Connection Parameters';
  $3C:Result:='Directed Advertising Timeout';
  $3D:Result:='Connection Terminated due to MIC Failure';
  $3E:Result:='Connection Failed to be Established';
  $3F:Result:='MAC Connection Failed';
  $40:Result:='Coarse Clock Adjustment Rejected but Will Try to Adjust Using Clock';
 end;
end;

procedure Fail(Message:String);
begin
 raise Exception.Create(Message);
end;

procedure HciCommand(OpCode:Word; Params:array of byte);
var 
 i:integer;
 Cmd:array of byte;
 res,count:LongWord;
 PacketType,EventCode,PacketLength,CanAcceptPackets,Status:Byte;
 Acknowledged:Boolean;
begin
 Inc(HciSequenceNumber);
 // if OpCode <> $fc4c then
 //  Log(Format('hci %d op %04.4x',[HciSequenceNumber,OpCode]));
 SetLength(Cmd,length(Params) + 4);
 Cmd[0]:=HCI_COMMAND_PKT;
 Cmd[1]:=lo(OpCode);
 Cmd[2]:=hi(OpCode);
 Cmd[3]:=length(Params);
 for i:=0 to length(Params) - 1 do
  Cmd[4 + i]:=Params[i];
 count:=0;
 res:=SerialDeviceWrite(UART0,@Cmd[0],length(Cmd),SERIAL_WRITE_NONE,count);
 if res = ERROR_SUCCESS then
  begin
   Acknowledged:=False;
   while not Acknowledged do
    begin
     PacketType:=ReadByte;
     if PacketType <> HCI_EVENT_PKT then
      Fail(Format('event type not hci event: %d',[PacketType]));
     EventCode:=ReadByte;
     if EventCode = $0E then
      begin
       PacketLength:=ReadByte;
       if PacketLength <> 4 then
        Fail(Format('packet length not 4: %d',[PacketLength]));
       CanAcceptPackets:=ReadByte;
       if CanAcceptPackets <> 1 then
        Fail(Format('can accept packets not 1: %d',[CanAcceptPackets]));
       ReadByte; // completed command low
       ReadByte; // completed command high
       Status:=ReadByte;
       Acknowledged:=True;
      end
     else if EventCode = $0F then
           begin
            PacketLength:=ReadByte;
            if PacketLength <> 4 then
             Fail(Format('packet length not 4: %d',[PacketLength]));
            Status:=ReadByte;
            CanAcceptPackets:=ReadByte;
            if CanAcceptPackets <> 1 then
             Fail(Format('can accept packets not 1: %d',[CanAcceptPackets]));
            ReadByte; // completed command low
            ReadByte; // completed command high
            Acknowledged:=True;
           end
     else
      begin
       PacketLength:=ReadByte;
       Log(Format('HciCommand discarding event %d length %d',[EventCode,PacketLength]));
       for I:=1 to PacketLength do
        ReadByte;
       Sleep(5*1000);
       // Fail(Format('event code not command completed nor status: %02.2x',[EventCode]));
      end;
    end;
   if Status <> 0 then
    Fail(Format('status not 0: %d',[Status]));
  end
 else
  Log('Error writing to BT.');
end;

procedure HciCommand(OGF:byte; OCF:Word; Params:array of byte);
begin
 HciCommand((OGF shl 10) or OCF,Params);
end;

function EventReadFirstByte:Byte;
var 
 c:LongWord;
 b:Byte;
 res:Integer;
 Now:LongWord;
 EntryTime:LongWord;
begin
 Result:=0;
 EntryTime:=ClockGetCount;
 while LongWord(ClockGetCount - EntryTime) < 10*1000*1000 do
  begin
   Now:=ClockGetCount;
   c:=0;
   res:=SerialDeviceRead(UART0,@b,1,SERIAL_READ_NON_BLOCK,c);
   if (res = ERROR_SUCCESS) and (c = 1) then
    begin
     Result:=b;
     Inc(ReadByteCounter);
     if ScanIdle then
      begin
       ScanIdle:=False;
       ScanStartTime:=Now;
       ScanRxCount:=0;
       if (ScanCycleCounter >= 1) and (LongWord(Now - EntryTime) div 1000 < Margin) then
        begin
         Margin:=LongWord(Now - EntryTime) div 1000;
         LoggingOutput(Format('lowest available processing time between scans is now %5.3fs',[Margin / 1000]));
        end;
      end;
     Inc(ScanRxCount);
     exit;
    end
   else
    begin
     if (not ScanIdle) and (LongWord(Now - ScanStartTime)/(1*1000*1000)  > ScanWindow + 0.200)  then
      begin
       ScanIdle:=True;
       Inc(ScanCycleCounter);
      end;
     ThreadYield;
    end;
  end;
 Fail('timeout waiting for serial read byte');
end;

function ReadByte:Byte;
var 
 c:LongWord;
 b:Byte;
 res:Integer;
 EntryTime:LongWord;
 SerialStatus:LongWord;
begin
 Result:=0;
 EntryTime:=ClockGetCount;
 while LongWord(ClockGetCount - EntryTime) < 1*1000*1000 do
  begin
   c:=0;
   res:=SerialDeviceRead(UART0,@b,1,SERIAL_READ_NON_BLOCK,c);
   if (res = ERROR_SUCCESS) and (c = 1) then
    begin
     Result:=b;
     Inc(ReadByteCounter);
     res:=SerialDeviceRead(UART0,@b,1,SERIAL_READ_PEEK_BUFFER,c);
     if c > ReadBackLog then
      begin
       ReadBackLog:=c;
       LoggingOutput(Format('highest SERIAL_READ_PEEK_BUFFER is now %d',[ReadBackLog]));
      end;
     SerialStatus:=SerialDeviceStatus(UART0);
     SerialStatus:=SerialStatus and not (SERIAL_STATUS_RX_EMPTY or SERIAL_STATUS_TX_EMPTY);
     if SerialStatus <> LastDeviceStatus then
      begin
       LastDeviceStatus:=SerialStatus;
       LoggingOutput(Format('SerialDeviceStatus changed %08.8x',[SerialStatus]));
      end;
     exit;
    end
   else
    ThreadYield;
  end;
 Fail('timeout waiting for serial read byte');
end;

function IsBlueToothAvailable:Boolean;
begin
 Result:=True;
 Log(Format('Board is %s',[BoardTypeToString(BoardGetType)]));
 case BoardGetType of 
  BOARD_TYPE_RPI3B:
                   begin
                    BluetoothUartDeviceDescription:='BCM2837 PL011 UART';
                    PrepareBcmFirmware(0);
                   end;
  BOARD_TYPE_RPI3B_PLUS:
                        begin
                         BluetoothUartDeviceDescription:='BCM2837 PL011 UART';
                         PrepareBcmFirmware(1);
                        end;
  BOARD_TYPE_RPI_ZERO_W:
                        begin
                         BluetoothUartDeviceDescription:='BCM2835 PL011 UART';
                         PrepareBcmFirmware(0);
                        end;
  else
   begin
    Log('');
    Log('');
    Log('Bluetooth is not available on this board');
    Result:=False;
   end;
 end;
end;

function OpenUART0:boolean;
var 
 res:LongWord;
begin
 Result:=False;
 UART0:=SerialDeviceFindByDescription(BluetoothUartDeviceDescription);
 if UART0 = nil then
  begin
   Log('Can''t find UART0');
   exit;
  end;
 if BoardGetType = BOARD_TYPE_RPI_ZERO_W then
  res:=SerialDeviceOpen(UART0,115200,SERIAL_DATA_8BIT,SERIAL_STOP_1BIT,SERIAL_PARITY_NONE,SERIAL_FLOW_RTS_CTS,0,0)
 else
  res:=SerialDeviceOpen(UART0,115200,SERIAL_DATA_8BIT,SERIAL_STOP_1BIT,SERIAL_PARITY_NONE,SERIAL_FLOW_NONE,0,0);
 if res = ERROR_SUCCESS then
  begin
   Result:=True;
   ReadBackLog:=0;
   LastDeviceStatus:=0;

   GPIOFunctionSelect(GPIO_PIN_14,GPIO_FUNCTION_IN);
   GPIOFunctionSelect(GPIO_PIN_15,GPIO_FUNCTION_IN);

   GPIOFunctionSelect(GPIO_PIN_32,GPIO_FUNCTION_ALT3);     // TXD0
   GPIOFunctionSelect(GPIO_PIN_33,GPIO_FUNCTION_ALT3);     // RXD0
   GPIOPullSelect(GPIO_PIN_32,GPIO_PULL_NONE);             //Added
   GPIOPullSelect(GPIO_PIN_33,GPIO_PULL_UP);               //Added

   if BoardGetType = BOARD_TYPE_RPI_ZERO_W then
    begin
     GPIOFunctionSelect(GPIO_PIN_30,GPIO_FUNCTION_ALT3);     // RTS
     GPIOFunctionSelect(GPIO_PIN_31,GPIO_FUNCTION_ALT3);     // CTS
     GPIOPullSelect(GPIO_PIN_30,GPIO_PULL_UP);
     GPIOPullSelect(GPIO_PIN_31,GPIO_PULL_NONE);
    end;

   Sleep(50);
  end;
end;

procedure ResetChip;
begin
 HciCommand(OGF_HOST_CONTROL,$03,[]);
end;

procedure CloseUART0;
begin
 SerialDeviceClose(UART0);
 UART0:=Nil;
end;

procedure BCMLoadFirmware;
var 
 Params:array of byte;
 len:integer;
 Op:Word;
 Index:Integer;
 I:Integer;
 P:Pointer;
function GetByte:Byte;
begin
 Result:=PByte(P)^;
 Inc(P);
 Inc(Index);
end;
begin
 Log('Firmware load ...');
 HciCommand(OGF_VENDOR,$2e,[]);
 Index:=0;
 P:=BcmFirmwarePointer;
 while Index < BcmFirmwareLength do
  begin
   Op:=GetByte;
   Op:=Op or (GetByte shl 8);
   Len:=GetByte;
   SetLength(Params,Len);
   for I:= 0 to Len - 1 do
    Params[I]:=GetByte;
   HciCommand(Op,Params);
  end;
 CloseUart0;
 Sleep(50);
 OpenUart0;
 Sleep(50);
 Log('Firmware load done');
end;

procedure StartLogging;
begin
 LOGGING_INCLUDE_COUNTER:=False;
 LOGGING_INCLUDE_TICKCOUNT:=True;
 CONSOLE_REGISTER_LOGGING:=True;
 CONSOLE_LOGGING_POSITION:=CONSOLE_POSITION_FULL;
 LoggingConsoleDeviceAdd(ConsoleDeviceGetDefault);
 LoggingDeviceSetDefault(LoggingDeviceFindByType(LOGGING_TYPE_CONSOLE));
end;

procedure SetLEScanParameters(Type_:byte;Interval,Window:Word;OwnAddressType,FilterPolicy:byte);
begin
 HciCommand(OGF_LE_CONTROL,$0b,[Type_,lo(Interval),hi(Interval),lo(Window),hi(Window),OwnAddressType,FilterPolicy]);
end;

procedure SetLEScanEnable(State,Duplicates:boolean);
var 
 Params:Array of Byte;
begin
 SetLength(Params,2);
 if State then
  Params[0]:=$01
 else
  Params[0]:=$00;
 if Duplicates then
  Params[1]:=$01
 else
  Params[1]:=$00;
 HciCommand(OGF_LE_CONTROL,$0c,Params);
end;

procedure StartPassiveScanning;
begin
 SetLEScanParameters(LL_SCAN_PASSIVE,Round(ScanInterval*ScanUnitsPerSecond),Round(ScanWindow*ScanUnitsPerSecond),$00,$00);
 SetLEScanEnable(True,False);
end;

procedure StartActiveScanning;
begin
 SetLEScanParameters(LL_SCAN_ACTIVE,Round(ScanInterval*ScanUnitsPerSecond),Round(ScanWindow*ScanUnitsPerSecond),$00,$00);
 SetLEScanEnable(True,False);
end;

procedure StopScanning;
begin
 SetLEScanEnable(False,False);
end;

// le control
procedure SetLEEventMask(Mask:QWord);
var 
 Params:array of byte;
 MaskHi,MaskLo:DWord;
begin
 MaskHi:=(Mask shr 32) and $FFFFFFFF;
 MaskLo:=Mask and $FFFFFFFF;
 SetLength(Params,8);
 Params[0]:=MaskLo and $ff;   // lsb
 Params[1]:=(MaskLo shr 8) and $ff;
 Params[2]:=(MaskLo shr 16) and $ff;
 Params[3]:=(MaskLo shr 24) and $ff;
 Params[4]:=MaskHi and $ff;   // lsb
 Params[5]:=(MaskHi shr 8) and $ff;
 Params[6]:=(MaskHi shr 16) and $ff;
 Params[7]:=(MaskHi shr 24) and $ff;
 HciCommand(OGF_LE_CONTROL,$01,Params);
end;

procedure Help;
begin
 Log('');
 Log('H - Help - display this help message');
 Log('Q - Quit - use default-config.txt');
 Log('R - Restart - use bluetooth-dev-bluetoothtest-config.txt');
 Log('');
 Log('Legend');
 Log('R/P/? Random/Public/Other MAC Address');
 Log('C/D/S/N/R Connectable/Directed/Scannable/Non-connectable/Response Ad Event Type');
 Log('');
end;

function KeyboardLoop(Parameter:Pointer):PtrInt;
begin
 Result:=0;
 while True do
  begin
   if ConsoleGetKey(ch,nil) then
    case uppercase(ch) of 
     'H' : Help;
     'Q' : SystemRestart(0);
     'R' :
          begin
           RestoreBootFile('microbitdemo','config.txt');
           SystemRestart(0);
          end;
    end;
  end;
end;

function MacAddressTypeToStr(MacAddressType:Byte):String;
begin
 case MacAddressType of 
  $00:Result:='P';
  $01:Result:='R';
  else
   Result:='?';
 end;
end;

function AdEventTypeToStr(AdEventType:Byte):String;
begin
 case AdEventType of 
  $00:Result:='C';
  $01:Result:='D';
  $02:Result:='S';
  $03:Result:='N';
  $04:Result:='R';
  else
   Result:='?';
 end;
end;

function AsWord(Hi,Lo:Integer):Word;
begin
 Result:=(Hi shl 8) or Lo;
end;

function FindOrMakeMicroBitPeripheral(NewAddressString:String):PMicroBitPeripheral;
var 
 I:Integer;
begin
 Result:=Nil;
 for I:= 0 to High(MicroBitPeripherals) do
  if MicroBitPeripherals[I].AddressString = NewAddressString then
   Result:=@MicroBitPeripherals[I];
 if Result = nil then
  begin
   SetLength(MicroBitPeripherals,Length(MicroBitPeripherals) + 1);
   Result:=@MicroBitPeripherals[High(MicroBitPeripherals)];
   with Result^ do
    begin
     AddressString:=NewAddressString;
     ButtonCounter:=0;
     ButtonChordStarted:=False;
    end;
   Log('');
   Log(Format('detected new micro:bit peripheral %s',[NewAddressString]));
  end;
end;

procedure ParseEvent;
var 
 I:Integer;
 EventType,EventSubtype,EventLength:Byte;
 AdEventType,AddressType:Byte;
 Event:array of Byte;
 S:string;
 GetByteIndex:Integer;
 AddressString:string;
 MainType,MfrLo,MfrHi,SignatureLo,SignatureHi:Byte;
 AddressBytes:array[0 .. 5] of Byte;
 LeEventType:Byte;
 NewButtonCounter:Integer;
 ButtonMessage:String;
 CounterByte:Byte;
 MicroEventIndex:Integer;
 MicroEvent:Byte;
 MicroBitPeripheral:PMicroBitPeripheral;
function GetByte:Byte;
begin
 Result:=Event[GetByteIndex];
 Inc(GetByteIndex);
end;
begin
 EventType:=EventReadFirstByte;
 EventSubtype:=Readbyte;
 EventLength:=ReadByte;
 SetLength(Event,0);
 S:='';
 for I:=1 to EventLength - 1 do
  begin
   SetLength(Event,Length(Event) + 1);
   Event[I - 1]:=ReadByte;
   if I > 11 then
    begin
     S:=S + Event[I - 1].ToHexString(2);
     if I mod 4 = 3 then
      S:=S + ' ';
    end;
  end;
 ReadByte;
 if EventSubType <> $3e then
  begin
   Log(Format('ParseEvent type %02.2x subtype %02.2x length %d discarded',[EventType,EventSubType,EventLength]));
   Sleep(5*1000);
   exit;
  end;
 if S = '' then
  begin
   S:='(no data)';
   exit;
  end;
 GetByteIndex:=0;
 LeEventType:=GetByte;
 GetByte;
 if LeEventType <> $02 then
  begin
   Log(Format('ParseEvent le event type %02.2x length %d discarded',[LeEventType,EventLength]));
   Sleep(5*1000);
   exit;
  end;
 AdEventType:=GetByte;
 AddressType:=GetByte;
 AddressString:='';
 for I:=0 to 5 do
  begin
   AddressBytes[I]:=GetByte;
   AddressString:=AddressBytes[I].ToHexString(2) + AddressString;
  end;
 AddressString:=AddressString + MacAddressTypeToStr(AddressType) + AdEventTypeToStr(AdEventType);
 GetByte;
 GetByte;
 GetByte;
 GetByte;
 GetByte;
 MainType:=GetByte;
 MfrLo:=GetByte;
 MfrHi:=GetByte;
 SignatureLo:=GetByte;
 SignatureHi:=GetByte;
 if (MainType = $ff) and (AsWord(MfrHi,MfrLo) = Word(ManufacturerTesting)) and (AsWord(SignatureHi,Signaturelo) = $9755) then
  begin
   MicroBitPeripheral:=FindOrMakeMicroBitPeripheral(AddressString);
   GetByteIndex:=20;
   NewButtonCounter:=(GetByte - Ord('0'))*10;
   NewButtonCounter:=NewButtonCounter + (GetByte - Ord('0'));
   S:='';
   while GetByteIndex <= High(Event) do
    begin
     S:=S + Char(GetByte);
    end;
   if NewButtonCounter <> MicroBitPeripheral^.ButtonCounter then
    begin
     MicroBitPeripheral^.ButtonCounter:=NewButtonCounter;
     if not MicroBitPeripheral^.ButtonChordStarted then
      begin
       LoggingOutput('');
       MicroBitPeripheral^.ButtonChordStarted:=True;
      end;
     case S[1] of 
      '0':
          begin
           ButtonMessage:='Released    ';
           MicroBitPeripheral^.ButtonChordStarted:=False;
          end;
      '1': ButtonMessage:='A down      ';
      '2': ButtonMessage:='B down      ';
      '3': ButtonMessage:='A and B down';
      else ButtonMessage:='????????????';
     end;
     LoggingOutput(Format('micro:bit addr %s %s - %02.2d events, history: %s',[AddressString,ButtonMessage,MicroBitPeripheral^.ButtonCounter,S]));
    end;
  end
 else if (MainType = $ff) and (AsWord(MfrHi,MfrLo) = Word(ManufacturerTesting)) and (AsWord(SignatureHi,SignatureLo) = $9855) then
       begin
        MicroBitPeripheral:=FindOrMakeMicroBitPeripheral(AddressString);
        GetByteIndex:=20;
        CounterByte:=GetByte;
        NewbuttonCounter:=CounterByte and $7f;
        S:='';
        while GetByteIndex <= High(Event) do
         S:=S + Char(Ord('0') + (GetByte shr 6));
        while (MicroBitPeripheral^.ButtonCounter mod 128) <> NewButtonCounter do
         begin
          Inc(MicroBitPeripheral^.ButtonCounter);
          MicroEventIndex:=NewButtonCounter - (MicroBitPeripheral^.ButtonCounter mod 128);
          // Log(Format('counter %d new %d index %d %s',[MicroBitPeripheral^.ButtonCounter,NewButtonCounter,MicroEventIndex,S]));
          if MicroEventIndex < 0 then
           Inc(MicroEventIndex,128);
          if MicroEventIndex >= 21 then
           begin
            Log(Format('unable to reconstruct event %d index %d from %d %s',[MicroBitPeripheral^.ButtonCounter,MicroEventIndex,NewButtonCounter,S]));
            if (CounterByte and $80) = 0 then
             begin
              MicroBitPeripheral^.ButtonCounter:=NewButtonCounter;
              Log('the micro:bit seems to have restarted');
             end;
           end
          else
           begin
            GetByteIndex:=21 + MicroEventIndex;
            if not MicroBitPeripheral^.ButtonChordStarted then
             begin
              LoggingOutput('');
              MicroBitPeripheral^.ButtonChordStarted:=True;
             end;
            MicroEvent:=GetByte shr 6;
            case MicroEvent of 
             0:
               begin
                ButtonMessage:='Released    ';
                MicroBitPeripheral^.ButtonChordStarted:=False;
               end;
             1: ButtonMessage:='A down      ';
             2: ButtonMessage:='B down      ';
             3: ButtonMessage:='A and B down';
             else ButtonMessage:='????????????';
            end;
            LoggingOutput(Format('micro:bit addr %s event number %03.3d %s - history: %s',[AddressString,MicroBitPeripheral^.ButtonCounter,ButtonMessage,S]));
           end;
         end;
       end;
end;

begin
 RestoreBootFile('default','config.txt');
 StartLogging;
 Log('prototype-microbit-as-ultibo-peripheral');

 BeginThread(@KeyboardLoop,Nil,KeyboardLoopHandle,THREAD_STACK_DEFAULT_SIZE);
 Help;

 if IsBlueToothAvailable then
  begin
   ReadByteCounter:=0;
   OpenUart0;
   ResetChip;
   try
    BCMLoadFirmware;
   except
    on E:Exception do
         begin
          LoggingOutput(Format('load exception %s',[E.Message]));
         end;
  end;
 SetLEEventMask($ff);
 Log('Init complete');
 ScanCycleCounter:=0;
 ReadByteCounter:=0;
 SetLength(MicroBitPeripherals,0);
 while True do
  begin
   ReadBackLog:=0;
   Margin:=High(Margin);
   StartActiveScanning;
   Log('Receiving scan data');
   ScanIdle:=True;
   ScanRxCount:=0;
   while True do
    ParseEvent;
  end;
end;
ThreadHalt(0);
end.
