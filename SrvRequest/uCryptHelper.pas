unit uCryptHelper;

interface

uses
  Winapi.Windows, Soap.Win.CertHelper, System.SysUtils, System.Classes,
  Soap.EncdDecd;//System.NetEncoding;

const
  CRYPT_VERIFYCONTEXT                  = $F0000000;
  ALG_CLASS_HASH                       = 4 shl 13;
  HP_HASHVAL                           = $0002; {hash value}
  AT_KEYEXCHANGE                       = 1;
  AT_SIGNATURE                         = 2;
  KP_CERTIFICATE                       = 26;
  PUBLICKEYBLOB                        = $6;
  CRYPT_FIRST                          = 1;
  CRYPT_NEXT                           = 2;
  PP_ENUMCONTAINERS                    = 2;
  CP_GR3410_2001_PROV_A                = 'Crypto-Pro GOST R 34.10-2001 Cryptographic Service Provider';
  PROV_GOST_2001_DH                    = 75;
  ALG_SID_GR3411                       = 30;
  CALG_GR3411                          = ALG_CLASS_HASH or ALG_SID_GR3411;

type

  HCRYPTPROV  = ULONG;
  PHCRYPTPROV = ^HCRYPTPROV;

  HCRYPTHASH = DWORD;

  ALG_ID = DWORD;

  HCRYPTKEY = DWORD;
  PHCRYPTKEY = ^HCRYPTKEY;

  PHCRYPTHASH = ^HCRYPTHASH;

  PPCCERT_CONTEXT = ^PCCERT_CONTEXT;

  PCRL_ENTRY = ^_CRL_ENTRY;
 _CRL_ENTRY = record
    SerialNumber: CRYPT_INTEGER_BLOB;
    RevocationDate: FILETIME;
    cExtension: DWORD;
    rgExtension: PCERT_EXTENSION;
  end;

  CRL_ENTRY = _CRL_ENTRY;

  PCRL_INFO = ^_CRL_INFO;

 _CRL_INFO = record
    dwVersion: DWORD;
    SignatureAlgorithm: CRYPT_ALGORITHM_IDENTIFIER;
    Issuer: CERT_NAME_BLOB;
    ThisUpdate: FILETIME;
    NextUpdate: FILETIME;
    cCRLEntry: DWORD;
    rgCRLEntry: PCRL_ENTRY;
    cExtension: DWORD;
    rgExtension: PCERT_EXTENSION;
  end;
  CRL_INFO = _CRL_INFO;

  PCRL_CONTEXT = ^_CRL_CONTEXT;

 _CRL_CONTEXT = record
    dwCertEncodingType: DWORD;
    pbCrlEncoded: PBYTE;
    cbCrlEncoded: DWORD;
    pCrlInfo: PCRL_INFO;
    hCertStore: HCERTSTORE;
  end;

  CRL_CONTEXT = _CRL_CONTEXT;

  PPCCRL_CONTEXT = ^PCRL_CONTEXT;

  PCRYPT_ATTR_BLOB = ^_CRYPTOAPI_BLOB;

  PCRYPT_ATTRIBUTE = ^_CRYPT_ATTRIBUTE;

 _CRYPT_ATTRIBUTE = record
    pszObjId: LPSTR;
    cValue: DWORD;
    rgValue: PCRYPT_ATTR_BLOB;
  end;

  CRYPT_ATTRIBUTE = _CRYPT_ATTRIBUTE;

  PCRYPT_SIGN_MESSAGE_PARA = ^CRYPT_SIGN_MESSAGE_PARA;

  CRYPT_SIGN_MESSAGE_PARA = record
    cbSize : DWORD;
    dwMsgEncodingType : DWORD;
    pSigningCert : PCCERT_CONTEXT;
    HashAlgorithm : CRYPT_ALGORITHM_IDENTIFIER;
    pvHashAuxInfo : PVOID;
    cMsgCert : DWORD;
    rgpMsgCert : PPCCERT_CONTEXT;
    cMsgCrl : DWORD;
    rgpMsgCrl : PPCCRL_CONTEXT;
    cAuthAttr : DWORD;
    rgAuthAttr : PCRYPT_ATTRIBUTE;
    cUnauthAttr :DWORD;
    rgUnauthAttr :PCRYPT_ATTRIBUTE;
    dwFlags :DWORD;
    dwInnerContentType :DWORD;
    HashEncryptionAlgorithm : CRYPT_ALGORITHM_IDENTIFIER;
    pvHashEncryptionAuxInfo : DWORD;
  end;

  PPUBLICKEYSTRUC = ^_BLOBHEADER;

 _BLOBHEADER = record
    bType: BYTE;
    bVersion: BYTE;
    reserved: WORD;
    aiKeyAlg: ALG_ID;
  end;

  PUBLICKEYSTRUC=_BLOBHEADER;

  PCRYPT_PUBKEYPARAM = ^_CRYPT_PUBKEYPARAM;
 _CRYPT_PUBKEYPARAM = record
    Magic,
    BitLen: DWORD;
  end;

  CRYPT_PUBKEYPARAM = _CRYPT_PUBKEYPARAM;

  PCRYPT_PUBKEY_INFO_HEADER = ^_CRYPT_PUBKEY_INFO_HEADER;

 _CRYPT_PUBKEY_INFO_HEADER = record
    BlobHeader : _BLOBHEADER;
    KeyParam: CRYPT_PUBKEYPARAM;
  end;

  CRYPT_PUBKEY_INFO_HEADER = _CRYPT_PUBKEY_INFO_HEADER;

function CryptEnumProviders(dwIndex: DWORD; pdwReserved: PDWORD; dwFlags: DWORD;
  pdwProvType: PDWORD; pszProvName: LPTSTR; pcbProvName: PDWORD): BOOL;
  stdcall;

function CryptAcquireContext(phPROV: PHCRYPTPROV; pszContainer: LPCTSTR;
  pszProvider: LPCTSTR; dwProvType: DWORD; dwFlags: DWORD): BOOL; stdcall;

function CryptCreateHash(hProv: HCRYPTPROV; Algid: ALG_ID; hKey: HCRYPTKEY;
  dwFlags: DWORD; phHash: PHCRYPTHASH): BOOL; stdcall;

function CryptHashData(hHash: HCRYPTHASH; const pbData: PBYTE;
  dwDataLen: DWORD; dwFlags: DWORD): BOOL; stdcall;

function CryptSignHash(hHash: HCRYPTHASH; dwKeySpec: DWORD; sDescription: LPCTSTR;
  dwFlags: DWORD; pbSignature: PBYTE; pdwSigLen: PDWORD): BOOL; stdcall;

function CryptDestroyHash(hHash: HCryptHash): BOOL; stdcall;

function CryptSetHashParam(hHash: HCRYPTHASH; dwParam: DWORD; const pbData:
  PBYTE; dwFlags: DWORD): BOOL; stdcall;

function CryptGetHashParam(hHash: HCRYPTHASH; dwParam: DWORD; pbData: PBYTE;
  pdwDataLen: PDWORD; dwFlags: DWORD): BOOL; stdcall;

function CryptUIDlgSelectCertificateFromStore(hCertStore: HCERTSTORE; hwnd: HWND;
  pwszTitle, pwszDisplayString: LPCWSTR; dwDontUseColumn, dwFlags: DWORD;
  pvReserved: LPVOID): PCCERT_CONTEXT; stdcall;

function CryptSignMessage(pSignPara: PCRYPT_SIGN_MESSAGE_PARA;
  fDetachedSignature: BOOL; cToBeSigned: DWORD; rgpbToBeSigned: PByte;
  rgcbToBeSigned: Pointer; pbSignedBlob: PByte; var pcbSignedBlob: DWORD): BOOL; stdcall;

function CryptGetUserKey(hProv: HCRYPTPROV; dwKeySpec: DWORD; phUserKey: PHCRYPTKEY): BOOL; stdcall;

function CryptGetKeyParam(hKey: HCRYPTKEY;dwParam: DWORD; pbData: PBYTE; pdwDataLen: PDWORD;
  dwFlags: DWORD): BOOL; stdcall;

function CryptExportKey(hKey: HCRYPTKEY; hExpKey: HCRYPTKEY; dwBlobType: DWORD;
  dwFlags: DWORD; pbData: PBYTE; pdwDataLen: PDWORD): BOOL; stdcall;

function CryptDestroyKey(hKey: HCRYPTKEY): BOOL; stdcall;

function CryptReleaseContext(hProv: HCRYPTPROV; dwFlags: DWORD): BOOL; stdcall;

function CryptGetProvParam(hProv: HCRYPTPROV; dwParam: DWORD; pbData: PBYTE;
  pdwDataLen: PDWORD; dwFlags: DWORD): BOOL; stdcall;

function CertStrToName(dwCertEncodingType: DWORD; pszX500: LPCTSTR; dwStrType: DWORD;
  pvReserved: PVOID; pbEncoded: PBYTE; pcbEncoded: PDWORD; ppszError: PLPCTSTR): BOOL; stdcall;

function CertCreateCertificateContext(dwCertEncodingType: DWORD; pbCertEncoded: PBYTE;
  cbCertEncoded: DWORD): PCCERT_CONTEXT; stdcall;

function CryptUIDlgViewContext(dwContextType: DWORD; pvContext: PVOID; hwnd: HWND;
  pwszTitle: LPCWSTR; dwFlags: DWORD; pvReserved: PVOID): BOOL; stdcall;

function CryptVerifySignature(hHash: HCRYPTHASH; pbSignature: PBYTE; dwSigLen: DWORD;
  hPubKey: HCRYPTKEY; sDescription: LPCTSTR; dwFlags: DWORD): BOOL; stdcall;

function CertOIDToAlgId(pszObjId: LPCSTR): DWORD; stdcall;

type
  ECryptException = class(Exception);

function CryptCheck(RetVal: BOOL; FuncName: string): BOOL;
function AsHex(Memory: Pointer; Size: Integer): string; overload;
function AsHex(Stream: TStream): string; overload;
function AsHex(Bytes: TBytes): string; overload;
function AsBase64(Memory: Pointer; Size: Integer): string; overload;
function AsBase64(Stream: TStream): string; overload;
function AsBase64(Bytes: TBytes): string; overload;
procedure GetHashStream(Container: WideString; DataStream: TStream; CertStream, KeyStream, HashStream, SignStream: TStream);
function GetProvContainers(Strings: TStrings): Boolean;
function GetCertificateSerialNumber(RAWCertificate: Pointer; Size: Int64): string;
procedure ViewCertificate(RAWCertificate: Pointer; Size: Int64; hwndParent: HWND);
procedure ViewContainerCertificate(Container: WideString; hwndParent: HWND);
function StreamAsBase64(Stream: TStream): string;

implementation

const
  advapi32 = 'advapi32.dll';
  cryptui = 'cryptui.dll';
  crypt32 = 'crypt32.dll';

function CryptEnumProviders; external advapi32 name 'CryptEnumProvidersW' delayed;
function CryptAcquireContext; external advapi32 name 'CryptAcquireContextW' delayed;
function CryptReleaseContext; external advapi32 name 'CryptReleaseContext';
function CryptCreateHash; external advapi32 name 'CryptCreateHash' delayed;
function CryptHashData; external advapi32 name 'CryptHashData' delayed;
function CryptDestroyHash; external advapi32 name 'CryptDestroyHash' delayed;
function CryptSetHashParam; external advapi32 name 'CryptSetHashParam' delayed;
function CryptGetHashParam; external advapi32 name 'CryptGetHashParam' delayed;
function CryptSignHash; external advapi32 name 'CryptSignHashW' delayed;
function CryptVerifySignature; external advapi32 name 'CryptVerifySignatureW' delayed;
function CryptUIDlgSelectCertificateFromStore; external cryptui name 'CryptUIDlgSelectCertificateFromStore' delayed;
function CryptSignMessage; external crypt32 name 'CryptSignMessage' delayed;
function CryptGetUserKey; external advapi32 name 'CryptGetUserKey' delayed;
function CryptGetKeyParam; external advapi32 name 'CryptGetKeyParam' delayed;
function CryptExportKey; external advapi32 name 'CryptExportKey' delayed;
function CryptDestroyKey; external advapi32 name 'CryptDestroyKey' delayed;
function CryptGetProvParam; external advapi32 name 'CryptGetProvParam' delayed;
function CertStrToName; external crypt32 name 'CertStrToNameW' delayed;
function CertCreateCertificateContext; external crypt32 name 'CertCreateCertificateContext' delayed;
function CryptUIDlgViewContext; external cryptui name 'CryptUIDlgViewContext' delayed;
function CertOIDToAlgId; external crypt32 name 'CertOIDToAlgId' delayed;

function CryptCheck(RetVal: BOOL; FuncName: string): BOOL;
begin
  try
    Result := Win32Check(RetVal);
  except
    on E: EOSError do raise ECryptException.Create(FuncName+#10+E.Message);
    else raise;
  end;
end;

procedure ReverseStream(Stream: TStream);
var
  FromBytes,ToBytes: TBytes;
  I, Size: Integer;
begin
  Size := Stream.Size;
  SetLength(FromBytes,Size);
  SetLength(ToBytes,Size);
  Stream.Position:=0;
  Stream.ReadData(FromBytes,Size);
  for I := Low(FromBytes) to Size-1 do
    ToBytes[I]:=FromBytes[Size-I-1];
  Stream.Position:=0;
  Stream.WriteData(ToBytes,Size);
  Stream.Position:=0;
end;

procedure CopyStream(FromStream,ToStream: TStream; Reverse: Boolean = False);
begin
  if (FromStream <> nil) and (ToStream <> nil) then
  begin
    FromStream.Position := 0;
    ToStream.Position := 0;
    ToStream.CopyFrom(FromStream, FromStream.Size);
    if Reverse then
      ReverseStream(ToStream);
  end;
end;

function AsHex(Memory: Pointer; Size: Integer): string;
begin
  SetLength(Result, Size*2);
  BinToHex(Memory, PChar(Result), Size);
end;

function AsHex(Stream: TStream): string;
var
  Memory: TMemoryStream;
begin
  Memory := TMemoryStream.Create;
  try
    Stream.Position := 0;
    Memory.CopyFrom(Stream, Stream.Size);
    Result := AsHex(Memory.Memory, Memory.Size);
  finally
    Memory.Free;
  end;
end;

function AsHex(Bytes: TBytes): string;
begin
  Result := AsHex(@Bytes[0], Length(Bytes));
end;

function AsBase64(Memory: Pointer; Size: Integer): string;
begin
//  Result:=StringReplace(TNetEncoding.Base64.EncodeBytesToString(Memory,Size),#13#10,'',[rfReplaceAll]);
  Result := StringReplace(EncodeBase64(Memory, Size), #13#10, '', [rfReplaceAll]);
end;

function AsBase64(Bytes: TBytes): string; overload;
begin
  Result := AsBase64(@Bytes[0], Length(Bytes));
end;

function AsBase64(Stream: TStream): string;
var
  Memory: TMemoryStream;
begin
  Memory := TMemoryStream.Create;
  try
    Stream.Position := 0;
    Memory.CopyFrom(Stream, Stream.Size);
    Result := AsBase64(Memory.Memory, Memory.Size);
  finally
    Memory.Free;
  end;
end;

function StreamAsBase64(Stream: TStream): string;
begin
  Result := AsBase64(Stream);
end;

function _WideStringFromAnsiMemory(Memory: PAnsiChar; Size: DWORD): WideString;
var
  AnsiStr: AnsiString;
  pAnsiCh: PAnsiChar;
begin
  pAnsiCh:=Memory;
  while (pAnsiCh^<>#0) and (pAnsiCh<Memory+Size) do Inc(pAnsiCh);
  SetString(AnsiStr,Memory,pAnsiCh-Memory);
  Result:=AnsiStr;
end;

function GetCertificateSerialNumber(RAWCertificate: Pointer; Size: Int64): string;
var
  CCERT_CONTEXT: PCCERT_CONTEXT;
begin
  CCERT_CONTEXT:=PCCERT_CONTEXT(CryptCheck(BOOL(CertCreateCertificateContext(
    X509_ASN_ENCODING or PKCS_7_ASN_ENCODING, RAWCertificate, Size)), 'CertCreateCertificateContext'));
  try
    Result:=GetCertSerialNumber(@CCERT_CONTEXT.pCertInfo.SerialNumber);
  finally
    CryptCheck(CertFreeCertificateContext(CCERT_CONTEXT), 'CertFreeCertificateContext');
  end;
end;

procedure ViewCertificate(RAWCertificate: Pointer; Size: Int64; hwndParent: HWND);
var
  CCERT_CONTEXT: PCCERT_CONTEXT;
begin
  CCERT_CONTEXT:=PCCERT_CONTEXT(CryptCheck(BOOL(CertCreateCertificateContext(
    X509_ASN_ENCODING or PKCS_7_ASN_ENCODING, RAWCertificate, Size)), 'CertCreateCertificateContext'));
  try
    CryptCheck(CryptUIDlgViewContext(1,CCERT_CONTEXT,hwndParent,nil,0,nil), 'CryptUIDlgViewContext');
  finally
    CryptCheck(CertFreeCertificateContext(CCERT_CONTEXT), 'CertFreeCertificateContext');
  end;
end;

function GetProvContainers(Strings: TStrings): Boolean;
var
  hProv: HCRYPTPROV;
  dwFlags, DataLen, EnterCount: DWORD;
  pbData: PByte;
  CryptRes: BOOL;
begin
  EnterCount:=Strings.Count;
  CryptCheck(CryptAcquireContext(@hProv, nil, nil, PROV_GOST_2001_DH, CRYPT_VERIFYCONTEXT), 'CryptAcquireContext');
  try
    dwFlags:=CRYPT_FIRST;
    try
      while CryptCheck(CryptGetProvParam(hProv, PP_ENUMCONTAINERS, nil, @DataLen, dwFlags), 'CryptGetProvParam') do
      begin
        GetMem(pbData,DataLen);
        try
          CryptCheck(CryptGetProvParam(hProv, PP_ENUMCONTAINERS, pbData, @DataLen, dwFlags), 'CryptGetProvParam');
          Strings.Add(_WideStringFromAnsiMemory(PAnsiChar(pbData),DataLen));
        finally
          FreeMem(pbData);
        end;
        dwFlags:=CRYPT_NEXT;
      end;
    except
      on E:Exception do
        if GetLastError<>ERROR_NO_MORE_ITEMS then raise;
    end;
  finally
    CryptCheck(CryptReleaseContext(hProv, 0), 'CryptReleaseContext');
  end;
  Result := Strings.Count > EnterCount;
end;

procedure ViewContainerCertificate(Container: WideString; hwndParent: HWND);
var
  Cert: TBytesStream;
begin
  Cert := TBytesStream.Create;
  try
    GetHashStream(Container, nil, Cert, nil, nil, nil);
    ViewCertificate(Cert.Memory, Cert.Size, hwndParent);
  finally
    Cert.Free;
  end;
end;

procedure GetHashStream(Container: WideString; DataStream: TStream; CertStream, KeyStream, HashStream, SignStream: TStream);
var
  hProv: HCRYPTPROV;
  DataLen: DWORD;
  hHash: HCRYPTHASH;
  hKey: HCRYPTKEY;
  dwKeySpec: DWORD;
  InStream, OutStream: TBytesStream;
begin
  dwKeySpec := AT_KEYEXCHANGE; //AT_SIGNATURE
  InStream := TBytesStream.Create;
  OutStream := TBytesStream.Create;
  try

    CopyStream(DataStream, InStream);

    CryptCheck(CryptAcquireContext(@hProv, @Container[1], nil, PROV_GOST_2001_DH, 0), 'CryptAcquireContext');
    try

      if (CertStream <> nil) or (KeyStream <> nil) then
      begin

        CryptCheck(CryptGetUserKey(hProv, dwKeySpec, @hKey), 'CryptGetUserKey');
        try

          //получение сертификата

          if CertStream <> nil then
          begin
            CryptCheck(CryptGetKeyParam(hKey, KP_CERTIFICATE, nil, @DataLen, 0), 'CryptGetKeyParam');
            OutStream.Size := DataLen;
            CryptCheck(CryptGetKeyParam(hKey, KP_CERTIFICATE, OutStream.Memory, @DataLen, 0), 'CryptGetKeyParam');
            CopyStream(OutStream, CertStream);
          end;

          //получение открытого ключа

          if KeyStream <> nil then
          begin
            CryptCheck(CryptExportKey(hKey, 0, PUBLICKEYBLOB, 0, nil, @DataLen), 'CryptExportKey');
            OutStream.Size := DataLen;
            CryptCheck(CryptExportKey(hKey, 0, PUBLICKEYBLOB, 0, OutStream.Memory, @DataLen), 'CryptExportKey');
            CopyStream(OutStream, KeyStream);
          end;

        finally
          CryptCheck(CryptDestroyKey(hKey), 'CryptDestroyKey');
        end;

      end;

      if (HashStream <> nil) or (SignStream <> nil) then
      begin

        CryptCheck(CryptCreateHash(hProv, CALG_GR3411, 0, 0, @hHash), 'CryptCreateHash');
        try

          CryptCheck(CryptHashData(hHash, InStream.Memory, InStream.Size, 0), 'CryptHashData');

          //получение хеша

          if HashStream <> nil then
          begin
            CryptCheck(CryptGetHashParam(hHash, HP_HASHVAL, nil, @DataLen, 0), 'CryptGetHashParam');
            OutStream.Size := DataLen;
            CryptCheck(CryptGetHashParam(hHash, HP_HASHVAL, OutStream.Memory, @DataLen, 0), 'CryptGetHashParam');
            CopyStream(OutStream,HashStream);
          end;

          //подпись хеша

          if SignStream<>nil then
          begin
            CryptCheck(CryptSignHash(hHash, dwKeySpec, nil, 0, nil, @DataLen), 'CryptSignHash');
            OutStream.Size := DataLen;
            CryptCheck(CryptSignHash(hHash, dwKeySpec, nil, 0, OutStream.Memory, @DataLen), 'CryptSignHash');
            CopyStream(OutStream, SignStream, True); //с обязательным переворачиванием
          end;

        finally
          CryptCheck(CryptDestroyHash(hHash), 'CryptDestroyHash');
        end;

      end;

    finally
      CryptCheck(CryptReleaseContext(hProv, 0), 'CryptReleaseContext');
    end;

  finally
    InStream.Free;
    OutStream.Free;
  end;

end;

end.
