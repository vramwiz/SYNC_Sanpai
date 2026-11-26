unit Sanpai_Fortunes;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// 一枚の和紙と独自の字形を描き、選択された方法で結果を表示する。

interface

uses
  Sanpai_Drawing, Sanpai_Timeline;

type
  TFortuneColors = record
    Paper, Text: Cardinal;
  end;

// Pose は紙の中心。Index は運勢の選択番号。
// Reveal は紙の形、Effect は登場時の動きと透過を制御する。
// BottomY は対象のローカル座標での画面下端。色は RGB。
procedure DrawFortune(C: TSanpaiCanvas; const Pose: TPose; Index: Integer;
  const Colors: TFortuneColors; Reveal: TFortuneReveal; Effect: TFortuneEffect;
  Progress: Double; BottomY: Single);

implementation

uses
  System.Math, Winapi.D2D1, Sanpai_Lettering;

const
  PaperW = 154;
  PaperH = 560;
  FrameInk = $9B483D;
  FortunePairs: array[0..5] of array[0..1] of TGlyph = (
    (glDai, glKichi), (glKichi, glKichi), (glChuu, glKichi),
    (glShou, glKichi), (glSue, glKichi), (glKyou, glKyou));
  Kana: array[0..3] of TGlyph = (glO, glMi, glKu, glJi);

function ShiftTint(Color, BaseColor, TargetColor: Cardinal): Cardinal;
var
  I, Shift, Offset, Channel: Integer;
begin
  Result := 0;
  for I := 0 to 2 do
  begin
    Shift := I*8;
    Offset := Integer((TargetColor shr Shift) and $FF)-Integer((BaseColor shr Shift) and $FF);
    Channel := EnsureRange(Integer((Color shr Shift) and $FF)+Offset,0,255);
    Result := Result or (Cardinal(Channel) shl Shift);
  end;
end;

procedure DrawBorder(C: TSanpaiCanvas; Inset,W: Single; Ink: Cardinal);
begin
  C.Line(Inset,Inset,PaperW-Inset,Inset,W,Ink,0.88);
  C.Line(PaperW-Inset,Inset,PaperW-Inset,PaperH-Inset,W,Ink,0.88);
  C.Line(PaperW-Inset,PaperH-Inset,Inset,PaperH-Inset,W,Ink,0.88);
  C.Line(Inset,PaperH-Inset,Inset,Inset,W,Ink,0.88);
end;

procedure DrawPrint(C: TSanpaiCanvas; Index: Integer; TextColor: Cardinal);
var
  I: Integer;
  Size: Single;
  HeadingInk: Cardinal;
begin
  HeadingInk := ShiftTint(FrameInk,TextBase,TextColor);
  DrawBorder(C,9,1.8,HeadingInk);
  DrawBorder(C,14,0.9,HeadingInk);
  DrawGlyph(C,glKai,28,54,47,HeadingInk);
  DrawGlyph(C,glUn,78,54,47,HeadingInk);
  C.Line(30,130,124,130,1,HeadingInk,0.57);
  if Index in [1,5] then
  begin
    Size := 120;
    DrawGlyph(C,FortunePairs[Index,0],(PaperW-Size)/2,222,Size,TextColor);
  end
  else
  begin
    Size := 110;
    DrawGlyph(C,FortunePairs[Index,0],(PaperW-Size)/2,159,Size,TextColor);
    DrawGlyph(C,FortunePairs[Index,1],(PaperW-Size)/2,281,Size,TextColor);
  end;
  C.Line(49,444,105,444,1,HeadingInk,0.55);
  C.Poly([77,440,81,444,77,448,73,444],HeadingInk,0.81);
  for I := 0 to High(Kana) do
    DrawGlyph(C,Kana[I],22+I*28,477,26,HeadingInk);
end;

procedure DrawPaper(C: TSanpaiCanvas; Index: Integer; const Colors: TFortuneColors; Back: Boolean;
  InkOpacity: Single);
var
  R: TGrain;
  I: Integer;
  X,Y,L: Single;

  function PaperTint(Color: Cardinal): Cardinal;
  begin
    Result := ShiftTint(Color,WashiBase,Colors.Paper);
  end;

begin
  C.Oval(80,PaperH*0.53,99,PaperH*0.58,C.Radial(80,PaperH*0.53,99,PaperH*0.58,
    [Stop(0,$1B1712,0.85),Stop(0.72,$241B15,0.6),Stop(1,$271B13,0)]));
  C.Shape([1,2,35,0,113,1,153,0,154,121,153,423,154,559,
    116,561,26,558,0,560,1,415,0,153,1,2],
    C.Linear(0,50,154,536,[Stop(0,PaperTint($E4D3AA)),Stop(0.17,PaperTint($F3E6C5)),Stop(0.49,PaperTint($F3E8CC)),
      Stop(0.75,PaperTint($EDE0BC)),Stop(1,PaperTint($D9C59C))]));
  C.Line(2,3,2,556,1.3,PaperTint($FFF7D8),0.84);
  C.Line(152,3,152,558,1.2,PaperTint($A88862),0.35);
  C.Line(4,3,151,2,1,PaperTint($FFF4D3),0.7);
  C.Line(3,557,152,557.7,1,PaperTint($D4B98D),0.65);
  R.State := 3381+Cardinal(Index)*7043;
  for I := 1 to 285 do
  begin
    X := 3+R.Next*(PaperW-10);
    Y := 3+R.Next*(PaperH-7);
    L := 0.5+R.Next*5;
    if Odd(I) then C.Line(X,Y,X+L,Y+L*0.43,0.55,PaperTint($A5855B),0.15+R.Next*0.14)
    else C.Line(X,Y,X+L*0.48,Y+L,0.62,PaperTint($FFFAE1),0.47);
  end;
  if Back or (InkOpacity<=0) then Exit;
  if InkOpacity>=1 then DrawPrint(C,Index,Colors.Text)
  else
  begin
    C.PushOpacity(0,0,PaperW,PaperH,InkOpacity);
    try
      DrawPrint(C,Index,Colors.Text);
    finally
      C.PopOpacity;
    end;
  end;
end;

procedure DrawAccordion(C: TSanpaiCanvas; Index: Integer; const Colors: TFortuneColors; P,InkOpacity: Single);
const
  PanelHeight = PaperH/4;
var
  Factor: array[0..3] of Single;
  Total,Y,SourceY: Single;
  I: Integer;
  M: TD2DMatrix3x2F;
begin
  Total := 0;
  for I := 0 to High(Factor) do
  begin
    // 最初の面を表に置き、奥の折り目を順に起こす。
    Factor[I] := 0.06+0.94*Ease((P-I*0.11)/0.66);
    if I=0 then Factor[I] := 1;
    Total := Total+PanelHeight*Factor[I];
  end;
  Y := -Total/2;
  for I := 0 to High(Factor) do
  begin
    SourceY := PanelHeight*I;
    M := C.PushBasis(-PaperW/2,Y-SourceY*Factor[I],1,0,0,Factor[I]);
    try
      C.Clip(-3,SourceY,PaperW+3,SourceY+PanelHeight);
      try
        DrawPaper(C,Index,Colors,(P<0.08) or (Factor[I]<0.28),InkOpacity);
        if Odd(I) then
          C.Rect(1,SourceY,PaperW-1,SourceY+PanelHeight,
            C.Linear(0,SourceY,0,SourceY+PanelHeight,[Stop(0,$5F4430,0.39*(1-P)),
              Stop(1,$5F4430,0.08*(1-P))]));
        if I>0 then
          C.Line(1,SourceY+1,PaperW-1,SourceY+1,2,$6B5139,0.65*(1-P));
      finally
        C.Unclip;
      end;
    finally
      C.Restore(M);
    end;
    Y := Y+PanelHeight*Factor[I];
  end;
end;

procedure DrawRevealingPaper(C: TSanpaiCanvas; Index: Integer; const Colors: TFortuneColors;
  Reveal: TFortuneReveal; Progress: Double; BottomY,InkOpacity: Single);
var
  Sheet: TD2DMatrix3x2F;
  P,Width,Edge,Offset,Radius,Opacity: Single;
begin
  P := Ease(Progress);
  if (Progress>=1) or (Reveal=frShow) then
  begin
    Sheet := C.Push(TPose.At(-PaperW/2,-PaperH/2));
    DrawPaper(C,Index,Colors,False,InkOpacity);
    C.Restore(Sheet);
    Exit;
  end;

  case Reveal of
    frFold: DrawAccordion(C,Index,Colors,P,InkOpacity);
    frRoll:
      begin
        Edge := P*PaperH;
        Radius := 19*(1-P)+2;
        Opacity := Min(1.0,12*(1-P));
        Sheet := C.Push(TPose.At(-PaperW/2,-Edge/2));
        if Edge>0 then
        begin
          C.Clip(-25,0,PaperW+25,Edge);
          try
            DrawPaper(C,Index,Colors,False,InkOpacity);
          finally
            C.Unclip;
          end;
        end;
        C.Rect(0,Edge-Radius,PaperW,Edge+Radius,
          C.Linear(0,Edge-Radius,0,Edge+Radius,[
            Stop(0,ShiftTint($B89C75,WashiBase,Colors.Paper),Opacity),
            Stop(0.41,ShiftTint($F7ECCD,WashiBase,Colors.Paper),Opacity),
            Stop(1,ShiftTint($A78B65,WashiBase,Colors.Paper),Opacity)]));
        C.Oval(PaperW,Edge,Radius*0.28,Radius,
          ShiftTint($AA8B66,WashiBase,Colors.Paper),Opacity);
        C.Oval(PaperW+0.5,Edge,Radius*0.12,Radius*0.61,
          ShiftTint($806949,WashiBase,Colors.Paper),Opacity);
        C.Restore(Sheet);
      end;
    frFlip:
      begin
        Width := Max(0.012,Abs(Cos(Pi*P)));
        Sheet := C.PushBasis(-PaperW*Width/2,-PaperH/2,Width,0,0,1);
        DrawPaper(C,Index,Colors,P<0.5,InkOpacity);
        C.Rect(1,1,PaperW-1,PaperH-2,$342823,0.37*(1-Width));
        C.Restore(Sheet);
      end;
    frPull:
      begin
        Offset := Max(0,BottomY+22+PaperH/2)*(1-P);
        Sheet := C.Push(TPose.At(-PaperW/2,-PaperH/2+Offset));
        DrawPaper(C,Index,Colors,False,InkOpacity);
        C.Restore(Sheet);
      end;
  end;
end;

type
  TResultMotion = record
    Y,Scale,Opacity,InkOpacity: Single;
  end;

function ResultMotion(Reveal: TFortuneReveal; Effect: TFortuneEffect; Progress: Double): TResultMotion;
var
  P,Arc,Spring: Double;
begin
  Result.Y := 0;
  Result.Scale := 1;
  Result.Opacity := 1;
  Result.InkOpacity := 1;
  if (Progress<0) or (Progress>=1) then Exit;

  P := Ease(Progress);
  Arc := Sin(Pi*P);
  case Effect of
    feFloat:
      if Reveal=frShow then
      begin
        Result.Y := 52*(1-P);
        Result.Scale := 0.91+0.09*P;
        Result.Opacity := Ease(Progress/0.68);
      end
      else
      begin
        Result.Y := -36*Arc;
        Result.Scale := 1+0.045*Arc;
      end;
    feFade:
      if Reveal=frShow then Result.Opacity := P
      else Result.InkOpacity := P;
    feBounce:
      begin
        Spring := Sin(3*Pi*P)*Sqr(1-P);
        Result.Y := -66*Spring;
        Result.Scale := 1+0.14*Spring;
        if Reveal=frShow then Result.Opacity := Ease(Progress/0.26);
      end;
  end;
end;

procedure DrawFortune(C: TSanpaiCanvas; const Pose: TPose; Index: Integer;
  const Colors: TFortuneColors; Reveal: TFortuneReveal; Effect: TFortuneEffect;
  Progress: Double; BottomY: Single);
var
  Motion: TResultMotion;
  Animated: TPose;
  M: TD2DMatrix3x2F;
begin
  if (Progress<0) and (Reveal in [frShow,frPull]) then Exit;
  if (Progress=0) and (Reveal=frPull) then Exit;
  Motion := ResultMotion(Reveal,Effect,Progress);
  if Motion.Opacity<=0 then Exit;
  Animated := Pose;
  Animated.Y := Pose.Y+Pose.Scale*Motion.Y;
  Animated.Scale := Pose.Scale*Motion.Scale;
  M := C.Push(Animated);
  try
    // 用紙全体をフェードするのは、そのまま表示する場合。開く等の下地は残す。
    if Motion.Opacity<1 then C.PushOpacity(-140,-335,140,335,Motion.Opacity);
    try
      DrawRevealingPaper(C,EnsureRange(Index,0,5),Colors,Reveal,Progress,
        (BottomY-Motion.Y)/Motion.Scale,Motion.InkOpacity);
    finally
      if Motion.Opacity<1 then C.PopOpacity;
    end;
  finally
    C.Restore(M);
  end;
end;

end.
