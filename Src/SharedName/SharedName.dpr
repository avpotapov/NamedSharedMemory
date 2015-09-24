program SharedName;

uses
  Vcl.Forms,
  uSharedNameForm in 'uSharedNameForm.pas' {NameSharedMemoryForm},
  uSharedNameCreator in 'uSharedNameCreator.pas' {NameSharedMemoryCreator: CoClass},
  uSharedName_TLB in '..\Common\uSharedName_TLB.pas';

{$R *.TLB}

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TNameSharedMemoryForm, NameSharedMemoryForm);
  Application.Run;
end.
