program Server;

uses
  Vcl.Forms,
  uServerForm in 'uServerForm.pas' {ServerForm} ,
{$IFDEF DEBUG}
  uSimpleLogger in '..\Common\uSimpleLogger.pas',
{$ENDIF}
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
  Application.CreateForm(TServerForm, ServerForm);
  Application.Run;

end.
