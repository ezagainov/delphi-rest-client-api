unit RTTI.UnMarshaling;

interface

uses
  TypInfo, SuperObject, Variants, SysUtils, Math, Classes, RTTI.Enumeration,
  RTTI.Marshaling, RTTI.MapKeywordProperties;

type
  TOldRttiUnMarshal = class
  protected
    function FromClass(AClassType: TClass; AJSONValue: ISuperObject): TObject;
    function FromCollection(AClassType: TClass; APropInfo: PPropInfo; const AJSONValue: ISuperObject): TObject;
    function FromList(AClassType: TClass; APropInfo: PPropInfo; const AJSONValue: ISuperObject): TList; overload;
    function FromList(AClassType, AItemClassType: TClass; const AJSONValue: ISuperObject): TList; overload;
    function FromInt(APropInfo: PPropInfo; const AJSONValue: ISuperObject): Variant;
    function FromInt64(APropInfo: PPropInfo; const AJSONValue: ISuperObject): Variant;
    function FromFloat(APropInfo: PPropInfo; const AJSONValue: ISuperObject): Variant;
    function FromString(APropInfo: PPropInfo; const AJSONValue: ISuperObject): Variant;
    function FromChar(APropInfo: PPropInfo; const AJSONValue: ISuperObject): Variant;
    function FromWideChar(APropInfo: PPropInfo; const AJSONValue: ISuperObject): Variant;
  public
    class function FromJson(AClassType: TClass; const AJson: string): TObject;
    class function FromJsonArray(AClassType, AItemClassType: TClass; const AJson: string): TObject;
  end;

  TOldRttiUnMarshalProviderClass = class of TOldRttiUnMarshal;

implementation

uses
  RestJsonUtils, RestClient, RTTI.JsonMarshaling, RTTI.Collections, RTTI.Lists, RTTI.EnumerationObjectHelper;

{ TOldRttiUnMarshal }

function TOldRttiUnMarshal.FromChar(APropInfo: PPropInfo; const AJSONValue: ISuperObject): Variant;
begin
  Result := Null;
  if ObjectIsType(AJSONValue, stString) and (Length(AJSONValue.AsString) = 1) then
  begin
    Result := Ord(AJSONValue.AsString[1]);
  end;
end;

function TOldRttiUnMarshal.FromClass(AClassType: TClass; AJSONValue: ISuperObject): TObject;
var
  prop: TPropInfo;
  value: Variant;
  vPropName: string;
  vInt64Value: Int64;
  vObjProp: TObject;
  vObjClass: TClass;
begin
  Result := nil;

  case ObjectGetType(AJSONValue) of
    stObject:
      begin
        if AClassType.InheritsFrom(TCollectionBean) then
          Result := TCollectionBeanClass(AClassType).Create
        else
          Result := AClassType.Create;
        try
          for Prop in Result.RTTIProperties do
          begin
            vPropName := {$IFDEF JSON_KEY_CASE_INSENSITIVE}LowerCase{$ENDIF}(TKeywordMapper.MapPropertyName(prop.Name));

            value := Null;
            try
              case prop.PropType^.Kind of
                tkMethod:
                  ;
                tkSet, tkInteger, tkEnumeration:
                  begin
                    value := FromInt(@prop, AJSONValue.O[vPropName]);
                    if not VarIsNull(value) then
                    begin
                      vInt64Value := value;
                      SetOrdProp(Result, @prop, vInt64Value);
                      value := Null;
                    end;
                  end;
                tkInt64:
                  begin
                    value := FromInt64(@prop, AJSONValue.O[vPropName]);
                    if not VarIsNull(value) then
                    begin
                      vInt64Value := value;
                      SetInt64Prop(Result, @prop, vInt64Value);
                      value := Null;
                    end;
                  end;
                tkFloat:
                  value := FromFloat(@prop, AJSONValue.O[vPropName]);
                tkChar:
                  value := FromChar(@prop, AJSONValue.O[vPropName]);
                tkWChar:
                  value := FromWideChar(@prop, AJSONValue.O[vPropName]);
                tkString, tkLString,
                          {$IFDEF UNICODE}
                tkUString,
                          {$ENDIF}
                tkWString:
                  value := FromString(@prop, AJSONValue.O[vPropName]);
                tkClass:
                  begin
                    value := Null;

                    vObjClass := GetObjectPropClass(Result, @prop);
                    if vObjClass.InheritsFrom(TCollectionBean) then
                      vObjProp := FromCollection(vObjClass, @prop, AJSONValue.O[vPropName])
                    else if vObjClass.InheritsFrom(TList) then
                    begin
                      vObjProp := FromList(vObjClass, @prop, AJSONValue.O[vPropName])
                    end
                    else
                    begin
                      vObjProp := FromClass(vObjClass, AJSONValue.O[vPropName]);
                    end;
                    if Assigned(vObjProp) then
                    begin
                      SetObjectProp(Result, @prop, vObjProp);
                    end;
                  end;
              end;
            except
              on E: Exception do
              begin
                raise EJsonInvalidValueForField.CreateFmt('UnMarshalling error for field "%s.%s" : %s', [Result.ClassName, vPropName, E.Message]);
              end;
            end;

            if not VarIsNull(value) then
            begin
              SetPropValue(Result, vPropName, value);
            end;
          end;
        except
          Result.Free;
          Raise;
        end;
      end;
    stArray:
      begin
        if AClassType.InheritsFrom(TCollectionBean) then
          Result := FromCollection(AClassType, nil, AJSONValue);
      end;
  end;
end;

function TOldRttiUnMarshal.FromCollection(AClassType: TClass; APropInfo: PPropInfo; const AJSONValue: ISuperObject): TObject;
var
  i: Integer;
  vItem: TCollectionItemBean;
  BeanClassType: TCollectionBeanClass;
  ResultCollection: TCollectionBean;
begin
  if not AClassType.InheritsFrom(TCollectionBean) then
    raise ENoSerializableClass.CreateFmt('Wrong classtype %s, expected TCollectionBean', [AClassType.ClassName]);
  BeanClassType := TCollectionBeanClass(AClassType);
  ResultCollection := BeanClassType.Create;
  //
  if ObjectIsType(AJSONValue, stArray) then
  begin
    if AClassType.InheritsFrom(TCollectionBean) and (AJSONValue.AsArray.Length > 0) then
    begin
      try
        for i := 0 to AJSONValue.AsArray.Length - 1 do
        begin
          vItem := TCollectionItemBean(FromClass(ResultCollection.ItemClass, AJSONValue.AsArray.O[i]));
          vItem.Collection := ResultCollection;
        end;
      except
        ResultCollection.Free;
        raise;
      end;
    end;
  end;
  Result := ResultCollection;
end;

function TOldRttiUnMarshal.FromFloat(APropInfo: PPropInfo; const AJSONValue: ISuperObject): Variant;
var
  o: ISuperObject;
begin
  Result := Null;
  case ObjectGetType(AJSONValue) of
    stInt, stDouble, stCurrency:
      begin
        if APropInfo^.PropType^ = System.TypeInfo(TDateTime) then
        begin
          Result := JavaToDelphiDateTime(AJSONValue.AsInteger);
        end
        else
        begin
          case GetTypeData(APropInfo^.PropType^).FloatType of
            ftSingle:
              Result := AJSONValue.AsDouble;
            ftDouble:
              Result := AJSONValue.AsDouble;
            ftExtended:
              Result := AJSONValue.AsDouble;
            ftCurr:
              Result := AJSONValue.AsCurrency;
          end;
        end;
      end;
    stString:
      begin
        o := SO(AJSONValue.AsString);
        if not ObjectIsType(o, stString) then
        begin
          Result := FromFloat(APropInfo, o);
        end;
      end
  end;
end;

function TOldRttiUnMarshal.FromInt(APropInfo: PPropInfo; const AJSONValue: ISuperObject): Variant;
var
  o: ISuperObject;
begin
  Result := Null;
  case ObjectGetType(AJSONValue) of
    stInt:
      Result := AJSONValue.AsInteger;
    stBoolean:
      Result := AJSONValue.AsBoolean;
    stString:
      begin
        o := SO(AJSONValue.AsString);
        if not ObjectIsType(o, stString) then
        begin
          Result := FromInt(APropInfo, o);
        end;
      end;
  end;
end;

function TOldRttiUnMarshal.FromInt64(APropInfo: PPropInfo; const AJSONValue: ISuperObject): Variant;
var
  i: Int64;
begin
  Result := Null;
  case ObjectGetType(AJSONValue) of
    stInt:
      begin
        Result := AJSONValue.AsInteger;
      end;
    stString:
      begin
        if TryStrToInt64(AJSONValue.AsString, i) then
        begin
          Result := i;
        end;
      end;
  end;
end;

class function TOldRttiUnMarshal.FromJson(AClassType: TClass; const AJson: string): TObject;
var
  vUnMarshal: TOldRttiUnMarshal;
  vJsonObject: ISuperObject;
begin
  Result := nil;

  vUnMarshal := OldRttiUnMarshalProviderClass.Create;
  try
    vJsonObject := SO(AJson);

    if vJsonObject = nil then
    begin
      raise EJsonInvalidSyntax.CreateFmt('Invalid json: "%s"', [AJson]);
    end;

    Result := vUnMarshal.FromClass(AClassType, vJsonObject);
  finally
    vUnMarshal.Free;
  end;
end;

class function TOldRttiUnMarshal.FromJsonArray(AClassType, AItemClassType: TClass; const AJson: string): TObject;
var
  vUnMarshal: TOldRttiUnMarshal;
  vJsonObject: ISuperObject;
begin
  Result := nil;

  vUnMarshal := OldRttiUnMarshalProviderClass.Create;
  try
    vJsonObject := SO(AJson);

    if vJsonObject = nil then
    begin
      raise EJsonInvalidSyntax.CreateFmt('Invalid json: "%s"', [AJson]);
    end;

    Result := vUnMarshal.FromList(AClassType, AItemClassType, vJsonObject);
  finally
    vUnMarshal.Free;
  end;
end;

function TOldRttiUnMarshal.FromList(AClassType: TClass; APropInfo: PPropInfo; const AJSONValue: ISuperObject): TList;
var
  vPosList: Integer;
  vItemClassName: string;
  vItemClass: TClass;
begin
  Result := nil;
  if ObjectIsType(AJSONValue, stArray) then
  begin
    if AClassType.InheritsFrom(TList) and (AJSONValue.AsArray.Length > 0) then
    begin
      if AClassType.InheritsFrom(TIntegerList) then
        Result := FromList(AClassType, TIntegerList, AJSONValue)
      else
      begin
        vItemClassName := '';
        if Assigned(APropInfo) then
        begin
          vPosList := Pos('ObjectList', string(APropInfo^.Name));
          if (vPosList = 0) then
          begin
            vPosList := Pos('List', string(APropInfo^.Name));
          end;

          vItemClassName := 'T' + Copy(string(APropInfo^.Name), 1, vPosList - 1);
        end;
        vItemClass := FindClass(vItemClassName);
        Result := FromList(AClassType, vItemClass, AJSONValue);
      end;
    end;
  end;
end;

function TOldRttiUnMarshal.FromList(AClassType, AItemClassType: TClass; const AJSONValue: ISuperObject): TList;
var
  i: Integer;
  vItem: TObject;
begin
  Result := nil;
  if ObjectIsType(AJSONValue, stArray) then
  begin
    if AClassType.InheritsFrom(TList) and (AJSONValue.AsArray.Length > 0) then
    begin
      Result := TList(AClassType.Create);
      try
        for i := 0 to AJSONValue.AsArray.Length - 1 do
        begin
          if AClassType.InheritsFrom(TIntegerList) then begin
            TIntegerList(Result).Add(AJSONValue.AsArray.O[i].AsInteger);
          end
          else begin
            vItem := FromClass(AItemClassType, AJSONValue.AsArray.O[i]);
            Result.Add(vItem);
          end;
        end;
      except
        Result.Free;
        raise;
      end;
    end;
  end;
end;

function TOldRttiUnMarshal.FromString(APropInfo: PPropInfo; const AJSONValue: ISuperObject): Variant;
begin
  case ObjectGetType(AJSONValue) of
    stNull:
      Result := '';
    stString:
      Result := AJSONValue.AsString;
  else
    raise EJsonInvalidValue.CreateFmt('Invalid value "%s".', [AJSONValue.AsJSon]);
  end;
end;

function TOldRttiUnMarshal.FromWideChar(APropInfo: PPropInfo; const AJSONValue: ISuperObject): Variant;
begin
  Result := Null;
  if ObjectIsType(AJSONValue, stString) and (Length(AJSONValue.AsString) = 1) then
  begin
    Result := Ord(AJSONValue.AsString[1]);
  end;
end;


end.

