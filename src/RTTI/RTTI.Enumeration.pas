unit RTTI.Enumeration;

interface

uses
  TypInfo;

type
  IPropEnumerator = interface
    function MoveNext: Boolean;
    function GetCurrentPropInfo: TPropInfo;
    property Current: TPropInfo read GetCurrentPropInfo;
  end;

  TPropEnumerator = class(TInterfacedObject, IPropEnumerator)
  private
    FTypeInfo: PTypeInfo;
    FTypeData: PTypeData;
    FPropList: PPropList;
    FIndex: Integer;
    FOwner: TObject;
    function Count: Integer;
  public
    constructor Create(AOwner: TObject);
    destructor Destroy; override;
    function MoveNext: Boolean;
    function GetCurrentPropInfo: TPropInfo;
    property Current: TPropInfo read GetCurrentPropInfo;
  end;

  IPropertyList = interface
    function GetEnumerator: IPropEnumerator;
  end;

  TPropertyList = class(TInterfacedObject, IPropertyList)
  private
    FOwner: TObject;
  public
    constructor Create(AOwner: TObject);
    function GetEnumerator: IPropEnumerator;
  end;

implementation

{ TPropEnumerator }

function TPropEnumerator.Count: Integer;
begin
  Result := FTypeData.PropCount;
end;

constructor TPropEnumerator.Create(AOwner: TObject);
begin
  inherited Create;
  FOwner := AOwner;
  FIndex := -1;
  if FOwner.ClassType.ClassInfo = nil then
    Raise EPropertyError.CreateFmt('Class %s has no runtime type information', [Fowner.ClassName]);
  FTypeInfo := FOwner.ClassType.ClassInfo;
  FTypeData := GetTypeData(FTypeInfo);
  New(FPropList);
  GetPropList(FTypeInfo, tkProperties, FPropList);
end;

destructor TPropEnumerator.Destroy;
begin
  Dispose(FPropList);
  inherited;
end;

function TPropEnumerator.GetCurrentPropInfo: TPropInfo;
begin
  if FPropList[FIndex] <> nil then
    Result := FPropList[FIndex]^;
end;

function TPropEnumerator.MoveNext: Boolean;
begin
  Result := FIndex < Count - 1;
  if Result then
    Inc(FIndex);
end;

{ TPropertyList }

constructor TPropertyList.Create(AOwner: TObject);
begin
  inherited Create;
  FOwner := AOwner;
end;

function TPropertyList.GetEnumerator: IPropEnumerator;
begin
  Result := TPropEnumerator.Create(FOwner);
end;

end.

