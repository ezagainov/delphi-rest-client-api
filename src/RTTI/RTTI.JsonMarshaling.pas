unit RTTI.JsonMarshaling;

{.$I DelphiRest.inc}

interface

uses
  RTTI.Marshaling, RTTI.UnMarshaling;

type
  TJsonUtilOldRTTI = class
    class function Marshal(entity: TObject): string;
    class function UnMarshal(AClassType: TClass; AJsonText: string): TObject;
  end;

  TObjectMarshal = class helper for TObject
    function toJson: string;
  end;

var
  OldRttiMarshalProviderClass: TOldRttiMarshalProviderClass = TOldRttiMarshal;
  OldRttiUnMarshalProviderClass: TOldRttiUnMarshalProviderClass = TOldRttiUnMarshal;

implementation
{ TJsonUtilOldRTTI }

class function TJsonUtilOldRTTI.Marshal(entity: TObject): string;
begin
  Result := OldRttiMarshalProviderClass.ToJson(entity).AsString;
end;

class function TJsonUtilOldRTTI.UnMarshal(AClassType: TClass; AJsonText: string): TObject;
begin
  Result := OldRttiUnMarshalProviderClass.FromJson(AClassType, AJsonText);
end;

{ TObjectMarshal }


function TObjectMarshal.toJson: string;
begin
  Result := TJsonUtilOldRTTI.Marshal(Self);
end;

end.

