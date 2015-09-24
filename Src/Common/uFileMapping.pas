
unit uFileMapping;

interface

{$REGION 'Описание модуля'}
(*
  *  Модуль представлен классами - обертками над Winapi-функциями
  *  для создания, открытия, и закрытия разделяемой области.
  *
  *  Фабрика создает область памяти либо для клиента, либо для сервера
  *
  *  https://msdn.microsoft.com/ru-ru/library/windows/desktop/aa366551(v=vs.85).aspx
*)
{$ENDREGION}
{$REGION 'uses'}

uses
  Winapi.Windows,
  System.Classes,
  System.SysUtils;

{$ENDREGION}

const
  // По условию объект shared memory размером 256Kb,
  BUFFER_SIZE = $40000; // 256 * 1024 == 0x100 * 0x400

type
  EFileMapping = class(Exception);

{$REGION 'TFileMapping - обертка для FileMapping'}

  IFileMapping = interface
    ['{F5F006B2-13B0-44EC-BE59-BE8A0131370A}']
    function GetMapView: Pointer;
    property MapView: Pointer read GetMapView;
  end;

  TFileMapping = class(TInterfacedObject, IFileMapping)
  private
    FFileMapping: THandle;
    FMapView    : Pointer;
  private
    procedure CreateMapFile(const AMapFileName: WideString; const ABufferSize: DWord);
    procedure OpenMapFile(const AMapFileName: WideString);
    procedure CreateMapView(const ADesiredAccess: Cardinal);
    function GetMapView: Pointer;
    // Объекта можно создать только из фабрики
    constructor Create;
  public
    destructor Destroy; override;
  end;

{$ENDREGION}
{$REGION 'TFileMappingFactory - фабрика TFileMapping'}

  TFileMappingFactory = class
  public
    class function GetServer(const AMapFileName: WideString; const ABufferSize: DWord = BUFFER_SIZE): IFileMapping;
    class function GetClient(const AMapFileName: WideString): IFileMapping;
  end;
{$ENDREGION}

implementation


{$REGION 'TFileMapping - обертка для FileMapping'}

constructor TFileMapping.Create;
begin
  inherited;
end;

destructor TFileMapping.Destroy;
begin
  // Отключим FileMapping от адресного пространства
  UnMapViewOfFile(FMapView);
  // Освободим объект FileMapping
  CloseHandle(FFileMapping);
  // теперь форму можно закрыть
  inherited;
end;

procedure TFileMapping.CreateMapFile(const AMapFileName: WideString; const ABufferSize: DWord);
begin

  // Cоздаем объект файла, проецируемого в память
  FFileMapping := CreateFileMapping(INVALID_HANDLE_VALUE, // дескриптор файла
    nil,                                                  // атрибуты защиты
    PAGE_READWRITE,                                       // флаги доступа к файлу
    0,                                                    // старшее двойное слово размера объекта
    ABufferSize,                                          // младшее двойное слово размера объекта
    PChar(AMapFileName));                                 // имя объекта отображения

  if (FFileMapping = 0) then
  begin
    raise EFileMapping.Create(SysErrorMessage(GetLastError));
  end;

end;

procedure TFileMapping.CreateMapView(const ADesiredAccess: Cardinal);
begin
  if FFileMapping = 0 then
  begin
    raise EFileMapping.Create('Не создан объект файлового отображения');
  end;

  // Подключаем файл к адресному пространству и получаем начальный адрес данных
  FMapView := MapViewOfFile(FFileMapping, // дескриптор объекта, отображающего файл
    Ord(ADesiredAccess),                  // режим доступа
    0,                                    // старшее двойное слово смещения
    0,                                    // младшее двойное слово смещения
    0);                                   // количество отображаемых байт, если 0, то будет считан весь файл.

  if not Assigned(FMapView) then
  begin
    raise EFileMapping.Create(SysErrorMessage(GetLastError()));
  end;

end;

function TFileMapping.GetMapView: Pointer;
begin
  Result := FMapView;
end;

procedure TFileMapping.OpenMapFile(const AMapFileName: WideString);
begin
  // Откроем FileMapping
  FFileMapping := OpenFileMapping(FILE_MAP_WRITE, // открывается для записи
    False, PChar(AMapFileName));                  // именованная область

  if (FFileMapping = 0) then
  begin
    raise EFileMapping.Create(SysErrorMessage(GetLastError));
  end;
end;
{$ENDREGION}
{$REGION 'TFileMappingFactory - фабрика TFileMapping'}

class function TFileMappingFactory.GetClient(const AMapFileName: WideString): IFileMapping;
begin
  Result := TFileMapping.Create;
  try
    TFileMapping(Result).OpenMapFile(AMapFileName);
    TFileMapping(Result).CreateMapView(FILE_MAP_WRITE);
  except
    Result := nil;
  end;
end;

class function TFileMappingFactory.GetServer(const AMapFileName: WideString; const ABufferSize: DWord): IFileMapping;
begin
  Result := TFileMapping.Create;
  try
    TFileMapping(Result).CreateMapFile(AMapFileName, ABufferSize);
    TFileMapping(Result).CreateMapView(FILE_MAP_READ);
  except
    Result := nil;
  end;
end;
{$ENDREGION}

end.
