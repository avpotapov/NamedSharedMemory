unit uTransaction;

interface

{$REGION '�������� ������'}
(*
  *  ������ �������� ������ �������������� ����� �������� � ��������
  *  � ������ ����������
  *
  *  ������ � ������ ��������� � ������ �������� ������ �� �������
  *  � ������ �� ����� � ��������� �������� �����
  *  ������� �� TFile (������ Nsm.Io)
  *
*)
{$ENDREGION}
{$REGION 'uses'}

uses
  Winapi.Windows,
  System.Classes,
  System.SysUtils,
  uProtocol;
{$ENDREGION}

type
  EBaseThread = class(Exception);

  TProgressEvent = procedure(const ASize, ACurrentPage: Int64) of object;

  TBaseThread = class(TThread)
  private
    FOnStartTransaction: TNotifyEvent;
    FOnEndTransaction  : TNotifyEvent;
    FOnLog             : TGetStrProc;
    FOnProgress        : TProgressEvent;
  protected
    // ��������� �� ������, ����������/����������� ����
    FFile  : IFile;
    FEvents: array [0 .. 2] of THandle; // ������ ��������� �������
    // ���������� ��� ��������������
    FSharedName: WideString;

    // �������� �������
    FReadEvent,                     // �������-������
    FWriteEvent,                    // �������-������
    FTerminateServerEvent,          // �������-������ �������� ����������
    FTerminateClientEvent: THandle; // �������-������ �������� ����������

    procedure CreateEvents; virtual; abstract;
    procedure ToLog(const ALog: string);
    procedure DoStartTransaction; virtual;
    procedure DoEndTransaction; virtual;
    procedure DoProgress(const ASize, ACurrentPage: Int64); virtual;

  public
    constructor Create(const AFile: IFile; const ASharedName: WideString); reintroduce;
    procedure AfterConstruction; override;

  public

    property OnLog: TGetStrProc read FOnLog write FOnLog;
    property OnStartTransaction: TNotifyEvent read FOnStartTransaction write FOnStartTransaction;
    property OnEndTransaction: TNotifyEvent read FOnEndTransaction write FOnEndTransaction;
    property OnProgress: TProgressEvent read FOnProgress write FOnProgress;
  end;

  TWriteThread = class(TBaseThread)
  protected
    procedure CreateEvents; override;
    procedure Execute; override;
  public
    procedure StartTransaction;

  end;

  TReadThread = class(TBaseThread)
  protected
    procedure CreateEvents; override;
    procedure Execute; override;
//  public
//    destructor Destroy; override;
  end;

implementation

{$REGION 'uses'}
{$IFDEF DEBUG}
uses
  uSimpleLogger;
{$ENDIF}
{$ENDREGION}
{$REGION 'TBaseThread'}

constructor TBaseThread.Create(const AFile: IFile; const ASharedName: WideString);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FFile           := AFile;
  FSharedName     := ASharedName;
end;

procedure TBaseThread.AfterConstruction;
begin
  inherited;
  CreateEvents;
end;


procedure TBaseThread.DoEndTransaction;
begin
  ToLog('����� ����������');
  FFile.Clear;
  DoProgress(0, 0);
  if Assigned(FOnEndTransaction) then
    Synchronize(
      procedure
      begin
        FOnEndTransaction(Self);
      end);

end;

procedure TBaseThread.DoProgress(const ASize, ACurrentPage: Int64);
begin
  if Assigned(FOnProgress) then
    Synchronize(
      procedure
      begin
        FOnProgress(ASize, ACurrentPage);
      end);

end;

procedure TBaseThread.DoStartTransaction;
begin
  ToLog('������ ����������');
  if Assigned(FOnStartTransaction) then
    Synchronize(
      procedure
      begin
        FOnStartTransaction(Self);
      end);

end;

procedure TBaseThread.ToLog(const ALog: string);
begin
  if Assigned(FOnLog) then
    Synchronize(
      procedure
      begin
        FOnLog(ALog);
      end);
end;

{$ENDREGION 'TBaseThread'}
{$REGION 'TWriteThread'}

procedure TWriteThread.CreateEvents;
begin
  // ��������� ������� ��� �������������
  FReadEvent := OpenEvent(EVENT_ALL_ACCESS, False, PChar(Format('%s_read', [FSharedName])));
  if FReadEvent = 0 then
  begin
    raise EBaseThread.Create(SysErrorMessage(GetLastError));
  end;
  ResetEvent(FReadEvent);
  FWriteEvent := OpenEvent(EVENT_ALL_ACCESS, False, PChar(Format('%s_write', [FSharedName])));
  if FWriteEvent = 0 then
  begin
    raise EBaseThread.Create(SysErrorMessage(GetLastError));
  end;
  ResetEvent(FWriteEvent);
  FTerminateServerEvent := OpenEvent(EVENT_ALL_ACCESS, False, PChar(Format('%s_serverabort', [FSharedName])));
  if FTerminateServerEvent = 0 then
  begin
    raise EBaseThread.Create(SysErrorMessage(GetLastError));
  end;
  FTerminateClientEvent := OpenEvent(EVENT_ALL_ACCESS, False, PChar(Format('%s_clientabort', [FSharedName])));
  if FTerminateClientEvent = 0 then
  begin
    raise EBaseThread.Create(SysErrorMessage(GetLastError));
  end;
  ResetEvent(FTerminateClientEvent);

end;

procedure TWriteThread.Execute;
begin
  FEvents[0] := FTerminateClientEvent;
  FEvents[1] := FTerminateServerEvent;
  FEvents[2] := FWriteEvent;
  try

    while not Terminated do
      case WaitForMultipleObjects(3, @FEvents, False, 100) of
        WAIT_OBJECT_0:
          Exit;

        WAIT_OBJECT_0 + 1:
          begin
{$IFDEF DEBUG}
            Log.LogStatus('������ ��������', 'TWriteThread.Execute');
{$ENDIF}
            ToLog('������ ��������');
          end;

        WAIT_OBJECT_0 + 2:
          if FFile.WriteFile then
          begin
{$IFDEF DEBUG}
              Log.LogStatus(Format('���������� ���� ''%s''(%d) - %d �� %d', [FFile.FileName, FFile.Size,
                FFile.CurrentPage, FFile.Size]), 'TReadThread.Execute');
{$ENDIF}
            DoProgress(FFile.Size, FFile.CurrentPage);
            SetEvent(FReadEvent)
          end
          else
          begin
{$IFDEF DEBUG}
            Log.LogStatus('����� ����������', 'TWriteThread.Execute');
{$ENDIF}
            DoEndTransaction;
          end;

        WAIT_TIMEOUT:
          ;
      else
        begin
{$IFDEF DEBUG}
          Log.LogError(SysErrorMessage(GetLastError), 'TWriteThread.Execute');
{$ENDIF}
          ToLog(SysErrorMessage(GetLastError));
          Exit;
        end;
      end;
  finally

    SetEvent(FTerminateClientEvent);
    DoEndTransaction;
    Sleep(500);
{$IFDEF DEBUG}
    Log.LogStatus('������ ��������', 'TWriteThread.Execute');
{$ENDIF}
    ToLog('������ ��������');
  end;
end;

procedure TWriteThread.StartTransaction;
begin
  if (FFile is TWriter) and TWriter(FFile).WriteFileInfo then
  begin
{$IFDEF DEBUG}
    Log.LogStatus('������ ����������', 'TWriteThread.StartTransaction');
{$ENDIF}
    DoStartTransaction;
    SetEvent(FReadEvent);
//    if WaitForSingleObject(FWriteEvent, 2000) = WAIT_OBJECT_0 then
//        SetEvent(FWriteEvent)
//    else
//    begin
//      ToLog('������ �� ��������');
//      DoEndTransaction;
//    end;


  end;
end;


{$ENDREGION 'TWriteThread'}
{$REGION 'TReadThread'}

procedure TReadThread.CreateEvents;
begin
  // ������� ������� ��� �������������
  FReadEvent := CreateEvent(nil, False, False, PChar(Format('%s_read', [FSharedName])));
  if FReadEvent = 0 then
  begin
    raise EBaseThread.Create(SysErrorMessage(GetLastError));
  end;

  FWriteEvent := CreateEvent(nil, False, False, PChar(Format('%s_write', [FSharedName])));
  if FWriteEvent = 0 then
  begin
    raise EBaseThread.Create(SysErrorMessage(GetLastError));
  end;

  FTerminateServerEvent := CreateEvent(nil, False, False, PChar(Format('%s_serverabort', [FSharedName])));
  if FTerminateServerEvent = 0 then
  begin
    raise EBaseThread.Create(SysErrorMessage(GetLastError));
  end;

  FTerminateClientEvent := CreateEvent(nil, False, False, PChar(Format('%s_clientabort', [FSharedName])));
  if FTerminateClientEvent = 0 then
  begin
    raise EBaseThread.Create(SysErrorMessage(GetLastError));
  end;
end;

//destructor TReadThread.Destroy;
//begin
//  CloseHandle(FReadEvent);
//  CloseHandle(FWriteEvent);
//  CloseHandle(FTerminateClientEvent);
//  CloseHandle(FTerminateServerEvent);
//  inherited;
//end;

procedure TReadThread.Execute;
begin
  FEvents[0] := FTerminateServerEvent;
  FEvents[1] := FTerminateClientEvent;
  FEvents[2] := FReadEvent;
  try
    while not Terminated do

      case WaitForMultipleObjects(3, @FEvents, False, 100) of
        WAIT_OBJECT_0:
          Exit;
        WAIT_OBJECT_0 + 1:
          begin
             DoEndTransaction;

{$IFDEF DEBUG}
            Log.LogStatus('������ ��������', 'TReadThread.Execute');
{$ENDIF}
            ToLog('������ ��������');
          end;
        WAIT_OBJECT_0 + 2:
          begin
            // ������ ����������
            if (FFile is TReader) and TReader(FFile).IsEmplty and TReader(FFile).ReadFileInfo then
            begin
{$IFDEF DEBUG}
              Log.LogStatus('������ ����������', 'TReadThread.Execute');
{$ENDIF}
              DoStartTransaction;
              ToLog(Format('���������� ���� ''%s''(%d)', [FFile.FileName, FFile.Size]));
{$IFDEF DEBUG}
              Log.LogStatus(Format('���������� ���� ''%s''(%d)', [FFile.FileName, FFile.Size]), 'TReadThread.Execute');
{$ENDIF}
              SetEvent(FWriteEvent);
              Continue;
            end;

            if FFile.ReadFile then
            begin
{$IFDEF DEBUG}
              Log.LogStatus(Format('���������� ���� ''%s''(%d) - %d �� %d', [FFile.FileName, FFile.Size,
                FFile.CurrentPage, FFile.Size]), 'TReadThread.Execute');
{$ENDIF}
              DoProgress(FFile.Size, FFile.CurrentPage);
              SetEvent(FWriteEvent);
            end
            else
            begin
{$IFDEF DEBUG}
              Log.LogStatus('����� ����������', 'TReadThread.Execute');
{$ENDIF}
              DoEndTransaction;
              SetEvent(FWriteEvent);
            end;
          end;

        WAIT_TIMEOUT:
        else
        begin
{$IFDEF DEBUG}
          Log.LogError(SysErrorMessage(GetLastError), 'TReadThread.Execute');
{$ENDIF}
          ToLog(SysErrorMessage(GetLastError));
          Exit;
        end;
      end;
  finally
    SetEvent(FTerminateServerEvent);
    DoEndTransaction;
{$IFDEF DEBUG}
    Log.LogStatus('������ ��������', 'TReadThread.Execute');
{$ENDIF}
    ToLog('������ ��������');
  end;

end;

{$ENDREGION 'TReadThread'}

end.
