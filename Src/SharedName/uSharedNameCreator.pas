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
  /// Возвращает уникальное имя Named Shared Memory.
  /// При создании экземпляра класса генерируется GUID,
  /// значение которого возвращается в функции GetSharedMemoryName
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
  /// Класс, унаследованный от TTypedComObjectFactory
  /// Реализован как Singletone
  /// Cодержит классовую ссылку на единственный экземпляр Com-объекта
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
  // Генерация уникального имени при создании объекта
  CreateGUID(GUID);
  FName := GUIDToString(GUID);
  // Сохранить только уникальное значение
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

  TSingletonTypedComObjectFactory.Create(ComServer, // ComServer реализуется модулем ComServ
    TSharedNameCreator,                             // Класс Com-объекта
    CLASS_SharedNameCreator,                        // Идентификатор
    ciMultiInstance,                                // Фабрика класса доступна всем клиентам.
    tmApartment);                                   // Любой варант, кроме Free
end;

end.
