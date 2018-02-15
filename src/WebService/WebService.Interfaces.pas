unit WebService.Interfaces;

interface

uses
  SysUtils, Classes, Contnrs, StrUtils, RestUtils, DB;

type
  IResource = interface;
  IBaseInterface = interface
    ['{A59630AF-CE53-412A-8D1E-E360E3261515}']
    function Get: string; overload;
    function Get(AListClass, AItemClass: TClass): TObject; overload;
    function Get(EntityClass: TClass): TObject; overload;
    //
    function Post(Content: string): string; overload;
    function Post(AParamObject: TObject; AResultEntityClass: TClass): TObject; overload;
    procedure Post(AParamObject: TObject; AResultDataSet: TDataSet); overload;
    //
    procedure GetAsDataSet(ADataSet: TDataSet); overload;
    function GetAsDataSet(): TDataSet; overload;
    function GetAsDataSet(const RootElement: string): TDataSet; overload;
    function Header(Name: string; Value: string): IResource;
    function BindQueryParams: IResource;
  end;

  IResource = interface(IBaseInterface)
    ['{D549C7E4-EEC8-46AB-8F3C-E24AB20A83F1}']
    //
    function Accept(AcceptType: string): IResource;
    function ContentType(ContentType: string): IResource;
    function Param(Name: string; Value: string): IResource; overload;
    function Param(Name: string; Value: Integer): IResource; overload;
  end;

  IWebService = interface
    ['{4ABA66CB-0564-4B68-9221-935FAEAFEE0E}']
    function Resource(const URL: string): IResource;
    procedure AddEndPointInstance(AInstance: TObject);
    procedure RemoveEndPointInstance(AInstance: TObject);    
  end;

  IWebServiceEndPoint = interface(IBaseInterface)
    ['{69B06727-3AF6-4609-B9AE-CFF57EA7BADE}']
    function methodName: string;
    function acceptedMediaTypes: TMediaTypes;
    function contentType: TMediaTypes;
  
  end;

implementation

end.

