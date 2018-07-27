#DEFINE CERT_X500_NAME_STR		3
#DEFINE CERT_NAME_SIMPLE_DISPLAY_TYPE	4
#DEFINE CERT_FIND_SUBJECT_STR  			458759
#DEFINE PP_KEYEXCHANGE_PIN		32
#define PKCS_7_ASN_ENCODING		0x00010000
#define X509_ASN_ENCODING		0x00000001
#define MY_ENCODING				BITOR(PKCS_7_ASN_ENCODING, X509_ASN_ENCODING)
m.VFCLDIR="H:\AVB"

#DEFINE ET_PROVIDER 		"eToken Base Cryptographic Provider"
#DEFINE CONTAINER_NAME		"8f87f8aa75319341"
#DEFINE PROV_RSA_FULL		1	
#DEFINE	CRYPT_VERIFYCONTEXT	0xF0000000	

DECLARE INTEGER GetLastError				IN kernel32	
DECLARE INTEGER CertStrToName				IN Crypt32 	LONG, STRING @, LONG, STRING @, STRING @, LONG @, STRING@
DECLARE INTEGER CertNameToStr				IN Crypt32 	LONG, string @, LONG, STRING @, LONG
DECLARE INTEGER CryptAcquireContext			IN advapi32 INTEGER @, STRING, STRING, INTEGER, INTEGER   
DECLARE INTEGER CryptReleaseContext			IN advapi32 INTEGER @, INTEGER
DECLARE INTEGER CryptSetProvParam			IN advapi32 INTEGER @, INTEGER, STRING @, INTEGER 
DECLARE INTEGER	CertCompareCertificate		IN Crypt32  INTEGER, INTEGER, INTEGER
DECLARE INTEGER	CertOpenSystemStore			IN Crypt32  INTEGER, STRING @
DECLARE INTEGER	CertCloseStore				IN Crypt32  INTEGER, INTEGER
DECLARE INTEGER	CertEnumCertificatesInStore	IN Crypt32  INTEGER, INTEGER
DECLARE INTEGER	CertFreeCertificateContext 	IN Crypt32  INTEGER
DECLARE INTEGER	CertGetNameString			IN Crypt32  INTEGER, INTEGER, INTEGER, STRING @, STRING @, INTEGER
DECLARE INTEGER	CertSerializeCertificateStoreElement	IN Crypt32 INTEGER, INTEGER, INTEGER, INTEGER
DECLARE INTEGER	CertFindCertificateInStore	IN Crypt32  INTEGER, INTEGER, INTEGER, INTEGER, STRING @, INTEGER
DECLARE Long 	CoCreateGuid 				IN Ole32.dll	STRING @ guid
DECLARE INTEGER	CertCreateCertificateContext	IN Crypt32 INTEGER, STRING @, INTEGER
DECLARE INTEGER	CertFreeCertificateContext 	IN Crypt32 INTEGER
Declare Integer FileTimeToLocalFileTime in Win32API ;
		String lpFileTime, ;
		String @lpLocalFileTime
Declare Integer FileTimeToSystemTime in Win32API ;
		String lpFileTime, ;
		String @lpSystemTime


LOCAL response, pbEncoded, CertName

CLEAR 
SET CLASSLIB TO struct, record, crypto_api_struct additive

CertName = "CN=Барцев А." + CHR(0)
pcbEncoded = 0
response = CertStrToName(X509_ASN_ENCODING, @CertName, CERT_X500_NAME_STR, .NULL., 0, @pcbEncoded, .NULL.)

IF response == 0 
	n = getLastError()
	? n, pcbEncoded
	RETURN
ENDIF

? pcbEncoded
pbEncoded = SPACE(pcbEncoded)
response = CertStrToName(X509_ASN_ENCODING, @CertName, CERT_X500_NAME_STR, .NULL., @pbEncoded, @pcbEncoded, .NULL.)
? "pbEncoded = ", pbEncoded

Return

oNameBlob.SetPointer(pNameBlob)
? "NameBlob = ", oNameBlob.GetString()
buf_size = (LEN(pszX500) + 1) * 2
buf = SPACE(buf_size)
response = CertNameToStr(X509_ASN_ENCODING, @pbEncoded, CERT_X500_NAME_STR, @buf, buf_size)
? "CertNameToStr - ",response
? "result=", buf


