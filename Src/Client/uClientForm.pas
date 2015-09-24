unit uClientForm;

interface

{$REGION 'Описание модуля'}
(*
  *  Модуль формы клиента
  *
  *  Клиент отправляет файл на сервер размером от 100Мб до 2 Гб на сервер. Размер файла проверяется при его выборе.
  *  Имя файла выбирается из ниспадающего меню у поля FileNameButtonedEdit при клике на правой иконке
  *  Если имя файла записано в поле, то также его можно сохранить в ini-файл.
  *  Отправка файла реализована в виде транзакции.
  *  На время транзакции блокируются кнопка 'Отправить'.
  *  При загрузке проверяется наличие сервера
  *  Клиент регистрируется для избежания создания дубликата
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
    // Идентификатор сервера
    FId: Word;
    // Сохранение из загрузка перемещаемого файла из Ini-файла
    FIniFile: ITransferredFile;
    // Диалог выбора файла
    FDialogFile: ITransferredFile;

    // Выполнение транзакции
    FWriter     : IFile;
    FWriteThread: TWriteThread;
    // Обраотчики событий
    procedure AddLog(const ALog: string);
    procedure ChangeProgress(const ASize, ACurrentPage: Int64);
    procedure StartTransaction(Sender: TObject);
    procedure EndTransaction(Sender: TObject);

    // Регистрация
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
{$REGION 'Создание и закрытие формы'}

procedure TClientForm.FormCreate(Sender: TObject);
var
  SharedName : Widestring;
  FileMapping: IFileMapping;

begin
  try
    // Получить имя разделяемой памяти
    SharedName := CoSharedNameCreator.Create.GetSharedMemoryName;
    // Проверить сервер
    CheckServer(SharedName);
    // Зарегистрировать клиента
    RegisterClient(SharedName);
    // Получить файл отображения
    FileMapping := TFileMappingFactory.GetClient(SharedName);

    // Создание объектов транзакции
    FWriter      := TWriter.Create(FileMapping, BUFFER_SIZE);
    FWriteThread := TWriteThread.Create(FWriter, SharedName);
    // Назначение обработчико событий
    FWriteThread.OnLog              := AddLog;
    FWriteThread.OnProgress         := ChangeProgress;
    FWriteThread.OnStartTransaction := StartTransaction;
    FWriteThread.OnEndTransaction   := EndTransaction;
    FWriteThread.OnTerminate        := EndTransaction;
    // Запуск транзакции
    FWriteThread.Start;

    // Объекты выбора и сохранения файла
    FIniFile    := TIni.Create(ExtractFilePath(Application.ExeName));
    FDialogFile := TDialog.Create;

    // Вывести на имя соединения
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
{$REGION 'Выбор и сохранение файла'}

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
{$REGION 'Регистрация'}

procedure TClientForm.RegisterClient(const ASharedName: Widestring);
var
  S: string;
begin
  S := Format('%s_client', [ASharedName]);
  if GlobalFindAtom(PChar(S)) = 0 then
    FId := GlobalAddAtom(PChar(S))
  else
    raise Exception.Create('Клиент уже зарегистрирован');

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
    raise Exception.Create('Сервер не найден');
end;

{$ENDREGION}
{$REGION 'Обработчики событий транзакции'}

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
