unit uSharedNameForm;

interface

{$REGION 'uses'}

uses
  Winapi.Windows,
  Winapi.Messages,

  System.SysUtils,
  System.Variants,
  System.Classes,

  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls;
{$ENDREGION}

type
  TNameSharedMemoryForm = class(TForm)
    procedure FormCreate(Sender: TObject);
  end;
var
  NameSharedMemoryForm: TNameSharedMemoryForm;

implementation

{$R *.dfm}

procedure TNameSharedMemoryForm.FormCreate(Sender: TObject);
begin
  Left := Screen.Width;
end;

end.
