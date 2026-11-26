unit Sanpai_Offerings;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// 固定された投入順で硬貨・紙幣を描き、格子に沈んだところで隠す。

interface

uses
  Sanpai_Drawing;

// Pose は賽銭箱と同じ基準。LandingX/Y は格子中央からの画面上の相対位置。
// Progress は演出位置。箱の中へ入った硬貨・紙幣はクリップする。
procedure DrawOfferings(C: TSanpaiCanvas; const Pose: TPose;
  Progress: Double; Coins,Bills: Integer; Rear: Boolean; LandingX,LandingY: Single);

implementation

uses
  System.Math, Winapi.D2D1, Sanpai_Timeline;

procedure DrawCoin(C: TSanpaiCanvas; Tumble,Turn: Double);
var
  W: Single;
begin
  W := 2.1+9.5*Abs(Cos(Tumble));
  C.Oval(0,2,W,11.3,$6D4D2D);
  C.Oval(0,0,W,11.2,C.Linear(-W,-9,W,10,
    [Stop(0,$F8DEA0),Stop(0.38,$BB965B),Stop(0.62,$E9D29B),Stop(1,$8B653D)]));
  C.Oval(0,0,W*0.72,8.3,$9E7B4D,0.68);
  C.Oval(-W*0.09,-0.65,W*0.61,7.2,C.Linear(-W,-8,W,8,
    [Stop(0,$C7A568),Stop(0.58,$F2D6A0),Stop(1,$A47C44)]));
  C.Line(-W*0.34,-2,W*0.27,-2,1.15,$765736,0.76);
  C.Line(-W*0.15,2,W*0.34,2,0.95,$FFF2C7,0.75);
  C.Oval(-W*0.55,-5.7,0.6+0.2*Cos(Turn),1.2,$FFF1C0,0.88);
end;

procedure DrawBill(C: TSanpaiCanvas; Flutter: Double);
var
  Height,Fold: Single;
begin
  Height := 4+8*Abs(Cos(Flutter));
  Fold := 5*Sin(Flutter);
  C.Shape([-28,-Height,-18,-Height-3,-8,-Height+Fold-2,0,-Height+Fold,
    11,-Height+Fold+4,22,-Height+1,28,-Height+2,
    29,-Height*0.3,28,Height*0.6,27,Height,
    14,Height-2,8,Height+Fold+4,0,Height+Fold,
    -9,Height+Fold-2,-18,Height+1,-27,Height-1,
    -27,3,-28,-2,-28,-Height],
    C.Linear(-26,-Height,28,Height,[Stop(0,$F2DFB0),Stop(0.38,$B6B68B),
      Stop(0.58,$E2D5A8),Stop(1,$EEE0B8)]));
  C.Curve([-24,-Height*0.61,-10,-Height*0.7,-6,-Height*0.6+Fold,-1,-Height*0.6+Fold,
    10,-Height*0.6+Fold,19,-Height*0.65,24,-Height*0.55],0.8,$716D52,0.74);
  C.Curve([-23,Height*0.64,-11,Height*0.53,-5,Height*0.6+Fold,-1,Height*0.6+Fold,
    11,Height*0.6+Fold,17,Height*0.7,23,Height*0.57],0.8,$716D52,0.68);
  C.Oval(-12,Fold*0.46,5.8,Height*0.43,$7D815F,0.67);
  C.Oval(-11,Fold*0.46,3.35,Height*0.27,$D7C8A2,0.71);
  C.Line(6,Fold*0.33-1,18,Fold*0.14-1,0.85,$676D51,0.81);
  C.Line(7,Fold*0.33+2,16,Fold*0.17+2,0.55,$676D51,0.69);
end;

procedure DrawPiece(C: TSanpaiCanvas; const Cue: TOfferingCue;
  Progress,AimX,AimY: Double; Rear,Paper,Scattered: Boolean);
var
  U,X,Y,StartY,Direction,Spin,Scale,ContactX: Double;
  M: TD2DMatrix3x2F;
begin
  if (Progress<Cue.Start) or (Progress>=Cue.Drop) then Exit;
  if Rear then
  begin
    StartY := -216;
    Direction := -1;
  end
  else
  begin
    StartY := 245;
    Direction := 1;
  end;

  ContactX := AimX+Direction*10*Ord(Scattered);
  if Progress<Cue.Contact then
  begin
    U := (Progress-Cue.Start)/(Cue.Contact-Cue.Start);
    X := ContactX+Direction*(Cue.Side*186+74)*(1-U);
    Y := StartY+(AimY-StartY)*U-(125+115*Ord(not Rear))*4*U*(1-U);
    Spin := Cue.Turn*5.9+U*(6.7+3.1*Ord(Paper));
    if Paper then
    begin
      X := X+17*Sin(Spin)*Sin(Pi*U);
      Y := Y+9*Cos(Spin)*Sin(Pi*U);
    end;
    Scale := 1+(0.16*Direction)*(1-U);
  end
  else
  begin
    U := (Progress-Cue.Contact)/(Cue.Drop-Cue.Contact);
    X := ContactX+(AimX-ContactX)*Ease(U);
    Y := AimY+19*Sqr(U)-19*Sin(Pi*U)*(1-U);
    Spin := Cue.Turn*5.9+6.7+3.1*Ord(Paper)+U*2.4;
    Scale := 1-(0.42+0.24*Ord(Paper))*Ease(U);
  end;

  // 格子より下へ入った部分を描かない。飛翔中は手前側も通過できる。
  if Progress>=Cue.Contact then C.Clip(-265,-300,265,AimY+11);
  try
    M := C.Push(TPose.At(X,Y,Scale,Direction*(Cue.Side*22+Sin(Spin)*26)));
    try
      if Paper then DrawBill(C,Spin) else DrawCoin(C,Spin,Cue.Turn*2*Pi);
    finally
      C.Restore(M);
    end;
  finally
    if Progress>=Cue.Contact then C.Unclip;
  end;
end;

procedure DrawOfferings(C: TSanpaiCanvas; const Pose: TPose;
  Progress: Double; Coins,Bills: Integer; Rear: Boolean; LandingX,LandingY: Single);
var
  I: Integer;
  M: TD2DMatrix3x2F;
  AimX,AimY,Spread: Double;
  Scattered: Boolean;
  Cue: TOfferingCue;
begin
  if (Progress<=0) or (Progress>=1) then Exit;
  AimX := LandingX/Pose.Scale;
  AimY := 39+LandingY/Pose.Scale;
  Scattered := Coins+Bills>1;
  Spread := Min(36,224-Abs(AimX))*Ord(Scattered)/166.2;
  M := C.Push(Pose);
  try
    for I := 0 to Bills-1 do
    begin
      Cue := OfferingCue(I,Bills,True);
      DrawPiece(C,Cue,Progress,AimX+Cue.Slot*Spread,AimY,Rear,True,Scattered);
    end;
    for I := 0 to Coins-1 do
    begin
      Cue := OfferingCue(I,Coins,False);
      DrawPiece(C,Cue,Progress,AimX+Cue.Slot*Spread,AimY,Rear,False,Scattered);
    end;
  finally
    C.Restore(M);
  end;
end;

end.
