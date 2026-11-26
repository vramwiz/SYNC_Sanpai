unit Sanpai_Shrine;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// 拝殿、注連縄、参道を共有する。画面の基準は 1280 × 720。

interface

uses
  Sanpai_Drawing, Sanpai_Timeline;

type
  TShrineView = (svLower, svUpper, svFortunes);

const
  ShrineWidth = 1280;
  ShrineHeight = 720;
  ShrineLowerTop = 126;
  ShrineUpperTop = -200;
  ShrineBellScreenY = 128;

// 同じ拝殿を正面から描き、View で画面に入る高さを選ぶ。
procedure DrawShrine(C: TSanpaiCanvas; const Pose: TPose; View: TShrineView; const Palette: TSanpaiPalette);

implementation

uses
  System.Math, Winapi.D2D1;

procedure DrawGrove(C: TSanpaiCanvas);
var
  R: TGrain;
  I: Integer;
  X,Y,Size: Single;
  Tint: Cardinal;
begin
  C.Rect(-40,-260,1320,540,C.Linear(0,-246,0,525,
    [Stop(0,$7D8B74),Stop(0.38,$9C9F7C),Stop(0.68,$79856A),Stop(1,$3F4C3D)]));
  C.Oval(97,260,165,238,C.Radial(97,260,165,238,
    [Stop(0,$D6D0A0,0.74),Stop(1,$D2CFA2,0)]));
  C.Oval(1210,223,170,265,C.Radial(1210,223,170,265,
    [Stop(0,$D4CC99,0.60),Stop(1,$C1C18A,0)]));
  C.Poly([-9,477,45,471,91,174,119,119,106,116,79,162,20,-210,4,-209,60,177,29,355],$383C2D,0.78);
  C.Poly([1227,479,1271,494,1248,304,1291,65,1277,31,1243,238,1201,-205,1188,-198],$3E4131,0.76);
  R.State := 11439;
  for I := 1 to 515 do
  begin
    X := R.Next*202-18;
    if Odd(I) then X := 1280-X;
    Y := R.Next*728-245;
    Size := 4+R.Next*18;
    case I mod 4 of
      0: Tint := $4B614D;
      1: Tint := $748360;
      2: Tint := $ABAA76;
    else
      Tint := $324835;
    end;
    C.Oval(X,Y,Size,Size*(0.35+R.Next*0.45),Tint,0.21+R.Next*0.23);
  end;
end;

procedure DrawFloor(C: TSanpaiCanvas);
const
  Rows: array[0..7] of Integer = (481,507,538,579,630,692,766,852);
var
  Row, Col, I: Integer;
  Y0,Y1,L0,L1,R0,R1,X,Y: Single;
  R: TGrain;
  Tone: Cardinal;
begin
  C.Rect(-40,472,1320,852,C.Linear(0,472,0,852,
    [Stop(0,$56564B),Stop(0.42,$817F71),Stop(1,$B1A99A)]));
  R.State := 13819;
  for Row := 0 to High(Rows)-1 do
  begin
    Y0 := Rows[Row];
    Y1 := Rows[Row+1];
    for Col := -8 to 7 do
    begin
      L0 := 640 + (Col + 0.5*Ord(Odd(Row)))*(84+(Y0-480)*0.32);
      L1 := 640 + (Col + 0.5*Ord(Odd(Row)))*(84+(Y1-480)*0.32);
      R0 := L0 + 84+(Y0-480)*0.32;
      R1 := L1 + 84+(Y1-480)*0.32;
      if (R0 < 0) and (R1 < 0) or (L0 > 1280) and (L1 > 1280) then Continue;
      if R.Next > 0.47 then Tone := $D5C8AD else Tone := $3F473E;
      C.Poly([L0+1,Y0+1,R0-1,Y0+1,R1-1,Y1-1,L1+1,Y1-1],Tone,0.07+0.21*R.Next);
      C.Line(L0,Y0,L1,Y1,1.25+(Y1-481)*0.004,$3D4238,0.35);
      C.Line(L0+2,Y0+2,R0-2,Y0+2,1,$DDD2BA,0.34);
      C.Line(L1,Y1,R1,Y1,1.5,$30372F,0.40);
    end;
  end;
  for I := 1 to 530 do
  begin
    X := R.Next*1280;
    Y := 485+R.Next*362;
    C.Oval(X,Y,0.3+R.Next*2.3,0.3+R.Next*0.85,$443F35,0.10+R.Next*0.19);
  end;
  C.Poly([0,492,215,496,944,846,597,846,0,566],
    C.Linear(16,540,164,679,[Stop(0,$1A291F,0.38),Stop(1,$222D24,0.02)]));
  C.Poly([1004,483,1101,477,1280,507,1280,846,1219,693],
    C.Linear(1020,511,1280,711,[Stop(0,$323B29,0.15),Stop(1,$1E3026,0.35)]));
end;

procedure DrawPillar(C: TSanpaiCanvas; X,Y,W,H: Single; Seed: Cardinal);
var
  M: TD2DMatrix3x2F;
begin
  C.Poly([X-9,Y+H-11,X+W+9,Y+H-11,X+W+17,Y+H+8,X-15,Y+H+8],$2B2A21);
  C.Rect(X,Y,X+W,Y+H,C.Linear(X,Y,X+W,Y,
    [Stop(0,$3B211A),Stop(0.12,$81513A),Stop(0.28,$9E6C49),Stop(0.69,$694330),Stop(1,$3F261C)]));
  M := C.PushBasis(X+W,Y,0,1,-1,0);
  C.Timber(H,W,$563424,$926045,Seed,32);
  C.Restore(M);
  C.Rect(X,Y,X+W,Y+H,C.Linear(X,Y,X+W,Y,
    [Stop(0,$201914,0.72),Stop(0.18,$E3AF72,0.2),Stop(0.35,$E1A76B,0.12),
      Stop(1,$251815,0.6)]));
  C.Line(X+W*0.24,Y+3,X+W*0.24,Y+H-2,1.5,$DEA576,0.36);
  C.Rect(X,Y+H-27,X+W,Y+H,$352821,0.74);
  C.Line(X,Y+H-26,X+W,Y+H-26,2,$926E4F,0.46);
end;

procedure DrawFortuneSteps(C: TSanpaiCanvas);
var
  I: Integer;
  Y: Single;
begin
  C.Poly([95,465,1180,465,1240,510,40,510],$605B50);
  for I := 0 to 3 do
  begin
    Y := 455+I*13;
    C.Poly([180-I*31,Y,1100+I*31,Y,1120+I*31,Y+11,160-I*31,Y+11],
      C.Linear(0,Y,0,Y+11,[Stop(0,$8F8170),Stop(0.30,$786A5D),Stop(1,$4D463D)]));
    C.Line(161-I*31,Y+11,1119+I*31,Y+11,2,$272722,0.60);
  end;
end;

// おみくじの背後に見える、引きで描いた拝殿を保つ。
procedure DrawFortuneHall(C: TSanpaiCanvas);
var
  I,J: Integer;
  X,Y: Single;
  M: TD2DMatrix3x2F;
begin
  C.Rect(141,-154,1139,455,C.Linear(0,-154,0,455,
    [Stop(0,$302821),Stop(0.56,$49372A),Stop(1,$5F4B39)]));
  for I := 0 to 2 do
  begin
    X := 231+I*279;
    C.Rect(X,-89,X+260,70,$362A21);
    C.Rect(X+9,-77,X+251,59,C.Linear(X,-77,X+132,59,
      [Stop(0,$574438),Stop(0.48,$957658),Stop(1,$69513E)]));
    C.Line(X+9,-77,X+251,-77,2,$251E18,0.62);
    C.Line(X+9,58,X+251,58,2,$B79A71,0.36);
    for J := 1 to 4 do
    begin
      Y := -82+J*28;
      C.Line(X+9,Y,X+251,Y,2,$4B3A2C,0.46);
      C.Line(X+9,Y+2,X+251,Y+2,1,$D0AB78,0.22);
    end;
  end;
  for I := 0 to 10 do
  begin
    Y := 190+I*23;
    M := C.Push(TPose.At(154,Y));
    C.Timber(970,22,$493628,$6A513C,4121+Cardinal(I)*650,12);
    C.Restore(M);
    C.Line(158,Y,1123,Y,1.5,$291F17,0.56);
  end;
  for I := 0 to 2 do
  begin
    X := 282+I*255;
    C.Rect(X,145,X+204,444,$2C211B);
    C.Rect(X+7,155,X+197,437,C.Linear(X,155,X+96,425,
      [Stop(0,$31231B),Stop(0.52,$574033),Stop(1,$241D16)]));
    for J := 1 to 15 do
    begin
      C.Rect(X+J*13-4,164,X+J*13+1,421,C.Linear(X+J*13-4,0,X+J*13+1,0,
        [Stop(0,$754F3A),Stop(0.45,$8B6348),Stop(1,$382820)]));
      C.Line(X+J*13,165,X+J*13,421,1,$C79965,0.18);
    end;
    for J := 0 to 4 do
    begin
      C.Rect(X+5,179+J*54,X+199,190+J*54,$614630);
      C.Line(X+6,180+J*54,X+198,180+J*54,1.1,$A88259,0.42);
    end;
    C.Rect(X+8,422,X+196,440,$463327);
  end;
  DrawPillar(C,155,-145,76,617,33671);
  DrawPillar(C,494,87,36,364,79931);
  DrawPillar(C,750,87,36,364,93033);
  DrawPillar(C,1049,-145,76,617,54931);
  M := C.Push(TPose.At(119,79));
  C.Timber(1042,44,$41291D,$89593D,2707,52);
  C.Restore(M);
  C.Line(120,83,1160,83,2,$CA9263,0.44);
  C.Poly([133,123,1147,123,1128,144,147,144],$30231B);
  C.Poly([110,148,190,147,409,501,328,508],$E7AD6A,0.09);
  C.Poly([195,148,222,148,444,496,410,498],$F4BF79,0.06);
  M := C.Push(TPose.At(114,-135));
  C.Timber(1052,41,$422B20,$906348,68799,55);
  C.Restore(M);
  C.Line(115,-134,1165,-134,2,$CB9D71,0.64);
  C.Line(119,-94,1161,-94,2.8,$28231D,0.72);
  C.Rect(141,123,1139,298,C.Linear(0,123,0,298,
    [Stop(0,$191812,0.59),Stop(1,$201911,0)]));
end;

procedure DrawFrontHall(C: TSanpaiCanvas; WoodColor: Cardinal);
const
  RailTop = -38;
  RailBottom = 237;
  BoardTop = 248;
  BoardBottom = 412;
  CellW = 42;
var
  M: TD2DMatrix3x2F;
  R: TGrain;
  I,J: Integer;
  X,Y,Radius: Single;
  Tint: TMaterialTint;
begin
  C.Rect(0,RailTop,1280,BoardBottom,C.Linear(0,RailTop,0,BoardBottom,
    [Stop(0,$282522),Stop(0.37,$38352A),Stop(0.68,$2D3028),Stop(1,$53473A)]));
  C.Rect(0,RailTop,1280,RailBottom,C.Radial(191,155,345,197,
    [Stop(0,$77806A,0.52),Stop(1,$47533C,0)]));
  C.Rect(0,RailTop,1280,RailBottom,C.Radial(1111,154,287,182,
    [Stop(0,$6A7760,0.42),Stop(1,$455740,0)]));
  R.State := 58093;
  C.Clip(0,RailTop,1280,RailBottom);
  try
    for I := 0 to 244 do
    begin
      X := R.Next*1280;
      Y := RailTop+R.Next*(RailBottom-RailTop);
      Radius := 2+R.Next*16;
      C.Oval(X,Y,Radius,Radius*(0.34+R.Next*0.56),$929473,0.035+R.Next*0.12);
    end;
  finally
    C.Unclip;
  end;

  Tint := C.UseTint(WoodBase,WoodColor);
  try
    C.Clip(0,RailTop,1280,RailBottom);
    try
      for I := 0 to 6 do
      begin
        Y := RailTop+16+I*42;
        C.Rect(0,Y-2,1280,Y+13,$392821,0.74);
        M := C.Push(TPose.At(0,Y));
        C.Timber(1280,10,$5A3D2D,$987457,61153+Cardinal(I)*673,29);
        C.Restore(M);
        C.Line(0,Y+1,1280,Y+1,1,$CC9E73,0.55);
      end;
      for I := 0 to 30 do
      begin
        X := 10+I*CellW;
        C.Rect(X+3,RailTop,X+12,RailBottom,$211C18,0.78);
        C.Rect(X,RailTop,X+8,RailBottom,C.Linear(X,0,X+8,0,
          [Stop(0,$5D4234),Stop(0.34,$A17A5D),Stop(0.81,$795743),Stop(1,$4F3A2D)]));
        C.Line(X+1.6,RailTop,X+1.6,RailBottom,0.9,$C6A07E,0.46);
      end;
      // 等間隔の細い桟の前に、建具を区切る太い框を置く。
      for I := 0 to 5 do
      begin
        X := 1+I*252;
        M := C.PushBasis(X+23,RailTop,0,1,-1,0);
        C.Timber(RailBottom-RailTop,23,$563D2F,$976E50,53813+Cardinal(I)*372,29);
        C.Restore(M);
        C.Line(X+21,RailTop,X+21,RailBottom,2,$32251D,0.80);
      end;
      C.Rect(0,RailTop,1280,101,C.Linear(0,RailTop,0,101,
        [Stop(0,$211A16,0.51),Stop(1,$2A211A,0)]));
    finally
      C.Unclip;
    end;

    // 格子の下を、縦木目のある板張りで画面の端までつなぐ。
    for J := 0 to 15 do
    begin
      X := J*83-21;
      M := C.PushBasis(X+81,BoardTop,0,1,-1,0);
      C.Timber(BoardBottom-BoardTop,81,$71543F,$A17E5E,45131+Cardinal(J)*677,36);
      C.Restore(M);
      C.Line(X+81,BoardTop,X+81,BoardBottom,2.4,$48372B,0.78);
      C.Line(X+2,BoardTop,X+2,BoardBottom,1.2,$CBA37B,0.63);
    end;
    C.Rect(0,BoardTop,1280,BoardBottom,C.Linear(0,BoardTop,0,BoardBottom,
      [Stop(0,$30231C,0.58),Stop(0.17,$4A3022,0.07),Stop(0.75,$553E2F,0),Stop(1,$30241E,0.34)]));

    M := C.Push(TPose.At(0,RailBottom-8));
    C.Timber(1280,27,$624432,$A17C5B,88567,50);
    C.Restore(M);
    C.Line(0,RailBottom-7,1280,RailBottom-7,1.65,$D0A785,0.64);
    M := C.Push(TPose.At(0,BoardBottom-6));
    C.Timber(1280,23,$503D32,$795E49,48247,51);
    C.Restore(M);
    C.Line(0,BoardBottom-5,1280,BoardBottom-5,1.4,$BE9A77,0.49);
    C.Line(0,BoardBottom+16,1280,BoardBottom+16,3,$302722,0.84);
  finally
    C.RestoreTint(Tint);
  end;
end;

procedure DrawConcreteSteps(C: TSanpaiCanvas);
const
  StepY: array[0..5] of Integer = (429,464,510,566,625,692);
var
  R: TGrain;
  I,J: Integer;
  Y0,Y1,Edge,X,Y,Size,ForecourtY: Single;
begin
  ForecourtY := StepY[High(StepY)];
  C.Rect(0,ForecourtY-2,1280,852,C.Linear(0,ForecourtY,0,852,
    [Stop(0,$666563),Stop(0.18,$82817C),Stop(1,$A19E93)]));
  C.Line(259,ForecourtY,117,852,1.4,$494944,0.52);
  C.Line(261,ForecourtY,119,852,1.1,$D1CAB6,0.35);
  C.Line(903,ForecourtY,987,852,1.4,$5B5950,0.52);

  R.State := 74281;
  for I := Low(StepY) to High(StepY)-1 do
  begin
    Y0 := StepY[I];
    Y1 := StepY[I+1];
    Edge := Y0+(Y1-Y0)*0.57;
    C.Rect(0,Y0,1280,Edge,C.Linear(0,Y0,0,Edge,
      [Stop(0,$737069),Stop(0.36,$97938B),Stop(1,$A9A59B)]));
    C.Rect(0,Edge,1280,Y1,C.Linear(0,Edge,0,Y1,
      [Stop(0,$89857C),Stop(0.31,$827E76),Stop(1,$65635E)]));
    C.Line(0,Edge-0.7,1280,Edge-0.7,1.55,$D0CABB,0.69);
    C.Line(0,Y1-1.3,1280,Y1-1.3,1.8,$393833,0.52);
    for J := 0 to 45 do
    begin
      X := R.Next*1280;
      Y := Y0+4+R.Next*(Y1-Y0-8);
      Size := 5+R.Next*29;
      C.Oval(X,Y,Size,Min(Y-Y0,Y1-Y)*0.42,$4C4940,0.018+R.Next*0.045);
    end;
    for J := 0 to 172 do
    begin
      X := R.Next*1280;
      Y := Y0+1.5+R.Next*(Y1-Y0-3);
      Size := 0.45+R.Next*2.05;
      C.Oval(X,Y,Size,Size*(0.26+R.Next*0.56),$4C4A45,0.12+R.Next*0.17);
      C.Oval(X-0.4,Y+0.75,Size*0.73,0.4,$DDD4C5,0.22);
    end;
    // 木の継ぎ目とは別の間隔で型枠跡を入れる。
    X := 220+I*77;
    C.Line(X,Edge+2,X+1.6,Y1-1,0.85,$504D47,0.52);
    C.Line(X+663,Edge+2,X+664.7,Y1-1,0.85,$504D47,0.47);
  end;
  for I := 0 to 438 do
  begin
    X := R.Next*1280;
    Y := ForecourtY+1+R.Next*(845-ForecourtY);
    Size := 0.45+R.Next*2;
    C.Oval(X,Y,Size,Size*(0.25+R.Next*0.5),$525048,0.10+R.Next*0.18);
  end;
end;

procedure DrawCanopy(C: TSanpaiCanvas);
var
  I: Integer;
  X,BackX: Single;
  M: TD2DMatrix3x2F;
begin
  C.Rect(0,-214,1280,-25,C.Linear(0,-200,0,-28,
    [Stop(0,$6B5241),Stop(0.38,$8F7055),Stop(0.65,$674A37),Stop(1,$423024)]));
  for I := -6 to 6 do
  begin
    X := 640+I*118;
    BackX := 640+I*103;
    C.Poly([X-12,-207,X+11,-207,BackX+12,-119,BackX-10,-119],
      C.Linear(X-12,-207,BackX+12,-119,[Stop(0,$281E19),Stop(0.41,$604431),Stop(1,$846247)]));
    C.Line(X-10,-207,BackX-8,-119,1.3,$B38360,0.57);
  end;
  M := C.Push(TPose.At(0,-207));
  C.Timber(1280,31,$523B30,$8C674E,71371,51);
  C.Restore(M);
  C.Line(0,-177,1280,-177,2,$3D2C23,0.69);
  M := C.Push(TPose.At(0,-122));
  C.Timber(1280,59,$4E382B,$8D664B,68799,69);
  C.Restore(M);
  C.Line(0,-121,1280,-121,1.8,$C18E66,0.63);
  C.Line(0,-65,1280,-65,2.5,$3D2C20,0.83);
  M := C.Push(TPose.At(0,-62));
  C.Timber(1280,24,$4B3427,$79553C,82517,37);
  C.Restore(M);
  C.Line(0,-39,1280,-39,2.2,$3D2C22,0.78);
end;

procedure DrawShimenawa(C: TSanpaiCanvas);
var
  I: Integer;
  X,Y: Single;
begin
  C.Curve([217,98,410,131,502,150,640,151,778,150,870,131,1063,98],
    18,$231D15,0.79);
  C.Curve([217,92,400,131,510,144,640,145,770,144,880,131,1063,92],
    15,$AD8758);
  C.Curve([217,89,400,128,510,141,640,142,770,141,880,128,1063,89],
    7,$D0AE75);
  for I := 1 to 116 do
  begin
    X := 218+I*7.25;
    Y := 145-53*Sqr((X-640)/423);
    C.Curve([X-5,Y-5,X-2,Y-4,X+3,Y+1,X+5,Y+7],1.7,$5E4831,0.74);
    C.Curve([X-4,Y-6,X-1,Y-5,X+4,Y,X+6,Y+6],0.8,$E6C991,0.73);
  end;
  for I := 0 to 5 do
  begin
    X := 272+I*147;
    Y := 146-48*Sqr((X-640)/420);
    C.Poly([X-7,Y,X+12,Y+4,X+10,Y+21,X+21,Y+26,X+15,Y+47,X+24,Y+54,
      X+15,Y+75,X-5,Y+66,X+1,Y+53,X-9,Y+46,X-3,Y+32,X-13,Y+25],
      C.Linear(X-8,Y,X+29,Y+74,
      [Stop(0,$BFB6A0),Stop(0.55,$E6DBBF),Stop(1,$AF9F85)]));
    C.Line(X-7,Y+26,X+10,Y+31,1.4,$877C68,0.46);
    C.Line(X-3,Y+48,X+15,Y+54,1.4,$877C68,0.45);
  end;
end;

procedure DrawShrine(C: TSanpaiCanvas; const Pose: TPose; View: TShrineView; const Palette: TSanpaiPalette);
var
  Viewport,World,Roof: TD2DMatrix3x2F;
  Tint: TMaterialTint;
  Top: Integer;
begin
  if View=svUpper then Top := ShrineUpperTop else Top := ShrineLowerTop;
  Viewport := C.Push(Pose);
  try
    C.Clip(0,0,ShrineWidth,ShrineHeight);
    try
      World := C.Push(TPose.At(0,-Top));
      if View=svFortunes then DrawGrove(C);
      Tint := C.UseTint(FoundationBase,Palette.Foundation);
      try
        if View=svFortunes then
        begin
          DrawFloor(C);
          DrawFortuneSteps(C);
        end
        else DrawConcreteSteps(C);
      finally
        C.RestoreTint(Tint);
      end;

      if View=svFortunes then
      begin
        Tint := C.UseTint(WoodBase,Palette.Wood);
        try
          DrawFortuneHall(C);
        finally
          C.RestoreTint(Tint);
        end;
      end
      else DrawFrontHall(C,Palette.Wood);

      if View=svUpper then
      begin
        Tint := C.UseTint(WoodBase,Palette.Wood);
        try
          DrawCanopy(C);
        finally
          C.RestoreTint(Tint);
        end;
        Roof := C.PushBasis(-256,-154,1.4,0,0,0.56);
        DrawShimenawa(C);
        C.Restore(Roof);
      end;
      C.Rect(0,ShrineUpperTop,ShrineWidth,ShrineLowerTop+ShrineHeight,
        C.Radial(640,278,752,700,[Stop(0,$241C15,0),Stop(0.55,$241C15,0.015),Stop(1,$161F17,0.33)]));
      C.Restore(World);
    finally
      C.Unclip;
    end;
  finally
    C.Restore(Viewport);
  end;
end;

end.
