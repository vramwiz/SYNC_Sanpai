unit Sanpai_Timeline;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// オブジェクト内の時刻に基づいて演出の進行を求める。

interface

type
  // AviUtl2 の選択欄は値が小さい順に並ぶため、演出順を列挙値に合わせる。
  TSanpaiScene = (ssOfferingBox, ssOfferingRear, ssBell, ssBellRear, ssTube, ssFortunes);
  TFortuneReveal = (frShow, frFold, frRoll, frFlip, frPull);
  TFortuneEffect = (feNone, feFloat, feFade, feBounce);

  TSanpaiPalette = packed record
    Wood, Foundation, Box, Bell, Rope, Tube, Text, Paper: Cardinal;
  end;

  TSanpaiVisual = packed record
    Scene: TSanpaiScene;
    Auxiliary: Boolean;
    AuxiliaryX, AuxiliaryY, Strength: Single;
    OfferingX, OfferingY: Single;
    FortuneX, FortuneY, FortuneScale: Single;
    Coins, Bills, Fortune: Integer;
    Reveal: TFortuneReveal;
    FortuneEffect: TFortuneEffect;
    Palette: TSanpaiPalette;
  end;

  // Delay、Duration、Progress に渡す Time はオブジェクト内の秒数。
  TSanpaiTiming = record
    Delay, Duration: Double;
    // 開始前は -1。開始後は 0～1。時間0なら開始時刻で完了する。
    function Progress(Time: Double): Double;
  end;

  TSanpaiSettings = record
    Visual: TSanpaiVisual;
    Timing: TSanpaiTiming;
  end;

  TOfferingCue = record
    Start, Contact, Drop, Side, Slot, Turn: Double;
  end;

function IsRear(Scene: TSanpaiScene): Boolean;
// 枚数と番号から、投入のタイミングと軌道を求める。
function OfferingCue(Index, Total: Integer; Paper: Boolean): TOfferingCue;
function Ease(Value: Double): Double;
function ShakeEnvelope(Progress: Double): Double;

const
  DefaultFortuneEffect = feFloat;
  WoodBase = $997052;
  FoundationBase = $96928B;
  BoxBase = $9B6A45;
  BellBase = $BDA072;
  RopeBase = $CBB68E;
  TubeBase = $C89459;
  TextBase = $913D35;
  WashiBase = $F3E8CC;
  DefaultPalette: TSanpaiPalette = (Wood:WoodBase; Foundation:FoundationBase;
    Box:BoxBase; Bell:BellBase; Rope:RopeBase; Tube:TubeBase; Text:TextBase; Paper:WashiBase);

  TubeStickStart = 0.72;

implementation

uses
  System.Math;

function TSanpaiTiming.Progress(Time: Double): Double;
begin
  if IsNan(Time) or (Time<Delay) then Exit(-1);
  if Duration<=0 then Exit(1);
  Result := Min(1,(Time-Delay)/Duration);
end;

function IsRear(Scene: TSanpaiScene): Boolean;
begin
  Result := Scene in [ssOfferingRear,ssBellRear];
end;

function Ease(Value: Double): Double;
begin
  Value := EnsureRange(Value,0.0,1.0);
  Result := Sqr(Value)*(3-2*Value);
end;

function ShakeEnvelope(Progress: Double): Double;
begin
  if (Progress<=0) or (Progress>=1) then Exit(0);
  Result := Sqr(Sin(Pi*Progress));
end;

function OfferingCue(Index, Total: Integer; Paper: Boolean): TOfferingCue;
var
  Seed, Part: Integer;
begin
  Seed := Index*73+Ord(Paper)*41+27;
  Part := (Seed*53) mod 101;
  Result.Start := 0.035+0.47*(Index+(Part+1)/104)/Max(1,Total);
  Result.Contact := Result.Start+0.25+(Seed mod 15)*0.005+0.035*Ord(Paper);
  Result.Drop := Result.Contact+0.105+0.03*Ord(Paper);
  Result.Side := ((Seed*29) mod 97-48)/48;
  Result.Slot := ((Seed*37) mod 13-6)*27.7;
  Result.Turn := ((Seed*47) mod 109)/109;
end;

end.
