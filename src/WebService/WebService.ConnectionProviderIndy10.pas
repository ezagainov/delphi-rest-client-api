unit WebService.ConnectionProviderIndy10;

interface

{$I DelphiRest.inc}

uses
  IdHTTP, WebService.ConnectionProvider, Classes, RestUtils, IdCompressorZLibEx,
  SysUtils, IdSSLOpenSSL, IdStack, RestException, IdUri, IdSSLOpenSSLHeaders;

type
  TIdHTTP = class(idHTTP.TIdHTTP)
  public
    procedure Delete(AURL: string);
    procedure Patch(AURL: string; ASource, AResponseContent: TStream);
  end;

  THttpConnectionIndy = class(TInterfacedObject, IHTTPConnectionProvider)
  private
    FIdHttp: TIdHTTP;
    FContainer: TComponent;
    FGetParams: TStrings;
    FEnabledCompression: Boolean;
    FVerifyCert: boolean;
    function ParamsUri: string;
    procedure CancelRequest;
    ///
    ///  Delphi 2007
    ///
    function IdSSLIOHandlerSocketOpenSSL1VerifyPeer(Certificate: TIdX509; AOk: Boolean): Boolean; overload;
    ///
    ///  Delphi 2010 and XE
    ///
    function IdSSLIOHandlerSocketOpenSSL1VerifyPeer(Certificate: TIdX509; AOk: Boolean; ADepth: Integer): Boolean; overload;
    ///
    ///  Delphi XE2 and newer
    ///
    function IdSSLIOHandlerSocketOpenSSL1VerifyPeer(Certificate: TIdX509; AOk: Boolean; ADepth, AError: Integer): Boolean; overload;
  public
    OnConnectionLost: THTTPConnectionLostEvent;
    constructor Create;
    destructor Destroy; override;
    function SetAcceptTypes(AAcceptTypes: string): IHTTPConnectionProvider;
    function SetAcceptedLanguages(AAcceptedLanguages: string): IHTTPConnectionProvider;
    function SetContentTypes(AContentTypes: string): IHTTPConnectionProvider;
    function SetHeaders(AHeaders: TStrings): IHTTPConnectionProvider;
    procedure Get(var AUrl: string; AResponse: TStream);
    procedure Post(var AUrl: string; AContent: TStream; AResponse: TStream);
    procedure Put(var AUrl: string; AContent: TStream; AResponse: TStream);
    procedure Patch(var AUrl: string; AContent: TStream; AResponse: TStream);
    procedure Delete(var AUrl: string; AContent: TStream; AResponse: TStream);
    function GetResponseCode: Integer;
    function GetResponseHeader(const Header: string): string;
    function GetEnabledCompression: Boolean;
    procedure SetEnabledCompression(const Value: Boolean);
    procedure SetVerifyCert(const Value: boolean);
    function GetVerifyCert: boolean;
    function SetAsync(const Value: Boolean): IHTTPConnectionProvider;
    function GetOnConnectionLost: THTTPConnectionLostEvent;
    procedure SetOnConnectionLost(AConnectionLostEvent: THTTPConnectionLostEvent);
    function ConfigureTimeout(const ATimeOut: TTimeOut): IHTTPConnectionProvider;
    function ConfigureProxyCredentials(AProxyCredentials: TProxyCredentials): IHTTPConnectionProvider;
    function SetOnAsyncRequestProcess(const Value: TAsyncRequestProcessEvent): IHTTPConnectionProvider;
    function SetParameters(AParameters: TStrings): IHTTPConnectionProvider;
  end;

implementation

uses
  ProxyUtils, StrUtils;

{ THttpConnectionIndy }

procedure THttpConnectionIndy.CancelRequest;
begin
  //
end;

function THttpConnectionIndy.ConfigureProxyCredentials(AProxyCredentials: TProxyCredentials): IHTTPConnectionProvider;
begin
  if assigned(AProxyCredentials) then
    if AProxyCredentials.Informed and ProxyActive then
    begin
      FIdHttp.ProxyParams.BasicAuthentication := True;
      FIdHttp.ProxyParams.ProxyUsername := AProxyCredentials.UserName;
      FIdHttp.ProxyParams.ProxyPassword := AProxyCredentials.Password;
    end;
  Result := Self;
end;

function THttpConnectionIndy.ConfigureTimeout(const ATimeOut: TTimeOut): IHTTPConnectionProvider;
begin
  FIdHttp.ConnectTimeout := ATimeOut.ConnectTimeout;
  FIdHttp.ReadTimeout := ATimeOut.ReceiveTimeout;
  Result := Self;
end;

constructor THttpConnectionIndy.Create;
var
  ssl: TIdSSLIOHandlerSocketOpenSSL;
  ProxyServerIP: string;
begin
  FContainer := TComponent.Create(nil);

  FIdHttp := TIdHTTP.Create(FContainer);

  if IdSSLOpenSSLHeaders.Load then
  begin
    ssl := TIdSSLIOHandlerSocketOpenSSL.Create(FIdHttp);
    ssl.OnVerifyPeer := IdSSLIOHandlerSocketOpenSSL1VerifyPeer;
    ssl.SSLOptions.Method := sslvTLSv1;
    FIdHttp.IOHandler := ssl;
  end;

  FIdHttp.HandleRedirects := True;
  FIdHttp.Request.CustomHeaders.FoldLines := false;

  FGetParams := TStringList.Create;
  FGetParams.Delimiter := '&';

  if ProxyActive then
  begin
    ProxyServerIP := GetProxyServerIP;
    if ProxyServerIP <> '' then
    begin
      FIdHttp.ProxyParams.ProxyServer := ProxyServerIP;
      FIdHttp.ProxyParams.ProxyPort := GetProxyServerPort;
    end;
  end;
end;

procedure THttpConnectionIndy.Delete(var AUrl: string; AContent, AResponse: TStream);
var
  retryMode: THTTPRetryMode;
  temp: TStringStream;
begin
  try
    FIdHttp.Request.Source := AContent;
    FIdHttp.Delete(AUrl);
  except
    on E: EIdHTTPProtocolException do
    begin
      if Length(E.ErrorMessage) > 0 then
      begin
        temp := TStringStream.Create(E.ErrorMessage);
        try
          AResponse.CopyFrom(temp, temp.Size);
        finally
          temp.Free;
        end;
      end;
    end;
    on E: EIdSocketError do
    begin
      FIdHttp.Disconnect(false);
      retryMode := hrmRaise;
      if assigned(OnConnectionLost) then
        OnConnectionLost(e, AUrl, retryMode);
      if retryMode = hrmRaise then
        raise EHTTPError.Create(E.Classname, E.Message, AUrl, Id_HTTPMethodDelete, e.LastError)
      else if retryMode = hrmRetry then
        Delete(AUrl, AContent, AResponse);
    end;
  end;
end;

destructor THttpConnectionIndy.Destroy;
begin
  FIdHttp.Free;
  FContainer.Free;
  FGetParams.Free;
  inherited;
end;

procedure THttpConnectionIndy.Get(var AUrl: string; AResponse: TStream);
var
  retryMode: THTTPRetryMode;
  temp: TStringStream;
  ParamsUriStr: string;
begin
  try
    ParamsUriStr := ParamsUri;
    if ParamsUriStr <> EmptyStr then
      AUrl := Format('%s?%s', [AUrl, ParamsUriStr]);
    FIdHttp.Get(AUrl, AResponse)
  except
    on E: EIdHTTPProtocolException do
    begin
      if Length(E.ErrorMessage) > 0 then
      begin
        temp := TStringStream.Create(E.ErrorMessage);
        try
          AResponse.CopyFrom(temp, temp.Size);
        finally
          temp.Free;
        end;
      end;
    end;
    on E: EIdSocketError do
    begin
      FIdHttp.Disconnect(false);
      retryMode := hrmRaise;
      if assigned(OnConnectionLost) then
        OnConnectionLost(e, AUrl, retryMode);
      if retryMode = hrmRaise then
        raise EHTTPError.Create(E.Classname, E.Message, AUrl, Id_HTTPMethodGet, 0) // Unreachable
      else if retryMode = hrmRetry then
        Get(AUrl, AResponse);
    end;
    on E: Exception do
    begin
      FIdHttp.Disconnect(false);
      retryMode := hrmRaise;
      if assigned(OnConnectionLost) then
        OnConnectionLost(e, AUrl, retryMode);
      if retryMode = hrmRaise then
        raise EHTTPError.Create(E.Classname, E.Message, AUrl, Id_HTTPMethodGet, 0) // Unreachable
      else if retryMode = hrmRetry then
        Get(AUrl, AResponse);
    end;
  end;
end;

function THttpConnectionIndy.GetEnabledCompression: Boolean;
begin
  Result := FEnabledCompression;
end;

function THttpConnectionIndy.GetOnConnectionLost: THTTPConnectionLostEvent;
begin
  result := OnConnectionLost;
end;

function THttpConnectionIndy.GetResponseCode: Integer;
begin
  Result := FIdHttp.ResponseCode;
end;

function THttpConnectionIndy.GetResponseHeader(const Header: string): string;
begin
  raise ENotSupportedException.Create('');
end;

function THttpConnectionIndy.GetVerifyCert: boolean;
begin
  result := FVerifyCert;
end;

function THttpConnectionIndy.IdSSLIOHandlerSocketOpenSSL1VerifyPeer(Certificate: TIdX509; AOk: Boolean): Boolean;
begin
  Result := IdSSLIOHandlerSocketOpenSSL1VerifyPeer(Certificate, AOk, -1);
end;

function THttpConnectionIndy.IdSSLIOHandlerSocketOpenSSL1VerifyPeer(Certificate: TIdX509; AOk: Boolean; ADepth: Integer): Boolean;
begin
  Result := IdSSLIOHandlerSocketOpenSSL1VerifyPeer(Certificate, AOk, ADepth, -1);
end;

function THttpConnectionIndy.IdSSLIOHandlerSocketOpenSSL1VerifyPeer(Certificate: TIdX509; AOk: Boolean; ADepth, AError: Integer): Boolean;
begin
  result := AOk;
  if not FVerifyCert then
  begin
    result := True;
  end;
end;

function THttpConnectionIndy.ParamsUri: string;
begin
  if FGetParams.Count > 0 then
  begin
    result := TIdURI.ParamsEncode((ReplaceStr(FGetParams.Text, sLineBreak, '&')));
    result := ReplaceStr(result, '{', '%7B');
    result := ReplaceStr(result, '{', '%7D');
  end
  else
    Result := EmptyStr;
end;

procedure THttpConnectionIndy.Patch(var AUrl: string; AContent, AResponse: TStream);
var
  retryMode: THTTPRetryMode;
  temp: TStringStream;
begin
  try
    FIdHttp.Patch(AUrl, AContent, AResponse);
  except
    on E: EIdHTTPProtocolException do
    begin
      if Length(E.ErrorMessage) > 0 then
      begin
        temp := TStringStream.Create(E.ErrorMessage);
        try
          AResponse.CopyFrom(temp, temp.Size);
        finally
          temp.Free;
        end;
      end;
    end;
    on E: EIdSocketError do
    begin
      FIdHttp.Disconnect(false);
      retryMode := hrmRaise;
      if assigned(OnConnectionLost) then
        OnConnectionLost(e, AUrl, retryMode);
      if retryMode = hrmRaise then
        raise EHTTPError.Create(E.Classname, E.Message, AUrl, 'PATCH', e.LastError)
      else if retryMode = hrmRetry then
        Patch(AUrl, AContent, AResponse);
    end;
  end;
end;

procedure THttpConnectionIndy.Post(var AUrl: string; AContent, AResponse: TStream);
var
  retryMode: THTTPRetryMode;
  temp: TStringStream;
begin
  try
    FIdHttp.Post(AUrl, AContent, AResponse);
  except
    on E: EIdHTTPProtocolException do
    begin
      if Length(E.ErrorMessage) > 0 then
      begin
        temp := TStringStream.Create(E.ErrorMessage);
        try
          AResponse.CopyFrom(temp, temp.Size);
        finally
          temp.Free;
        end;
      end;
    end;
    on E: EIdSocketError do
    begin
      FIdHttp.Disconnect(false);
      retryMode := hrmRaise;
      if assigned(OnConnectionLost) then
        OnConnectionLost(e, AUrl, retryMode);
      if retryMode = hrmRaise then
        raise EHTTPError.Create(E.Classname, E.Message, AUrl, Id_HTTPMethodPost, e.LastError)
      else if retryMode = hrmRetry then
        Post(AUrl, AContent, AResponse);
    end;
  end;
end;

procedure THttpConnectionIndy.Put(var AUrl: string; AContent, AResponse: TStream);
var
  retryMode: THTTPRetryMode;
  temp: TStringStream;
begin
  try
    FIdHttp.Put(AUrl, AContent, AResponse);
  except
    on E: EIdHTTPProtocolException do
    begin
      if Length(E.ErrorMessage) > 0 then
      begin
        temp := TStringStream.Create(E.ErrorMessage);
        try
          AResponse.CopyFrom(temp, temp.Size);
        finally
          temp.Free;
        end;
      end;
    end;
    on E: EIdSocketError do
    begin
      FIdHttp.Disconnect(false);
      retryMode := hrmRaise;
      if assigned(OnConnectionLost) then
        OnConnectionLost(e, AUrl, retryMode);
      if retryMode = hrmRaise then
        raise EHTTPError.Create(E.Classname, E.Message, AUrl, Id_HTTPMethodPut, e.LastError)
      else if retryMode = hrmRetry then
        Put(AUrl, AContent, AResponse);
    end;
  end;
end;

function THttpConnectionIndy.SetAcceptedLanguages(AAcceptedLanguages: string): IHTTPConnectionProvider;
begin
  FIdHttp.Request.AcceptLanguage := AAcceptedLanguages;
  Result := Self;
end;

function THttpConnectionIndy.SetAcceptTypes(AAcceptTypes: string): IHTTPConnectionProvider;
begin
  FIdHttp.Request.Accept := AAcceptTypes;
  Result := Self;
end;

function THttpConnectionIndy.SetAsync(const Value: Boolean): IHTTPConnectionProvider;
begin
  if Value then
    raise ENotImplemented.Create('Async requests not implemented for Indy.');

  Result := Self;
end;

function THttpConnectionIndy.SetContentTypes(AContentTypes: string): IHTTPConnectionProvider;
begin
  FIdHttp.Request.ContentType := AContentTypes;
  Result := Self;
end;

procedure THttpConnectionIndy.SetEnabledCompression(const Value: Boolean);
begin
  if (FEnabledCompression <> Value) then
  begin
    FEnabledCompression := Value;

    if FEnabledCompression then
    begin
      {$IFDEF DELPHI_XE2}
        {$Message Warn 'TIdCompressorZLib does not work properly in Delphi XE2. Access violation occurs.'}
      {$ENDIF}
      FIdHttp.Compressor := TIdCompressorZLibEx.Create(FIdHttp);
    end
    else
    begin
      FIdHttp.Compressor.Free;
      FIdHttp.Compressor := nil;
    end;
  end;
end;

function THttpConnectionIndy.SetHeaders(AHeaders: TStrings): IHTTPConnectionProvider;
var
  i: Integer;
begin
  FIdHttp.Request.Authentication.Free;
  FIdHttp.Request.Authentication := nil;
  FIdHttp.Request.CustomHeaders.Clear;

  for i := 0 to AHeaders.Count - 1 do
  begin
    FIdHttp.Request.CustomHeaders.Values[AHeaders.Names[i]] := AHeaders.ValueFromIndex[i];
  end;

  Result := Self;
end;

function THttpConnectionIndy.SetOnAsyncRequestProcess(const Value: TAsyncRequestProcessEvent): IHTTPConnectionProvider;
begin
  Result := Self;
end;

procedure THttpConnectionIndy.SetOnConnectionLost(AConnectionLostEvent: THTTPConnectionLostEvent);
begin
  OnConnectionLost := AConnectionLostEvent;
end;

function THttpConnectionIndy.SetParameters(AParameters: TStrings): IHTTPConnectionProvider;
begin
  FGetParams.Assign(AParameters);
end;

procedure THttpConnectionIndy.SetVerifyCert(const Value: boolean);
begin
  FVerifyCert := Value;
end;

{ TIdHTTP }

procedure TIdHTTP.Delete(AURL: string);
begin
  try
    DoRequest(Id_HTTPMethodDelete, AURL, Request.Source, nil, []);
  except
    on E: EIdHTTPProtocolException do
      raise EHTTPError.Create(e.Message, e.ErrorMessage, AURL, Id_HTTPMethodDelete, e.ErrorCode);
  end;
end;

procedure TIdHTTP.Patch(AURL: string; ASource, AResponseContent: TStream);
begin
  DoRequest('PATCH', AURL, ASource, AResponseContent, []);
end;

end.

