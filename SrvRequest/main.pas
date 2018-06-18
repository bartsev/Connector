unit main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.SvcMgr,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param,
  FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf,
  FireDAC.Stan.Async, FireDAC.DApt, FireDAC.UI.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Phys, FireDAC.Phys.MSSQL, FireDAC.Phys.MSSQLDef,
  Data.DB, FireDAC.Comp.Client, FireDAC.Comp.DataSet, Xml.XMLDoc, Xml.XMLIntf,
  Xml.xmldom, FireDAC.Phys.ODBCBase;

type
  TGisSrvc = class(TService)
    qryParams: TFDQuery;
    Connection: TFDConnection;
    qryPayer: TFDQuery;
    qryPayerCount: TFDQuery;
    qryChargeRequest: TFDQuery;
    qryUpdateChargeRequest1: TFDQuery;
    qryUpdateChargeRequest2: TFDQuery;
    qryInsertChargeResponse: TFDQuery;
    qryPaymentRequest: TFDQuery;
    qryUpdatePaymentRequest1: TFDQuery;
    qryUpdatePaymentRequest2: TFDQuery;
    qryInsertPaymentResponse: TFDQuery;
    qryPaymentResponse: TFDQuery;
    qryUpdatePaymentResponse1: TFDQuery;
    qryUpdatePaymentResponse2: TFDQuery;
    qryCancelRequest: TFDQuery;
    qryUpdateCancelRequest1: TFDQuery;
    XMLDocument1: TXMLDocument;
    FDPhysMSSQLDriverLink1: TFDPhysMSSQLDriverLink;
    procedure ServiceExecute(Sender: TService);
    procedure ServicePause(Sender: TService; var Paused: Boolean);
    procedure ServiceStart(Sender: TService; var Started: Boolean);
    procedure ServiceStop(Sender: TService; var Stopped: Boolean);
    procedure ServiceCreate(Sender: TObject);
  private
    { Private declarations }
    Interval: integer;
    Server,Database,UserName,Password,LogFileName: string;
    SenderCode,SenderName,RecipientCode,RecipientName: string;
    IncFolder, OutFolder, IncBakFolder, OutBakFolder, CryptContainer: string;
    procedure LoadParams;
    procedure ConnectDatabase;
    function SoapGenID: string;
    procedure WriteLog(AMessage: string);
    function MessageHeader(SenderCode,SenderName,RecipientCode,RecipientName,
      ServiceName,Status: string; RequestId: string = ''): string;
    procedure SendChargeRequest;
    procedure SendPaymentRequest;
    procedure SendCancelRequest;
    procedure SendPaymentResultRequest;
    procedure SendCancelResultRequest;
    procedure LoadResponse;
    function IncludeRequestPayer(RequestId: integer): boolean;
    function SaveMessage(MessageText: string; MessageId, ActionId: integer): boolean;
    function SoapCreateMessage(CryptContainer: WideString; BodyContext: string): string;
    function CopyFileToFolder(const AFileName, AFolderName: string): boolean;
    function ChargeRequestMessageData(RequestId: integer): string;
    function PaymentRequestMessageData: string;
    function CancelRequestMessageData: string;
    function PaymentResultMessageData(MessageGUID: string): string;
    function GetNodeValue(Parent: IXMLNode; NodeName: string; ErrorString: string = ''): string;
    procedure LoadChargeResponse(XmlDoc: IXMLDocument; RequestId: integer; FileName: string);
    procedure LoadPaymentResponse(XmlDoc: IXMLDocument; RequestId: integer; FileName: string);
    procedure LoadCancelResponse(XmlDoc: IXMLDocument; FileName: string);
    procedure LoadPaymentResult(XmlDoc: IXMLDocument; RequestId: integer; FileName: string);
    procedure LoadCancelResult(XmlDoc: IXmlDocument; RequestId: integer; FileName: string);
    procedure ParseChargeResponse(XmlDoc: IXMLDocument; AFields: TStringList);
    procedure ParsePaymentResponse(XmlDoc: IXMLDocument; AFields: TStringList);
    procedure ParsePaymentResult(XmlDoc: IXMLDocument; AFields: TStringList);
    function MoveFileToFolder(const AFileName, AFolderName: string): boolean;
    function InsertChargeResponse(RequestId: integer; AFields: TStringList): boolean;
    procedure ParserExceptionHandler(AProc, AMessage: string; AFields: TStringList);
    function XmlReplace(Str: string): string;
  public
    function GetServiceController: TServiceController; override;
    { Public declarations }
  end;

var
  GisSrvc: TGisSrvc;

implementation

uses System.IniFiles, System.StrUtils, System.Math, uCryptHelper, ActiveX;

{$R *.dfm}

const
  ACT_CHARGE_REQUEST = 0;
  ACT_PAYMENT_REQUEST = 1;
  ACT_CANCEL_REQUEST = 2;
  ACT_PAYMENT_RESULT = 3;
  ACT_CANCEL_RESULT = 4;

  CXML = '<?xml version="1.0" encoding="UTF-8"?>';
  REQUEST_SERVICE = 'MNSVsvedPayGKYKO';
  PAYMENT_SERVICE = 'MNSVsvedPayKO';

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  GisSrvc.Controller(CtrlCode);
end;
//------------------------------------------------------------------------------
function TGisSrvc.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;
//------------------------------------------------------------------------------
procedure TGisSrvc.ServiceCreate(Sender: TObject);
begin
  IncBakFolder := ExtractFilePath(ParamStr(0)) + 'BAK\Inc';
  OutBakFolder := ExtractFilePath(ParamStr(0)) + 'BAK\Out';
  LogFileName  := ChangeFileExt(ParamStr(0), '.log');
end;
//------------------------------------------------------------------------------
procedure TGisSrvc.ServiceExecute(Sender: TService);
var
  i: integer;
begin
  while NOT Terminated do
  begin
    WriteLog('');

    try
      LoadParams();
      ConnectDatabase();
      if Connection.Connected then
      begin
        SendChargeRequest;
        SendPaymentRequest;
        SendCancelRequest;
        SendPaymentResultRequest;
        SendCancelResultRequest;
        LoadResponse;
      end
      else
        WriteLog('Нет соединения с SQL сервером');
    finally
      Connection.Connected := False;
    end;

    for i := 1 to Interval * 60 do
    begin
      Sleep(1000);
      ServiceThread.ProcessRequests(False);
      if Terminated then break;
    end;

  end;
end;
//------------------------------------------------------------------------------
procedure TGisSrvc.ServicePause(Sender: TService; var Paused: Boolean);
begin
//  WriteLog('On Pause');
  CoUnInitialize;
end;
//------------------------------------------------------------------------------
procedure TGisSrvc.ServiceStart(Sender: TService; var Started: Boolean);
begin
//  LoadParams;
  CoInitialize(nil);
  WriteLog(FormatDateTime('----- dddddd -----', Date));
//  ConnectDatabase();
end;
//------------------------------------------------------------------------------
procedure TGisSrvc.ServiceStop(Sender: TService; var Stopped: Boolean);
begin
//  WriteLog('On Stop');
  CoUnInitialize;
end;
//------------------------------------------------------------------------------
procedure TGisSrvc.SendChargeRequest;
var
  RequestId: integer;
  SoapMessage: string;
begin
  qryChargeRequest.Open;
  while NOT qryChargeRequest.Eof do
  begin
    RequestId := qryChargeRequest.FieldByName('Id').AsInteger;
    SoapMessage := SoapCreateMessage(CryptContainer, ChargeRequestMessageData(RequestId));
    if NOT SaveMessage(SoapMessage, RequestId, ACT_CHARGE_REQUEST) then break;
    qryUpdateChargeRequest1.Params.ParamByName('Request').Value := AnsiReplaceStr(SoapMessage, CXML, '');
    qryUpdateChargeRequest1.Params.ParamByName('Id').Value := RequestId;
    qryUpdateChargeRequest1.ExecSQL;
    qryChargeRequest.Next;
  end;
  qryChargeRequest.Close;
end;
//------------------------------------------------------------------------------
procedure TGisSrvc.SendPaymentRequest;
var
  RequestId: integer;
  SoapMessage: string;
begin
  qryPaymentRequest.Open;
  qryPaymentRequest.FetchAll;
  while NOT qryPaymentRequest.Eof do
  begin
    RequestId := qryPaymentRequest.FieldByName('Id').AsInteger;
    SoapMessage := SoapCreateMessage(CryptContainer, PaymentRequestMessageData);
    SaveMessage(SoapMessage, RequestId, ACT_PAYMENT_REQUEST);
    qryUpdatePaymentRequest1.Params.ParamByName('Id').Value := RequestId;
    qryUpdatePaymentRequest1.Params.ParamByName('Request').Value := AnsiReplaceStr(SoapMessage, CXML,'');
    try
      qryUpdatePaymentRequest1.ExecSQL;
    except
      on E:Exception do WriteLog(E.Message);
    end;
    qryPaymentRequest.Next;
  end;
  qryPaymentRequest.Close;
end;
//------------------------------------------------------------------------------
procedure TGisSrvc.SendCancelRequest;
var
  RequestId: integer;
  SoapMessage: string;
begin
(*
  qryCancelRequest.Open;
  while NOT qryCancelRequest.Eof do
  begin
    RequestId := qryCancelRequest.FieldByName('Id').AsInteger;
    SoapMessage := SoapCreateMessage(CryptContainer, CancelRequestMessageData);
    SaveMessage(SoapMessage, RequestId, ACT_CANCEL_REQUEST);
    qryUpdateCancelRequest1.Params.ParamByName('Id').Value := RequestId;
    qryUpdateCancelRequest1.Params.ParamByName('Request').Value := AnsiReplaceStr(SoapMessage, CXML,'');
    qryUpdateCancelRequest1.ExecSQL;
    qryCancelRequest.Next;
  end;
  qryPaymentRequest.Close();
*)
end;
//------------------------------------------------------------------------------
procedure TGisSrvc.SendPaymentResultRequest;
var
  RequestId: integer;
  SoapMessage, MessageGUID: string;
begin
  qryPaymentResponse.Open;
  while NOT qryPaymentResponse.Eof do
  begin
    RequestId := qryPaymentResponse.FieldByName('id').AsInteger;
    MessageGUID := qryPaymentResponse.FieldByName('MessageGUID').AsString;
    SoapMessage := SoapCreateMessage(CryptContainer, PaymentResultMessageData(MessageGUID));
    SaveMessage(SoapMessage, RequestId, ACT_PAYMENT_RESULT);
    qryUpdatePaymentResponse1.Params.ParamByName('Id').Value := RequestId;
    qryUpdatePaymentResponse1.Params.ParamByName('Request').Value := AnsiReplaceStr(SoapMessage, CXML,'');
    try
      qryUpdatePaymentResponse1.ExecSQL;
    except
      on E:Exception do WriteLog(E.Message);
    end;
    qryPaymentResponse.Next;
  end;
  qryPaymentResponse.Close;
end;
//------------------------------------------------------------------------------
procedure TGisSrvc.SendCancelResultRequest;
begin

end;
//------------------------------------------------------------------------------
procedure TGisSrvc.LoadResponse;
var
  S: TSearchRec;
  XmlDoc: IXmlDocument;
  ActionId, RequestId: integer;
begin
  if FindFirst(IncFolder + '\*.xml', faArchive, S) = 0 then
  repeat
    WriteLog(Copy(S.Name,1,11) + ': получен ответ');
    if NOT MoveFileToFolder(IncFolder + '\' + S.Name, IncBakFolder) then
      continue;
    try
      XmlDoc := NewXmlDocument;
      XmlDoc.LoadFromFile(IncBakFolder + '\' + S.Name);
    except
      on E:Exception do WriteLog('Ошибка чтения XML из файла ' + S.Name +': '+ E.Message);
    end;
    RequestId := StrToInt('$' + Copy(S.Name, 1, 8));
    ActionId := StrToInt(Copy(S.Name,11,1));
    case  ActionId of
      ACT_CHARGE_REQUEST : LoadChargeResponse(XmlDoc, RequestId, S.Name);
      ACT_PAYMENT_REQUEST: LoadPaymentResponse(XmlDoc, RequestId, S.Name);
      ACT_CANCEL_REQUEST : LoadCancelResponse(XmlDoc, S.Name);
      ACT_PAYMENT_RESULT : LoadPaymentResult(XmlDoc, RequestId, S.Name);
      ACT_CANCEL_RESULT  : LoadCancelResult(XmlDoc, RequestId, S.Name);
    end;
  until FindNext(S) <> 0;
  FindClose(S);
end;
//------------------------------------------------------------------------------
procedure TGisSrvc.LoadChargeResponse(XmlDoc: IXMLDocument; RequestId: integer; FileName: string);
const
  FieldName: array[0..25] of string = (
    'Status', 'ErrorCode', 'ErrorDesc', 'Year', 'Month', 'UnifiedAccountNumber',
    'region', 'city', 'housenum', 'FIASHouseGuid', 'apartment', 'address_string',
    'PaymentDocumentID', 'AccountNumber', 'INN', 'KPP', 'Name', 'RecipientINN',
    'RecipientKPP', 'BankName', 'PaymentRecipient', 'BankBIK', 'operatingAccountNumber',
    'CorrespondentBankAccount', 'DocErrorCode', 'DocErrorDesc');
var
  i: integer;
  XmlFields: TStringList;
begin
  try
    XmlFields := TStringList.Create;
    for i := 0 to High(FieldName) do
      XmlFields.Add(FieldName[i] + '=');
    ParseChargeResponse(XmlDoc, XmlFields);
    with qryUpdateChargeRequest2 do
    begin
      Params.ClearValues;
      Params.ParamByName('id').Value := RequestId;
      Params.ParamByName('Status').Value := XmlFields.Values['Status'];
      if XmlFields.Values['ErrorCode'] <> '' then
      begin
        Params.ParamByName('ErrorCode').Value := XmlFields.Values['ErrorCode'];
        Params.ParamByName('ErrorDesc').Value := XmlFields.Values['ErrorDesc'];
      end;
      Params.ParamByName('Response').Value := AnsiReplaceStr(XmlDoc.XML.Text ,CXML,'');
      try
        ExecSQL;
      except
        on E:Exception do WriteLog('qryUpdateChargeRequest2 error: ' + E.Message);
      end;
    end;
    if InsertChargeResponse(RequestId, XmlFields) then
      WriteLog(Copy(FileName,1,11) + ': ответ записан в базу данных');
  finally
    XmlFields.Free;
  end;
end;
//------------------------------------------------------------------------------
procedure TGisSrvc.LoadPaymentResponse(XmlDoc: IXMLDocument; RequestId: integer; FileName: string);
const
  FieldName: array[0..3] of string = (
    'Status', 'MessageGUID', 'ErrorCode', 'ErrorDesc');
var
  i: integer;
  XmlFields: TStringList;
begin
  try
    XmlFields := TStringList.Create;
    for i := 0 to High(FieldName) do
      XmlFields.Add(FieldName[i] + '=');
    ParsePaymentResponse(XmlDoc, XmlFields);
    with qryUpdatePaymentRequest2 do
    begin
      Params.ClearValues;
      Params.ParamByName('Id').Value := RequestId;
      Params.ParamByName('Status').Value := XmlFields.Values['Status'];
      if XmlFields.Values['ErrorCode'] <> '' then
      begin
        Params.ParamByName('ErrorCode').Value := XmlFields.Values['ErrorCode'];
        Params.ParamByName('ErrorDesc').Value := XmlFields.Values['ErrorDesc'];
      end;
      Params.ParamByName('Response').Value := AnsiReplaceStr(XmlDoc.XML.Text ,CXML,'');
      try
        ExecSQL;
      except
        on E:Exception do WriteLog('qryUpdatePaymentRequest2 error: ' + E.Message);
      end;
    end;
    if XmlFields.Values['MessageGUID'] <> '' then
      with qryInsertPaymentResponse do
      begin
        Params.ParamByName('Id_Request').Value := RequestId;
        Params.ParamByName('MessageGUID').Value := XmlFields.Values['MessageGUID'];
        try
          ExecSQL;
        except
          on E:Exception do WriteLog('qryInsertPaymentResponse error: ' + E.Message);
        end;
      end;
  finally
    XmlFields.Free;
  end;
end;
//------------------------------------------------------------------------------
procedure TGisSrvc.LoadCancelResponse(XmlDoc: IXMLDocument; FileName: string);
begin

end;
//------------------------------------------------------------------------------
procedure TGisSrvc.LoadPaymentResult(XmlDoc: IXMLDocument; RequestId: integer; FileName: string);
const
  FieldName: array[0..3] of string = (
    'Status', 'ErrorCode', 'ErrorDesc', 'UpdateDate');
var
  i: integer;
  XmlFields: TStringList;
begin
  try
    XmlFields := TStringList.Create;
    for i := 0 to High(FieldName) do
      XmlFields.Add(FieldName[i] + '=');
    ParsePaymentResult(XmlDoc, XmlFields);
    with qryUpdatePaymentResponse2 do
    begin
      Params.ClearValues;
      Params.ParamByName('Id').Value := RequestId;
      Params.ParamByName('Status').Value := XmlFields.Values['Status'];
      Params.ParamByName('Response').Value := AnsiReplaceStr(XmlDoc.XML.Text ,CXML,'');
      if XmlFields.Values['ErrorCode'] <> '' then
      begin
        Params.ParamByName('ErrorCode').Value := XmlFields.Values['ErrorCode'];
        Params.ParamByName('ErrorDesc').Value := XmlFields.Values['ErrorDesc'];
      end;
      if XmlFields.Values['UpdateDate'] <> '' then
        Params.ParamByName('UpdateDate').Value := XmlFields.Values['UpdateDate'];
      try
        ExecSQL;
      except
        on E:Exception do WriteLog(E.Message);
      end;
    end;
  finally
    XmlFields.Free;
  end;
end;
//------------------------------------------------------------------------------
procedure TGisSrvc.LoadCancelResult(XmlDoc: IXmlDocument; RequestId: integer; FileName: string);
begin

end;
//------------------------------------------------------------------------------
procedure TGisSrvc.LoadParams;
begin
  with TIniFile.Create(ChangeFileExt(ParamStr(0), '.ini')) do
  try
    IncFolder := ReadString('Params','IncFolder','');
    OutFolder := ReadString('Params','OutFolder','');
    CryptContainer := ReadString('Params','CryptContainer','');
    Server   := ReadString('ServerSQL','Server','');
    Database := ReadString('ServerSQL','Database','');
    UserName := ReadString('ServerSQL','UserName','');
    Password := ReadString('ServerSQL','Password','');
    Interval := ReadInteger('Params','DelayMinutes',5);
    SenderCode := ReadString('InfoSystem','SenderCode','');
    SenderName := ReadString('InfoSystem','SenderName','');
    RecipientCode := ReadString('InfoSystem','RecipientCode','');
    RecipientName := ReadString('InfoSystem','RecipientName','');
  finally
    Free;
  end;
end;
//------------------------------------------------------------------------------
procedure TGisSrvc.ConnectDatabase;
  procedure CheckParam(ParamName: string);
  begin
    if Connection.Params.IndexOfName(ParamName) = -1 then
      Connection.Params.Add(ParamName + '=');
  end;
begin
  CheckParam('Server');
  CheckParam('Database');
  CheckParam('User_name');
  CheckParam('Password');

  Connection.Params.Values['Server'] := Server;
  Connection.Params.Values['Database'] := Database;
  Connection.Params.Values['User_name'] := UserName;
  Connection.Params.Values['Password'] := Password;

  try
    Connection.Connected := True;
  except
    WriteLog('Ошибка при соединении с SQL сервером!');
    WriteLog('Connection Params:');
    WriteLog(Connection.Params.Text);
  end;

end;
//------------------------------------------------------------------------------
function TGisSrvc.SoapCreateMessage(CryptContainer: WideString; BodyContext: string): string;
var
  DataStream: TStream;
  Cert,Hash,Sign: TBytesStream;
  SignedInfo,Security: string;
  TimeStamp: string;
  CertId,KeyId,STRId,SignID: string;
begin

//обертка данных сообщения блоком <Body>
  BodyContext:=
    '<soapenv:Body '+
    'xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" '+
    'xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" '+
    'wsu:Id="body">'+
    BodyContext +
    '</soapenv:Body>';

  DataStream := TStringStream.Create(BodyContext, TEncoding.UTF8);
  Hash := TBytesStream.Create;
  try
    try

//вычисление хеша блока <Body>
      GetHashStream(CryptContainer, DataStream, nil, nil, Hash, nil);

//блок для подписи
      SignedInfo:=
        '<ds:SignedInfo xmlns:ds="http://www.w3.org/2000/09/xmldsig#">'+
        '<ds:CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#">'+
        '</ds:CanonicalizationMethod>'+
        '<ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#gostr34102001-gostr3411">'+
        '</ds:SignatureMethod>'+
        '<ds:Reference URI="#body">'+
        '<ds:Transforms>'+
        '<ds:Transform Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#">'+
        '</ds:Transform>'+
        '</ds:Transforms>'+
        '<ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#gostr3411">'+
        '</ds:DigestMethod>'+
        '<ds:DigestValue>'+
//хэш элемента <soapenv:Body> по алгоритму ГОСТ Р 34.11-94 в формате base64
        StreamAsBase64(Hash)+
        '</ds:DigestValue>'+
        '</ds:Reference>'+
        '</ds:SignedInfo>';
    except
      on E:Exception do WriteLog('SoapCreateMessage(1): ' + E.Message);
    end;

  finally
    DataStream.Free;
    Hash.Free;
  end;

  DataStream := TStringStream.Create(SignedInfo,TEncoding.ansi);//UTF8);
  Cert := TBytesStream.Create;
  Sign := TBytesStream.Create;
  try
    try

//подпись <SignedInfo> и получение данных сертификата
      GetHashStream(CryptContainer, DataStream, Cert, nil, nil, Sign);

      TimeStamp := '';
      CertId := 'CertId-' + SoapGenID;
      KeyId := 'KeyId-' + SoapGenID;
      STRId := 'STRId-' + SoapGenID;
      SignID := 'SignID-' + SoapGenID;

      Security :=
        '<wsse:Security '+
        'soapenv:actor="http://smev.gosuslugi.ru/actors/smev" xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">'+
        '<wsse:BinarySecurityToken '+
        'EncodingType="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary" '+
        'ValueType="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-x509-token-profile-1.0#X509v3" '+
        'wsu:Id="' + CertId + '">'+
//сертификат в формате Base64
        StreamAsBase64(Cert)+
        '</wsse:BinarySecurityToken>'+
        '<ds:Signature Id="' + SignID + '" '+
        'xmlns:ds="http://www.w3.org/2000/09/xmldsig#">'+
//вставим готовый блок <SignedInfo>
        SignedInfo+
        '<ds:SignatureValue>'+
//электронная подпись для <ds:SignedInfo> по алгоритму ГОСТ Р 34.11-2001 в формате base64
        StreamAsBase64(Sign)+
        '</ds:SignatureValue>'+
        '<ds:KeyInfo Id="' + KeyId + '">'+
        '<wsse:SecurityTokenReference wsu:Id="' + STRId + '">'+
        '<wsse:Reference URI="#' + CertId + '" '+
        'ValueType="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-x509-token-profile-1.0#X509v3"/>'+
        '</wsse:SecurityTokenReference>'+
        '</ds:KeyInfo>'+
        '</ds:Signature>'+
        '</wsse:Security>';

//soap envelope
      Result:=
        '<?xml version="1.0" encoding="UTF-8"?>'+
        '<soapenv:Envelope '+
        'xmlns:rev="http://smev.gosuslugi.ru/rev120315" ' +
        'xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" '+
        'xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">'+
        '<soapenv:Header>'+
        Security +
        '</soapenv:Header>' +
        BodyContext +
        '</soapenv:Envelope>';
    except
      on E:Exception do WriteLog('SoapCreateMessage(2): ' + E.Message);
    end;

  finally
    DataStream.Free;
    Cert.Free;
    Sign.Free;
  end;

end;
//------------------------------------------------------------------------------
function TGisSrvc.SaveMessage(MessageText: string; MessageId, ActionId: integer): boolean;
var
  FileName: string;
  Request: TStringStream;
begin
  Result := False;
  Request := TStringStream.Create(MessageText,TEncoding.UTF8);
  FileName := IncludeTrailingBackslash(OutBakFolder) + IntToHex(MessageId, 8) + 'rq' + Trim(IntToStr(ActionId)) + '.xml';
  try
    Request.SaveToFile(FileName);
  except
    WriteLog('Ошибка при записи в файл ' + FileName);
    Exit;
  end;
  if NOT CopyFileToFolder(FileName, OutFolder) then
    Exit;
  WriteLog(Copy(ExtractFileName(FileName),1,11) + ': записан в файл');
  Result := True;
end;
//------------------------------------------------------------------------------
function TGisSrvc.InsertChargeResponse(RequestId: integer; AFields: TStringList): boolean;
begin
  Result := True;
  with qryInsertChargeResponse do
  try
    Open;
    Append;
    FieldByName('id_ChargeRequest').AsInteger := RequestId;
    FieldByName('Year').AsString := AFields.Values['Year'];
    FieldByName('Month').AsString := AFields.Values['Month'];
    FieldByName('UnifiedAccountNumber').AsString := AFields.Values['UnifiedAccountNumber'];
    FieldByName('Region').AsString := AFields.Values['region'];
    FieldByName('City').AsString := AFields.Values['city'];
    FieldByName('HouseNumber').AsString := AFields.Values['housenum'];
    FieldByName('FIASHouseGuid').AsString := AFields.Values['FIASHouseGuid'];
    FieldByName('Apartment').AsString := AFields.Values['apartment'];
    FieldByName('Address').AsString := AFields.Values['address_string'];
    FieldByName('PaymentDocumentID').AsString := AFields.Values['PaymentDocumentID'];
    FieldByName('AccountNumber').AsString := AFields.Values['AccountNumber'];
    FieldByName('RecipientINN').AsString := AFields.Values['RecipientINN'];
    FieldByName('RecipientKPP').AsString := AFields.Values['RecipientKPP'];
    FieldByName('BankName').AsString := AFields.Values['BankName'];
    FieldByName('RecipientName').AsString := AFields.Values['PaymentRecipient'];
    FieldByName('BankBIK').AsString := AFields.Values['BankBIK'];
    FieldByName('OperatingAccount').AsString := AFields.Values['operatingAccountNumber'];
    FieldByName('CorrespondentAccount').AsString := AFields.Values['CorrespondentBankAccount'];
    FieldByName('ExecutorINN').AsString := AFields.Values['INN'];
    FieldByName('ExecutorKPP').AsString := AFields.Values['KPP'];
    FieldByName('ExecutorName').AsString := AFields.Values['Name'];
    if AFields.Values['DocErrorCode'] <> '' then
    begin
      FieldByName('ErrorCode').AsString := AFields.Values['DocErrorCode'];
      FieldByName('ErrorDesc').AsString := AFields.Values['DocErrorDesc'];
    end;
    Post;
    Close;
  except
    WriteLog('Ошибка при записи в таблицу GetChargeResponse');
    Result := False;
  end;
end;
//------------------------------------------------------------------------------
function TGisSrvc.ChargeRequestMessageData(RequestId: integer): string;
type
  TPayerType = (ptOrganization, ptIndividual);
var
  Name, Value: string;
begin
  Result :=
    '<rev:exportPaymentDocumentDetailsRequest xmlns:rev="http://smev.gosuslugi.ru/rev120315">' +
    MessageHeader(SenderCode,SenderName,RecipientCode,RecipientName,REQUEST_SERVICE,'REQUEST') +
    '<rev:MessageData>' +
    '<rev:AppData>' +
    '<rev:PaymentDocumentDetailsRequest>';

    qryParams.Close;
    qryParams.ParamByName('ChargeRequestId').Value := RequestId;
    qryParams.Open;
    while NOT qryParams.Eof do
    begin
      Name := Trim(qryParams.FieldByName('Name').AsString);
      Value := Trim(qryParams.FieldByName('ParamValue').AsString);
      Result := Result + '<rev:' + Name + '>' + Value +  '</rev:' + Name + '>';
      qryParams.Next;
    end;
    qryParams.Close;

    if IncludeRequestPayer(RequestId) then
    begin
      qryPayer.Close;
      qryPayer.ParamByName('id_ChargeRequest').Value := RequestId;
      qryPayer.Open;

      Result := Result + '<rev:AmountRequired>';

      while NOT qryPayer.Eof do
      begin
        case TPayerType(qryPayer.FieldByName('id_PayerType').AsInteger - 1) of
          ptIndividual:
          begin
            Result := Result +
              '<rev:Individual>' +
              '<rev:Surname>'   + Trim(qryPayer.FieldByName('LastName').AsString)  + '</rev:Surname>' +
              '<rev:FirstName>' + Trim(qryPayer.FieldByName('FirstName').AsString) + '</rev:FirstName>';
            if NOT qryPayer.FieldByName('MiddleName').IsNull then
              Result := Result +
                '<rev:Patronymic>' + Trim(qryPayer.FieldByName('MiddleName').AsString) + '</rev:Patronymic>';
            Result := Result +
              '</rev:Individual>';
          end;
          ptOrganization:
          begin
            Result := Result +
              '<rev:Legal>' +
              '<rev:INN>' + Trim(qryPayer.FieldByName('INN').AsString) + '</rev:INN>' +
              '<rev:KPP>' + Trim(qryPayer.FieldByName('KPP').AsString) + '</rev:KPP>' +
              '</rev:Legal>';
          end;
        end;
        qryPayer.Next;
      end; // while

      Result := Result + '</rev:AmountRequired>';

    end;  // if

  Result := Result +
    '</rev:PaymentDocumentDetailsRequest>' +
    '</rev:AppData>' +
    '</rev:MessageData>' +
    '</rev:exportPaymentDocumentDetailsRequest>';
end;
//------------------------------------------------------------------------------
function TGisSrvc.PaymentRequestMessageData: string;

function IncludeSupplier: boolean;
begin
  with qryPaymentRequest do
    Result := (NOT FieldByName('SupplierID').IsNull) and (NOT FieldByName('SupplierName').IsNull);
end;

function IncludePaymentInformation: boolean;
begin
  with qryPaymentRequest do
    Result := (NOT FieldByName('PaymentInfoINN').IsNull) and
              (NOT FieldByName('PaymentInfoBankName').IsNull) and
              (NOT FieldByName('PaymentInfoPaymentRecipient').IsNull) and
              (NOT FieldByName('PaymentInfoBankBIK').IsNull) and
              (NOT FieldByName('PaymentInfoOperatingAccountNumber').IsNull);
//    and (NOT FieldByName('PaymentInfoCorrespondentBankAccount').IsNull);
end;

function IncludeRecipient: boolean;
begin
  with qryPaymentRequest do
    Result := (NOT FieldByName('RecipientINN').IsNull) and
      (
      ((NOT FieldByName('RecipientSurname').IsNull) and (NOT FieldByName('RecipientFirstName').IsNull))
      or
      ((NOT FieldByName('RecipientKPP').IsNull) and (NOT FieldByName('RecipientName').IsNull))
      );
end;

function IncludeOrderInfo: boolean;
begin
  with qryPaymentRequest do
    Result :=
      ((NOT FieldByName('OrderInfoYear').IsNull) and (NOT FieldByName('OrderInfoMonth').IsNull))
      and
      ((NOT FieldByName('OrderInfoUnifiedAccountNumber').IsNull) or
       (NOT FieldByName('OrderInfoFIASHouseGuid').IsNull) or
       (NOT FieldByName('OrderInfoServiceServiceID').IsNull) or
       (NOT FieldByName('OrderInfoServiceAccountNumber').IsNull));
end;

begin
  with qryPaymentRequest do
  try
    Result :=
      '<rev:importNotificationsOfOrderExecutionRequest xmlns:rev="http://smev.gosuslugi.ru/rev120315">' +
      MessageHeader(SenderCode,SenderName,RecipientCode,RecipientName,PAYMENT_SERVICE,'REQUEST') +
      '<rev:MessageData>' +
      '<rev:AppData>' +
      '<rev:importNotificationsOfOrderExecution>' +
      '<rev:payment-organization-guid>' + Trim(FieldByName('BankGIUD').AsString) + '</rev:payment-organization-guid>' +
//      '<rev:payment-organization-guid>d29eff39-741b-4a40-86ef-7cf2d2a086d4</rev:payment-organization-guid>' +
      '<rev:NotificationOfOrderExecutionType>';

    if IncludeSupplier then
    begin
      Result := Result +
        '<rev:SupplierInfo>' +
        '<rev:SupplierID>' + Trim(FieldByName('SupplierID').AsString) + '</rev:SupplierID>' +
        '<rev:SupplierName>' + XmlReplace(FieldByName('SupplierName').AsString) + '</rev:SupplierName>' +
        '</rev:SupplierInfo>';
    end;

    if IncludeRecipient then
    begin
      Result := Result +
        '<rev:RecipientInfo>' +
        '<rev:INN>' + Trim(FieldByName('RecipientINN').AsString) + '</rev:INN>';
        if (NOT FieldByName('RecipientSurname').IsNull) and (NOT FieldByName('RecipientFirstName').IsNull) then
        begin
          Result := Result +
            '<rev:Entpr>' +
            '<rev:Surname>' + Trim(FieldByName('RecipientSurname').AsString) + '</rev:Surname>' +
            '<rev:FirstName>' + Trim(FieldByName('RecipientFirstName').AsString) + '</rev:FirstName>';
          if NOT FieldByName('RecipientPatronymic').IsNull then
            Result := Result +
              '<rev:Patronymic>' + Trim(FieldByName('RecipientPatronymic').AsString) + '</rev:Patronymic>';
          Result := Result +
            '</rev:Entpr>';
        end
        else
        begin
          Result := Result +
            '<rev:Legal>' +
            '<rev:KPP>' + Trim(FieldByName('RecipientKPP').AsString) + '</rev:KPP>' +
            '<rev:Name>' + XmlReplace(FieldByName('RecipientName').AsString) + '</rev:Name>' +
            '</rev:Legal>';
        end;
        if IncludePaymentInformation then
        begin
          Result := Result +
            '<rev:PaymentInformation>' +
            '<rev:RecipientINN>' + Trim(FieldByName('PaymentInfoINN').AsString) + '</rev:RecipientINN>';
          if NOT FieldByName('PaymentInfoKPP').IsNull then
            Result := Result +
              '<rev:RecipientKPP>' + Trim(FieldByName('PaymentInfoKPP').AsString) + '</rev:RecipientKPP>';
          Result := Result +
            '<rev:BankName>' + XmlReplace(FieldByName('PaymentInfoBankName').AsString) + '</rev:BankName>' +
            '<rev:PaymentRecipient>' + XmlReplace(FieldByName('PaymentInfoPaymentRecipient').AsString) + '</rev:PaymentRecipient>' +
            '<rev:BankBIK>' + Trim(FieldByName('PaymentInfoBankBIK').AsString) + '</rev:BankBIK>' +
            '<rev:operatingAccountNumber>' + Trim(FieldByName('PaymentInfoOperatingAccountNumber').AsString) + '</rev:operatingAccountNumber>';
          if NOT FieldByName('PaymentInfoCorrespondentBankAccount').IsNull then
            Result := Result +
              '<rev:CorrespondentBankAccount>' + Trim(FieldByName('PaymentInfoCorrespondentBankAccount').AsString) + '</rev:CorrespondentBankAccount>';
          Result := Result +
            '</rev:PaymentInformation>';
        end;
        Result := Result +
          '</rev:RecipientInfo>';
    end;

    Result := Result +
      '<rev:OrderInfo>' +
      '<rev:OrderID>' + XmlReplace(FieldByName('OrderInfoOrderID').AsString) + '</rev:OrderID>' +
      '<rev:OrderDate>' + FormatDateTime('yyyy-mm-dd', FieldByName('OrderInfoOrderDate').AsDateTime) + '</rev:OrderDate>';
    if NOT FieldByName('OrderInfoOrderNum').IsNull then
      Result := Result +
        '<rev:OrderNum>' + Trim(FieldByName('OrderInfoOrderNum').AsString) + '</rev:OrderNum>';
    Result := Result +
      '<rev:Amount>' + Trim(IntToStr(Trunc(FieldByName('OrderInfoAmount').AsCurrency * 100))) + '</rev:Amount>';
    if NOT FieldByName('OrderInfoPaymentPurpose').IsNull then
      Result := Result +
        '<rev:PaymentPurpose>' + XmlReplace(FieldByName('OrderInfoPaymentPurpose').AsString) + '</rev:PaymentPurpose>';
    if NOT FieldByName('OrderInfoComment').IsNull then
      Result := Result +
        '<rev:Comment>' + XmlReplace(FieldByName('OrderInfoComment').AsString) + '</rev:Comment>';
    if NOT FieldByName('OrderInfoPaymentDocumentID').IsNull then
      Result := Result +
        '<rev:PaymentDocumentID>' + Trim(FieldByName('OrderInfoPaymentDocumentID').AsString) + '</rev:PaymentDocumentID>';
    if NOT FieldByName('OrderInfoPaymentDocumentNumber').IsNull then
      Result := Result +
        '<rev:PaymentDocumentNumber>' + Trim(FieldByName('OrderInfoPaymentDocumentNumber').AsString) + '</rev:PaymentDocumentNumber>';

    if IncludeOrderInfo then
    begin
      Result := Result +
        '<rev:Year>' + Trim(IntToStr(FieldByName('OrderInfoYear').AsInteger)) + '</rev:Year>' +
        '<rev:Month>' + Trim(FormatFloat('00',FieldByName('OrderInfoMonth').AsInteger)) + '</rev:Month>';
      if (NOT FieldByName('OrderInfoUnifiedAccountNumber').IsNull) then
        Result := Result +
          '<rev:UnifiedAccountNumber>' + Trim(FieldByName('OrderInfoUnifiedAccountNumber').AsString) + '</rev:UnifiedAccountNumber>';

      if (NOT FieldByName('OrderInfoFIASHouseGuid').IsNull) and
        ((NOT FieldByName('OrderInfoSurname').IsNull and NOT FieldByName('OrderInfoFirstName').IsNull) or (NOT FieldByName('OrderInfoINN').IsNull)) then
      begin
        Result := Result +
          '<rev:AddressAndConsumer>' +
          '<rev:FIASHouseGuid>' + Trim(FieldByName('OrderInfoFIASHouseGuid').AsString) + '</rev:FIASHouseGuid>';
        if ((NOT FieldByName('OrderInfoApartment').IsNull) and (NOT FieldByName('OrderInfoPlacement').IsNull)) then
        begin
          Result := Result +
            '<rev:Apartment>' + Trim(FieldByName('OrderInfoApartment').AsString) + '</rev:Apartment>' +
            '<rev:Placement>' + Trim(FieldByName('OrderInfoPlacement').AsString) + '</rev:Placement>';
        end
        else
          if NOT FieldByName('OrderInfoNonLivingApartment').IsNull then
            Result := Result +
              '<rev:NonLivingApartment>' + Trim(FieldByName('OrderInfoNonLivingApartment').AsString) + '</rev:NonLivingApartment>';
        if ((NOT FieldByName('OrderInfoSurname').IsNull) and (NOT FieldByName('OrderInfoFirstName').IsNull)) then
        begin
          Result := Result +
            '<rev:Ind>' +
            '<rev:Surname>' + Trim(FieldByName('OrderInfoSurname').AsString) + '</rev:Surname>' +
            '<rev:FirstName>' + Trim(FieldByName('OrderInfoFirstName').AsString) + '</rev:FirstName>';
          if (NOT FieldByName('OrderInfoPatronymic').IsNull) then
            Result := Result +
              '<rev:Patronymic>' + Trim(FieldByName('OrderInfoPatronymic').AsString) + '</rev:Patronymic>';
          Result := Result + '</rev:Ind>';
        end
        else
          if NOT FieldByName('OrderInfoINN').IsNull then
            Result := Result +
              '<rev:INN>' + Trim(FieldByName('OrderInfoINN').AsString) + '</rev:INN>';
          Result := Result + '</rev:AddressAndConsumer>';
      end;

      if (NOT FieldByName('OrderInfoServiceServiceID').IsNull) then
      begin
        Result := Result +
          '<rev:Service>' +
          '<rev:ServiceID>' + Trim(FieldByName('OrderInfoServiceServiceID').AsString) + '</rev:ServiceID>' +
          '</rev:Service>';
      end;

      if (NOT FieldByName('OrderInfoServiceAccountNumber').IsNull) then
      begin
        Result := Result +
          '<rev:AccountNumber>' + Trim(FieldByName('OrderInfoServiceAccountNumber').AsString) + '</rev:AccountNumber>';
      end;

    end;

    Result := Result +
      '</rev:OrderInfo>';

    Result := Result +
      '<rev:TransportGUID>' + Trim(FieldByName('TransportGUID').AsString) + '</rev:TransportGUID>' +
      '</rev:NotificationOfOrderExecutionType>' +
      '</rev:importNotificationsOfOrderExecution>' +
      '</rev:AppData>' +
      '</rev:MessageData>' +
      '</rev:importNotificationsOfOrderExecutionRequest>';
  except
    on E:Exception do WriteLog('Ошибка в PaymentRequestMessageData ' + E.Message);
  end;
//  WriteLog(Result);
end;
//------------------------------------------------------------------------------
function TGisSrvc.CancelRequestMessageData: string;
begin
  with qryCancelRequest do
  try
    Result :=
      '<rev:importNotificationsOfOrderExecutionCancellationRequest>' +
      MessageHeader(SenderCode,SenderName,RecipientCode,RecipientName,PAYMENT_SERVICE,'REQUEST') +
(*
<rev:Message>
<rev:Sender>
<rev:Code>RCPT00001</rev:Code>
<rev:Name>Получатель</rev:Name>
</rev:Sender>
<rev:Recipient>
<rev:Code>MNSV10001</rev:Code>
<rev:Name>Минкомсвязь РФ</rev:Name>
</rev:Recipient>
<rev:Originator>
<rev:Code>RCPT00001</rev:Code>
<rev:Name>Получатель</rev:Name>
</rev:Originator>
<rev:ServiceName>MNSVsvedPayKO</rev:ServiceName>
<rev:TypeCode>GFNC</rev:TypeCode>
<rev:Status>REQUEST</rev:Status>
<rev:Date>2016-05-11T00:00:00</rev:Date>
<rev:ExchangeType>2</rev:ExchangeType>
<rev:TestMsg/>
</rev:Message>
*)
      '<rev:MessageData>' +
      '<rev:AppData>' +
      '<rev:importNotificationsOfOrderExecutionCancellation>' +
//      '<rev:payment-organization-guid>01309b2f-fdec-48cb-9de5-e7c52d6f7d04</rev:payment-organization-guid>' +
      '<rev:payment-organization-guid>' + Trim(FieldByName('BankGUID').AsString) + '</rev:payment-organization-guid>' +
      '<rev:NotificationOfOrderExecutionCancellation>' +
//      '<rev:OrderID>27000000000000000000000000001984</rev:OrderID>' +
      '<rev:OrderID>' + Trim(FieldByName('OrderID').AsString) + '</rev:OrderID>' +
//      '<rev:CancellationDate>2016-03-11</rev:CancellationDate>' +
      '<rev:CancellationDate>' + FormatDateTime('yyyy-dmm-dd', FieldByName('CancellationDate').AsDateTime) + '</rev:CancellationDate>' +
//      '<rev:Comment>Тест</rev:Comment>' +
//      '<rev:TransportGUID>7993452e-f7df-44ca-ae15-2f90f38059ee</rev:TransportGUID>' +
      '<rev:TransportGUID>' + Trim(FieldByName('TransportGUID').AsString) + '</rev:TransportGUID>' +
      '</rev:NotificationOfOrderExecutionCancellation>' +
      '</rev:importNotificationsOfOrderExecutionCancellation>' +
      '</rev:AppData>' +
      '</rev:MessageData>' +
      '</rev:importNotificationsOfOrderExecutionCancellationRequest>';
  except
    on E:Exception do WriteLog('CancelRequestMessageData ' + E.Message);
  end;

end;
//------------------------------------------------------------------------------
function TGisSrvc.PaymentResultMessageData(MessageGUID: string): string;
begin
  Result :=
    '<rev:getStateRequest xmlns:rev="http://smev.gosuslugi.ru/rev120315">' +
    MessageHeader(SenderCode,SenderName,RecipientCode,RecipientName,PAYMENT_SERVICE,'PING') +
    '<rev:MessageData>' +
    '<rev:AppData>' +
    '<rev:AcknowledgmentRequest>' +
    '<rev:MessageGUID>' + Trim(MessageGUID) + '</rev:MessageGUID>' +   //f6c971dd-e817-43d7-9704-237f4a0d763b
    '</rev:AcknowledgmentRequest>' +
    '</rev:AppData>' +
    '</rev:MessageData>' +
    '</rev:getStateRequest>';
end;
//------------------------------------------------------------------------------
(*
function TGisSrvc.MessageBody2(Status: string): string;
begin
 Result :=
   '<rev:Message>' +
   '<rev:Sender>' +
   '<rev:Code>RCPT00001</rev:Code>' +
   '<rev:Name>Получатель</rev:Name>' +
   '</rev:Sender>' +
   '<rev:Recipient>' +
   '<rev:Code>MNSV10001</rev:Code>' +
   '<rev:Name>Минкомсвязь РФ</rev:Name>' +
   '</rev:Recipient>' +
   '<rev:Originator>' +
   '<rev:Code>RCPT00001</rev:Code>' +
   '<rev:Name>Получатель</rev:Name>' +
   '</rev:Originator>' +
   '<rev:ServiceName>MNSVsvedPayKO</rev:ServiceName>' +
   '<rev:TypeCode>GFNC</rev:TypeCode>' +
//   '<rev:Status>PING</rev:Status>' +
    '<rev:Status>' + Trim(Status) + '</rev:Status>' +
//   '<rev:Date>2016-06-08T00:00:00</rev:Date>' +
   '<rev:Date>' + FormatDateTime('yyyy-mm-dd"T"hh:mm:ss',Now) + '</rev:Date>' +
   '<rev:ExchangeType>2</rev:ExchangeType>' +
   '<rev:RequestIdRef>d95ef522-c0a5-41eb-b838-b82f7beef4b3</rev:RequestIdRef>' +      // TO DO
   '<rev:OriginRequestIdRef>d95ef522-c0a5-41eb-b838-b82f7beef4b3</rev:OriginRequestIdRef>' +  // TO DO
   '<rev:TestMsg></rev:TestMsg>' +
   '</rev:Message>';
end;
*)
//------------------------------------------------------------------------------
function TGisSrvc.MessageHeader(SenderCode,SenderName,RecipientCode,RecipientName,
  ServiceName,Status: string; RequestId: string = ''): string;
begin
  Result :=
    '<rev:Message>' +
    '<rev:Sender>' +
//    '<rev:Code>RCPT00001</rev:Code>' +
    '<rev:Code>' + Trim(SenderCode) + '</rev:Code>' +
//    '<rev:Name>АО КБ Синергия</rev:Name>' +
    '<rev:Name>' + Trim(SenderName) + '</rev:Name>' +
    '</rev:Sender>' +
    '<rev:Recipient>' +
//    '<rev:Code>MNSV10000</rev:Code>' +
    '<rev:Code>' + Trim(RecipientCode) + '</rev:Code>' +
//    '<rev:Name>Государственная информационная система коммунального хозяйства</rev:Name>' +
    '<rev:Name>' + Trim(RecipientName) + '</rev:Name>' +
    '</rev:Recipient>' +
    '<rev:Originator>' +
//    '<rev:Code>RCPT00001</rev:Code>' +
    '<rev:Code>' + Trim(SenderCode) + '</rev:Code>' +
//    '<rev:Name>АО КБ Синергия</rev:Name>' +
    '<rev:Name>' + Trim(SenderName) + '</rev:Name>' +
    '</rev:Originator>' +
//    '<rev:ServiceName>Service</rev:ServiceName>' +
    '<rev:ServiceName>' + Trim(ServiceName) + '</rev:ServiceName>' +
    '<rev:TypeCode>GFNC</rev:TypeCode>' +
    '<rev:Status>' + Trim(Status) + '</rev:Status>' +
//    '<rev:Status>REQUEST</rev:Status>' +
    '<rev:Date>' + FormatDateTime('yyyy-mm-dd"T"hh:mm:ss',Now) + '</rev:Date>' +
//    '<rev:Date>2016-05-19T00:00:00</rev:Date>' +
    '<rev:ExchangeType>2</rev:ExchangeType>';
(*
    Result := Result +
      '<rev:RequestIdRef>d95ef522-c0a5-41eb-b838-b82f7beef4b3</rev:RequestIdRef>' +
      '<rev:OriginRequestIdRef>d95ef522-c0a5-41eb-b838-b82f7beef4b3</rev:OriginRequestIdRef>';
*)
(*
    if RequestId <> '' then
    begin
      Result := Result +
        '<rev:RequestIdRef>' + Trim(RequestId) + '</rev:RequestIdRef>' +
        '<rev:OriginRequestIdRef>' + Trim(RequestId) + '</rev:OriginRequestIdRef>';
    end;
*)
    Result := Result +
//      '<rev:TestMsg></rev:TestMsg>' +
      '</rev:Message>';
end;
//------------------------------------------------------------------------------
function TGisSrvc.IncludeRequestPayer(RequestId: integer): boolean;
begin
  qryPayerCount.Close;
  qryPayerCount.Params.ParamByName('Id_ChargeRequest').Value := RequestId;
  qryPayerCount.Open;
  Result := qryPayerCount.FieldByName('PayerCount').AsInteger > 0;
  qryPayerCount.Close;
end;
//------------------------------------------------------------------------------
function TGisSrvc.SoapGenID: string;
const
  Chars: array[1..35] of Char = '123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';    // TO DO
var
  S: string;
  i: integer;
begin
  S := '';
  for i := 1 to 35 do
    S := S + Chars[RandomRange(Low(Chars),High(Chars)+1)];
  Result := S;
end;
//------------------------------------------------------------------------------
function TGisSrvc.CopyFileToFolder(const AFileName, AFolderName: string): boolean;
const
  S = 'Ошибка при копировании файла %s в каталог %s ErrorCode = %s';
begin
  Result := True;
  if NOT CopyFile(PWideChar(AFileName),PWideChar(IncludeTrailingBackslash(AFolderName) + ExtractFileName(AFileName)), False) then
  begin
    WriteLog(Format(S,[AFileName,AFolderName,IntToStr(GetLastError)]));
    Result := False;
  end;
end;
//------------------------------------------------------------------------------
function TGisSrvc.MoveFileToFolder(const AFileName, AFolderName: string): boolean;
const
  S = 'Ошибка при удалении файла %s ErrorCode = %s';
begin
  Result := False;
  if NOT CopyFileToFolder(AFileName, AFolderName) then
    Exit;
  if NOT DeleteFile(AFileName) then
  begin
    WriteLog(Format(S,[AFileName,IntToStr(GetLastError)]));
    Exit;
  end;
  Result := True;
end;
//------------------------------------------------------------------------------
procedure TGisSrvc.ParseChargeResponse(XmlDoc: IXMLDocument; AFields: TStringList);
var
  ErrNode, Node: IXmlNode;
begin

  try
    XmlDoc.Options := XmlDoc.Options - [doNodeAutoCreate];

    Node := XmlDoc.Node;// .DocumentElement;         // .Node;
    Node := Node.ChildNodes['soap:Envelope'];
    Node := Node.ChildNodes['soap:Body'];
    Node := Node.ChildNodes[0];   //'exportPaymentDocumentDetailsResult'];

    Node := Node.ChildNodes['Message'];
    AFields.Values['Status'] := Node.ChildValues['Status'];

    if Node.ChildValues['Status'] <> 'RESULT' then
    begin
      Exit;
    end;

    Node := Node.ParentNode;
    Node := Node.ChildNodes['MessageData'];
    Node := Node.ChildNodes['AppData'];
    Node := Node.ChildNodes['ExportPaymentDocumentDetails'];

    ErrNode := Node.ChildNodes.FindNode('ErrorMessage');
    if Assigned(ErrNode) then
    begin
      AFields.Values['ErrorCode'] := ErrNode.ChildValues['ErrorCode'];
      AFields.Values['ErrorDesc'] := ErrNode.ChildValues['Description'];
      Exit;
    end;

    Node := Node.ChildNodes['Charge'];
    AFields.Values['Year'] := GetNodeValue(Node, 'Year');
    AFields.Values['Month'] := GetNodeValue(Node, 'Month');
    Node := Node.ChildNodes['PaymentDocument'];
    // Node := Node.ChildNodes['Service'];
    AFields.Values['UnifiedAccountNumber'] :=
      GetNodeValue(Node, 'UnifiedAccountNumber');
    Node := Node.ChildNodes['ConsumerInformation'];
    Node := Node.ChildNodes['address'];
    AFields.Values['Region'] := GetNodeValue(Node, 'region');
    AFields.Values['City'] := GetNodeValue(Node, 'city');
    AFields.Values['HouseNum'] := GetNodeValue(Node, 'housenum');
    AFields.Values['FIASHouseGuid'] := GetNodeValue(Node, 'FIASHouseGuid');
    AFields.Values['Apartment'] := GetNodeValue(Node, 'apartment');
    AFields.Values['Address_String'] := GetNodeValue(Node, 'address_string');
    Node := Node.ParentNode.ParentNode;
    Node := Node.ChildNodes['PaymentDocumentDetails'];
    AFields.Values['PaymentDocumentID'] :=
      GetNodeValue(Node, 'PaymentDocumentID');
    AFields.Values['AccountNumber'] := GetNodeValue(Node, 'AccountNumber');

    ErrNode := Node.ChildNodes.FindNode('ErrorMessage');
    if Assigned(ErrNode) then
    begin
      AFields.Values['DocErrorCode'] := ErrNode.ChildValues['ErrorCode'];
      AFields.Values['DocErrorDesc'] := ErrNode.ChildValues['Description'];
    end;

    Node := Node.ChildNodes['ExecutorInformation'];
    AFields.Values['INN'] := GetNodeValue(Node, 'INN');
    Node := Node.ChildNodes['Legal'];
    AFields.Values['KPP'] := GetNodeValue(Node, 'KPP');
    AFields.Values['Name'] := GetNodeValue(Node, 'Name');
    Node := Node.ParentNode;
    Node := Node.ChildNodes['PaymentInformation'];
    AFields.Values['RecipientINN'] := GetNodeValue(Node, 'RecipientINN');
    AFields.Values['RecipientKPP'] := GetNodeValue(Node, 'RecipientKPP');
    AFields.Values['BankName'] := GetNodeValue(Node, 'BankName');
    AFields.Values['PaymentRecipient'] :=
      GetNodeValue(Node, 'PaymentRecipient');
    AFields.Values['BankBIK'] := GetNodeValue(Node, 'BankBIK');
    AFields.Values['operatingAccountNumber'] :=
      GetNodeValue(Node, 'operatingAccountNumber');
    AFields.Values['CorrespondentBankAccount'] :=
      GetNodeValue(Node, 'CorrespondentBankAccount');
  except
//    AFields.Values['Status'] := 'FAIL';
    on E:Exception do ParserExceptionHandler('ParseChargeResponse', E.Message, AFields);
  end;

end;
// ------------------------------------------------------------------------------
procedure TGisSrvc.ParsePaymentResponse(XmlDoc: IXMLDocument; AFields: TStringList);
var
  i: integer;
  ErrNode,Node: IXmlNode;
begin
  try
    XmlDoc.Options := XmlDoc.Options - [doNodeAutoCreate];
    Node := XmlDoc.Node;
    Node := Node.ChildNodes['soap:Envelope'];
    Node := Node.ChildNodes['soap:Body'];
    Node := Node.ChildNodes[0];             // ns3:ackResult или soap:Fault

    if Node.NodeName = 'soap:Fault' then
    begin
      for i := 0 to Node.ChildNodes.Count - 1 do
      begin
        if Node.ChildNodes[i].NodeName = 'detail' then
        begin
          Node := Node.ChildNodes[i];
          break;
        end;
      end;
//      Node := Node.ChildNodes.FindNode('detail');
//      Node := Node.ChildNodes['detail'];
      Node := Node.ChildNodes['fault'];
    end;

    Node := Node.ChildNodes['Message'];
    AFields.Values['Status'] := Node.ChildValues['Status'];
//    if Node.ChildValues['Status'] <> 'ACCEPT' then
//      Exit;
    Node := Node.ParentNode;
    Node := Node.ChildNodes['MessageData'];
    Node := Node.ChildNodes['AppData'];

    ErrNode := Node.ChildNodes.FindNode('ErrorMessage');
    if Assigned(ErrNode) then
    begin
      AFields.Values['DocErrorCode'] := ErrNode.ChildValues['ErrorCode'];
      AFields.Values['DocErrorDesc'] := ErrNode.ChildValues['Description'];
      Exit;
    end;

    Node := Node.ChildNodes['AcknowledgmentResponse'];
    Node := Node.ChildNodes['MessageGUID'];
    AFields.Values['MessageGUID'] := Node.NodeValue;
  except
//    AFields.Values['Status'] := 'FAIL';
    on E:Exception do ParserExceptionHandler('ParsePaymentResponse', E.Message, AFields);
  end;
end;
//------------------------------------------------------------------------------
procedure TGisSrvc.ParsePaymentResult(XmlDoc: IXMLDocument; AFields: TStringList);
var
  i: integer;
  ErrNode, Node: IXmlNode;
begin
  try
    XmlDoc.Options := XmlDoc.Options - [doNodeAutoCreate];
    Node := XmlDoc.Node;
    Node := Node.ChildNodes['soap:Envelope'];
    Node := Node.ChildNodes['soap:Body'];
    Node := Node.ChildNodes[0];                     // ns3:ackResult

    if Node.NodeName = 'soap:Fault' then
    begin
      for i := 0 to Node.ChildNodes.Count - 1 do
      begin
        if Node.ChildNodes[i].NodeName = 'detail' then
        begin
          Node := Node.ChildNodes[i];
          break;
        end;
      end;
      Node := Node.ChildNodes['fault'];
    end;

    Node := Node.ChildNodes['Message'];
    AFields.Values['Status'] := Node.ChildValues['Status'];
//    if Node.ChildValues['Status'] <> 'RESULT' then
//      Exit;
    Node := Node.ParentNode;
    Node := Node.ChildNodes['MessageData'];
    Node := Node.ChildNodes['AppData'];
    Node := Node.ChildNodes['CommonResult'];
    ErrNode := Node.ChildNodes.FindNode('ErrorMessage');
    if Assigned(ErrNode) then
    begin
      AFields.Values['ErrorCode'] := ErrNode.ChildValues['ErrorCode'];
      AFields.Values['ErrorDesc'] := ErrNode.ChildValues['Description'];
      Exit;
    end;
    AFields.Values['UpdateDate'] := GetNodeValue(Node, 'UpdateDate');
  except
//    AFields.Values['Status'] := 'FAIL';
    on E:Exception do ParserExceptionHandler('ParsePaymentResult', E.Message, AFields);
  end;
end;
//------------------------------------------------------------------------------
function TGisSrvc.GetNodeValue(Parent: IXMLNode; NodeName: string; ErrorString: string = ''): string;
var
  Node: IXMLNode;
begin
  Node := Parent.ChildNodes.FindNode(NodeName);
  if Assigned(Node) then
    Result := Node.NodeValue
  else
    Result := ErrorString;
end;
// ------------------------------------------------------------------------------
procedure TGisSrvc.ParserExceptionHandler(AProc, AMessage: string; AFields: TStringList);
begin
  AFields.Values['Status'] := 'FAIL';
  AFields.Values['ErrorCode'] := 'Xml Error';
  AFields.Values['ErrorDesc'] := AMessage;
  WriteLog('Ошибка ' + AProc + ': ' + AMessage);
end;
// ------------------------------------------------------------------------------
procedure TGisSrvc.WriteLog(AMessage: string);
var
  F: TextFile;
begin
  AssignFile(F,LogFileName);
  if FileExists(LogFileName) then
    Append(F)
  else
    Rewrite(F);
  Writeln(F, FormatDateTime('hh:mm:ss', GetTime()) + #32 + AMessage);
  CloseFile(F);
end;
//------------------------------------------------------------------------------
function TGisSrvc.XmlReplace(Str: string): string;
var
  S: string;
  i: integer;
begin
  Result := '';
  S := Trim(Str);
  for i := 1 to Length(S) do
  begin
    case Ord(S[i]) of
//      Ord('"'): Result := Result + '&quot;';        //  " => &quot;
      Ord('©'): Result := Result + '&copy;';        //  © => &copy;
      Ord('®'): Result := Result + '&reg;';         //  ® => &reg;
      Ord('™'): Result := Result + '&trade;';       //  ™ => &trade;
//      Ord('?'): Result := Result + '&euro;';        //  ? => &euro;
//      Ord('™'): Result := Result + '&pound;';       //  Ј => &pound;
      Ord('„'): Result := Result + '&bdquo;';       //  „ => &bdquo;
      Ord('“'): Result := Result + '&ldquo;';       //  “ => &ldquo;
      Ord('«'): Result := Result + '&laquo;';       //  « => &laquo;
      Ord('»'): Result := Result + '&raquo;';       //  » => &raquo;
      Ord('>'): Result := Result + '&gt;';          //  > => &gt;
      Ord('<'): Result := Result + '&lt;';          //  < => &lt;
      Ord('≥'): Result := Result + '&ge;';          //  ≥ => &ge;
      Ord('≤'): Result := Result + '&le;';          //  ≤ => &le;
      Ord('≈'): Result := Result + '&asymp;';       //  ≈ => &asymp;
      Ord('≠'): Result := Result + '&ne;';          //  ≠ => &ne;
      Ord('≡'): Result := Result + '&equiv;';       //  ≡ => &equiv;
      Ord('§'): Result := Result + '&sect;';        //  § => &sect;
      Ord('&'): Result := Result + '&amp;';         //  & => &amp;
      Ord('∞'): Result := Result + '&infin;';       //  ∞ => &infin;
    else
      Result := Result + S[i];
    end;
  end;

end;

end.
