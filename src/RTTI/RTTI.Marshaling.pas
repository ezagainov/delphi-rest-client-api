unit RTTI.Marshaling;

interface

uses
  TypInfo, SuperObject, Classes, RTTI.Enumeration, RTTI.EnumerationObjectHelper, RTTI.MapKeywordProperties;

type
  TOldRttiMarshal = class
  protected
    function ToClass(AObject: TObject): ISuperObject;
    function ToCollection(AObject: TObject): ISuperObject;
    function ToList(AList: TList): ISuperObject;
    function ToInteger(AObject: TObject; APropInfo: PPropInfo): ISuperObject;
    function ToInt64(AObject: TObject; APropInfo: PPropInfo): ISuperObject;
    function ToFloat(AObject: TObject; APropInfo: PPropInfo): ISuperObject;
    function ToJsonString(AObject: TObject; APropInfo: PPropInfo): ISuperObject;
    function ToChar(AObject: TObject; APropInfo: PPropInfo): ISuperObject;
  public
    class function ToJson(AObject: TObject): ISuperObject;
  end;

  TOldRttiMarshalProviderClass = class of TOldRttiMarshal;

implementation

uses
  Variants, SysUtils, RestJsonUtils, RTTI.Collections, RTTI.UnMarshaling, RTTI.Lists, Contnrs;


{ TOldRttiMarshal }

function TOldRttiMarshal.ToChar(AObject: TObject; APropInfo: PPropInfo): ISuperObject;
begin
  Result := TSuperObject.Create(Char(GetOrdProp(AObject, APropInfo)));
end;

function TOldRttiMarshal.ToClass(AObject: TObject): ISuperObject;
var
  Prop: TPropInfo;
  Value: ISuperObject;
  ObjProp: TObject;
begin
  if AObject = nil then
  begin
    Result := SuperObject.SO();
    Exit;
  end;

  if AObject.InheritsFrom(TList) then
    Result := ToList(TList(AObject))
  else
    if AObject.InheritsFrom(TCollectionBean) then
      Result := ToCollection(AObject)
    else
      begin
        Result := SO();
        for Prop in AObject.RTTIProperties do
        begin
          Value := nil;
          case Prop.PropType^^.Kind of
            tkMethod:
              ;
            tkSet, tkInteger, tkEnumeration:
              Value := ToInteger(AObject, @Prop);
            tkInt64:
              Value := ToInt64(AObject, @Prop);
            tkFloat:
              Value := ToFloat(AObject, @Prop);
            tkChar, tkWChar:
              Value := ToChar(AObject, @Prop);
            tkString, tkLString,
            {$IFDEF UNICODE}
            tkUString,
            {$ENDIF}
            tkWString:
              Value := ToJsonString(AObject, @Prop);
            tkClass:
              begin
                ObjProp := GetObjectProp(AObject, TKeywordMapper.MapPropertyName(Prop.Name));
                if Assigned(ObjProp) then
                begin
                  if ObjProp.InheritsFrom(TList) then
                    Value := ToList(TList(ObjProp))
                  else if ObjProp.InheritsFrom(TCollectionBean) then
                    Value := ToCollection(TCollectionBean(ObjProp))
                  else
                    Value := ToClass(ObjProp);
                end;
              end;
          end;
          if Assigned(Value) then
            Result.O[{$IFDEF JSON_KEY_CASE_INSENSITIVE}LowerCase{$ENDIF}(TKeywordMapper.MapPropertyName(Prop.Name))] := Value;
        end;
      end;
end;

function TOldRttiMarshal.ToCollection(AObject: TObject): ISuperObject;
var
  i: TCollectionItem;
begin
  Result := TSuperObject.Create(stArray);
  //
  for i in TCollectionBean(AObject) do
    Result.AsArray.Add(ToClass(i))
end;

function TOldRttiMarshal.ToFloat(AObject: TObject; APropInfo: PPropInfo): ISuperObject;
begin
  if APropInfo^.PropType^ = System.TypeInfo(TDateTime) then
    Result := TSuperObject.Create(DelphiToJavaDateTime(GetFloatProp(AObject, APropInfo)))
  else
    Result := TSuperObject.Create(GetFloatProp(AObject, APropInfo));
end;

function TOldRttiMarshal.ToInt64(AObject: TObject; APropInfo: PPropInfo): ISuperObject;
begin
  Result := TSuperObject.Create(GetInt64Prop(AObject, APropInfo));
end;

function TOldRttiMarshal.ToInteger(AObject: TObject; APropInfo: PPropInfo): ISuperObject;
var
  vIntValue: Integer;
begin
  vIntValue := GetOrdProp(AObject, APropInfo);

  if APropInfo^.PropType^ = TypeInfo(Boolean) then
    Result := TSuperObject.Create(Boolean(vIntValue))
  else
    Result := TSuperObject.Create(vIntValue);
end;

class function TOldRttiMarshal.ToJson(AObject: TObject): ISuperObject;
var
  vMarshal: TOldRttiMarshal;
begin
  vMarshal := TOldRttiMarshal.Create;
  try
    Result := vMarshal.ToClass(AObject);
  finally
    vMarshal.Free;
  end;
end;

function TOldRttiMarshal.ToJsonString(AObject: TObject; APropInfo: PPropInfo): ISuperObject;
begin
  Result := TSuperObject.Create(GetWideStrProp(AObject, APropInfo));
end;

function TOldRttiMarshal.ToList(AList: TList): ISuperObject;
var
  i: Integer;
begin
  Result := TSuperObject.Create(stArray);
  //
  for i := 0 to AList.Count - 1 do
  begin
    if AList.InheritsFrom(TIntegerList) then
      Result.AsArray.Add(TIntegerList(AList).Items[i])
    else
      if AList.InheritsFrom(TObjectList) then
        Result.AsArray.Add(ToClass(AList.Items[i]));
  end;
end;

end.

