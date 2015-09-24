unit uSharedNameCreator;

{$WARN SYMBOL_PLATFORM OFF}

interface

{$REGION 'uses'}

uses
  Windows,
  ActiveX,
  Classes,
  SysUtils,
  ComObj,
  StdVcl,
  uSharedName_TLB;

{$ENDREGION}

type
  {$REGION 'summary'}
  /// <summary>
  /// ���������� ���������� ��� Named Shared Memory.
  /// ��� �������� ���������� ������ ������������ GUID,
  /// �������� �������� ������������ � ������� GetSharedMemoryName
  /// </summary>
  {$ENDREGION}
  TSharedNameCreator = class(TTypedComObject, ISharedNameCreator)
  private
    FName: WideString;
  protected
    function GetSharedMemoryName: WideString; safecall;
  public
    procedure AfterConstruction; override;
    destructor Destroy; override;
  end;

implementation

{$REGION 'uses'}

uses
  ComServ;
{$ENDREGION}
{$REGION 'TSingletonTypedComObjectFactory'}

type
{$REGION 'summary'}
  /// <summary>
  /// �����, �������������� �� TTypedComObjectFactory
  /// ���������� ��� Singletone
  /// C������� ��������� ������ �� ������������ ��������� Com-�������
  /// </summary>
{$ENDREGION}
  TSingletonTypedComObjectFactory = class(TTypedComObjectFactory)
  private
    class var Instance: TComObject;
  public
    function CreateComObject(const Controller: IUnknown): TComObject; override;
  end;

function TSingletonTypedComObjectFactory.CreateComObject(const Controller: IUnknown): TComObject;
begin
  if Instance = nil then
  begin
    Instance := TSharedNameCreator.CreateFromFactory(Self, Controller);
  end;
  Result := Instance;
end;
{$ENDREGION}
{$REGION 'NameCreator'}

procedure TSharedNameCreator.AfterConstruction;
var
  GUID     : TGUID;
  StartChar: Integer;
  EndChar  : Integer;
  Count    : Integer;

begin
  inherited;
  // ��������� ����������� ����� ��� �������� �������
  CreateGUID(GUID);
  FName := GUIDToString(GUID);
  // ��������� ������ ���������� ��������
  StartChar := Pos('{', FName) + 1;
  EndChar   := Pos('}', FName) - 1;
  Count     := EndChar - StartChar + 1;
  FName     := Copy(FName, StartChar, Count);
end;

destructor TSharedNameCreator.Destroy;
begin
  TSingletonTypedComObjectFactory.Instance := nil;
  inherited;
end;

function TSharedNameCreator.GetSharedMemoryName: WideString;
begin
  Result := FName;
end;

{$ENDREGION}

initialization

begin
  ComServer.UIInteractive := False;

  TSingletonTypedComObjectFactory.Create(ComServer, // ComServer ����������� ������� ComServ
    TSharedNameCreator,                             // ����� Com-�������
    CLASS_SharedNameCreator,                        // �������������
    ciMultiInstance,                                // ������� ������ �������� ���� ��������.
    tmApartment);                                   // ����� ������, ����� Free
end;

end.
