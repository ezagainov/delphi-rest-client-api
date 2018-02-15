unit WebService.ConnectionProvider;

interface

uses
  Classes, SysUtils;

const
  // TODO: Pref
  TIMEOUT_CONNECT_DEFAULT = 5000;
  TIMEOUT_SEND_DEFAULT = 5000;
  TIMEOUT_RECEIVE_DEFAULT = 5000;

type
  THttpConnectionProviderType = (hctUnknown, hctIndy);

  EHTTPError = class(Exception)
  private
    FErrorCode: integer;
    FErrorMessage: string;
    FMethod: string;
    FUrl: string;
    procedure SetMethod(const Value: string);
    procedure SetUrl(const Value: string);
  public
    constructor Create(const AMsg, AErrorMessage, AUrl, AMethod: string; const AErrorCode: integer); overload; virtual;
    property ErrorMessage: string read FErrorMessage;
    property ErrorCode: integer read FErrorCode;
    property Url: string read FUrl write SetUrl;
    property Method: string read FMethod write SetMethod;
  end;

  THTTPRetryMode = (hrmRaise, hrmIgnore, hrmRetry);
  TAsyncRequestProcessEvent = procedure(var Cancel: Boolean) of object;
  THTTPConnectionLostEvent = procedure(AException: Exception; AUri: String; var ARetryMode: THTTPRetryMode) of object;

  EHTTPVerifyCertError = class(Exception)
  end;

  TProxyCredentials = class(TComponent)
  private
    FUserName: string;
    FPassword: string;
  public
    function Informed: Boolean;
  published
    property UserName: string read FUserName write FUsername;
    property Password: string read FPassword write FPassword;
  end;

  TTimeOut = class(TComponent)
  private
    FConnectTimeout: Integer;
    FSendTimeout: Integer;
    FReceiveTimeout: Integer;
  public
    procedure AfterConstruction; override;
  published
    ///	<summary>
    ///	  Time-out value applied when establishing a communication socket with
    ///	  the target server, in milliseconds. The default value is 60,000 (60
    ///	  seconds).
    ///	</summary>
    property ConnectTimeout: Integer read FConnectTimeout write FConnectTimeout default TIMEOUT_CONNECT_DEFAULT;

    ///	<summary>
    ///	  Time-out value applied when sending an individual packet of request
    ///	  data on the communication socket to the target server, in
    ///	  milliseconds. A large request sent to an HTTP server are normally be
    ///	  broken up into multiple packets; the send time-out applies to sending
    ///	  each packet individually. The default value is 30,000 (30 seconds).
    ///	</summary>
    ///	<remarks>
    ///	  Property ignored for Indy connection
    ///	</remarks>
    property SendTimeout: Integer read FSendTimeout write FSendTimeout default TIMEOUT_SEND_DEFAULT;

    ///	<summary>
    ///	  Time-out value applied when receiving a packet of response data from
    ///	  the target server, in milliseconds. Large responses are be broken up
    ///	  into multiple packets; the receive time-out applies to fetching each
    ///	  packet of data off the socket. The default value is 30,000 (30
    ///	  seconds).
    ///	</summary>
    property ReceiveTimeout: Integer read FReceiveTimeout write FReceiveTimeout default TIMEOUT_RECEIVE_DEFAULT;
  end;

  {$M+}
  IHTTPConnectionProvider = interface
    ['{CF2CBB47-F10F-48C2-B271-5BCCABBD0BEE}']
    function SetAcceptTypes(AAcceptTypes: string): IHTTPConnectionProvider;
    function SetContentTypes(AContentTypes: string): IHTTPConnectionProvider;
    function SetAcceptedLanguages(AAcceptedLanguages: string): IHTTPConnectionProvider;
    function SetHeaders(AHeaders: TStrings): IHTTPConnectionProvider;
    function SetParameters(AParameters: TStrings): IHTTPConnectionProvider;
    function ConfigureTimeout(const ATimeOut: TTimeOut): IHTTPConnectionProvider;
    function ConfigureProxyCredentials(AProxyCredentials: TProxyCredentials): IHTTPConnectionProvider;
    function SetAsync(const Value: Boolean): IHTTPConnectionProvider;
    function SetOnAsyncRequestProcess(const Value: TAsyncRequestProcessEvent): IHTTPConnectionProvider;
    //
    procedure Get(var AUrl: string; AResponse: TStream);
    procedure Post(var AUrl: string; AContent, AResponse: TStream);
    procedure Put(var AUrl: string; AContent, AResponse: TStream);
    procedure Patch(var AUrl: string; AContent, AResponse: TStream);
    procedure Delete(var AUrl: string; AContent, AResponse: TStream);
    //
    function GetResponseCode: Integer;
    property ResponseCode: Integer read GetResponseCode;
    function GetResponseHeader(const Header: string): string;
    property ResponseHeader[const Header: string]: string read GetResponseHeader;


    procedure CancelRequest;
    function GetEnabledCompression: Boolean;
    procedure SetEnabledCompression(const Value: Boolean);
    property EnabledCompression: Boolean read GetEnabledCompression write SetEnabledCompression;
    function GetVerifyCert: Boolean;
    procedure SetVerifyCert(const Value: boolean);
    property VerifyCert: boolean read GetVerifyCert write SetVerifyCert;
    function GetOnConnectionLost: THTTPConnectionLostEvent;
    procedure SetOnConnectionLost(AConnectionLostEvent: THTTPConnectionLostEvent);
    property OnConnectionLost: THTTPConnectionLostEvent read GetOnConnectionLost write SetOnConnectionLost;
  end;
  {$M-}

implementation

{ THttpError }

constructor EHTTPError.Create(const AMsg, AErrorMessage, AUrl, AMethod: string; const AErrorCode: integer);
begin
  inherited Create(AMsg);
  FErrorMessage := AErrorMessage;
  FErrorCode := AErrorCode;
  FUrl := AUrl;
  FMethod := AMethod;
end;

{ TTimeOut }

procedure TTimeOut.AfterConstruction;
begin
  inherited;
  FConnectTimeout := TIMEOUT_CONNECT_DEFAULT;
  FSendTimeout := TIMEOUT_SEND_DEFAULT;
  FReceiveTimeout := TIMEOUT_RECEIVE_DEFAULT;
end;

{ TProxyCredentials }

function TProxyCredentials.Informed: Boolean;
begin
  Result := (FUserName <> '') and (FPassword <> '');
end;

procedure EHTTPError.SetMethod(const Value: string);
begin
  FMethod := Value;
end;

procedure EHTTPError.SetUrl(const Value: string);
begin
  FUrl := Value;
end;

end.

