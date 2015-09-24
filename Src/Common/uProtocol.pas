unit uProtocol;

interface

{$REGION 'Описание модуля'}
(*
  *  Модуль содержит классы, реализующие протокол передачи файла
  *
  *   Протокол передачи:
  *   - Стартовый пакет FileInfo
  *   - Последующие пакеты содержат в первых 8 байтах реальный размер
  *     передаваемых данных
  *
  *  - В начале транзакции клиент отправляет в разделяемую память информацию
  *    о копируемом файле. Данная информация содержится в записи FileInfo.
  *    FileInfo содержит статические методы для сохранения и восстановления
  *    структуры в объект TStream.
  *
  *  - Поскольку размер разделяемой памяти лимитирован, копируемый файл
  *    передается по частям. За разделение файла на части и объединение в
  *    единый файл, отвечают классы TWriter и TReader.
  *    Данные классы содержат вышеупомянутую структуру FileInfo, унаследованы
  *    от TFile.
  *    Зависят от интерфейса отображаемого файла.
  *
  *  - Все исключения в данном модуля возбуждаются в класса EFile
  *
  *  - Для удобства записи/чтения части файла из временного буфера
  *    создан Helper для TBytesStream.
  *
  *
*)
{$ENDREGION}
{$REGION 'uses'}

uses
  Winapi.Windows,
  System.Classes,
  System.SysUtils,
  System.Math,
  uFileMapping;
{$ENDREGION}

type
  EFile = class(Exception);

  TFileInfo = record
  private
    LengthFileName: Integer;
  public
    FileSize: Int64;
    FileName: string;
  public
    constructor Create(const AFileName: String; const AFileSize: Int64);
    class procedure Serialize(AStream: TStream; AFileInfo: TFileInfo); static;
    class procedure Deserialize(AStream: TStream; out AFileInfo: TFileInfo); static;
  end;

  IFile = interface
    ['{0F464370-D5FB-4C73-8DD7-337533003462}']
    function GetSize: Int64;
    function GetCurrentPage: Int64;
    function GetFileName: String;
    procedure Clear;
    function WriteFile: Boolean;
    function ReadFile: Boolean;
    property Size: Int64 read GetSize;
    property CurrentPage: Int64 read GetCurrentPage;
    property FileName: string read GetFileName;

  end;

  TFile = class(TInterfacedObject, IFile)
  protected
    // Указатель на файл отображения
    FFileMapping: IFileMapping;
    // Максимальный размер буфера обмена
    FMaxBufferSize: Int64;
    // Файловый поток (основной)
    FFileStream: TFileStream;
    // Описание файла
    FFileInfo: TFileInfo;
    // Буферный (временный) поток (копируется часть перемещаемых данных)
    FBuffer: TBytesStream;

    function GetSize: Int64; virtual; abstract;
    function GetCurrentPage: Int64; virtual; abstract;
    function GetFileName: String; virtual;

  public
    constructor Create(const AFileMapping: IFileMapping; const AMaxBufferSize: Int64); reintroduce;
    destructor Destroy; override;
  public
    procedure Clear; virtual;
    function WriteFile: Boolean; virtual;
    function ReadFile: Boolean; virtual;
    property Size: Int64 read GetSize;
    property CurrentPage: Int64 read GetCurrentPage;
    property FileName: string read GetFileName;
  end;

  TWriter = class(TFile)
  private
    // Текущее положение указателя
    FPosition: Int64;
    procedure SetFileName(const AFileName: String);
    // Получить текущий размер части файла для сохранения в буфер
    function GetCurrentPartSize: Int64;
  protected
    function GetSize: Int64; override;
    function GetCurrentPage: Int64; override;
  public
    procedure Clear; override;
    function WriteFileInfo: Boolean;
    function WriteFile: Boolean; override;
    property FileName: string read GetFileName write SetFileName;

  end;

  TReader = class(TFile)
  const
    TMP_FILE = 'nsm.tmp';
  private
    FDirectory: string;
    procedure CreateTempFile;
  protected
    function GetSize: Int64; override;
    function GetCurrentPage: Int64; override;
  public
    procedure Clear; override;
    function IsEmplty: Boolean;
    function ReadFileInfo: Boolean;
    function ReadFile: Boolean; override;
    property Directory: string write FDirectory;

  end;

implementation
{$IFDEF DEBUG}
uses
  uSimpleLogger;
{$ENDIF}
{$ENDREGION}

{$REGION 'TFileInfo'}


constructor TFileInfo.Create(const AFileName: String; const AFileSize: Int64);
begin
  LengthFileName := ByteLength(AFileName);
  FileName       := AFileName;
  FileSize       := AFileSize;
end;

class procedure TFileInfo.Serialize(AStream: TStream; AFileInfo: TFileInfo);
begin
{$IFDEF DEBUG}
  Assert(AStream <> nil);
{$ENDIF}
  AStream.Size := 0;
  AStream.Write(AFileInfo.LengthFileName, SizeOf(Integer));
  AStream.Write(AFileInfo.FileSize, SizeOf(Int64));
  AStream.Write(AFileInfo.FileName[1], AFileInfo.LengthFileName);
  AStream.Position := 0;
end;

class procedure TFileInfo.Deserialize(AStream: TStream; out AFileInfo: TFileInfo);
var
  P: Pointer;
begin
{$IFDEF DEBUG}
  Assert(AStream <> nil);
{$ENDIF}
  AStream.Position := 0;
  AStream.Read(AFileInfo.LengthFileName, SizeOf(Integer));
  AStream.Read(AFileInfo.FileSize, SizeOf(Int64));
  GetMem(P, 1024);
  try
    FillChar(P^, 1024, #0);
    AStream.Read(P^, AFileInfo.LengthFileName);
    AFileInfo.FileName := PChar(P);
  finally
    FreeMem(P);
  end;
  AStream.Position := 0;
end;

{$ENDREGION 'TFileInfo'}
{$REGION 'TBytesStreamHelper'}

type
  TBytesStreamHelper = class Helper for TBytesStream
  private
    function GetDataSize: Int64;
    procedure SetDataSize(ADataSize: Int64);
  public
    procedure CopyToSelf(AStream: TStream; const ADataSize: Int64);
    procedure CopyFromSelf(AStream: TStream; const ADataSize: Int64);

    property DataSize: Int64 read GetDataSize write SetDataSize;
  end;

procedure TBytesStreamHelper.CopyFromSelf(AStream: TStream; const ADataSize: Int64);
begin
{$IFDEF DEBUG}
  Assert(Size > 0);
  Assert(AStream <> nil);
{$ENDIF}
  AStream.CopyFrom(Self, ADataSize);
end;

procedure TBytesStreamHelper.CopyToSelf(AStream: TStream; const ADataSize: Int64);
begin
{$IFDEF DEBUG}
  Assert(Size > 0);
  Assert(AStream <> nil);
{$ENDIF}
  CopyFrom(AStream, ADataSize);
  Position := 0;
end;

function TBytesStreamHelper.GetDataSize: Int64;
begin
{$IFDEF DEBUG}
  Assert(Size > 0);
{$ENDIF}
  Position := 0;
  Read(Result, SizeOf(Int64));
end;

procedure TBytesStreamHelper.SetDataSize(ADataSize: Int64);
begin
  Size := 0;
  Write(ADataSize, SizeOf(Int64))
end;
{$ENDREGION}
{$REGION 'TFile'}

procedure TFile.Clear;
begin
  FFileInfo.FileName := '';
  FFileInfo.FileSize := 0;
  FBuffer.Size := 0;
  FreeAndNil(FFileStream);
end;

constructor TFile.Create(const AFileMapping: IFileMapping; const AMaxBufferSize: Int64);
begin
  FBuffer        := TBytesStream.Create;
  FFileMapping   := AFileMapping;
  FMaxBufferSize := AMaxBufferSize;
end;

destructor TFile.Destroy;
begin
  FreeAndNil(FBuffer);
  FreeAndNil(FFileStream);
  inherited;
end;

function TFile.GetFileName: String;
begin
  Result := FFileInfo.FileName;
end;

function TFile.ReadFile: Boolean;
begin

{$IFDEF DEBUG}
  Assert(FBuffer <> nil);
  Assert(FFileMapping <> nil);
  Assert(FFileMapping.MapView <> nil);
{$ENDIF}
  FBuffer.Position := 0;
  FBuffer.WriteBuffer(FFileMapping.MapView, BUFFER_SIZE);
  FBuffer.Position := 0;

  Result := True;
end;

function TFile.WriteFile: Boolean;
begin
{$IFDEF DEBUG}
  Assert(FBuffer <> nil);
  Assert(FFileMapping <> nil);
  Assert(FFileMapping.MapView <> nil);
{$ENDIF}
  // Запись в отображаемый файл
  FBuffer.Position := 0;
  FBuffer.Read(FFileMapping.MapView^, BUFFER_SIZE);
  FBuffer.Position := 0;
  Result := True;
end;

{$ENDREGION 'TFile'}
{$REGION 'TWriter'}

procedure TWriter.Clear;
begin
  inherited;
  FPosition := 0;
end;

function TWriter.GetCurrentPage: Int64;
begin
  Result := FPosition;
end;

function TWriter.GetCurrentPartSize: Int64;
var
  Min1, Min2: Int64;
begin
{$IFDEF DEBUG}
  Assert(FFileStream <> nil);
{$ENDIF}
  // Поиск минимального размера отправки данных
  Min1   := FMaxBufferSize - SizeOf(Int64);
  Min2   := FFileStream.Size - FPosition;
  Result := Min(Min1, Min2);
end;

function TWriter.GetSize: Int64;
begin
  Result := FFileStream.Size;
end;

function TWriter.WriteFile: Boolean;
var
  DataSize: Int64;
begin
{$IFDEF DEBUG}
  Assert(FBuffer <> nil);
  Assert(FFileStream <> nil);
{$ENDIF}
  try
   {$IFDEF DEBUG}
   Log.LogStatus(Format('Текущая позиция в потоке (%d)', [FPosition]), 'TWriter.WriteFile');
   {$ENDIF}

    DataSize         := GetCurrentPartSize;
    if DataSize = 0 then
      Exit(False);

   {$IFDEF DEBUG}
   Log.LogStatus(Format('Размер передаваемого дампа (%d)', [DataSize]), 'TWriter.WriteFile');
   {$ENDIF}

    FBuffer.DataSize := DataSize;


    // Запись данных из файлового потока
    FBuffer.CopyToSelf(FFileStream, DataSize);
   {$IFDEF DEBUG}
   Log.LogStatus(Format('Реальный размер передаваемого дампа (%d)', [FBuffer.Size]), 'TWriter.WriteFile');
   {$ENDIF}

    Result := inherited;
    // Инкрементируем указатель
    Inc(FPosition, DataSize);
   {$IFDEF DEBUG}
   Log.LogStatus(Format('Текущая позиция в файловом потоке (%d) из %d', [FFileStream.Position, FFileStream.Size]), 'TWriter.WriteFile');
    {$ENDIF}

  except
    on E: Exception do
      raise EFile.CreateFmt('[%s]: %s', [ClassName, 'Ошибка записи в отображаемый файл']);
  end;
end;

function TWriter.WriteFileInfo: Boolean;
begin
{$IFDEF DEBUG}
  Assert(FBuffer <> nil);
{$ENDIF}
  try
    TFileInfo.Serialize(FBuffer, FFileInfo);
    Result := inherited WriteFile;
  except
    on E: Exception do
      raise EFile.CreateFmt('[%s]: %s', [ClassName, 'Ошибка записи в отображаемый файл']);
  end;
end;

procedure TWriter.SetFileName(const AFileName: String);
begin
  if not FileExists(AFileName) then
    raise EFile.CreateFmt('[%s]: %s', [ClassName, 'Файл не наден']);
  Clear;
  // Создать файловый поток
  FFileStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  // Заполнить структуру
  FFileInfo := TFileInfo.Create(AFileName, FFileStream.Size);
end;

{$ENDREGION 'TWriter'}
{$REGION 'TReader'}

procedure TReader.Clear;
begin
  inherited;
  if FileExists(FDirectory + TMP_FILE) then
    DeleteFile(FDirectory + TMP_FILE);
end;

procedure TReader.CreateTempFile;
var
  TempFile: TextFile;
begin
  AssignFile(TempFile, FDirectory + TMP_FILE);
  try
    Rewrite(TempFile);
  finally
    Close(TempFile);
  end;

end;

function TReader.GetCurrentPage: Int64;
begin
  Result := FFileStream.Size;
end;

function TReader.GetSize: Int64;
begin
  Result := FFileInfo.FileSize;
end;

function TReader.IsEmplty: Boolean;
begin
  Result := (FFileInfo.FileSize = 0) or (FFileInfo.FileName = '');
end;

function TReader.ReadFile: Boolean;
var
  DataSize: Int64;
begin
{$IFDEF DEBUG}
  Assert(FBuffer <> nil);
  Assert(FFileStream <> nil);
{$ENDIF}
  try
    FBuffer.Size := 0;
    Result       := inherited;
    if Result then
    begin
      DataSize := FBuffer.DataSize;
      FBuffer.CopyFromSelf(FFileStream, DataSize);
      Result := True;
    end;

    if FFileStream.Size >= FFileInfo.FileSize then
    begin
      {$IFDEF DEBUG}
      Log.LogStatus(Format('TMP_FILE (%s) NEW_FILE (%s)', [FDirectory + TMP_FILE, FDirectory, FDirectory + ExtractFileName(FFileInfo.FileName)]), 'TReader.ReadFile');
      {$ENDIF}
      FreeAndNil(FFileStream);
      if not RenameFile(FDirectory + TMP_FILE, FDirectory + ExtractFileName(FFileInfo.FileName)) then
      {$IFDEF DEBUG}
      Log.LogStatus(Format('Ошибка сохранения файла (%s)', [FDirectory + ExtractFileName(FFileInfo.FileName)]), 'TReader.ReadFile');
      if FileExists(FDirectory + ExtractFileName(FFileInfo.FileName)) then
        Log.LogStatus(Format('Фйл ''%s'' уже существует)', [FDirectory + ExtractFileName(FFileInfo.FileName)]), 'TReader.ReadFile');
      {$ENDIF}

      Clear;
      Result := False;
    end;

  except
    on E: Exception do
    begin
      raise EFile.CreateFmt('[%s]: %s', [ClassName, 'Ошибка чтения из отображаемого файла']);
    end;
  end;
end;

function TReader.ReadFileInfo: Boolean;
begin
{$IFDEF DEBUG}
  Assert(FBuffer <> nil);
{$ENDIF}
  try
    Clear;
    Result := inherited ReadFile;
    if Result then
    begin
      // Получение информации о передаваемом файле
      TFileInfo.Deserialize(FBuffer, FFileInfo);
      // Создание временного файла
      CreateTempFile;
      // Создание файлового потока
      FFileStream := TFileStream.Create(FDirectory + TMP_FILE, fmCreate or fmShareDenyNone);
      Result      := True;
    end;
  except
    on E: Exception do
    begin
      raise EFile.CreateFmt('[%s]: %s', [ClassName, 'Ошибка чтения из отображаемого файла']);
    end;
  end;
end;

{$ENDREGION 'TReader'}

end.
