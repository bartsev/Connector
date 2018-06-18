object GisSrvc: TGisSrvc
  OldCreateOrder = False
  OnCreate = ServiceCreate
  DisplayName = #1054#1073#1084#1077#1085' '#1089' '#1043#1048#1057' '#1046#1050#1061
  StartType = stManual
  OnExecute = ServiceExecute
  OnPause = ServicePause
  OnStart = ServiceStart
  OnStop = ServiceStop
  Height = 468
  Width = 718
  object qryParams: TFDQuery
    Connection = Connection
    SQL.Strings = (
      'SELECT T.Name, P.ParamValue FROM GetChargeRequestParam P'
      'JOIN ParamType T on P.id_ParamType=T.id'
      'WHERE id_ChargeRequest = :ChargeRequestId'
      'ORDER BY T.[Order];')
    Left = 56
    Top = 392
    ParamData = <
      item
        Name = 'CHARGEREQUESTID'
        DataType = ftInteger
        ParamType = ptInput
        Value = 2
      end>
  end
  object qryChargeRequest: TFDQuery
    Connection = Connection
    SQL.Strings = (
      'SELECT * FROM GetChargeRequest WHERE Processed = 0;')
    Left = 56
    Top = 120
  end
  object Connection: TFDConnection
    Params.Strings = (
      'ApplicationName=Architect'
      'Workstation=HOME-PC'
      'MARS=yes'
      'DriverID=MSSQL')
    ResourceOptions.AssignedValues = [rvDirectExecute]
    ResourceOptions.DirectExecute = True
    LoginPrompt = False
    Left = 56
    Top = 24
  end
  object qryUpdateChargeRequest1: TFDQuery
    Connection = Connection
    SQL.Strings = (
      'Update GetChargeRequest '
      'set processed = 1, '
      'RequestXML = :Request'
      'where id = :id;')
    Left = 56
    Top = 184
    ParamData = <
      item
        Name = 'REQUEST'
        DataType = ftMemo
        ParamType = ptInput
        Value = Null
      end
      item
        Name = 'ID'
        DataType = ftInteger
        ParamType = ptInput
        Value = Null
      end>
  end
  object qryPaymentRequest: TFDQuery
    Connection = Connection
    UpdateOptions.AssignedValues = [uvEDelete, uvEInsert, uvEUpdate]
    UpdateOptions.EnableDelete = False
    UpdateOptions.EnableInsert = False
    UpdateOptions.EnableUpdate = False
    SQL.Strings = (
      'SELECT * FROM PutPaymentRequest WHERE Processed = 0;')
    Left = 216
    Top = 120
  end
  object qryPayerCount: TFDQuery
    Connection = Connection
    SQL.Strings = (
      'Select count(*) as PayerCount'
      'from GetChargeRequestPayer '
      'where '
      '  id_ChargeRequest = :id_ChargeRequest;')
    Left = 144
    Top = 392
    ParamData = <
      item
        Name = 'ID_CHARGEREQUEST'
        DataType = ftInteger
        ParamType = ptInput
        Value = 1
      end>
  end
  object qryPayer: TFDQuery
    Connection = Connection
    SQL.Strings = (
      'Select '
      '  R.id_PayerType, '
      '  I.FirstName, '
      '  I.LastName, '
      '  I.MiddleName,'
      '  L.INN, '
      '  L.KPP'
      'from GetChargeRequestPayer R'
      'left join AttrIndividual I '
      '  on I.id = R.id_Payer'
      'left join AttrLegal L '
      '  on L.id = R.id_Payer'
      'where '
      '  R.id_ChargeRequest = :id_ChargeRequest;')
    Left = 240
    Top = 392
    ParamData = <
      item
        Name = 'ID_CHARGEREQUEST'
        DataType = ftInteger
        ParamType = ptInput
        Value = 1
      end>
  end
  object qryUpdateChargeRequest2: TFDQuery
    Connection = Connection
    SQL.Strings = (
      'Update GetChargeRequest set'
      'Status = :Status,'
      'ErrorCode = :ErrorCode,'
      'ErrorDesc = :ErrorDesc,'
      'ResponseXML = :Response '
      'where id = :id;')
    Left = 56
    Top = 240
    ParamData = <
      item
        Name = 'STATUS'
        DataType = ftString
        ParamType = ptInput
        Value = Null
      end
      item
        Name = 'ERRORCODE'
        DataType = ftString
        ParamType = ptInput
        Value = Null
      end
      item
        Name = 'ERRORDESC'
        DataType = ftString
        ParamType = ptInput
        Value = Null
      end
      item
        Name = 'RESPONSE'
        DataType = ftMemo
        ParamType = ptInput
        Value = Null
      end
      item
        Name = 'ID'
        DataType = ftInteger
        ParamType = ptInput
        Value = Null
      end>
  end
  object qryInsertChargeResponse: TFDQuery
    Connection = Connection
    SQL.Strings = (
      'SELECT * FROM GetChargeResponse;')
    Left = 56
    Top = 296
  end
  object qryUpdatePaymentRequest1: TFDQuery
    Connection = Connection
    SQL.Strings = (
      'Update PutPaymentRequest '
      'set processed = 1, '
      'RequestXML = :Request'
      'where id = :id;')
    Left = 216
    Top = 184
    ParamData = <
      item
        Name = 'REQUEST'
        DataType = ftMemo
        ParamType = ptInput
        Value = Null
      end
      item
        Name = 'ID'
        DataType = ftInteger
        ParamType = ptInput
        Value = Null
      end>
  end
  object qryUpdatePaymentRequest2: TFDQuery
    Connection = Connection
    SQL.Strings = (
      'Update PutPaymentRequest set'
      'processed = 1, '
      'Status = :Status,'
      'ErrorCode = :ErrorCode,'
      'ErrorDesc = :ErrorDesc,'
      'ResponseXML = :Response'
      'where id = :id;')
    Left = 216
    Top = 240
    ParamData = <
      item
        Name = 'STATUS'
        DataType = ftString
        ParamType = ptInput
        Value = Null
      end
      item
        Name = 'ERRORCODE'
        DataType = ftString
        ParamType = ptInput
        Value = Null
      end
      item
        Name = 'ERRORDESC'
        DataType = ftString
        ParamType = ptInput
        Value = Null
      end
      item
        Name = 'RESPONSE'
        DataType = ftMemo
        ParamType = ptInput
        Value = Null
      end
      item
        Name = 'ID'
        DataType = ftInteger
        ParamType = ptInput
        Value = Null
      end>
  end
  object qryInsertPaymentResponse: TFDQuery
    Connection = Connection
    SQL.Strings = (
      'Insert into PutPaymentResponse '
      '(id_PutPaymentRequest, MessageGUID, Processed)'
      'values (:id_Request, :MessageGuid, 0);')
    Left = 216
    Top = 296
    ParamData = <
      item
        Name = 'ID_REQUEST'
        DataType = ftInteger
        ParamType = ptInput
        Value = Null
      end
      item
        Name = 'MESSAGEGUID'
        DataType = ftString
        ParamType = ptInput
        Value = Null
      end>
  end
  object qryPaymentResponse: TFDQuery
    Connection = Connection
    SQL.Strings = (
      'SELECT * FROM PutPaymentResponse (NOLOCK) WHERE Processed = 0;')
    Left = 392
    Top = 120
  end
  object qryUpdatePaymentResponse2: TFDQuery
    Connection = Connection
    SQL.Strings = (
      'Update PutPaymentResponse set'
      'Status = :Status,'
      'ResponseXML = :Response,'
      'ErrorCode = :ErrorCode,'
      'Description = :ErrorDesc,'
      'UpdateDate = :UpdateDate'
      'where id = :id;')
    Left = 392
    Top = 240
    ParamData = <
      item
        Name = 'STATUS'
        DataType = ftString
        ParamType = ptInput
        Value = Null
      end
      item
        Name = 'RESPONSE'
        DataType = ftMemo
        ParamType = ptInput
        Value = Null
      end
      item
        Name = 'ERRORCODE'
        DataType = ftString
        ParamType = ptInput
        Value = Null
      end
      item
        Name = 'ERRORDESC'
        DataType = ftString
        ParamType = ptInput
        Value = Null
      end
      item
        Name = 'UPDATEDATE'
        DataType = ftString
        ParamType = ptInput
        Value = Null
      end
      item
        Name = 'ID'
        DataType = ftInteger
        ParamType = ptInput
        Value = Null
      end>
  end
  object qryUpdatePaymentResponse1: TFDQuery
    Connection = Connection
    SQL.Strings = (
      'Update PutPaymentResponse set '
      'processed = 1, '
      'RequestXML = :Request'
      'where id = :id;')
    Left = 392
    Top = 184
    ParamData = <
      item
        Name = 'REQUEST'
        DataType = ftMemo
        ParamType = ptInput
        Value = Null
      end
      item
        Name = 'ID'
        DataType = ftInteger
        ParamType = ptInput
        Value = Null
      end>
  end
  object qryCancelRequest: TFDQuery
    Connection = Connection
    SQL.Strings = (
      'SELECT * FROM PutCancelRequest WHERE Processed = 0;')
    Left = 560
    Top = 120
  end
  object qryUpdateCancelRequest1: TFDQuery
    Connection = Connection
    SQL.Strings = (
      'Update PutCancelRequest'
      'set processed = 1, '
      'RequestXML = :Request,'
      'where id = :id;')
    Left = 560
    Top = 184
    ParamData = <
      item
        Name = 'REQUEST'
        DataType = ftMemo
        ParamType = ptInput
        Value = Null
      end
      item
        Name = 'ID'
        DataType = ftInteger
        ParamType = ptInput
        Value = Null
      end>
  end
  object XMLDocument1: TXMLDocument
    Left = 576
    Top = 32
  end
  object FDPhysMSSQLDriverLink1: TFDPhysMSSQLDriverLink
    Left = 176
    Top = 24
  end
end
