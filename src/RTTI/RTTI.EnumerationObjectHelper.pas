unit RTTI.EnumerationObjectHelper;

interface

uses
  Rtti.Enumeration;

type
  TObjectRTTI = class helper for TObject
    function RTTIProperties: IPropertyList;
  end;

implementation

{ TObjectRTTI }

function TObjectRTTI.RTTIProperties: IPropertyList;
begin
  Result := TPropertyList.Create(Self);
end;

end.

