using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Xml;
using System.Net;
using System.IO;
using System.Security.Cryptography.X509Certificates;
using System.Security.Cryptography.Xml;

namespace Receivers
{
    class Program
    {
        static void Main(string[] args)
        {
            XmlDocument xmldoc = new XmlDocument();
            xmldoc.Load("status_resp.xml");
            XmlElement root = xmldoc.DocumentElement;
            XmlNodeList nodes = root.GetElementsByTagName("BinaryData", "http://smev.gosuslugi.ru/rev120315");
            if (nodes.Count == 0)
            {
                Console.WriteLine("BinaryData not found");
                return;
            }
            File.WriteAllBytes("BinaryData.zip", Convert.FromBase64String(nodes[0].InnerXml));
            return;

            if (SendRequest())
            {
                SendStatus();
            }
        }

        static bool SendStatus()
        {
            string uri = "http://smev-mvf.test.gosuslugi.ru:7777/gateway/services/SID0004768";
            string actionStatus = "urn:async_getResult";
            string guid;

            XmlDocument xmldoc = new XmlDocument();

            // Читаем xml текст вашего запроса в смэв.
            xmldoc.Load("request_resp.xml");
            XmlElement root = xmldoc.DocumentElement;
            XmlNodeList nodes = root.GetElementsByTagName("MessageGUID", "http://smev.gosuslugi.ru/rev120315");
            if (nodes.Count == 0)
            {
                return false;
            } else
            {
                guid = nodes[0].InnerXml;
            }

            xmldoc.Load("status.xml");
            root = xmldoc.DocumentElement;
            nodes = root.GetElementsByTagName("MessageGUID", "http://smev.gosuslugi.ru/rev120315");
            nodes[0].InnerXml = guid;
            xmldoc.Save("status.xml");

            X509Store certStore = new X509Store(StoreLocation.CurrentUser);
            certStore.Open(OpenFlags.ReadOnly);
            X509Certificate2Collection certs = X509Certificate2UI.SelectFromCollection(
                certStore.Certificates,
                "Выберите сертификат",
                "Пожалуйста, выберите сертификат электронной подписи",
                X509SelectionFlag.SingleSelection);

            if (certs.Count == 0)
            {
                Console.WriteLine("Сертификат не выбран.");
                return false;
            }

            // Подписываем запрос
            SignXmlFile("status.xml", "status_signed.xml", certs[0]);

            // Создаем новый документ XML.
            XmlDocument doc = new XmlDocument();

            // Читаем xml текст вашего запроса в смэв.
            doc.Load("status_signed.xml");

            HttpWebRequest request = (HttpWebRequest)WebRequest.Create(uri);
            request.Credentials = CredentialCache.DefaultCredentials;
            request.Headers.Add("SOAPAction", actionStatus);
            request.ContentType = "text/xml;charset=\"utf-8\"";
            request.Method = "POST";
            StreamWriter writer = new StreamWriter(request.GetRequestStream());
            writer.Write(doc.OuterXml);

            writer.Close();
            request.GetRequestStream().Flush();
            int err = 0;
            string errDescription = string.Empty;
            HttpWebResponse response;
            try
            {
                response = (HttpWebResponse)request.GetResponse();
            }
            catch (WebException wex)
            {
                err = 10001;
                errDescription = wex.Message;
                response = (HttpWebResponse)wex.Response;
                return false;
            }
            XmlDocument respDoc = new XmlDocument();
            respDoc.PreserveWhitespace = true;
            StreamReader reader = new StreamReader(response.GetResponseStream(), System.Text.Encoding.GetEncoding("utf-8"));
            respDoc.LoadXml(reader.ReadToEnd());

            if (err > 0)
            {
                Console.WriteLine("Найдены ошибки при передаче сообщения: " + errDescription);
                return false;
            }
            else
            {
                respDoc.Save("status_resp.xml");
                Console.WriteLine("Получен ответ от сервера СМЭВ");
                Console.ReadKey();
                // Проверяете подпись (я испеользую КриптоПро .NET, пример есть у них на сайте)
                //                VerifyXmlData(respDoc);
                //Обрабатываете результат respDoc.OuterXml
                //можете отправить его, как результат работы вашего wcf сервиса
            }
            response.Close();
            return true;

        }

        static bool SendRequest()
        {
            string uri = "http://smev-mvf.test.gosuslugi.ru:7777/gateway/services/SID0004768";
            string action = "urn:async_exportPaymentReceiver";

            X509Store certStore = new X509Store(StoreLocation.CurrentUser);
            certStore.Open(OpenFlags.ReadOnly);
            X509Certificate2Collection certs = X509Certificate2UI.SelectFromCollection(
                certStore.Certificates,
                "Выберите сертификат",
                "Пожалуйста, выберите сертификат электронной подписи",
                X509SelectionFlag.SingleSelection);

            if (certs.Count == 0)
            {
                Console.WriteLine("Сертификат не выбран.");
                return false;
            }

            // Подписываем запрос
            SignXmlFile("request.xml", "request_signed.xml", certs[0]);

            // Создаем новый документ XML.
            XmlDocument doc = new XmlDocument();

            // Читаем xml текст вашего запроса в смэв.
            doc.Load("request_signed.xml");

            HttpWebRequest request = (HttpWebRequest)WebRequest.Create(uri);
            request.Credentials = CredentialCache.DefaultCredentials;
            request.Headers.Add("SOAPAction", action);
            request.ContentType = "text/xml;charset=\"utf-8\"";
            request.Method = "POST";
            StreamWriter writer = new StreamWriter(request.GetRequestStream());
            writer.Write(doc.OuterXml);

            writer.Close();
            request.GetRequestStream().Flush();
            int err = 0;
            string errDescription = string.Empty;
            HttpWebResponse response;
            try
            {
                response = (HttpWebResponse)request.GetResponse();
            }
            catch (WebException wex)
            {
                err = 10001;
                errDescription = wex.Message;
                response = (HttpWebResponse)wex.Response;
                return false;
            }
            XmlDocument respDoc = new XmlDocument();
            respDoc.PreserveWhitespace = true;
            StreamReader reader = new StreamReader(response.GetResponseStream(), System.Text.Encoding.GetEncoding("utf-8"));
            respDoc.LoadXml(reader.ReadToEnd());

            if (err > 0)
            {
                Console.WriteLine("Найдены ошибки при передаче сообщения: " + errDescription);
                return false;
            }
            else
            {
                respDoc.Save("request_resp.xml");
                Console.WriteLine("Получен ответ от сервера СМЭВ");
                Console.ReadKey();
                // Проверяете подпись (я испеользую КриптоПро .NET, пример есть у них на сайте)
                //                VerifyXmlData(respDoc);
                //Обрабатываете результат respDoc.OuterXml
                //можете отправить его, как результат работы вашего wcf сервиса
            }
            response.Close();
            return true;
        }

        static void SignXmlFile(string FileName, string SignedFileName, X509Certificate2 Certificate)
        {
            // Создаем новый документ XML.
            XmlDocument doc = new XmlDocument();

            // Читаем документ из файла.
            doc.Load(new XmlTextReader(FileName));

            // Создаём объект SmevSignedXml - наследник класса SignedXml с перегруженным GetIdElement
            // для корректной обработки атрибута wsu:Id. 
            SmevSignedXml signedXml = new SmevSignedXml(doc);

            // Задаём ключ подписи для документа SmevSignedXml.
            signedXml.SigningKey = Certificate.PrivateKey;

            // Создаем ссылку на подписываемый узел XML. В данном примере и в методических
            // рекомендациях СМЭВ подписываемый узел soapenv:Body помечен идентификатором "body".
            Reference reference = new Reference();
            reference.Uri = "#body";

            // Задаём алгоритм хэширования подписываемого узла - ГОСТ Р 34.11-94. Необходимо
            // использовать устаревший идентификатор данного алгоритма, т.к. именно такой
            // идентификатор используется в СМЭВ.
#pragma warning disable 612
            //warning CS0612: 'CryptoPro.Sharpei.Xml.CPSignedXml.XmlDsigGost3411UrlObsolete' is obsolete
            reference.DigestMethod = CryptoPro.Sharpei.Xml.CPSignedXml.XmlDsigGost3411UrlObsolete;
#pragma warning restore 612

            // Добавляем преобразование для приведения подписываемого узла к каноническому виду
            // по алгоритму http://www.w3.org/2001/10/xml-exc-c14n# в соответствии с методическими
            // рекомендациями СМЭВ.
            XmlDsigExcC14NTransform c14 = new XmlDsigExcC14NTransform();
            reference.AddTransform(c14);

            // Добавляем ссылку на подписываемый узел.
            signedXml.AddReference(reference);

            // Задаём преобразование для приведения узла ds:SignedInfo к каноническому виду
            // по алгоритму http://www.w3.org/2001/10/xml-exc-c14n# в соответствии с методическими
            // рекомендациями СМЭВ.
            signedXml.SignedInfo.CanonicalizationMethod = SignedXml.XmlDsigExcC14NTransformUrl;

            // Задаём алгоритм подписи - ГОСТ Р 34.10-2001. Необходимо использовать устаревший
            // идентификатор данного алгоритма, т.к. именно такой идентификатор используется в
            // СМЭВ.
#pragma warning disable 612
            //warning CS0612: 'CryptoPro.Sharpei.Xml.CPSignedXml.XmlDsigGost3411UrlObsolete' is obsolete
            signedXml.SignedInfo.SignatureMethod = CryptoPro.Sharpei.Xml.CPSignedXml.XmlDsigGost3410UrlObsolete;
#pragma warning restore 612

            // Вычисляем подпись.
            signedXml.ComputeSignature();

            // Получаем представление подписи в виде XML.
            XmlElement xmlDigitalSignature = signedXml.GetXml();

            // Добавляем необходимые узлы подписи в исходный документ в заготовленное место.
            doc.GetElementsByTagName("ds:Signature")[0].PrependChild(
                doc.ImportNode(xmlDigitalSignature.GetElementsByTagName("SignatureValue")[0], true));
            doc.GetElementsByTagName("ds:Signature")[0].PrependChild(
                doc.ImportNode(xmlDigitalSignature.GetElementsByTagName("SignedInfo")[0], true));

            // Добавляем сертификат в исходный документ в заготовленный узел
            // wsse:BinarySecurityToken.
            doc.GetElementsByTagName("wsse:BinarySecurityToken")[0].InnerText =
                Convert.ToBase64String(Certificate.RawData);

            // Сохраняем подписанный документ в файл.
            using (XmlTextWriter xmltw = new XmlTextWriter(SignedFileName,
                new UTF8Encoding(false)))
            {
                doc.WriteTo(xmltw);
            }
        }

        // Класс SmevSignedXml - наследник класса SignedXml с перегруженным
        // GetIdElement для корректной обработки атрибута wsu:Id. 
        class SmevSignedXml : SignedXml
        {
            public SmevSignedXml(XmlDocument document): base(document)
            {
            }

            public override XmlElement GetIdElement(XmlDocument document, string idValue)
            {
                XmlNamespaceManager nsmgr = new XmlNamespaceManager(document.NameTable);
                nsmgr.AddNamespace("wsu", WSSecurityWSUNamespaceUrl);
                return document.SelectSingleNode("//*[@wsu:Id='" + idValue + "']", nsmgr) as XmlElement;
            }
        }

        public const string WSSecurityWSSENamespaceUrl = "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd";
        public const string WSSecurityWSUNamespaceUrl = "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd";

    }
}
