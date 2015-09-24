unit uSimpleLogger;

interface

{$REGION 'Описание модуля'}
(*
  *  Логгер для отладки
*)
{$ENDREGION}

uses
  Classes,
  SysUtils;

type
  TSimpleLogger = class
  private
    FFileHandle     : TextFile;
    FApplicationName: string;
    FApplicationPath: string;
  protected

  public
    constructor Create;
    destructor Destroy; override;
    function GetApplicationName: string;
    function GetApplicationPath: string;
    procedure LogError(ErrorMessage: string; Location: string);
    procedure LogWarning(WarningMessage: string; Location: string);
    procedure LogStatus(StatusMessage: string; Location: string);
    property ApplicationName: string read GetApplicationName;
    property ApplicationPath: string read GetApplicationPath;
  end;

var
  Log: TSimpleLogger;

implementation

{ TLogger }
constructor TSimpleLogger.Create;
var
  FileName: string;
begin
  FApplicationName := ExtractFileName(ParamStr(0));
  FApplicationPath := ExtractFilePath(ParamStr(0));
  FileName         := FApplicationPath + ChangeFileExt(FApplicationName, '.log');
  AssignFile(FFileHandle, FileName);
  ReWrite(FFileHandle);
end;

destructor TSimpleLogger.Destroy;
begin
  CloseFile(FFileHandle);
  inherited;
end;

function TSimpleLogger.GetApplicationName: string;
begin
  result := FApplicationName;
end;

function TSimpleLogger.GetApplicationPath: string;
begin
  result := FApplicationPath;
end;

procedure TSimpleLogger.LogError(ErrorMessage, Location: string);
var
  S: string;
begin
  S := '*** ERROR *** : @ ' + TimeToStr(Time) + ' MSG : ' + ErrorMessage + ' IN : ' + Location + #13#10;
  WriteLn(FFileHandle, S);
  Flush(FFileHandle);
end;

procedure TSimpleLogger.LogStatus(StatusMessage, Location: string);
var
  S: string;
begin
  S := 'STATUS INFO : @ ' + TimeToStr(Time) + ' MSG : ' + StatusMessage + ' IN : ' + Location + #13#10;
  WriteLn(FFileHandle, S);
  Flush(FFileHandle);
end;

procedure TSimpleLogger.LogWarning(WarningMessage, Location: string);
var
  S: string;
begin
  S := '=== WARNING === : @ ' + TimeToStr(Time) + ' MSG : ' + WarningMessage + ' IN : ' + Location + #13#10;
  WriteLn(FFileHandle, S);
  Flush(FFileHandle);
end;

initialization

begin
  Log := TSimpleLogger.Create;
  Log.LogStatus('Starting Application', 'Initialization');
end;

finalization

begin
  Log.LogStatus('Terminating Application', 'Finalization');
  FreeAndNil(Log);
end;

end.
