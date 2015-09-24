unit uSharedName_TLB;

{$TYPEDADDRESS OFF}
{$WARN SYMBOL_PLATFORM OFF}
{$WRITEABLECONST ON}
{$VARPROPSETTER ON}
{$ALIGN 4}

interface

uses Winapi.Windows, System.Classes, System.Variants, System.Win.StdVCL, Vcl.Graphics, Vcl.OleServer, Winapi.ActiveX;


const
  uSharedNameMajorVersion = 1;
  uSharedNameMinorVersion = 0;

  LIBID_uSharedName: TGUID = '{8457B35F-1E0C-469A-BB29-857D2C41897E}';

  IID_ISharedNameCreator: TGUID = '{1598A1F6-6294-4366-A6E9-E133031E159D}';
  CLASS_SharedNameCreator: TGUID = '{0EDE7542-A099-4845-A9D1-F0DC756F7574}';
type

  ISharedNameCreator = interface;

  SharedNameCreator = ISharedNameCreator;


  ISharedNameCreator = interface(IUnknown)
    ['{1598A1F6-6294-4366-A6E9-E133031E159D}']
    function GetSharedMemoryName: WideString; safecall;
  end;

  CoSharedNameCreator = class
    class function Create: ISharedNameCreator;
    class function CreateRemote(const MachineName: string): ISharedNameCreator;
  end;

implementation

uses System.Win.ComObj;

class function CoSharedNameCreator.Create: ISharedNameCreator;
begin
  Result := CreateComObject(CLASS_SharedNameCreator) as ISharedNameCreator;
end;

class function CoSharedNameCreator.CreateRemote(const MachineName: string): ISharedNameCreator;
begin
  Result := CreateRemoteComObject(MachineName, CLASS_SharedNameCreator) as ISharedNameCreator;
end;

end.

