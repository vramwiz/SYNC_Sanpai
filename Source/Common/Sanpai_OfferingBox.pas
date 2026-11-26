unit Sanpai_OfferingBox;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// 木製賽銭箱の板組み、格子、金具と接地影を描く。

interface

uses
  Sanpai_Drawing;

// Pose は格子の奥辺の中央。投げ入れる硬貨と紙幣もこの原点を使う。
// Rear の場合は背板を描き、透明背景へ接地影を出さない。
procedure DrawOfferingBox(C: TSanpaiCanvas; const Pose: TPose; Rear: Boolean; Color: Cardinal);

implementation

uses
  Winapi.D2D1, Sanpai_Timeline;

procedure DrawSlats(C: TSanpaiCanvas);
var
  I: Integer;
  BackX,FrontX: Single;
  Slat: TD2DMatrix3x2F;
begin
  C.Poly([-238,8,238,8,261,69,-261,69],
    C.Linear(0,8,0,69,[Stop(0,$241912),Stop(0.5,$38281D),Stop(1,$201711)]));
  C.Poly([-243,26,243,26,246,33,-246,33],$665039);
  C.Line(-243,26,243,26,1.3,$A38259,0.65);
  C.Poly([-252,50,252,50,255,57,-255,57],$5A422D);
  C.Line(-252,50,252,50,1.3,$A38259,0.60);
  for I := 0 to 17 do
  begin
    BackX := (I-8.5)*26.1;
    FrontX := (I-8.5)*28.8;
    C.Poly([BackX-7,7,BackX+8,7,FrontX+11,69,FrontX-8,69],$412B20);
    Slat := C.PushBasis(BackX+7,7,(FrontX-BackX)/60,1,-1,0);
    C.Timber(60,14,$795536,$BF9058,5311+Cardinal(I)*712,7);
    C.Restore(Slat);
    C.Line(BackX-7,8,FrontX-7,67,1.2,$DAA76D,0.77);
    C.Line(BackX+8,10,FrontX+10,66,1.25,$301E15,0.72);
  end;
end;

procedure DrawHardware(C: TSanpaiCanvas; X,Y: Single);
var
  M: TD2DMatrix3x2F;
begin
  M := C.Push(TPose.At(X,Y));
  C.Poly([0,2,20,2,20,49,15,61,5,61,0,49],
    C.Linear(0,0,20,56,[Stop(0,$77634A),Stop(0.4,$B39768),Stop(0.68,$574634),Stop(1,$806D4E)]));
  C.Line(1,3,1,47,1,$D6B580,0.65);
  C.Oval(10,17,3.3,2.8,$3A3226);
  C.Oval(9,16,1.0,0.8,$E0C08A);
  C.Oval(10,44,3.3,2.8,$3A3226);
  C.Oval(9,43,1.0,0.8,$E0C08A);
  C.Restore(M);
end;

procedure DrawCrest(C: TSanpaiCanvas);
const
  Lobe: array[0..19] of Single = (0,-22,13,-23,23,-10,21,0,
    18,7,10,11,2,8,13,6,12,-9,0,-10);
var
  M,L: TD2DMatrix3x2F;
  I: Integer;
begin
  M := C.Push(TPose.At(0,179));
  C.Oval(0,0,36,36,$3A271C,0.72);
  C.Oval(0,-1,34,34,C.Linear(-26,-29,29,33,
    [Stop(0,$D7B782),Stop(0.48,$89744D),Stop(1,$5A452F)]));
  C.Oval(0,-1,30,30,$71503A);
  C.Oval(0,-1,27.3,27.3,$403024);
  for I := 0 to 2 do
  begin
    L := C.Push(TPose.At(0,-1,1,I*120));
    C.Shape(Lobe,$C5A473);
    C.Restore(L);
  end;
  C.Restore(M);
end;

procedure DrawOfferingBox(C: TSanpaiCanvas; const Pose: TPose; Rear: Boolean; Color: Cardinal);
var
  M,Face: TD2DMatrix3x2F;
  Tint,MetalTint: TMaterialTint;
  I: Integer;
begin
  M := C.Push(Pose);
  try
    if not Rear then C.Oval(0,286,367,48,C.Radial(0,286,367,48,
      [Stop(0,$1E211A,0.79),Stop(0.55,$26281F,0.57),Stop(1,$312F24,0)]));
    Tint := C.UseTint(BoxBase,Color);
    try
      C.Poly([-244,232,-195,232,-195,281,-203,287,-245,287],$543724);
      C.Poly([195,232,244,232,245,287,203,287,195,281],$543724);
      C.Line(-239,257,-239,284,1.6,$B17F54,0.63);
      C.Line(239,257,239,284,1.6,$B17F54,0.63);
      for I := 0 to 2 do
      begin
        Face := C.Push(TPose.At(-261,87+I*49));
        C.Timber(522,48,$65422D,$9B6A45,43777+Cardinal(I)*591,38);
        C.Line(0,1,522,1,1.3,$D2A474,0.53);
        C.Line(0,47,522,47,1.3,$342016,0.65);
        C.Restore(Face);
      end;
      C.Rect(-261,92,261,234,C.Linear(0,91,0,234,
        [Stop(0,$382317,0.51),Stop(0.28,$CB9B68,0.13),Stop(0.7,$B27D4F,0.05),Stop(1,$432A1E,0.48)]));
      Face := C.Push(TPose.At(-267,234));
      C.Timber(534,26,$593A2B,$9C6A48,7399,21);
      C.Line(0,2,534,2,1.8,$C79464,0.66);
      C.Line(0,25,534,25,1.8,$382419,0.8);
      C.Restore(Face);
      if Rear then
      begin
        // 背板は化粧金具の代わりに縦の補強材と木栓を持つ。
        for I := -1 to 1 do
          if I<>0 then
          begin
            Face := C.PushBasis(I*179+14,103,0,1,-1,0);
            C.Timber(126,28,$513626,$845B3C,77291+Cardinal(I+1)*617,24);
            C.Restore(Face);
            C.Line(I*179-13,103,I*179-13,229,1.15,$C99762,0.62);
            C.Oval(I*179,119,3.7,3.7,$3F2C22);
            C.Oval(I*179,208,3.7,3.7,$3F2C22);
          end;
        C.Line(-260,163,260,163,1.4,$4C3628,0.71);
      end
      else
      begin
        MetalTint := C.UseTint(0,0);
        try
          DrawHardware(C,-248,132);
          DrawHardware(C,228,132);
          DrawCrest(C);
        finally
          C.RestoreTint(MetalTint);
        end;
      end;

      // 同じ消失点を使う上面だけを浅く見せ、側面と左右の傾きを除く。
      C.Poly([-251,0,251,0,280,72,-280,72],
        C.Linear(0,0,0,72,[Stop(0,$CE9D64),Stop(0.67,$A27045),Stop(1,$D9A673)]));
      DrawSlats(C);
      C.Line(-248,3,248,3,2,$673F29,0.85);
      C.Line(-249,4,-276,70,2.2,$DFB17A,0.83);
      C.Line(249,4,276,70,2.2,$DFB17A,0.83);
      Face := C.Push(TPose.At(-280,71));
      C.Timber(560,29,$64402A,$C08A56,65113,43);
      C.Line(0,1,560,1,2,$EDC08A,0.86);
      C.Line(0,28,560,28,1.5,$3B2419,0.76);
      C.Restore(Face);
      C.Line(-260,102,-260,230,2,$AF8358,0.73);
      C.Line(260,102,260,230,2,$AF8358,0.73);
    finally
      C.RestoreTint(Tint);
    end;
  finally
    C.Restore(M);
  end;
end;

end.
