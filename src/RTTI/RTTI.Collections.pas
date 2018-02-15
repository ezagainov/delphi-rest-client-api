unit RTTI.Collections;

interface

uses
  Classes, Windows, RTTI.Marshaling, RTTI.UnMarshaling, RTTI.Enumeration;

type
  TInterfacedCollection = class(TCollection, IInterface)
  protected
    FRefCount: Integer;
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
    //
    class function GetItemClass: TCollectionItemClass; virtual;
  public
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;
    class function NewInstance: TObject; override;
    property RefCount: Integer read FRefCount;
    //
    constructor Create;
  end;

  TCollectionItemBean = class(TCollectionItem)
  public
    function SourceString: string;
    function Clone: TCollectionItemBean;
    function Properties: IPropertyList;
  end;

  TCollectionBean = class(TInterfacedCollection)
  protected
    class function GetItemClass: TCollectionItemClass; override;
  end;

  TCollectionBeanClass = class of TCollectionBean;

implementation

procedure TInterfacedCollection.AfterConstruction;
begin
  // Release the constructor's implicit refcount
  InterlockedDecrement(FRefCount);
  //
  Assert(ItemClass = GetItemClass, 'CollectionItremClass mismatch');
end;

procedure TInterfacedCollection.BeforeDestruction;
begin
  if RefCount <> 0 then
    System.Error(System.reInvalidPtr);
end;

constructor TInterfacedCollection.Create;
begin
  inherited Create(GetItemClass);
end;

class function TInterfacedCollection.GetItemClass: TCollectionItemClass;
begin
  Result := TCollectionItem;
end;

class function TInterfacedCollection.NewInstance: TObject;
begin
  Result := inherited NewInstance;
  TInterfacedCollection(Result).FRefCount := 1;
end;

function TInterfacedCollection.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
  if GetInterface(IID, Obj) then
    Result := 0
  else
    Result := E_NOINTERFACE;
end;

function TInterfacedCollection._AddRef: Integer;
begin
  Result := InterlockedIncrement(FRefCount);
end;

function TInterfacedCollection._Release: Integer;
begin
  Result := InterlockedDecrement(FRefCount);
  if Result = 0 then
    Destroy;
end;

{ TCollectionBean }

class function TCollectionBean.GetItemClass: TCollectionItemClass;
begin
  Result := TCollectionItemBean;
end;

{ TCollectionItemBean }

function TCollectionItemBean.Clone: TCollectionItemBean;
var
  JsonValue: string;
begin
  JsonValue := TOldRttiMarshal.ToJson(Self).AsString;
  Result := TOldRttiUnMarshal.FromJson(ClassType, JsonValue) as TCollectionItemBean;
end;

function TCollectionItemBean.Properties: IPropertyList;
begin
  Result := TPropertyList.create(Self);
end;

function TCollectionItemBean.SourceString: string;
begin
  Result := TOldRttiMarshal.ToJson(Self).AsString;
end;

end.

