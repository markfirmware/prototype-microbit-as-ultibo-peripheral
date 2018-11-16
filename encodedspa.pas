unit EncodedSpa;
{$mode objfpc}{$H+}

interface

uses 
classes;

var 
 SpaBuffer:TStringStream;

procedure BuildSpaBuffer;

implementation

uses SysUtils;

procedure AddData(Data:Array of Byte);
var 
 I:Integer;
 S:String;
begin
 S:='';
 for I:=0 to High(Data) do
  S:=S + Char(Data[I]);
 SpaBuffer.WriteString(S);
end;

procedure Allocate(Len:Integer);
begin
 SpaBuffer:=TStringStream.Create;
end;

{$I encodedspa.inc}

end.
