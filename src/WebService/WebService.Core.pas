unit WebService.Core;

interface

uses
  SysUtils, Classes, RestClient, WebService.Interfaces;

type
  TWebService = class abstract(TRestClient, IWebService)
  private
    FEndPointInstances: TThreadList;
  protected
    procedure AddEndPointInstance(AInstance: TObject);
    procedure RemoveEndPointInstance(AInstance: TObject);
  public
    function Url: string; virtual; abstract;
    //
    function Resource(const AMethodName: string): IResource;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

{ TWebService }

constructor TWebService.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FEndPointInstances := TThreadList.Create;
  EnabledCompression := False;
end;

destructor TWebService.Destroy;
var
  LockList: TList;
  Inst: TObject;
begin
  LockList := FEndPointInstances.LockList;
  try
    while LockList.Count > 0 do begin
      Inst := LockList.Items[0];
      LockList.Delete(0);
      FreeAndNil(Inst);
    end;
  finally
    FEndPointInstances.UnlockList;
  end;
  FEndPointInstances.Free;
  inherited;
end;

procedure TWebService.AddEndPointInstance(AInstance: TObject);
begin
  FEndPointInstances.Add(AInstance);
end;

procedure TWebService.RemoveEndPointInstance(AInstance: TObject);
begin
  if not (csDestroying in self.ComponentState) then
    FEndPointInstances.Remove(AInstance);
end;

function TWebService.Resource(const AMethodName: string): IResource;
begin
  Result := inherited Resource(Url + '/' + AMethodName);
end;

end.

