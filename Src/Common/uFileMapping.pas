
unit uFileMapping;

interface

{$REGION '�������� ������'}
(*
  *  ������ ����������� �������� - ��������� ��� Winapi-���������
  *  ��� ��������, ��������, � �������� ����������� �������.
  *
  *  ������� ������� ������� ������ ���� ��� �������, ���� ��� �������
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
  // �� ������� ������ shared memory �������� 256Kb,
  BUFFER_SIZE = $40000; // 256 * 1024 == 0x100 * 0x400

type
  EFileMapping = class(Exception);

{$REGION 'TFileMapping - ������� ��� FileMapping'}

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
    // ������� ����� ������� ������ �� �������
    constructor Create;
  public
    destructor Destroy; override;
  end;

{$ENDREGION}
{$REGION 'TFileMappingFactory - ������� TFileMapping'}

  TFileMappingFactory = class
  public
    class function GetServer(const AMapFileName: WideString; const ABufferSize: DWord = BUFFER_SIZE): IFileMapping;
    class function GetClient(const AMapFileName: WideString): IFileMapping;
  end;
{$ENDREGION}

implementation


{$REGION 'TFileMapping - ������� ��� FileMapping'}

constructor TFileMapping.Create;
begin
  inherited;
end;

destructor TFileMapping.Destroy;
begin
  // �������� FileMapping �� ��������� ������������
  UnMapViewOfFile(FMapView);
  // ��������� ������ FileMapping
  CloseHandle(FFileMapping);
  // ������ ����� ����� �������
  inherited;
end;

procedure TFileMapping.CreateMapFile(const AMapFileName: WideString; const ABufferSize: DWord);
begin

  // C������ ������ �����, ������������� � ������
  FFileMapping := CreateFileMapping(INVALID_HANDLE_VALUE, // ���������� �����
    nil,                                                  // �������� ������
    PAGE_READWRITE,                                       // ����� ������� � �����
    0,                                                    // ������� ������� ����� ������� �������
    ABufferSize,                                          // ������� ������� ����� ������� �������
    PChar(AMapFileName));                                 // ��� ������� �����������

  if (FFileMapping = 0) then
  begin
    raise EFileMapping.Create(SysErrorMessage(GetLastError));
  end;

end;

procedure TFileMapping.CreateMapView(const ADesiredAccess: Cardinal);
begin
  if FFileMapping = 0 then
  begin
    raise EFileMapping.Create('�� ������ ������ ��������� �����������');
  end;

  // ���������� ���� � ��������� ������������ � �������� ��������� ����� ������
  FMapView := MapViewOfFile(FFileMapping, // ���������� �������, ������������� ����
    Ord(ADesiredAccess),                  // ����� �������
    0,                                    // ������� ������� ����� ��������
    0,                                    // ������� ������� ����� ��������
    0);                                   // ���������� ������������ ����, ���� 0, �� ����� ������ ���� ����.

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
  // ������� FileMapping
  FFileMapping := OpenFileMapping(FILE_MAP_WRITE, // ����������� ��� ������
    False, PChar(AMapFileName));                  // ����������� �������

  if (FFileMapping = 0) then
  begin
    raise EFileMapping.Create(SysErrorMessage(GetLastError));
  end;
end;
{$ENDREGION}
{$REGION 'TFileMappingFactory - ������� TFileMapping'}

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
