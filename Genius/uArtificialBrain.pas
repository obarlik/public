unit uArtificialBrain;

interface

uses Windows, System.Contnrs, System.Generics.Collections, System.SysUtils,
     System.Classes;

type
  TNeuron = class;

  TSynapse = class
    constructor Create(_neuronA, _neuronB: TNeuron);
  public
    NeuronA, NeuronB: TNeuron;
    Weight: single;

    procedure Transfer(Src: TNeuron; Pain: Boolean);
    procedure Learn(v: Integer);
  end;

  TBrain = class;

  TNeuron = class
    constructor Create(_brain: TBrain);
  public
    Brain: TBrain;
    Synapses: array [0 .. 3] of TSynapse;
    Value: single;
    LastImpulse: Int32;
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

  TBrainClock = class
  private
    FTicks: Int32;
    function GetTicks: Int32;
  public
    property Ticks:Int32 read GetTicks;
  end;

  TBrain = class
    constructor Create;
    destructor Destroy; override;

  private
    FiredNeurons: TThreadedQueue<TFiredNeuron>;
    FBrainClock: TBrainClock;
    FStopping: Boolean;
    FProcessThreadCount: Integer;

    function GetTicks: Int32;

  public
    procedure NeuronFired(Neuron: TNeuron; Pain: Boolean);
    procedure Process;
    procedure StopProcessing;

    property Ticks: Int32 read GetTicks;
    property Stopping: Boolean read FStopping;
  end;

implementation

uses System.Math;

{ TSynapse }

constructor TSynapse.Create(_neuronA, _neuronB: TNeuron);
begin
  inherited Create;
  NeuronA := _neuronA;
  NeuronB := _neuronB;
  Weight := 0.1;
end;

procedure TSynapse.Learn(v: Integer);
begin
  TMonitor.Enter(Self);
  try
    if v > 0 then
      Weight := Weight + (1 - Weight) * 0.0001
    else if v < 0 then
      Weight := Weight * 0.9999;
  finally
    TMonitor.Exit(Self);
  end;
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
      Synapses[i] := TSynapse.Create(Self, Dst);
      Dst.Contact(Self);
      Result := True;
      Exit;
    end;

    with s do
    if ((NeuronA = Dst) or (NeuronB = Dst)) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

constructor TNeuron.Create(_brain: TBrain);
begin
  inherited Create;
  Brain := _brain;
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
  t: Int32;
begin
  TMonitor.Enter(Self);
  try
    t := LastImpulse;
    LastImpulse := Brain.Ticks;
    t := Abs(LastImpulse - t);

    Value := Value * Power(0.5, t);

    if Firing then
    begin
      Firing := Abs(Value) >= 0.05;
      if Firing then
        synapse.Learn(Sign(Value) * Sign(s))
      else
        Value := 0;
    end;

    if not Firing then
    begin
      Value := Value + s;
      if Abs(Value) > 0.25 then
      begin
        if Value > 0 then
          Value := 1
        else
          Value := -1;
        Firing := True;
        Brain.NeuronFired(Self, Value > 0);
      end;
    end;

  finally
    TMonitor.Exit(Self);
  end;
end;

{ TBrain }

constructor TBrain.Create;
begin
  inherited Create;
  FBrainClock := TBrainClock.Create;
end;

destructor TBrain.Destroy;
begin
  StopProcessing;
  inherited;
end;

function TBrain.GetTicks: Int32;
begin
  Result := FBrainClock.Ticks;
end;

procedure TBrain.NeuronFired(Neuron: TNeuron; Pain: Boolean);
begin
  FiredNeurons.PushItem(TFiredNeuron.Create(Neuron, Pain));
end;

procedure TBrain.Process;
var
  i: Integer;
begin
  FProcessThreadCount := 0;

  for i := 0 to 2 do
  begin
    TThread.CreateAnonymousThread(
      procedure()
      var
        f: TFiredNeuron;
      begin
        AtomicIncrement(Self.FProcessThreadCount);

        while not Self.Stopping do
        begin
          while Self.FiredNeurons.QueueSize>0 do
          begin
            f := Self.FiredNeurons.PopItem;
            f.Neuron.Fire(f.Pain);
          end;
          Sleep(100);
        end;

        AtomicDecrement(Self.FProcessThreadCount);
      end
    ).Resume;
  end;
end;

procedure TBrain.StopProcessing;
begin
  FStopping := True;
  while FProcessThreadCount>0 do
    Sleep(100);
end;

{ TFiredNeuron }

constructor TFiredNeuron.Create(_neuron: TNeuron; _pain: Boolean);
begin
  Neuron := _neuron;
  Pain := _pain;
end;


{ TBrainClock }

function TBrainClock.GetTicks: Int32;
begin
  Result := AtomicIncrement(FTicks);
end;

end.
