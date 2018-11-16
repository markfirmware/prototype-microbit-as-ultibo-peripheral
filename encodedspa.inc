{$include encodedspa1.inc}
{$include encodedspa2.inc}
{$include encodedspa3.inc}
{$include encodedspa4.inc}
{$include encodedspa5.inc}

procedure BuildSpaBuffer;
begin
 Allocate(143586);
 AddPart1;
 AddPart2;
 AddPart3;
 AddPart4;
 AddPart5;
end;
