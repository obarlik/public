unit uMatrix;

interface

uses System.SysUtils;

type

  TMatrix = class
    constructor Create(m, n: UInt32);
  private
    FnValue: UInt32;
    FmValue: UInt32;

    function FindCell(i, j: UInt32):PDouble;
    function GetCell(i, j: UInt32): Double;
    procedure SetCell(i, j: UInt32; const Value: Double);
  public
    property mValue:UInt32 read FmValue;
    property nValue:UInt32 read FnValue;
    property Cell[i, j: UInt32]: Double read GetCell write SetCell;
  end;

implementation

{ TMatrix }

constructor TMatrix.Create(m, n: UInt32);
begin

end;

function TMatrix.FindCell(i, j: UInt32): PDouble;
begin
  if (i>=mValue) or (j>=nValue) then
    raise Exception.Create('Invalid matrix cell!');

end;

function TMatrix.GetCell(i, j: UInt32): Double;
begin

end;

procedure TMatrix.SetCell(i, j: UInt32; const Value: Double);
begin

end;

end.
