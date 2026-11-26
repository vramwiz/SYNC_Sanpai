unit Sanpai_Bell;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// 正面から見る本坪鈴と鈴緒。鈴と縄の接点を一つの周期運動から求める。

interface

uses
  Sanpai_Drawing, Sanpai_Timeline;

// Pose は吊り金具の原点。BottomY は Pose を基準とする画面下端。
procedure DrawBell(C: TSanpaiCanvas; const Pose: TPose; Progress,Strength: Double;
  BottomY: Single; Rear: Boolean; const Palette: TSanpaiPalette);

procedure DrawBellCeiling(C: TSanpaiCanvas; const Pose: TPose; Color: Cardinal);

implementation

uses
  System.Math, Winapi.D2D1;

const
  RopeAttachmentY = 236;
  RopeSwayLength = 287;
  BellCenterY = 137;
  BellRadius = 95;


procedure DrawBracket(C: TSanpaiCanvas);
var
  I: Integer;
begin
  C.Poly([-61,-27,60,-27,54,-3,-54,-3],
    C.Linear(-30,-27,39,-1,[Stop(0,$504039),Stop(0.45,$8E7453),Stop(0.70,$514237),Stop(1,$312923)]));
  C.Line(-58,-26,58,-26,1.5,$C6A677,0.58);
  for I := 0 to 1 do
  begin
    C.Oval((I*2-1)*42,-15,5,5,$2D2823);
    C.Oval((I*2-1)*42-1,-16,2.5,2.5,$AE936B,0.70);
  end;
  C.Shape([-19,-8,-20,-3,-18,13,-11,17,-5,24,5,24,11,17,
    18,13,20,-3,19,-8,10,-10,-10,-10,-19,-8],$483A30);
  C.Curve([-14,-5,-13,13,-6,18,0,19,7,18,13,9,13,-5],5,$957D58);
  C.Line(-12,0,-10,7,1.3,$D5B783,0.73);
end;

procedure DrawMetal(C: TSanpaiCanvas; Rear: Boolean);
var
  I: Integer;
  X,Y: Single;
  R: TGrain;
begin
  C.Curve([0,1,-24,1,-29,32,-11,42,8,54,30,24,15,7,11,3,5,1,0,1],10,$3D3129);
  C.Curve([-2,0,-19,2,-24,22,-15,32,2,50,24,25,16,12],5,$B29A70);
  C.Oval(0,45,25,8,C.Linear(-24,39,24,51,
    [Stop(0,$624F3F),Stop(0.36,$D1B784),Stop(1,$564137)]));

  C.Oval(0,BellCenterY,BellRadius,BellRadius,C.Linear(-94,90,95,159,
    [Stop(0,$3A3027),Stop(0.17,$776147),Stop(0.36,$BDA072),Stop(0.47,$EFCE98),
     Stop(0.60,$A48457),Stop(0.78,$6F563C),Stop(0.92,$483B2F),Stop(1,$6A5541)]));
  C.Oval(0,BellCenterY,BellRadius,BellRadius,C.Radial(-29,92,123,109,
    [Stop(0,$FFF0C7,0.57),Stop(0.43,$EBD0A0,0.22),Stop(1,$5F4938,0)]));
  C.Oval(0,BellCenterY,BellRadius,BellRadius,C.Linear(0,139,0,233,
    [Stop(0,$2A221B,0),Stop(0.63,$412C21,0.30),Stop(1,$201A16,0.68)]));

  C.Curve([-82,92,-45,70,46,70,82,92],2.8,$533F2E,0.68);
  C.Curve([-79,89,-43,68,43,69,79,89],1.3,$EED1A1,0.77);
  C.Curve([-94,140,-55,115,54,115,94,140],3.9,$493528,0.71);
  C.Curve([-94,139,-55,112,55,112,94,139],1.55,$E2C094,0.8);
  C.Curve([-91,152,-56,130,56,130,91,152],1,$E9C996,0.52);
  for I := -4 to 4 do
  begin
    X := I*18;
    Y := 136+Sqr(X)*0.0015;
    C.Oval(X,Y,2.2,2,$4C3A2C,0.60);
    C.Oval(X-0.4,Y-0.55,1.1,0.85,$E5C792,0.84);
  end;
  R.State := 52493;
  for I := 0 to 85 do
  begin
    X := (R.Next-0.5)*176;
    Y := 63+R.Next*151;
    if Sqr(X)+Sqr(Y-BellCenterY)>Sqr(BellRadius-5) then Continue;
    C.Oval(X,Y,0.4+R.Next*1.35,0.36+R.Next*0.75,$3F392A,0.10+R.Next*0.14);
  end;
  C.Curve([-67,201,-36,226,36,226,67,201],2.2,$DDBB84,0.71);
  C.Shape([-51,188,-39,172,39,172,51,188,54,194,49,201,43,197,
    20,183,-20,183,-43,197,-49,201,-54,194,-51,188],$241C17);
  C.Curve([-48,197,-31,182,30,182,48,197],1.8,$D9AE73,0.86);
  if Rear then
  begin
    C.Curve([0,45,-21,75,-24,126,-18,168],1.4,$F3CF96,0.60);
    C.Curve([1,45,-19,75,-22,126,-16,166],2.6,$62462E,0.46);
    C.Oval(1,159,4.1,3.4,$654B35,0.73);
    C.Oval(0,158,1.55,1.25,$EBD3A2,0.85);
  end;
  C.Oval(0,229,14,6,$362A23);
  C.Curve([-10,225,-11,244,11,244,10,225],6,$4F3B2C);
  C.Curve([-8,225,-9,239,9,239,8,225],2.3,$CCAD75);
end;

type
  TRope = record
    X,Y,Pull,Bend,Tip: Single;
    function Center(V: Single): Single;
    function Height(V: Single): Single;
    function Radius(V: Single): Single;
  end;

function TRope.Center(V: Single): Single;
var
  T, Extension: Single;
begin
  T := Min(1,V);
  Result := X+Pull*T+Bend*Sin(Pi*T)+Tip*Sqr(T);
  // 元の揺れの終端から接線方向へつなぎ、画面外へ向けて横振れを抑える。
  Extension := Max(0,V-1);
  Result := Result+(Pull-Pi*Bend+2*Tip)*Extension/(1+4*Extension);
end;

function TRope.Height(V: Single): Single;
begin
  // 横に振れた分だけ鉛直方向を短くし、縄を弧に沿わせる。
  Result := Y+Sqrt(Max(0,Sqr(RopeSwayLength*V)-Sqr(Center(V)-X)));
end;

function TRope.Radius(V: Single): Single;
begin
  V := Min(1,V);
  Result := 11+3.6*V+1.1*Sin(V*Pi);
end;

procedure DrawBraid(C: TSanpaiCanvas; const Rope: TRope; BottomY,Reach: Single);
const
  // 同じ縄の上で暗部・撚りの色・ハイライトを重ねる。
  FiberColors: array[0..3] of Cardinal = ($916240,$DAC396,$C6A877,$E5CBA0);
  BraidsPerSwayLength = 43;
  MaxSegments = 256;
var
  I,J,Segments: Integer;
  V,X,Y,W,Before,After,Extent,Step,Angle,Scale,Stretch: Single;
  Outline: TArray<Single>;
  M: TD2DMatrix3x2F;
begin
  // 横振れで短くなる分を見込んで、最後の編み目が画面外に出る長さを確保する。
  Extent := Sqrt(Sqr(Max(0,BottomY-Rope.Y)+24)+Sqr(Reach))/RopeSwayLength;
  Step := Max(1/BraidsPerSwayLength,Extent/MaxSegments);
  Segments := Ceil(Extent/Step);
  SetLength(Outline,4*(Segments+1));
  for I := 0 to Segments do
  begin
    V := I*Step;
    X := Rope.Center(V);
    Y := Rope.Height(V);
    W := Rope.Radius(V)*0.86;
    Outline[2*I] := X-W;
    Outline[2*I+1] := Y;
    Outline[High(Outline)-2*I-1] := X+W;
    Outline[High(Outline)-2*I] := Y;
  end;
  C.Poly(Outline,$49372A);
  for I := 0 to Segments-1 do
  begin
    V := (I+0.3)*Step;
    X := Rope.Center(V);
    Y := Rope.Height(V);
    Scale := Rope.Radius(V)/12;
    Stretch := Scale*Step*BraidsPerSwayLength;
    Before := Max(0,V-Step*0.6);
    After := V+Step*0.6;
    Angle := ArcTan2(Rope.Center(After)-Rope.Center(Before),Rope.Height(After)-Rope.Height(Before));
    M := C.PushBasis(X,Y,Cos(Angle)*Scale,-Sin(Angle)*Scale,
      Sin(Angle)*Stretch,Cos(Angle)*Stretch);
    C.Shape([-11,-5,-9,-8,-3,-5,1,-1,6,2,10,1,12,6,12,8,10,11,7,10,
      0,9,-6,4,-11,1,-13,-1,-13,-4,-11,-5],
      C.Linear(-12,-4,11,8,[Stop(0,$9D8260),Stop(0.38,$CBB68E),Stop(1,$766347)]));
    C.Shape([11,-7,13,-6,13,-1,11,2,8,5,3,8,0,8,-3,7,-5,4,-5,3,
      -1,0,6,-7,11,-7],FiberColors[I mod 4]);
    C.Curve([-11,-4,-7,-4,-3,0,2,3,5,5,8,7,11,6],0.9,$F2DBB2,0.72);
    for J := 0 to 2 do
      C.Curve([10-J*2,-6,7-J*2,-2,4-J*2,-1,-J*2,4],0.55,$715439,0.69);
    C.Restore(M);
  end;

end;

procedure DrawBell(C: TSanpaiCanvas; const Pose: TPose; Progress,Strength: Double;
  BottomY: Single; Rear: Boolean; const Palette: TSanpaiPalette);
var
  M,MetalPose: TD2DMatrix3x2F;
  Tint: TMaterialTint;
  Envelope,Pulse,Angle,Direction: Double;
  Rope: TRope;
begin
  Envelope := ShakeEnvelope(Progress)*Strength/50;
  if Envelope=0 then Progress := 0;
  Direction := 1-2*Ord(Rear);
  Pulse := 2*Pi*3*Progress;
  Angle := Direction*Envelope*(8*Sin(Pulse)+1.25*Sin(2*Pulse));
  Rope.X := -RopeAttachmentY*Sin(DegToRad(Angle));
  Rope.Y := RopeAttachmentY*Cos(DegToRad(Angle));
  Rope.Pull := -70*Direction*Envelope*Sin(Pulse-0.63);
  Rope.Bend := 28*Direction*Envelope*Sin(Pulse+0.29);
  Rope.Tip := -26*Direction*Envelope*Sin(Pulse-1.17);

  M := C.Push(Pose);
  try
    Tint := C.UseTint(BellBase,Palette.Bell);
    try
      DrawBracket(C);
      C.UseTint(RopeBase,Palette.Rope);
      DrawBraid(C,Rope,BottomY,150*Envelope);
      C.UseTint(BellBase,Palette.Bell);
      MetalPose := C.Push(TPose.At(0,0,1,Angle));
      try
        DrawMetal(C,Rear);
      finally
        C.Restore(MetalPose);
      end;
    finally
      C.RestoreTint(Tint);
    end;
  finally
    C.Restore(M);
  end;
end;

procedure DrawBellCeiling(C: TSanpaiCanvas; const Pose: TPose; Color: Cardinal);
var
  M,Beam: TD2DMatrix3x2F;
  Tint: TMaterialTint;
begin
  M := C.Push(Pose);
  Tint := C.UseTint(WoodBase,Color);
  try
    C.Poly([-220,-80,220,-80,177,-49,-177,-49],
      C.Linear(0,-80,0,-49,[Stop(0,$A58160),Stop(1,$664837)]));
    Beam := C.Push(TPose.At(-177,-49));
    C.Timber(354,48,$503629,$997052,94087,43);
    C.Restore(Beam);
    C.Poly([-177,-1,177,-1,160,15,-160,15],
      C.Linear(0,-1,0,15,[Stop(0,$73503A),Stop(1,$392B24)]));
    C.Line(-175,-47,175,-47,2,$D2A47A,0.66);
  finally
    C.RestoreTint(Tint);
    C.Restore(M);
  end;
end;

end.
