program GeniusPrj;

uses
  Vcl.Forms,
  uMain in 'uMain.pas' {frmMain},
  uArtificialBrain in 'uArtificialBrain.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  AApplication.CreateForm(TfrmMain, frmMain);
  pplication.Run;
end.
