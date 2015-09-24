program Client;

uses
  Vcl.Forms,
  uClientForm in 'uClientForm.pas' {ClientForm},
  {$IFDEF DEBUG}
  uSimpleLogger in '..\Common\uSimpleLogger.pas',
  {$ENDIF}
  uTransferredFile in 'uTransferredFile.pas',
  uSharedName_TLB in '..\Common\uSharedName_TLB.pas',
  uFileMapping in '..\Common\uFileMapping.pas',
  uProtocol in '..\Common\uProtocol.pas',
  uTransaction in '..\Common\uTransaction.pas';

{$R *.res}

begin
  Application.Initialize;
{$REGION 'Debug'}
{$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
{$ENDIF}
{$ENDREGION}
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TClientForm, ClientForm);
  Application.Run;

end.
