unit Sanpai_Lettering;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// おみくじに使う全字形を筆画の輪郭で定義する。各字の基準は 100 × 100。

interface

uses
  Sanpai_Drawing;

type
  TGlyph = (glKai, glUn, glO, glMi, glKu, glJi, glDai, glKichi, glChuu, glShou, glSue, glKyou);

// X, Y は字枠の左上。Size は字枠の幅と高さ。Ink は RGB。
procedure DrawGlyph(C: TSanpaiCanvas; Glyph: TGlyph; X,Y,Size: Single; Ink: Cardinal);

implementation

uses
  Winapi.D2D1;

type
  TLetter = record
    C: TSanpaiCanvas;
    Ink: Cardinal;
    procedure H(X1,X2,Y,W: Single);
    procedure V(X,Y1,Y2,W: Single);
    procedure Stroke(const XY: array of Single);
    procedure Brush(const XY: array of Single);
    procedure Kai;
    procedure Un;
    procedure O;
    procedure Mi;
    procedure Ku;
    procedure Ji;
    procedure Dai;
    procedure Kichi;
    procedure Chuu;
    procedure Shou;
    procedure Sue;
    procedure Kyou;
  end;

procedure TLetter.H(X1,X2,Y,W: Single);
begin
  Stroke([X1,Y,X1+2,Y-W*0.4,X2-W*1.15,Y-W*0.46,
    X2-W*0.59,Y-W*1.19,X2,Y-W*0.35,X2-0.3,Y+W*0.46,X1,Y+W*0.59]);
end;

procedure TLetter.V(X,Y1,Y2,W: Single);
begin
  Stroke([X-W*0.5,Y1+1,X-W*0.22,Y1-W*0.41,X+W*0.46,Y1+1,
    X+W*0.41,Y2-W*0.53,X-W*0.52,Y2,X-W*0.43,Y2-W*0.57]);
end;

procedure TLetter.Stroke(const XY: array of Single);
begin
  C.Poly(XY,Ink);
end;

procedure TLetter.Brush(const XY: array of Single);
begin
  C.Shape(XY,Ink);
end;

procedure TLetter.Kai;
begin
  V(14,10,92,8);
  H(15,43,13,4.8);
  H(14,41,26,4.2);
  H(15,44,39,4.6);
  V(42,13,41,6.8);
  V(58,11,42,7);
  H(57,88,13,4.7);
  H(60,85,26,4.1);
  H(59,85,39,4.7);
  Brush([81,12,83,9,88,10,91,13,90,33,90,66,90,79,
    91,88,90,93,81,94,79,87,76,85,71,82,77,83,82,84,82,79,
    81,58,84,32,81,12]);
  H(25,74,51,4.7);
  H(23,76,65,5.1);
  V(61,51,86,7.5);
  Brush([37,52,40,51,43,52,44,54,44,73,39,85,25,90,
    33,81,37,70,37,52]);
end;

procedure TLetter.Un;
begin
  Brush([9,14,20,12,30,22,28,29,23,33,20,31,18,26,15,20,12,17,9,14]);
  Brush([8,48,14,47,21,47,27,43,31,46,32,49,28,52,
    28,61,27,70,27,77,42,90,82,87,96,83,92,88,91,91,90,94,
    66,96,41,96,26,83,21,88,17,91,13,94,11,94,8,90,7,87,
    12,84,18,82,20,78,20,69,20,57,20,52,16,52,11,53,8,53,
    7,52,7,50,8,48]);
  Brush([36,13,42,18,45,26,41,32,38,37,33,35,32,32,34,27,38,22,36,13]);
  H(39,90,19,4.8);
  Stroke([86,17,89,14,94,18,91,23,83,30,83,25]);
  H(42,85,34,4.5);
  V(62,30,84,7);
  V(44,43,69,6.2);
  H(44,82,44,4.3);
  V(81,44,69,7.4);
  H(46,80,55,3.8);
  H(45,81,65,4.2);
  H(36,91,75,4.7);
end;

procedure TLetter.O;
begin
  Brush([22,32,33,31,51,28,60,22,65,19,69,26,63,29,51,36,31,38,21,37,
    16,36,18,33,22,32]);
  Brush([43,10,48,9,55,13,54,17,50,29,50,56,49,74,47,85,39,88,30,81,
    20,74,21,69,28,65,44,55,66,49,79,56,92,63,89,80,76,86,
    69,90,59,87,55,80,62,83,69,82,74,78,81,73,81,64,75,62,
    67,55,49,61,31,70,25,73,32,78,37,79,41,79,41,65,41,58,
    42,41,42,23,43,10]);
  Brush([73,24,81,22,92,30,93,35,94,42,87,44,84,39,81,34,80,28,73,24]);
end;

procedure TLetter.Mi;
begin
  Brush([22,23,33,25,41,22,50,16,55,13,61,19,59,23,
    48,34,44,55,35,71,28,82,17,87,11,79,5,69,14,58,29,55,
    52,47,78,56,93,70,99,76,96,82,90,79,
    74,66,51,52,30,62,15,67,14,78,20,76,30,74,43,36,48,25,
    39,29,29,36,23,32,20,30,19,26,22,23]);
  Brush([70,36,76,35,83,40,82,46,79,70,66,88,49,92,
    65,78,70,62,73,47,73,42,69,39,70,36]);
end;

procedure TLetter.Ku;
begin
  Brush([59,9,63,7,73,13,73,19,69,26,43,44,39,49,
    32,56,65,68,73,83,79,92,72,97,67,91,61,80,46,68,34,60,
    25,54,30,47,36,41,47,32,61,18,59,9]);
end;

procedure TLetter.Ji;
begin
  Brush([27,14,34,12,44,18,42,25,39,42,37,61,40,70,
    45,88,68,81,85,65,77,83,62,94,49,92,24,91,28,65,28,52,
    29,35,32,22,27,14]);
  Brush([61,24,69,23,78,30,78,35,78,42,73,42,70,37,68,32,64,28,61,24]);
  Brush([76,17,84,16,93,22,93,27,94,33,89,34,86,29,83,24,79,20,76,17]);
end;

procedure TLetter.Dai;
begin
  H(9,90,39,5.5);
  Brush([45,9,48,7,55,8,57,12,55,45,50,81,8,94,
    20,85,35,66,41,44,43,34,45,17,45,9]);
  Brush([53,41,57,55,74,77,94,83,92,86,85,90,83,94,
    65,84,54,58,50,42,50,41,52,40,53,41]);
end;

procedure TLetter.Kichi;
begin
  H(10,90,23,5.4);
  V(50,6,44,9);
  H(18,82,43,5.3);
  V(25,57,94,8);
  H(24,78,61,5.0);
  V(73,60,93,8.7);
  H(28,75,86,5.0);
end;

procedure TLetter.Chuu;
begin
  V(19,26,69,8.7);
  H(18,83,30,5.3);
  V(79,30,69,8.5);
  H(21,80,62,4.8);
  V(50,7,95,9.5);
end;

procedure TLetter.Shou;
begin
  Brush([46,9,53,6,58,8,58,14,57,33,58,72,57,83,57,90,50,94,45,96,
    43,89,38,85,34,81,39,82,44,83,47,83,50,63,49,27,46,9]);
  Brush([26,38,30,39,35,43,33,48,28,62,19,71,8,76,17,66,22,49,26,38]);
  Brush([66,41,78,43,93,58,93,66,94,75,87,78,83,70,79,58,72,47,66,41]);
end;

procedure TLetter.Sue;
begin
  // 「末」は上の横画が長い。下の横画と払いは上の横画の幅に収める。
  H(6,95,23,5.6);
  H(23,77,42,5.0);
  V(50,6,96,8.6);
  Brush([43,42,48,42,51,47,47,51,37,69,22,81,11,86,
    24,76,36,58,43,42]);
  Brush([53,44,62,54,76,69,91,74,88,78,83,81,80,85,
    67,76,56,60,50,47,48,44,50,43,53,44]);
end;

procedure TLetter.Kyou;
begin
  Brush([15,31,18,28,23,29,25,34,24,51,24,70,24,82,28,85,29,89,24,92,
    13,93,14,85,15,81,16,63,15,47,15,31]);
  H(20,82,84,5.1);
  Brush([77,29,79,26,85,28,86,32,85,52,86,74,85,87,84,92,78,95,77,91,
    78,72,77,54,77,29]);
  Brush([30,27,42,29,62,45,70,57,77,65,69,71,65,65,56,54,44,37,30,27]);
  Brush([62,14,66,13,72,15,72,21,67,41,55,65,28,77,44,64,56,39,62,14]);
end;

procedure DrawGlyph(C: TSanpaiCanvas; Glyph: TGlyph; X,Y,Size: Single; Ink: Cardinal);
var
  M: TD2DMatrix3x2F;
  Letter: TLetter;
begin
  M := C.Push(TPose.At(X,Y,Size/100));
  try
    Letter.C := C;
    Letter.Ink := Ink;
    case Glyph of
      glKai: Letter.Kai;
      glUn: Letter.Un;
      glO: Letter.O;
      glMi: Letter.Mi;
      glKu: Letter.Ku;
      glJi: Letter.Ji;
      glDai: Letter.Dai;
      glKichi: Letter.Kichi;
      glChuu: Letter.Chuu;
      glShou: Letter.Shou;
      glSue: Letter.Sue;
      glKyou: Letter.Kyou;
    end;
  finally
    C.Restore(M);
  end;
end;

end.
