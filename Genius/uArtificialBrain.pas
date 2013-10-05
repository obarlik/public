unit uArtificialBrain;

interface

uses Windows, System.Contnrs, System.Generics.Collections, System.SysUtils,
     System.Classes, System.SyncObjs;

type
  TNeuron = class;

  TSynapse = class
    constructor Create(_neuronA, _neuronB: TNeuron);
    destructor Destroy;override;
  public
    NeuronA, NeuronB: TNeuron;
    Weight: single;

    procedure Transfer(Src: TNeuron; Pain: Boolean);
    procedure Learn(v: Integer);
    procedure Attach(_neuronA, _neuronB: TNeuron);
    procedure Detach;
  end;

  TBrain = class;

  TNeuron = class
    constructor Create(_brain: TBrain);
    destructor Destroy; override;
  public
    Brain: TBrain;
    Synapses: array [0 .. 3] of TSynapse;
    Value: single;
    LastImpulse: Int32;
    Firing: Boolean;

    function Contact(Dst: TNeuron): Boolean;
    function IsContacted(Dst: TNeuron):Boolean;
    procedure Signal(synapse: TSynapse; s: single);
    procedure Fire(Pain: Boolean);
    procedure ClearSynapses;
  end;

  TFiredNeuron = record
    Neuron: TNeuron;
    Pain: Boolean;

    constructor Create(_neuron: TNeuron; _pain: Boolean);
  end;

  TBrain = class
    constructor Create;
    destructor Destroy; override;

  private
    FireLock: TObject;
    ProcessLock: TObject;
    FiredNeurons: TQueue<TFiredNeuron>;
    FNeurons: TObjectList<TNeuron>;
    FTicks: Integer;
    FStopping: Boolean;
    FProcessThreadCount: Integer;
    FMeshSize: TSize;

    function GetTicks: Integer;
    function GetNeuron(x, y: Integer): TNeuron;
  public
    procedure PushFiredNeuron(Neuron: TNeuron; Pain: Boolean);
    function PopFiredNeuron(var fn:TFiredNeuron):Boolean;
    procedure StartProcessing;
    procedure StopProcessing;
    procedure BuildNetwork(m, n: integer);

    property Ticks: Integer read GetTicks;
    property Stopping: Boolean read FStopping;
    property Neuron[x, y: Integer]: TNeuron read GetNeuron;
    property MeshSize: TSize read FMeshSize;
  end;

implementation

uses System.Math;

{ TSynapse }

procedure TSynapse.Attach(_neuronA, _neuronB: TNeuron);
var
  i: Integer;
  sa, sb : boolean;
begin
  Detach;
  NeuronA := _neuronA;
  NeuronB := _neuronB;
  sa := false;
  sb := false;

  for i := 0 to 3 do
  begin
    if not (sa or (NeuronA.Synapses[i]<>Self)) then
      sa := True;

    if not (sb or (NeuronB.Synapses[i]<>Self)) then
      sb := True;

    if sa and sb then
      Exit;
  end;

  for i := 0 to 3 do
  begin
    if not (sa or Assigned(NeuronA.Synapses[i])) then
    begin
      NeuronA.Synapses[i] := Self;
      sa := True;
    end;

    if not (sb or Assigned(NeuronB.Synapses[i])) then
    begin
      NeuronB.Synapses[i] := Self;
      sb := True;
    end;

    if sa and sb then
      Break;
  end;
end;

constructor TSynapse.Create(_neuronA, _neuronB: TNeuron);
begin
  inherited Create;
  Weight := 0.1;
  Attach(_neuronA, _neuronB);
end;

destructor TSynapse.Destroy;
begin
  Detach;
  inherited;
end;

procedure TSynapse.Detach;
var
  i: Integer;
  sa, sb : boolean;
begin
  sa := false;
  sb := false;

  for i := 0 to 3 do
  begin
    if not(sa or (NeuronA.Synapses[i]<>Self)) then
    begin
      NeuronA.Synapses[i] := nil;
      sa := True;
    end;

    if not(sb or (NeuronB.Synapses[i]<>Self)) then
    begin
      NeuronB.Synapses[i] := nil;
      sb := True;
    end;

    if sa and sb then
      Break;
  end;

  NeuronA := nil;
  NeuronB := nil;
end;

procedure TSynapse.Learn(v: Integer);
begin
  TMonitor.Enter(Self);
  try
    if v > 0 then
      Weight := Weight + (1 - Weight) * 0.001
    else if v < 0 then
      Weight := Weight * 0.999;
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
begin
  Result := IsContacted(Dst);

  if not Result then
    for i := 0 to 3 do
      if not Assigned(Synapses[i]) then
      begin
        Synapses[i] := TSynapse.Create(Self, Dst);
        Result := True;
        Break;
      end;
end;

constructor TNeuron.Create(_brain: TBrain);
begin
  inherited Create;
  Brain := _brain;
end;

destructor TNeuron.Destroy;
begin
  ClearSynapses;
  inherited;
end;

procedure TNeuron.ClearSynapses;
var
  i: Integer;
begin
  for i := 0 to 3 do
    FreeAndNil(Synapses[i]);
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

function TNeuron.IsContacted(Dst: TNeuron): Boolean;
var
  i: Integer;
begin
  for i := 0 to 3 do
    if Assigned(Synapses[i])
    and ((Synapses[i].NeuronA = Dst)
      or (Synapses[i].NeuronB = Dst)) then
      Exit(True);

  Result := False;
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
        Brain.PushFiredNeuron(Self, Value > 0);
      end;
    end;

  finally
    TMonitor.Exit(Self);
  end;
end;

{ TBrain }

procedure TBrain.BuildNetwork(m, n: integer);
var
  x, y: Integer;
  t: TNeuron;
begin
  if (m<=0) or (n<=0) then
    raise Exception.Create('Invalid mesh size for network!');

  FNeurons.Clear;
  FMeshSize.cx := m;
  FMeshSize.cy := n;

  for y := 0 to n-1 do
  begin
    for x := 0 to m-1 do
    begin
      t := TNeuron.Create(Self);

      FNeurons.Add(t);

      if y>0 then
        t.Contact(Neuron[x, y-1]);

      if x>0 then
        t.Contact(Neuron[x-1, y]);

      if y=(n-1) then
        t.Contact(Neuron[x, 0]);
    end;

    t.Contact(Neuron[0, y]);
  end;
end;

constructor TBrain.Create;
begin
  inherited Create;
  FireLock := TObject.Create;
  ProcessLock := TObject.Create;
  FiredNeurons := TQueue<TFiredNeuron>.Create;
  FNeurons := TObjectList<TNeuron>.Create;
end;

destructor TBrain.Destroy;
begin
  StopProcessing;
  FreeAndNil(FireLock);
  FreeAndNil(ProcessLock);
  FreeAndNil(FiredNeurons);
  FNeurons.Free;
  inherited;
end;

function TBrain.GetNeuron(x, y: Integer): TNeuron;
begin
  with MeshSize do
  begin
    if (x<0) or (x>=cx)
    or (y<0) or (y>=cy) then
      raise Exception.Create('Invalid neuron coordinate!');

    Result := FNeurons[y*cx + x];
  end;
end;

function TBrain.GetTicks: Int32;
begin
  Result := AtomicIncrement(FTicks);
end;

procedure TBrain.PushFiredNeuron(Neuron: TNeuron; Pain: Boolean);
var
  f : TFiredNeuron;
begin
  f := TFiredNeuron.Create(Neuron, Pain);
  TMonitor.Enter(FireLock);
  try
    FiredNeurons.Enqueue(f);
    TMonitor.Pulse(FireLock);
  finally
    TMonitor.Exit(FireLock);
  end;
end;

function TBrain.PopFiredNeuron(var fn: TFiredNeuron): Boolean;
begin
  TMonitor.Enter(FireLock);
  try
    Result := FiredNeurons.Count>0;
    if Result then
      fn := FiredNeurons.Dequeue;
  finally
    TMonitor.Exit(FireLock);
  end;
end;

procedure TBrain.StartProcessing;
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
        ok: Boolean;
      begin
        AtomicIncrement(Self.FProcessThreadCount);

        while not Self.Stopping do
        begin
          TMonitor.Enter(FireLock);
          try
            ok := TMonitor.Wait(FireLock, 100)
              and Self.PopFiredNeuron(f);
          finally
            TMonitor.Exit(FireLock);
          end;

          if ok then
            f.Neuron.Fire(f.Pain);
        end;

        TMonitor.Enter(ProcessLock);
        try
          AtomicDecrement(Self.FProcessThreadCount);
          TMonitor.Pulse(ProcessLock);
        finally
          TMonitor.Exit(ProcessLock);
        end;
      end
    ).Start;
  end;
end;

procedure TBrain.StopProcessing;
begin
  FStopping := True;

  while FProcessThreadCount>0 do
  begin
    TMonitor.Enter(ProcessLock);
    try
      TMonitor.Wait(ProcessLock, 100);
    finally
      TMonitor.Exit(ProcessLock);
    end;
  end;
end;

{ TFiredNeuron }

constructor TFiredNeuron.Create(_neuron: TNeuron; _pain: Boolean);
begin
  Neuron := _neuron;
  Pain := _pain;
end;


end.
