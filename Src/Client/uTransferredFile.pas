
unit uTransferredFile;

interface
{$REGION 'Описание модуля'}
(*
  *  Имя файла должно настраиваться в опциях клиента (допустима настройка в INI файле)
  *  либо выбираться посредством диалога открытия файла
  *

*)
{$ENDREGION}
uses
  System.Classes,
  System.SysUtils,
  System.IniFiles,
  Vcl.Dialogs,
  Vcl.Forms;

const
  MIN_FILE_SIZE: Int64 = $100000; // 100 Mb
  MAX_FILE_SIZE: Int64 = $80000000; // 2 Gb


type
  ETransferredFileException = class(Exception);

  ITransferredFile = interface
    ['{2CDD1BC4-0CD8-492B-AE49-08DD899098E4}']
    function GetFileName: string;
    property FileName: string read GetFileName;
  end;

  IFileSaver = interface
    ['{A6C155F0-3C7D-4C66-A636-E652DF5E3315}']
    procedure SetFileName(const AFileName: string);
    property FileName: string write SetFileName;
  end;

  TAbstractTransferredFile = class abstract(TInterfacedObject, ITransferredFile)
  private
    procedure CheckFileSize(const AFileName: string);
  public
    function GetFileName: string; virtual; abstract;

  end;

  TIni = class(TAbstractTransferredFile, IFileSaver)
  private
    FInitialDirectory: string;
  public
    constructor Create(const AInitialDirectory: string); reintroduce;
  public
    function GetFileName: string; override;
    procedure SetFileName(const AFileName: string);
  end;

  TDialog = class(TAbstractTransferredFile)
  public
    function GetFileName: string; override;
  end;

implementation

{ TAbstractTransferredFile }

procedure TAbstractTransferredFile.CheckFileSize(const AFileName: string);
var
  FileStream: TFileStream;
begin
  FileStream := TFileStream.Create(AFileName, fmOpenRead);
  try
    if (FileStream.Size < MIN_FILE_SIZE) or
       (FileStream.Size > MAX_FILE_SIZE)  then
      raise ETransferredFileException.Create(Format('File size is not in range 100 Mb - 2Gb ''%d''', [FileStream.Size]));
  finally
    FileStream.Free;
  end;
end;

{ TIni }

constructor TIni.Create(const AInitialDirectory: string);
begin
  FInitialDirectory := AInitialDirectory;
end;

function TIni.GetFileName: string;
var
  IniFile: TIniFile;
begin
  Result := '';
  if not DirectoryExists(FInitialDirectory) then
    raise ETransferredFileException.Create(Format('Directory ''%s'' not found', [FInitialDirectory]));

  IniFile := TIniFile.Create(FInitialDirectory + 'Client.ini');
  try
    Result := IniFile.ReadString('Client', 'FileName', '');
    if not FileExists(Result) then
    begin
      Result := '';
      raise ETransferredFileException.Create(Format('File ''%s'' not found', [Result]));
    end;
   CheckFileSize(Result);
  finally
    FreeAndNil(IniFile);
  end;
end;

procedure TIni.SetFileName(const AFileName: string);
var
  IniFile: TIniFile;
begin
  if not DirectoryExists(FInitialDirectory) then
    raise ETransferredFileException.Create(Format('Directory ''%s'' not found', [FInitialDirectory]));
  CheckFileSize(AFileName);
  IniFile := TIniFile.Create(IncludeTrailingPathDelimiter(FInitialDirectory) + 'Client.ini');
  try
    IniFile.WriteString('Client', 'FileName', AFileName);
  finally
    FreeAndNil(IniFile);
  end;
end;

{ TDialog }

function TDialog.GetFileName: string;
var
  OpenDialog: TOpenDialog;
begin
  Result     := '';
  OpenDialog := TOpenDialog.Create(Application);
  try
    OpenDialog.InitialDir := GetCurrentDir;
    if OpenDialog.Execute then
    begin
      Result := OpenDialog.FileName;
      CheckFileSize(Result);
    end;
  finally
    OpenDialog.Free;
  end;
end;

end.
