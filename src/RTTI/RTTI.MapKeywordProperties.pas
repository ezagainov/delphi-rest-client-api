unit RTTI.MapKeywordProperties;

interface

uses
  Classes, Windows;

type
  TKeywordMapper = class abstract
    class var
      FLock: TRTLCriticalSection;
      FKeyWordList: TStringList;
  public
    class function LockList: TStringList;
    class procedure UnlockList;
    //
    class procedure AddKeyWord(const AKeyWord, AReplaceKeyWord: string);
    class function MapPropertyName(const ASrcName: string): string;
  end;

implementation

uses
  SysUtils, StrUtils;

{ TKeywordMapper }

class procedure TKeywordMapper.AddKeyWord(const AKeyWord, AReplaceKeyWord: string);
begin
  LockList;
  try
    FKeyWordList.Values[AKeyWord] := AReplaceKeyWord;
  finally
    UnlockList;
  end;
end;

class function TKeywordMapper.LockList: TStringList;
begin
  EnterCriticalSection(FLock);
  Result := FKeyWordList;
end;

class function TKeywordMapper.MapPropertyName(const ASrcName: string): string;
var
  I: integer;
begin
  Result := ASrcName;
  LockList;
  try
    for I := 0 to FKeyWordList.Count - 1 do
    begin
      if AnsiSameStr(ASrcName, FKeyWordList.Names[I]) then
      begin
        result := FKeyWordList.Values[FKeyWordList.Names[I]];
        Exit;
      end;
      if AnsiSameStr(ASrcName, FKeyWordList.ValueFromIndex[I]) then
      begin
        result := FKeyWordList.Names[I];
        Exit;
      end;
    end;
  finally
    UnlockList;
  end;
end;

class procedure TKeywordMapper.UnlockList;
begin
  LeaveCriticalSection(FLock);
end;

initialization
  InitializeCriticalSection(TKeywordMapper.FLock);
  TKeywordMapper.FKeyWordList := TStringList.Create;

  TKeywordMapper.AddKeyWord('end', '_end');

finalization
  TKeywordMapper.LockList;
  try
    TKeywordMapper.FKeyWordList.Free;
  finally
    TKeywordMapper.UnlockList;
    DeleteCriticalSection(TKeywordMapper.FLock);
  end;

end.

