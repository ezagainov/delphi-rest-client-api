unit RestClient;

{$I DelphiRest.inc}

interface

uses
  Classes, SysUtils, WebService.ConnectionProvider, RestUtils, RestJsonUtils,
  Contnrs, RTTI.UnMarshaling, DB, RestException, WebService.Interfaces;

const
  DEFAULT_COOKIE_VERSION = 1; {Cookies using the default version correspond to RFC 2109.}

type
  TRequestMethod = (METHOD_GET, METHOD_POST, METHOD_PUT, METHOD_PATCH, METHOD_DELETE);

  TRestResponseHandler = procedure(ResponseContent: TStream) of object;

  TResource = class;

  TCustomCreateConnection = procedure(Sender: TObject; AConnectionType: THttpConnectionProviderType; out AConnection: IHTTPConnectionProvider) of object;

  TRestClient = class;

  TRestOnRequestEvent = procedure(ARestClient: TRestClient; AResource: TResource; AMethod: TRequestMethod) of object;

  TRestOnResponseEvent = procedure(ARestClient: TRestClient; ResponseCode: Integer; const ResponseContent: string) of object;

  THTTPErrorEvent = procedure(ARestClient: TRestClient; AResource: TResource; AMethod: TRequestMethod; AHTTPError: EHTTPError; var ARetryMode: THTTPRetryMode) of object;

  TRestClient = class abstract(TComponent)
  private
    FHttpConnection: IHTTPConnectionProvider;
    FResources: TInterfaceList;
    FEnabledCompression: Boolean;
    FOnCustomCreateConnection: TCustomCreateConnection;
    FTimeOut: TTimeOut;
    FProxyCredentials: TProxyCredentials;
    FLogin: string;
    FOnAsyncRequestProcess: TAsyncRequestProcessEvent;
    FPassword: string;
    FOnError: THTTPErrorEvent;
    FVerifyCert: boolean;
    function DoRequest(Method: TRequestMethod; ResourceRequest: TResource; AHandler: TRestResponseHandler = nil): string; overload;
    function GetResponseCode: Integer;
    procedure RecreateConnection;
    procedure CheckConnection;
    procedure SetEnabledCompression(const Value: Boolean);
    function GetOnConnectionLost: THTTPConnectionLostEvent;
    procedure SetOnConnectionLost(AConnectionLostEvent: THTTPConnectionLostEvent);
    function GetOnError: THTTPErrorEvent;
    procedure SetOnError(AErrorEvent: THTTPErrorEvent);
    function GetResponseHeader(const Header: string): string;
    procedure SetVerifyCertificate(AValue: boolean);
  protected
    procedure Loaded; override;
    function ResponseCodeRaisesError(ResponseCode: Integer): Boolean; virtual;
  public
    OnBeforeRequest: TRestOnRequestEvent;
    OnAfterRequest: TRestOnRequestEvent;
    OnResponse: TRestOnResponseEvent;
    constructor Create(Owner: TComponent); override;
    destructor Destroy; override;
    property ResponseCode: Integer read GetResponseCode;
    property ResponseHeader[const Header: string]: string read GetResponseHeader;
    function Resource(URL: string): IResource;
    function UnWrapConnection: IHTTPConnectionProvider;
    function SetCredentials(const ALogin, APassword: string): TRestClient;
    property OnConnectionLost: THTTPConnectionLostEvent read GetOnConnectionLost write SetOnConnectionLost;
    property OnError: THTTPErrorEvent read GetOnError write SetOnError;
    property OnAsyncRequestProcess: TAsyncRequestProcessEvent read FOnAsyncRequestProcess write FOnAsyncRequestProcess;
  published
    property EnabledCompression: Boolean read FEnabledCompression write SetEnabledCompression default True;
    property VerifyCert: Boolean read FVerifyCert write SetVerifyCertificate default True;
    property OnCustomCreateConnection: TCustomCreateConnection read FOnCustomCreateConnection write FOnCustomCreateConnection;
    property TimeOut: TTimeOut read FTimeOut;
    property ProxyCredentials: TProxyCredentials read FProxyCredentials;
  end;

  TCookie = class
  private
    FName: string;
    FValue: string;
    FVersion: Integer;
    FPath: string;
    FDomain: string;
  public
    property Name: string read FName;
    property Value: string read FValue;
    property Version: Integer read FVersion default DEFAULT_COOKIE_VERSION;
    property Path: string read FPath;
    property Domain: string read FDomain;
  end;

  TResource = class(TInterfacedObject, IResource, IBaseInterface)
  private
    FRestClient: TRestClient;
    FURL: string;
    FAcceptTypes: string;
    FContent: TMemoryStream;
    FContentTypes: string;
    FHeaders: TStrings;
    FGetParams: TStrings;
    FAcceptedLanguages: string;
    FAsync: Boolean;
    constructor Create(RestClient: TRestClient; URL: string);
    procedure SetContent(entity: TObject);
  public
    destructor Destroy; override;
    function GetAcceptTypes: string;
    function GetURL: string;
    function GetContent: TStream;
    function GetContentTypes: string;
    function GetHeaders: TStrings;
    function GetParams: TStrings;
    function GetAcceptedLanguages: string;
    function GetAsync: Boolean;
    function Accept(AcceptType: string): IResource;
    function Async(const Value: Boolean = True): TResource;
    function Authorization(Authorization: string): IResource;
    function ContentType(ContentType: string): IResource;
    function AcceptLanguage(Language: string): IResource;
    function Header(Name: string; Value: string): IResource;

    //function Cookie(Cookie: TCookie): TResource;

    function Get: string; overload;
    procedure Get(AHandler: TRestResponseHandler); overload;
    function Get(EntityClass: TClass): TObject; overload;
    function Post(Content: TStream): string; overload;
    function Post(Content: string): string; overload;
    procedure Post(Content: TStream; AHandler: TRestResponseHandler); overload;
    function Post(AParamObject: TObject; AResultEntityClass: TClass): TObject; overload;
    procedure Post(AParamObject: TObject; AResultDataSet: TDataSet); overload;
    function Post(Entity: TObject): TObject; overload;
    function Put(Content: TStream): string; overload;
    function Put(Content: string): string; overload;
    procedure Put(Content: TStream; AHandler: TRestResponseHandler); overload;
    function Put(Entity: TObject): TObject; overload;
    function Patch(Content: TStream): string; overload;
    function Patch(Content: string): string; overload;
    procedure Patch(Content: TStream; AHandler: TRestResponseHandler); overload;
    function Patch(Entity: TObject): TObject; overload;
    procedure Delete(); overload;
    procedure Delete(Entity: TObject); overload;
    function Get(AListClass, AItemClass: TClass): TObject; overload;

    procedure GetAsDataSet(ADataSet: TDataSet); overload;

    function GetAsDataSet(): TDataSet; overload;
    function GetAsDataSet(const RootElement: string): TDataSet; overload;
    function Param(Name: string; Value: string): IResource; overload;
    function Param(Name: string; Value: integer): IResource; overload;
    function BindQueryParams: IResource;
  end;

implementation

uses
  StrUtils, Math, SuperObject, JsonToDataSetConverter, WebService.ConnectionProviderFactory;

{ TRestClient }

constructor TRestClient.Create(Owner: TComponent);
begin
  inherited;
  FResources := TInterfaceList.Create;

  FTimeOut := TTimeOut.Create(Self);
  FTimeOut.Name := 'TimeOut';
  FTimeOut.SetSubComponent(True);

  FProxyCredentials := TProxyCredentials.Create(Self);
  FProxyCredentials.Name := 'ProxyCredentials';
  FProxyCredentials.SetSubComponent(True);

  FLogin := '';
  FPassword := '';

  FEnabledCompression := True;
  FVerifyCert := True;
  RecreateConnection;
end;

destructor TRestClient.Destroy;
begin
  if FHttpConnection <> nil then
  begin
    FHttpConnection.CancelRequest;
    FHttpConnection := nil;
  end;
  FResources.Free;
  inherited;
end;

function TRestClient.DoRequest(Method: TRequestMethod; ResourceRequest: TResource; AHandler: TRestResponseHandler): string;
const
  AuthorizationHeader = 'Authorization';
var
  vResponse: TStringStream;
  vUrl: string;
  vResponseString: string;
  vRetryMode: THTTPRetryMode;
  vHeaders: TStrings;
  vEncodedCredentials: string;
  vHttpError: EHTTPError;
begin
  CheckConnection;

  vResponse := TStringStream.Create('');
  try
    vHeaders := ResourceRequest.GetHeaders;

    if (FLogin <> EmptyStr) and (vHeaders.IndexOfName(AuthorizationHeader) = -1) then
    begin
      vEncodedCredentials := TRestUtils.Base64Encode(Format('%s:%s', [FLogin, FPassword]));
      vHeaders.Values[AuthorizationHeader] := 'Basic ' + vEncodedCredentials;
    end;
    FHttpConnection.SetParameters(ResourceRequest.GetParams);
    FHttpConnection.SetAcceptTypes(ResourceRequest.GetAcceptTypes).SetContentTypes(ResourceRequest.GetContentTypes).SetHeaders(vHeaders).SetAcceptedLanguages(ResourceRequest.GetAcceptedLanguages).ConfigureTimeout(FTimeOut).ConfigureProxyCredentials(FProxyCredentials).SetAsync(ResourceRequest.GetAsync).SetOnAsyncRequestProcess(FOnAsyncRequestProcess);
    vUrl := ResourceRequest.GetURL;

    ResourceRequest.GetContent.Position := 0;
    if assigned(OnBeforeRequest) then
      OnBeforeRequest(self, ResourceRequest, Method);
    ResourceRequest.GetContent.Position := 0;
    try
      case Method of
        METHOD_GET:
          FHttpConnection.Get(vUrl, vResponse);
        METHOD_POST:
          FHttpConnection.Post(vUrl, ResourceRequest.GetContent, vResponse);
        METHOD_PUT:
          FHttpConnection.Put(vUrl, ResourceRequest.GetContent, vResponse);
        METHOD_PATCH:
          FHttpConnection.Patch(vUrl, ResourceRequest.GetContent, vResponse);
        METHOD_DELETE:
          FHttpConnection.Delete(vUrl, ResourceRequest.GetContent, vResponse);
      end;
      vResponseString := UTF8Decode(vResponse.DataString);
      
      if ResponseCodeRaisesError(FHttpConnection.ResponseCode) then
        raise EHTTPError.Create(format('HTTP Error: %d, %s', [FHttpConnection.ResponseCode, vResponseString]), vUrl, EmptyStr, Result, FHttpConnection.ResponseCode);
      if Assigned(AHandler) then
        AHandler(vResponse)
      else
      begin
        vResponseString := vResponse.DataString;
        Result := UTF8Decode(vResponse.DataString);
        if Assigned(OnResponse) then
          OnResponse(Self, FHttpConnection.ResponseCode, Result);
      end;
      if assigned(OnAfterRequest) then
        OnAfterRequest(self, ResourceRequest, Method);
    except
      on E: EHTTPError do
      begin
        vRetryMode := hrmRaise;
        if assigned(FOnError) then
        begin
          vHttpError := EHTTPError.Create(E.Message, result, E.Url, e.Method, FHTTPConnection.ResponseCode);
          try
            FOnError(self, ResourceRequest, Method, vHttpError, vRetryMode);
          finally
            vHttpError.Free;
          end;
        end;
        if vRetryMode = hrmRaise then
          raise EHTTPError.Create(format('HTTP Error: %d', [FHttpConnection.ResponseCode]), result, E.Url, e.Method, FHTTPConnection.ResponseCode)
        else if vRetryMode = hrmRetry then
          result := DoRequest(Method, ResourceRequest, AHandler)
        else
          result := '';
      end;
    end;
  finally
    vResponse.Free;
    FResources.Remove(ResourceRequest);
  end;
end;

function TRestClient.GetOnConnectionLost: THTTPConnectionLostEvent;
begin
  result := FHttpConnection.OnConnectionLost;
end;

function TRestClient.GetOnError: THTTPErrorEvent;
begin
  result := FOnError;
end;

function TRestClient.GetResponseCode: Integer;
begin
  CheckConnection;

  Result := FHttpConnection.ResponseCode;
end;

function TRestClient.GetResponseHeader(const Header: string): string;
begin
  CheckConnection;

  Result := FHttpConnection.ResponseHeader[Header];
end;

procedure TRestClient.RecreateConnection;
begin
  if not (csDesigning in ComponentState) then
  begin
    FHttpConnection := THttpConnectionProviderFactory.NewConnection;
    FHttpConnection.EnabledCompression := FEnabledCompression;
    FHttpConnection.VerifyCert := FVerifyCert;
  end;
end;

procedure TRestClient.CheckConnection;
begin
  if (FHttpConnection = nil) then
  begin
    raise EInactiveConnection.CreateFmt('%s: Connection is not active.', [Name]);
  end;
end;

procedure TRestClient.Loaded;
begin
//  RecreateConnection;
end;

function TRestClient.Resource(URL: string): IResource;
begin
  Result := TResource.Create(Self, URL);

  FResources.Add(Result);
end;

function TRestClient.ResponseCodeRaisesError(ResponseCode: Integer): Boolean;
begin
  Result := (ResponseCode >= TStatusCode.BAD_REQUEST.StatusCode);
end;

procedure TRestClient.SetVerifyCertificate(AValue: boolean);
begin
  if FVerifyCert = AValue then
    exit;
  FVerifyCert := AValue;
  if Assigned(FHttpConnection) then
  begin
    FHttpConnection.VerifyCert := FVerifyCert;
  end;
end;

function TRestClient.SetCredentials(const ALogin, APassword: string): TRestClient;
begin
  FLogin := ALogin;
  FPassword := APassword;
  Result := Self;
end;

procedure TRestClient.SetEnabledCompression(const Value: Boolean);
begin
  if (FEnabledCompression <> Value) then
  begin
    FEnabledCompression := Value;

    if Assigned(FHttpConnection) then
    begin
      FHttpConnection.EnabledCompression := FEnabledCompression;
    end;
  end;
end;

procedure TRestClient.SetOnConnectionLost(AConnectionLostEvent: THTTPConnectionLostEvent);
begin
  FHttpConnection.OnConnectionLost := AConnectionLostEvent;
end;

procedure TRestClient.SetOnError(AErrorEvent: THTTPErrorEvent);
begin
  FOnError := AErrorEvent;
end;

function TRestClient.UnWrapConnection: IHTTPConnectionProvider;
begin
  Result := FHttpConnection;
end;

{ TResource }

function TResource.Accept(AcceptType: string): IResource;
begin
  FAcceptTypes := FAcceptTypes + IfThen(FAcceptTypes <> EmptyStr, ',') + AcceptType;
  Result := Self;
end;

procedure TResource.Get(AHandler: TRestResponseHandler);
begin
  FRestClient.DoRequest(METHOD_GET, Self, AHandler);
end;

procedure TResource.Post(Content: TStream; AHandler: TRestResponseHandler);
begin
  Content.Position := 0;
  FContent.CopyFrom(Content, Content.Size);

  FRestClient.DoRequest(METHOD_POST, Self, AHandler);
end;

function TResource.Put(Content: string): string;
var
  vStringStream: TStringStream;
begin
  vStringStream := TStringStream.Create(Content);
  try
    Result := Put(vStringStream);
  finally
    vStringStream.Free;
  end;
end;

function TResource.Post(Content: string): string;
var
  vStringStream: TStringStream;
begin
  vStringStream := TStringStream.Create(AnsiToUtf8(Content));
  try
    Result := Post(vStringStream);
  finally
    vStringStream.Free;
  end;
end;

procedure TResource.Put(Content: TStream; AHandler: TRestResponseHandler);
begin
  Content.Position := 0;
  FContent.CopyFrom(Content, Content.Size);

  FRestClient.DoRequest(METHOD_PUT, Self, AHandler);
end;

function TResource.Get(EntityClass: TClass): TObject;
var
  vResponse: string;
begin
  vResponse := Self.Get;

  Result := TJsonUtil.UnMarshal(EntityClass, vResponse);
end;

function TResource.GetAcceptedLanguages: string;
begin
  Result := FAcceptedLanguages;
end;

function TResource.AcceptLanguage(Language: string): IResource;
begin
  Result := Header('Accept-Language', Language);
end;

function TResource.Async(const Value: Boolean = True): TResource;
begin
  FAsync := True;

  Result := Self;
end;

function TResource.Authorization(Authorization: string): IResource;
begin
  Result := Header('Authorization', Authorization);
end;

function TResource.BindQueryParams: IResource;
begin
  Result := Self;
end;

function TResource.ContentType(ContentType: string): IResource;
begin
  FContentTypes := ContentType;

  Result := Self;
end;

constructor TResource.Create(RestClient: TRestClient; URL: string);
begin
  inherited Create;
  FRestClient := RestClient;
  FURL := URL;
  FContent := TMemoryStream.Create;
  FHeaders := TStringList.Create;
  FGetParams := TStringList.Create;
  FGetParams.Delimiter := '&';
end;

procedure TResource.Delete();
begin
  FRestClient.DoRequest(METHOD_DELETE, Self);
end;

procedure TResource.Delete(Entity: TObject);
begin
  SetContent(Entity);

  FRestClient.DoRequest(METHOD_DELETE, Self);
end;

destructor TResource.Destroy;
begin
  FRestClient.FResources.Remove(Self);
  FContent.Free;
  FHeaders.Free;
  FGetParams.Free;
  inherited;
end;

function TResource.Get: string;
begin
  Result := FRestClient.DoRequest(METHOD_GET, Self);
end;

function TResource.GetAcceptTypes: string;
begin
  Result := FAcceptTypes;
end;

function TResource.GetAsync: Boolean;
begin
  Result := FAsync;
end;

function TResource.GetContent: TStream;
begin
  Result := FContent;
end;

function TResource.GetContentTypes: string;
begin
  Result := FContentTypes;
end;

function TResource.GetHeaders: TStrings;
begin
  Result := FHeaders;
end;

function TResource.GetParams: TStrings;
begin
  Result := FGetParams;
end;

function TResource.GetURL: string;
begin
  Result := FURL;
end;

function TResource.Header(Name, Value: string): IResource;
begin
  FHeaders.Values[Name] := Value;
  Result := Self;
end;

function TResource.Post(Content: TStream): string;
begin
  Content.Position := 0;
  FContent.CopyFrom(Content, Content.Size);

  Result := FRestClient.DoRequest(METHOD_POST, Self);
end;

function TResource.Get(AListClass, AItemClass: TClass): TObject;
var
  vResponse: string;
begin
  vResponse := Self.Get;

  Result := TOldRttiUnMarshal.FromJsonArray(AListClass, AItemClass, vResponse);
end;

function TResource.Param(Name, Value: string): IResource;
begin
  FGetParams.Values[Name] := Value;
  Result := Self;
end;

function TResource.GetAsDataSet(const RootElement: string): TDataSet;
var
  vJson: ISuperObject;
begin
  if RootElement <> EmptyStr then
  begin
    vJson := SuperObject.SO(Get);
    Result := TJsonToDataSetConverter.CreateDataSetMetadata(vJson[RootElement]);
    TJsonToDataSetConverter.UnMarshalToDataSet(Result, vJson[RootElement]);
  end
  else
  begin
    Result := GetasDataSet();
  end;
end;

function TResource.GetAsDataSet: TDataSet;
var
  vJson: ISuperObject;
begin
  vJson := SuperObject.SO(Get);

  Result := TJsonToDataSetConverter.CreateDataSetMetadata(vJson);

  TJsonToDataSetConverter.UnMarshalToDataSet(Result, vJson);
end;

procedure TResource.GetAsDataSet(ADataSet: TDataSet);
var
  vJson: string;
begin
  vJson := Self.Get;

  TJsonToDataSetConverter.UnMarshalToDataSet(ADataSet, vJson);
end;

procedure TResource.SetContent(entity: TObject);
var
  vRawContent: string;
  vStream: TStringStream;
begin
  FContent.Clear;
  if not Assigned(entity) then
    Exit;

  vRawContent := AnsiToUtf8(TJsonUtil.Marshal(entity));

  vStream := TStringStream.Create(vRawContent);
  try
    vStream.Position := 0;
    FContent.CopyFrom(vStream, vStream.Size);
  finally
    vStream.Free;
  end;
end;

function TResource.Put(Content: TStream): string;
begin
  if Content <> nil then
  begin
    Content.Position := 0;
    FContent.CopyFrom(Content, Content.Size);
  end;
  Result := FRestClient.DoRequest(METHOD_PUT, Self);
end;

function TResource.Post(Entity: TObject): TObject;
var
  vResponse: string;
begin
  if Entity <> nil then
    SetContent(Entity);
  vResponse := FRestClient.DoRequest(METHOD_POST, Self);
  if trim(vResponse) <> '' then
    Result := TJsonUtil.UnMarshal(Entity.ClassType, vResponse)
  else
    Result := nil;
end;

procedure TResource.Post(AParamObject: TObject; AResultDataSet: TDataSet);
var
  vResponse: string;
begin
  if AParamObject <> nil then
    SetContent(AParamObject);
  vResponse := FRestClient.DoRequest(METHOD_POST, Self);
  if trim(vResponse) <> '' then
    TJsonToDataSetConverter.UnMarshalToDataSet(AResultDataSet, vResponse);
end;

function TResource.Post(AParamObject: TObject; AResultEntityClass: TClass): TObject;
var
  vResponse: string;
begin
  if AParamObject <> nil then
    SetContent(AParamObject);
  vResponse := FRestClient.DoRequest(METHOD_POST, Self);
  if trim(vResponse) <> '' then
    Result := TJsonUtil.UnMarshal(AResultEntityClass, vResponse)
  else
    Result := nil;
end;

function TResource.Put(Entity: TObject): TObject;
var
  vResponse: string;
begin
  if Entity <> nil then
    SetContent(Entity);

  vResponse := FRestClient.DoRequest(METHOD_PUT, Self);
  if trim(vResponse) <> '' then
    Result := TJsonUtil.UnMarshal(Entity.ClassType, vResponse)
  else
    Result := nil;
end;

function TResource.Patch(Content: TStream): string;
begin
  Content.Position := 0;
  FContent.CopyFrom(Content, Content.Size);

  Result := FRestClient.DoRequest(METHOD_PATCH, Self);
end;

procedure TResource.Patch(Content: TStream; AHandler: TRestResponseHandler);
begin
  Content.Position := 0;
  FContent.CopyFrom(Content, Content.Size);

  FRestClient.DoRequest(METHOD_PATCH, Self, AHandler);
end;

function TResource.Param(Name: string; Value: integer): IResource;
begin
  Result := Param(Name, IntToStr(Value))
end;

function TResource.Patch(Entity: TObject): TObject;
var
  vResponse: string;
begin
  if Entity <> nil then
    SetContent(Entity);

  vResponse := FRestClient.DoRequest(METHOD_PATCH, Self);
  if trim(vResponse) <> '' then
    Result := TJsonUtil.UnMarshal(Entity.ClassType, vResponse)
  else
    Result := nil;
end;

function TResource.Patch(Content: string): string;
var
  vStringStream: TStringStream;
begin
  vStringStream := TStringStream.Create(Content);
  try
    Result := Patch(vStringStream);
  finally
    vStringStream.Free;
  end;
end;

{ TMultiPartFormData }

end.

