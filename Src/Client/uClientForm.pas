unit uClientForm;

interface

{$REGION '�������� ������'}
(*
  *  ������ ����� �������
  *
  *  ������ ���������� ���� �� ������ �������� �� 100�� �� 2 �� �� ������. ������ ����� ����������� ��� ��� ������.
  *  ��� ����� ���������� �� ������������ ���� � ���� FileNameButtonedEdit ��� ����� �� ������ ������
  *  ���� ��� ����� �������� � ����, �� ����� ��� ����� ��������� � ini-����.
  *  �������� ����� ����������� � ���� ����������.
  *  �� ����� ���������� ����������� ������ '���������'.
  *  ��� �������� ����������� ������� �������
  *  ������ �������������� ��� ��������� �������� ���������
*)
{$ENDREGION}
{$REGION 'uses'}

uses
  Winapi.Windows,
  Winapi.Messages,

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
  Vcl.Menus,

  uSharedName_TLB,
  uTransferredFile,
  uFileMapping,
  uProtocol,
  uTransaction, Vcl.ComCtrls;

{$ENDREGION}

type
  TClientForm = class(TForm)
    NameSharedMemoryLabeledEdit: TLabeledEdit;
    FileNameLabel: TLabel;
    FileNameButtonedEdit: TButtonedEdit;
    FileNameImageList: TImageList;
    FileNamePopupMenu: TPopupMenu;
    OpenIniFileMenuItem: TMenuItem;
    SaveIniFileMenuItem: TMenuItem;
    OpenDialogMenuItem: TMenuItem;
    LogMemo: TMemo;
    SendButton: TButton;
    ProgressBar: TProgressBar;

    procedure FormCreate(Sender: TObject);
    procedure OpenDialogMenuItemClick(Sender: TObject);
    procedure SaveIniFileMenuItemClick(Sender: TObject);
    procedure OpenIniFileMenuItemClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure SendButtonClick(Sender: TObject);
  private
    // ������������� �������
    FId: Word;
    // ���������� �� �������� ������������� ����� �� Ini-�����
    FIniFile: ITransferredFile;
    // ������ ������ �����
    FDialogFile: ITransferredFile;

    // ���������� ����������
    FWriter     : IFile;
    FWriteThread: TWriteThread;
    // ���������� �������
    procedure AddLog(const ALog: string);
    procedure ChangeProgress(const ASize, ACurrentPage: Int64);
    procedure StartTransaction(Sender: TObject);
    procedure EndTransaction(Sender: TObject);

    // �����������
    procedure RegisterClient(const ASharedName: Widestring);
    procedure UnRegisterClient;
    procedure CheckServer(const ASharedName: Widestring);
  public
    { Public declarations }
  end;

var
  ClientForm: TClientForm;

implementation

{$R *.dfm}
{$REGION '�������� � �������� �����'}

procedure TClientForm.FormCreate(Sender: TObject);
var
  SharedName : Widestring;
  FileMapping: IFileMapping;

begin
  try
    // �������� ��� ����������� ������
    SharedName := CoSharedNameCreator.Create.GetSharedMemoryName;
    // ��������� ������
    CheckServer(SharedName);
    // ���������������� �������
    RegisterClient(SharedName);
    // �������� ���� �����������
    FileMapping := TFileMappingFactory.GetClient(SharedName);

    // �������� �������� ����������
    FWriter      := TWriter.Create(FileMapping, BUFFER_SIZE);
    FWriteThread := TWriteThread.Create(FWriter, SharedName);
    // ���������� ����������� �������
    FWriteThread.OnLog              := AddLog;
    FWriteThread.OnProgress         := ChangeProgress;
    FWriteThread.OnStartTransaction := StartTransaction;
    FWriteThread.OnEndTransaction   := EndTransaction;
    FWriteThread.OnTerminate        := EndTransaction;
    // ������ ����������
    FWriteThread.Start;

    // ������� ������ � ���������� �����
    FIniFile    := TIni.Create(ExtractFilePath(Application.ExeName));
    FDialogFile := TDialog.Create;

    // ������� �� ��� ����������
    NameSharedMemoryLabeledEdit.Text := SharedName;

  except
    on E: Exception do
      AddLog(Format('%s: %s', [E.ClassName, E.Message]));
  end;

end;

procedure TClientForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  FreeAndNil(FWriteThread);
  UnRegisterClient;
end;
{$ENDREGION}
{$REGION '����� � ���������� �����'}

procedure TClientForm.OpenDialogMenuItemClick(Sender: TObject);
begin
  if Assigned(FDialogFile) then
    try
      FileNameButtonedEdit.Text := FDialogFile.FileName;
    except
      on E: Exception do
        AddLog(Format('%s: %s', [E.ClassName, E.Message]));
    end;
end;

procedure TClientForm.OpenIniFileMenuItemClick(Sender: TObject);
begin
  if Assigned(FIniFile) then
    try
      FileNameButtonedEdit.Text := FIniFile.FileName;
    except
      on E: Exception do
        AddLog(Format('%s: %s', [E.ClassName, E.Message]));
    end;

end;

procedure TClientForm.SaveIniFileMenuItemClick(Sender: TObject);
begin
  if Assigned(FIniFile) then
    try
      (FIniFile as IFileSaver).FileName := FileNameButtonedEdit.Text;
    except
      on E: Exception do
        AddLog(Format('%s: %s', [E.ClassName, E.Message]));
    end;
end;
{$ENDREGION}

procedure TClientForm.SendButtonClick(Sender: TObject);
begin
  try
    CheckServer(NameSharedMemoryLabeledEdit.Text);
    if Assigned(FWriteThread) and Assigned(FWriter) then
    begin
      (FWriter as TWriter).FileName := FileNameButtonedEdit.Text;
      FWriteThread.StartTransaction;
    end;


  except
    on E: Exception do
      AddLog(Format('%s: %s', [E.ClassName, E.Message]));
  end;
end;
{$REGION '�����������'}

procedure TClientForm.RegisterClient(const ASharedName: Widestring);
var
  S: string;
begin
  S := Format('%s_client', [ASharedName]);
  if GlobalFindAtom(PChar(S)) = 0 then
    FId := GlobalAddAtom(PChar(S))
  else
    raise Exception.Create('������ ��� ���������������');

end;

procedure TClientForm.UnRegisterClient;
begin
  GlobalDeleteAtom(FId);
end;

procedure TClientForm.CheckServer(const ASharedName: Widestring);
var
  S: string;
begin
  S := Format('%s_server', [ASharedName]);
  if GlobalFindAtom(PChar(S)) = 0 then
    raise Exception.Create('������ �� ������');
end;

{$ENDREGION}
{$REGION '����������� ������� ����������'}

procedure TClientForm.StartTransaction(Sender: TObject);
begin
  SendButton.Enabled := False;
end;

procedure TClientForm.EndTransaction(Sender: TObject);
begin
  SendButton.Enabled := True;
end;

procedure TClientForm.AddLog(const ALog: string);
begin
  LogMemo.Lines.Add(Format('[%s]: %s', [TimeToStr(Time), ALog]));
end;

procedure TClientForm.ChangeProgress(const ASize, ACurrentPage: Int64);
begin
  ProgressBar.Min      := 0;
  ProgressBar.Max      := ASize;
  ProgressBar.Position := ACurrentPage;
  if ProgressBar.Position = Integer(ASize) then
    ProgressBar.Position := 0;
end;
{$ENDREGION}

end.
