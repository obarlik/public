unit uArtificialBrain;

interface

uses Contnrs, System.Generics.Collections;

type
  TNeuron = class;

  TSynapse = class
    NeuronA, NeuronB: TNeuron;
    Weight: single;

    procedure Fired(Src:TNeuron; Pain:Boolean);
  end;

  TBrain = class;

  TNeuron = class
    Brain: TBrain;
    Synapses: array[0..3]of TSynapse;

    function Contact(Dst:TNeuron):Boolean;
    procedure Signal(value:Single);
  end;

  TSignal = class

  end;

  TBrain = class
    Signals: TThreadedQueue<TSignal>;

  end;

implementation

{ TSynapse }

procedure TSynapse.Fired(Src: TNeuron; Pain:Boolean);
var
  Dst: TNeuron;
  s: Single;
begin
  if Src=NeuronA then
    Dst := NeuronB
  else
    Dst := NeuronA;

  if Pain then
    s := -Weight
  else
    s := Weight;

  Dst.Signal(s);
end;

{ TNeuron }

function TNeuron.Contact(Dst: TNeuron):Boolean;
var
  i: Integer;
  s: TSynapse;
begin
  Result := False;
  for i := 0 to 3 do
  begin
    s := Synapses[i];

    if not Assigned(s) then
    begin
      s := TSynapse.Create;
      try
        s.NeuronA := Self;
        s.NeuronB := Dst;
        Synapses[i] := s;
        Result := True;
      except
        s.Free;
        raise;
      end;
    end
    else
    if ((s.NeuronA = Dst)
     or (s.NeuronB = Dst)) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

procedure TNeuron.Signal(value: Single);
var
  s: TSignal;
begin
  s := TSignal.Create;
  //s.

  //Brain.Signals.PushItem(
end;

end.
