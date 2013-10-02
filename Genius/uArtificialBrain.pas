unit uArtificialBrain;

interface

uses Contnrs, System.Generics.Collections, System.SysUtils;

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
    Synapses: TArray<TSynapse>;
    Value: Single;
    LastImpulse: TDateTime;
    Firing: Boolean;

    function Contact(Dst:TNeuron):Boolean;
    procedure Signal(s:Single);
  end;

  TFiredNeuron = record
    Neuron: TNeuron;
    Pain: Boolean;
  end;

  TBrain = class
    FiredNeurons: TThreadedQueue<TFiredNeuron>;

  end;

implementation

uses System.Math;

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

  for s in Synapses do
  begin
    if ((s.NeuronA = Dst)
     or (s.NeuronB = Dst)) then
    begin
      Result := True;
      Exit;
    end;
  end;

  i := Length(Synapses);
  if i>=4 then
    Exit;

  s := TSynapse.Create;
  try
    s.NeuronA := Self;
    s.NeuronB := Dst;
    SetLength(Synapses, i+1);
    Synapses[i] := s;
    Result := True;
  except
    s.Free;
    raise;
  end;
end;

procedure TNeuron.Signal(s: Single);
var
  t : TDateTime;
begin
  t := LastImpulse;
  LastImpulse := Now;
  t := Trunc((LastImpulse - t)*24*3600*1000);

  Value := Value * Power(0.5, t);

  if Firing then
  begin
    Firing := Abs(Value)>=0.05;
    if not Firing then
      Value := 0;
  end;

  if not Firing then
  begin
    Value := Value + s;
    if Abs(Value)>0.25 then
    begin
      Value := 1;
      Firing := True;
      Brain.NeuronFired(Self, Value>0);
    end;
  end;
end;

end.
