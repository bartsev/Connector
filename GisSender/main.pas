unit main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.SvcMgr, Vcl.Dialogs, System.IniFiles,
  Soap.SOAPHTTPTrans;

type
  TGisSend = class(TService)
    procedure ServiceStart(Sender: TService; var Started: Boolean);
    procedure ServiceExecute(Sender: TService);
  private
    Interval: integer;
    HTTPReqResp: THTTPReqResp;
    Request, Response: TMemoryStream;
    ServiceURL,RequestURL,PaymentURL,IncFolder,OutFolder,LogFileName: string;
    procedure LoadParams;
    procedure SendMessages;
    procedure WriteLog(AMessage: string);
    function LoadRequest(FileName: string): boolean;
    function SaveResponse(FileName: string): boolean;
    procedure SendSoapMessage(FileName: string);
  public
    function GetServiceController: TServiceController; override;
    { Public declarations }
  end;

var
  GisSend: TGisSend;

implementation

{$R *.dfm}

const
  SoapActionStr: array[0..4] of string = (
    'urn:#export_payment_document_details',
    'urn:async_getId_import_notifications_of_order_execution',
    'urn:async_getId_import_notifications_of_order_execution_cancellation',
    'urn:async_getResult',
    'urn:async_getResult');

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  GisSend.Controller(CtrlCode);
end;
//------------------------------------------------------------------------------
function TGisSend.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;
//------------------------------------------------------------------------------
procedure TGisSend.ServiceExecute(Sender: TService);
var
  i: integer;
begin
  while NOT Terminated do
  begin
    WriteLog('');
    SendMessages;
    for i := 1 to Interval * 60 do
    begin
      Sleep(1000);
      ServiceThread.ProcessRequests(False);
      if Terminated then break;
    end;
  end;
end;
//------------------------------------------------------------------------------
procedure TGisSend.ServiceStart(Sender: TService; var Started: Boolean);
begin
  LoadParams;
  LogFileName := ChangeFileExt(ParamStr(0), '.log');
end;
//------------------------------------------------------------------------------
procedure TGisSend.SendMessages;
var
  S: TSearchRec;
begin
  if FindFirst(OutFolder + '*.xml', faArchive, S) = 0 then
  try
    Request := TMemoryStream.Create;
    Response := TMemoryStream.Create;
    HTTPReqResp := THTTPReqResp.Create(nil);
    repeat
      Request.Clear;
      Response.Clear;
      if NOT LoadRequest(S.Name) then
        break;
      SendSoapMessage(S.Name);
      WriteLog(Copy(S.Name,1,11) + ': отправлен в ГИС ЖКХ');
      if Response.Size > 0 then
      begin
        WriteLog(Copy(S.Name,1,11) + ': получен ответ');
        if NOT SaveResponse(S.Name) then
          continue;
        WriteLog(Copy(S.Name,1,11) + ': ответ записан в файл');
      end
      else
        WriteLog(Copy(S.Name,1,11) + ': ответ нулевой длины');
      DeleteFile(OutFolder + S.Name);
    until FindNext(S) <> 0;
  finally
    HTTPReqResp.Free;
    Response.Free;
    Request.Free;
  end;
  FindClose(S);
end;
//------------------------------------------------------------------------------
procedure TGisSend.LoadParams;
begin
  with TIniFile.Create(ChangeFileExt(ParamStr(0), '.ini')) do
  try
    RequestURL := ReadString('Params','RequestURL','');
    PaymentURL := ReadString('Params','PaymentURL','');
    IncFolder := ReadString('Params','IncFolder','') + '\';
    OutFolder := ReadString('Params','OutFolder','') + '\';
    Interval := ReadInteger('Params','DelayMinutes',5);
  finally
    Free;
  end;
end;
//------------------------------------------------------------------------------
procedure TGisSend.WriteLog(AMessage: string);
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
function TGisSend.LoadRequest(FileName: string): boolean;
begin
  Result := True;
  try
    Request.LoadFromFile(OutFolder + FileName);
  except
    WriteLog('Ошибка при чтении файла ' + FileName);
    Result := False;
  end;
end;
//------------------------------------------------------------------------------
function TGisSend.SaveResponse(FileName: string): boolean;
var
  lFileName: string;
begin
  Result := True;
  try
    lFileName := FileName;
    lFileName[10] := 's';
    Response.SaveToFile(IncFolder + lFileName);
  except
    WriteLog('Ошибка при записи файла ' + FileName);
    Result := False;
  end;
end;
//------------------------------------------------------------------------------
procedure TGisSend.SendSoapMessage(FileName: string);
var
  ActionId: integer;
begin

  ActionId := StrToInt(Copy(FileName,11,1));
  case ActionId of
       0: ServiceURL := RequestURL;
    1..4: ServiceURL := PaymentURL;
  end;

  with HTTPReqResp do
  try
    URL := ServiceURL;
    SoapAction := SoapActionStr[ActionId];
    Execute(Request, Response);
  except
    on E: Exception do
      WriteLog(FormatDateTime('hh:mm', Time) + #32 + 'Exception: ' + E.Message);
  end;

end;
//------------------------------------------------------------------------------

end.
