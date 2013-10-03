unit uArtificialBrain;

interface

uses Contnrs, System.Generics.Collections, System.SysUtils;

type
  TNeuron = class;

  TSynapse = class
    NeuronA, NeuronB: TNeuron;
    Weight: single;

    procedure Transfer(Src: TNeuron; Pain: Boolean);
    procedure Learn(v:Integer);
  end;

  TBrain = class;

  TNeuron = class
    Brain: TBrain;
    Synapses: array [0 .. 3] of TSynapse;
    Value: single;
    LastImpulse: TDateTime;
    Firing: Boolean;

    function Contact(Dst: TNeuron): Boolean;
    procedure Signal(synapse: TSynapse; s: single);
    procedure Fire(Pain: Boolean);
  end;

  TFiredNeuron = record
    Neuron: TNeuron;
    Pain: Boolean;

    constructor Create(_neuron: TNeuron; _pain: Boolean);
  end;

  TBrain = class
    FiredNeurons: TThreadedQueue<TFiredNeuron>;

    procedure NeuronFired(Neuron: TNeuron; Pain: Boolean);
  end;

implementation

uses System.Math;

{ TSynapse }

procedure TSynapse.Learn(v: Integer);
begin
  if v>0 then
    Weight := Weight + (1-Weight)*0.0001
  else
  if v<0 then
    Weight := Weight * 0.9999;
end;

procedure TSynapse.Transfer(Src: TNeuron; Pain: Boolean);
var
  Dst: TNeuron;
  s: single;
begin
  if Src = NeuronA then
    Dst := NeuronB
  else
    Dst := NeuronA;

  if Pain then
    s := -Weight
  else
    s := Weight;

  Dst.Signal(Self, s);
end;

{ TNeuron }

function TNeuron.Contact(Dst: TNeuron): Boolean;
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
        Dst.Contact(Self);
        Exit;
      except
        s.Free;
        raise;
      end;
    end;

    if ((s.NeuronA = Dst) or (s.NeuronB = Dst)) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

procedure TNeuron.Fire(Pain: Boolean);
var
  i: Integer;
  s: TSynapse;
begin
  for i := 0 to 3 do
  begin
    s := Synapses[i];
    if not Assigned(s) then
      Exit;

    s.Transfer(Self, Pain);
  end;
end;

procedure TNeuron.Signal(synapse: TSynapse; s: single);
var
  t: TDateTime;
begin
  t := LastImpulse;
  LastImpulse := Now;
  t := Trunc((LastImpulse - t) * 24 * 3600 * 1000);

  Value := Value * Power(0.5, t);

  if Firing then
  begin
    Firing := Abs(Value) >= 0.05;
    if not Firing then
      Value := 0;
  end;

  if not Firing then
  begin
    Value := Value + s;
    if Abs(Value) > 0.25 then
    begin
      if Value>0 then
        Value := 1
      else
        Value := -1;
      Firing := True;
      Brain.NeuronFired(Self, Value > 0);
    end;
  end;

  if Firing then
    synapse.Learn(Sign(Value) * Sign(s))
end;

{ TBrain }

procedure TBrain.NeuronFired(Neuron: TNeuron; Pain: Boolean);
begin
  FiredNeurons.PushItem(TFiredNeuron.Create(Neuron, Pain));
end;

{ TFiredNeuron }

constructor TFiredNeuron.Create(_neuron: TNeuron; _pain: Boolean);
begin
  Neuron := _neuron;
  Pain := _pain;
end;

end.
