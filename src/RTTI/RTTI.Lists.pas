unit RTTI.Lists;

interface

uses
  Classes, Windows, RTTI.Marshaling, RTTI.UnMarshaling, RTTI.Enumeration;

type
  TIntegerList = class(TList)
  private
    function Get(Index: Integer): Integer;
    procedure Put(Index: Integer; const Value: Integer);
  public
    function Add(Item: Integer): Integer;
    function First: Integer;
    function IndexOf(Item: Integer): Integer;
    procedure Insert(Index: Integer; Item: Integer);
    function Last: Integer;
    function Remove(Item: Integer): Integer;
    property Items[Index: Integer]: Integer read Get write Put; default;
  end;

implementation

{ TIntegerList }

function TIntegerList.Add(Item: Integer): Integer;
begin
  Result := inherited Add(Pointer(Item));
end;

function TIntegerList.First: Integer;
begin
  Result := Integer(inherited First);
end;

function TIntegerList.Get(Index: Integer): Integer;
begin
  Result := Integer(inherited Get(Index));
end;

function TIntegerList.IndexOf(Item: Integer): Integer;
begin
  Result := inherited IndexOf(Pointer(Item));
end;

procedure TIntegerList.Insert(Index, Item: Integer);
begin
  inherited Insert(Index, Pointer(Item));
end;

function TIntegerList.Last: Integer;
begin
  Result := Integer(inherited Last);
end;

procedure TIntegerList.Put(Index: Integer; const Value: Integer);
begin
  inherited Put(Index, Pointer(Value));
end;

function TIntegerList.Remove(Item: Integer): Integer;
begin
  Result := inherited Remove(Pointer(Item));
end;

end.

