program GeniusPrj;

uses
  Vcl.Forms,
  uMain in 'uMain.pas' {frmMain},
  uArtificialBrain in 'uArtificialBrain.pas',
  uMatrix in 'uMatrix.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
