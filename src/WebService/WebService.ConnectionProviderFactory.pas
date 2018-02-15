unit WebService.ConnectionProviderFactory;

interface

{$I DelphiRest.inc}

uses
  WebService.ConnectionProvider;

type
  THttpConnectionProviderFactory = class
  public
    class function NewConnection: IHTTPConnectionProvider;
  end;

implementation

uses
  SysUtils, WebService.ConnectionProviderIndy10, Classes, TypInfo;
    
{ THttpConnectionFactory }

class function THttpConnectionProviderFactory.NewConnection: IHTTPConnectionProvider;
begin
  Result := THttpConnectionIndy.Create;
end;

end.

