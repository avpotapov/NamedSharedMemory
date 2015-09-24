unit uServerForm;

interface

{$REGION '�������� ������'}
(*
  *  ������ ����� �������
  *
  *  ������ �������������� � �������
  *  �� ����������� �������� ���� �������� � ����������� �������
  *  ��� ������� ��������� ������� ��� ���������� ����������
  *  ����� ������ ������� ������� ������ ����������� ������
  *  �� ����� ���������� ����������� ������ '����� ����������'.
  *
*)
{$ENDREGION}
{$REGION 'uses'}

uses
  Winapi.Windows,
  Winapi.Messages,
  Winapi.ShlObj,

  System.SysUtils,
  System.Variants,
  System.Classes,
  System.ImageList,

  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ImgList,

  uSharedName_TLB,
  uFileMapping,
  uProtocol,
  uTransaction, Vcl.ComCtrls;

{$ENDREGION}

type
  TServerForm = class(TForm)
    NameSharedMemoryLabeledEdit: TLabeledEdit;
    DirectoryButtonedEdit: TButtonedEdit;
    DirectoryLabel: TLabel;
    ImageList: TImageList;
    LogMemo: TMemo;
    ProgressBar: TProgressBar;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure DirectoryButtonedEditRightButtonClick(Sender: TObject);
  private
    // ������������� �������
    FId        : Word;
    FSharedName: ISharedNameCreator;
    // ������� ����������
    FReader    : IFile;
    FReadThread: TReadThread;
    // ����������� ������� ����������
    procedure ChangeProgress(const ASize, ACurrentPage: Int64);
    procedure AddLog(const ALog: string);
    procedure StartTransaction(Sender: TObject);
    procedure EndTransaction(Sender: TObject);
    // �����������
    procedure RegisterServer(const ASharedName: Widestring);
    procedure UnRegisterServer;
  public

  end;

var
  ServerForm: TServerForm;

implementation

{$R *.dfm}
{$REGION '�������� � �������� �����'}

procedure TServerForm.FormCreate(Sender: TObject);
var
  FileMapping: IFileMapping;
begin
  try

    FSharedName := CoSharedNameCreator.Create;
    RegisterServer(FSharedName.GetSharedMemoryName);
    FileMapping := TFileMappingFactory.GetServer(FSharedName.GetSharedMemoryName);

    FReader                        := TReader.Create(FileMapping, BUFFER_SIZE);
    (FReader as TReader).Directory := ExtractFilePath(Application.ExeName);
    FReadThread                    := TReadThread.Create(FReader, FSharedName.GetSharedMemoryName);
    FReadThread.OnLog              := AddLog;
    FReadThread.OnProgress         := ChangeProgress;
    FReadThread.OnStartTransaction := StartTransaction;
    FReadThread.OnEndTransaction   := EndTransaction;
    FReadThread.OnTerminate        := EndTransaction;
    FReadThread.Start;

    NameSharedMemoryLabeledEdit.Text := FSharedName.GetSharedMemoryName;
    DirectoryButtonedEdit.Text       := ExtractFilePath(Application.ExeName);
  except
    on E: Exception do
      AddLog(Format('%s: %s', [E.ClassName, E.Message]));
  end;
end;

procedure TServerForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  FreeAndNil(FReadThread);
  UnRegisterServer;
end;
{$ENDREGION}
{$REGION '������ ������ ���������� ���������� �����'}

procedure TServerForm.DirectoryButtonedEditRightButtonClick(Sender: TObject);
var
  ItemID    : PItemIDList;
  BrowseInfo: TBrowseInfo;
  TempPath  : array [0 .. MAX_PATH] of Char;
begin
  FillChar(BrowseInfo, sizeof(TBrowseInfo), #0);
  BrowseInfo.ulFlags := BIF_RETURNONLYFSDIRS;
  ItemID             := SHBrowseForFolder(BrowseInfo);
  if ItemID <> nil then
  begin
    SHGetPathFromIDList(ItemID, TempPath);

    DirectoryButtonedEdit.Text     := IncludeTrailingPathDelimiter(TempPath);
    (FReader as TReader).Directory := IncludeTrailingPathDelimiter(TempPath);

    GlobalFreePtr(ItemID);
  end;
end;
{$ENDREGION}
{$REGION '����������� ������� ����������'}

procedure TServerForm.StartTransaction(Sender: TObject);
begin
  DirectoryButtonedEdit.Enabled := False;
end;

procedure TServerForm.EndTransaction(Sender: TObject);
begin
  DirectoryButtonedEdit.Enabled := True;
end;

procedure TServerForm.AddLog(const ALog: string);
begin
  LogMemo.Lines.Add(Format('[%s]: %s', [TimeToStr(Time), ALog]));
end;

procedure TServerForm.ChangeProgress(const ASize, ACurrentPage: Int64);
begin
  ProgressBar.Min      := 0;
  ProgressBar.Max      := ASize;
  ProgressBar.Position := ACurrentPage;
  if ProgressBar.Position = Integer(ASize) then
    ProgressBar.Position := 0;
end;

{$ENDREGION}
{$REGION '�����������'}

procedure TServerForm.RegisterServer(const ASharedName: Widestring);
var
  S: string;
begin
  S := Format('%s_server', [ASharedName]);
  if GlobalFindAtom(PChar(S)) = 0 then
    FId := GlobalAddAtom(PChar(S))
  else
    raise Exception.Create('������ ��� ���������������');

end;

procedure TServerForm.UnRegisterServer;
begin
  GlobalDeleteAtom(FId);
end;
{$ENDREGION}

end.
