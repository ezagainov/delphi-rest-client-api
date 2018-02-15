unit WebService.EndPoint;

interface

uses
  SysUtils, Classes, RestUtils, WebService.Interfaces, RestJsonUtils, DB, RTTI.UnMarshaling;

type
  {$M+}
  TEndPointMethod = class abstract(TInterfacedObject);

  TJsonEndPointMethod = class abstract(TEndPointMethod, IWebServiceEndPoint)
  private
    FWebService: IWebService;
    function SetContentType(AResource: IResource; ContentType: TMediaType): IResource;
    function SetAccept(AResource: IResource; AcceptType: TMediaType): IResource;
    //
    function PrepareResource: IResource;
  public
    constructor Create(AService: IWebService); virtual;
    destructor Destroy; override;
    //
    function methodName: string; virtual;
    function acceptedMediaTypes: TMediaTypes; virtual;
    function contentType: TMediaTypes; virtual;
    //
    function Get: string; overload; virtual;
    function Get(AListClass, AItemClass: TClass): TObject; overload; virtual;
    function Get(EntityClass: TClass): TObject; overload; virtual;
    procedure GetAsDataSet(ADataSet: TDataSet); overload;
    function GetAsDataSet(): TDataSet; overload;
    function GetAsDataSet(const RootElement: string): TDataSet; overload;
    function Post(Content: string): string; overload; virtual;
    function Post(AParamObject: TObject; AResultEntityClass: TClass): TObject; overload; virtual;
    procedure Post(AParamObject: TObject; AResultDataSet: TDataSet); overload; virtual;
    //

    function Header(Name: string; Value: string): IResource;
    function BindQueryParams: IResource; virtual;
  end;
  {$M-}

implementation

{ TJsonEndPointMethod }

function TJsonEndPointMethod.SetAccept(AResource: IResource; AcceptType: TMediaType): IResource;
begin
  Result := AResource.Accept(cMediaTypeStr[AcceptType]);
end;

function TJsonEndPointMethod.SetContentType(AResource: IResource; ContentType: TMediaType): IResource;
begin
  Result := AResource.ContentType(cMediaTypeStr[ContentType]);
end;

function TJsonEndPointMethod.acceptedMediaTypes: TMediaTypes;
begin
  Result := [MediaTypeJson];
end;

function TJsonEndPointMethod.BindQueryParams: IResource;
begin
  Result := PrepareResource.BindQueryParams;
end;

function TJsonEndPointMethod.ContentType: TMediaTypes;
begin
  Result := [MediaTypeJson];
end;

function TJsonEndPointMethod.methodName: string;
begin
  raise EAbstractError.Create('TJsonEndPointMethod.methodName');
end;

function TJsonEndPointMethod.Post(Content: string): string;
begin
  Result := PrepareResource.Post(Content);
end;

function TJsonEndPointMethod.Post(AParamObject: TObject; AResultEntityClass: TClass): TObject;
begin
  Result := PrepareResource.Post(AParamObject, AResultEntityClass);
end;

function TJsonEndPointMethod.PrepareResource: IResource;
var
  I: TMediaType;
begin
  Result := FWebService.Resource(methodName);
  for I in acceptedMediaTypes do
    SetAccept(Result, I);
  for I in ContentType do
    SetContentType(Result, I);
end;

constructor TJsonEndPointMethod.Create(AService: IWebService);
begin
  inherited Create;
  FWebService := AService;
//  FWebService.AddEndPointInstance(Self);
end;

destructor TJsonEndPointMethod.Destroy;
begin
//  if Assigned(FWebService) then
//    FWebService.RemoveEndPointInstance(Self);
  inherited;
end;

function TJsonEndPointMethod.Get(EntityClass: TClass): TObject;
var
  vResponse: string;
begin
  vResponse := Get;
  Result := TJsonUtil.UnMarshal(EntityClass, vResponse);
end;

function TJsonEndPointMethod.GetAsDataSet: TDataSet;
begin
  Result := BindQueryParams.GetAsDataSet;
end;

procedure TJsonEndPointMethod.GetAsDataSet(ADataSet: TDataSet);
begin
  BindQueryParams.GetAsDataSet(ADataSet);
end;

function TJsonEndPointMethod.GetAsDataSet(const RootElement: string): TDataSet;
begin
  Result := BindQueryParams.GetAsDataSet(RootElement);
end;

function TJsonEndPointMethod.Header(Name, Value: string): IResource;
begin
  Result := BindQueryParams.Header(Name, Value);
end;

function TJsonEndPointMethod.Get(AListClass, AItemClass: TClass): TObject;
var
  vResponse: string;
begin
  vResponse := Get;
  Result := TOldRttiUnMarshal.FromJsonArray(AListClass, AItemClass, vResponse);
end;

function TJsonEndPointMethod.Get: string;
begin
  Result := BindQueryParams.Get;
end;

procedure TJsonEndPointMethod.Post(AParamObject: TObject; AResultDataSet: TDataSet);
begin
  PrepareResource.Post(AParamObject, AResultDataSet);
end;

end.

