unit Sanpai_Tube;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// 木製のおみくじ筒を振り、蓋の穴から棒を1本取り出す。

interface

uses
  Sanpai_Drawing;

// Pose の原点は筒の中心。Strength は 0～100。Color は木部の RGB。
// Progress が 1 になると棒が出た姿勢を保持する。
procedure DrawFortuneTube(C: TSanpaiCanvas; const Pose: TPose; Progress,Strength: Double; Color: Cardinal);

implementation

uses
  System.Math, Winapi.D2D1, Sanpai_Timeline;

procedure DrawStick(C: TSanpaiCanvas; Extension: Single);
var
  Y: Single;
begin
  Y := -144-Extension;
  C.Poly([-6,Y-1,4,Y-1,7,Y+3,6,-142,-6,-142],
    C.Linear(-6,0,7,0,[Stop(0,$A07243),Stop(0.38,$ECD39F),Stop(1,$AE8752)]));
  C.Line(-3,Y+5,-3,-144,1.1,$F8DEAA,0.64);
  C.Line(3,Y+13,2,-146,0.65,$895F3B,0.59);
end;

procedure DrawTubeBody(C: TSanpaiCanvas; Extension: Single);
const
  Edges: array[0..4] of Single = (-87,-62,0,62,87);
  Dark: array[0..3] of Cardinal = ($60402D,$8A5634,$715038,$432C22);
  Light: array[0..3] of Cardinal = ($B38252,$C89459,$AC784A,$805638);
var
  I: Integer;
  X,W: Single;
  M: TD2DMatrix3x2F;
begin
  C.Poly([-86,116,86,116,87,133,60,151,-60,151,-87,134],$57392A);
  C.Line(-60,150,60,150,2.6,$BA8858,0.62);
  for I := 0 to High(Dark) do
  begin
    X := Edges[I];
    W := Edges[I+1]-X;
    M := C.PushBasis(X+W,-129,0,1,-1,0);
    C.Timber(263,W,Dark[I],Light[I],44263+Cardinal(I)*937,45);
    C.Restore(M);
    C.Line(X+1,-128,X+1,135,1.35,$DDAD75,0.49);
  end;
  C.Rect(-87,121,87,136,C.Linear(-87,0,87,0,
    [Stop(0,$422D23),Stop(0.33,$96704C),Stop(0.72,$76533B),Stop(1,$3E2A20)]));
  C.Line(-86,122,87,122,1.5,$E2B480,0.72);
  C.Poly([-87,-130,-63,-154,64,-154,87,-131,60,-112,-60,-112],
    C.Linear(-45,-154,75,-113,[Stop(0,$D8AD73),Stop(0.48,$B48757),Stop(1,$8C623F)]));
  C.Poly([-87,-132,-60,-112,60,-112,87,-132,87,-119,62,-100,-61,-100,-87,-118],
    C.Linear(-84,0,87,0,[Stop(0,$70472D),Stop(0.43,$C18953),Stop(0.68,$98643F),Stop(1,$5C3C2B)]));
  C.Line(-59,-112,59,-112,1.7,$EDBB81,0.77);
  C.Line(-64,-148,63,-148,1.15,$F0C388,0.56);
  C.Oval(0,-142,13,6.7,$D5A270);
  C.Oval(0,-142,9.7,4.75,$33231A);
  if Extension>0 then DrawStick(C,Extension);
  C.Oval(0,9,23,27,$85593A,0.63);
  C.Poly([0,-12,15,9,0,30,-15,9],$D3A373,0.86);
  C.Poly([0,-4,9,9,0,21,-9,9],$9F6D45);
end;

procedure DrawFortuneTube(C: TSanpaiCanvas; const Pose: TPose; Progress,Strength: Double; Color: Cardinal);
var
  M,Motion: TD2DMatrix3x2F;
  Tint: TMaterialTint;
  P,Wave,Swing,Tilt,Extension: Double;
begin
  P := EnsureRange(Progress,0.0,1.0);
  Wave := Min(1,P/0.65);
  Swing := ShakeEnvelope(Wave)*Strength/50;
  // 取り出し口を下にして振り、傾けた先から棒を出す。
  Tilt := 180-33*Ease((P-0.54)/0.27)+12*Swing*Sin(Wave*10*Pi);
  Extension := 120*Ease((P-TubeStickStart)/(1-TubeStickStart));
  M := C.Push(Pose);
  try
    C.Oval(0,188,216,35,C.Radial(0,188,216,35,
      [Stop(0,$1B1811,0.63),Stop(1,$1B1811,0)]));
    Motion := C.Push(TPose.At(27*Swing*Sin(Wave*8*Pi),
      -27*Swing*Abs(Sin(Wave*5*Pi)),1,Tilt));
    Tint := C.UseTint(TubeBase,Color);
    try
      DrawTubeBody(C,Extension);
    finally
      C.RestoreTint(Tint);
      C.Restore(Motion);
    end;
  finally
    C.Restore(M);
  end;
end;

end.
