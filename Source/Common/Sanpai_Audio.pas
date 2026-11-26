unit Sanpai_Audio;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// 投入・揺れ・棒の取り出しに同期した効果音を Float32 PCM として生成する。

interface

uses
  Sanpai_Timeline;

// Samples は呼出元のバッファ。オブジェクト内の絶対サンプル位置で再現する。
procedure RenderSanpaiAudio(const Settings: TSanpaiSettings; FirstSample: Int64;
  Rate: Integer; var Samples: TArray<Single>);

implementation

uses
  System.Math;

type
  TVoice = (svCoin, svBox, svBell, svWood, svStick);
  TMode = record
    Hz, Gain, Decay: Double;
  end;

const
  VoiceLength: array[TVoice] of Double = (0.15,0.085,0.51,0.064,0.095);
  NoiseGain: array[TVoice] of Double = (0.13,0.28,0.049,0.31,0.39);
  Modes: array[TVoice,0..5] of TMode = (
    ((Hz:1184;Gain:0.36;Decay:0.030),(Hz:2374;Gain:0.26;Decay:0.041),
     (Hz:3511;Gain:0.24;Decay:0.035),(Hz:4483;Gain:0.16;Decay:0.025),
     (Hz:5399;Gain:0.13;Decay:0.015),(Hz:6860;Gain:0.08;Decay:0.009)),
    ((Hz:176;Gain:0.43;Decay:0.026),(Hz:412;Gain:0.28;Decay:0.019),
     (Hz:615;Gain:0.17;Decay:0.018),(Hz:1007;Gain:0.12;Decay:0.011),
     (Hz:1723;Gain:0.06;Decay:0.008),(Hz:2659;Gain:0.030;Decay:0.005)),
    ((Hz:537;Gain:0.28;Decay:0.23),(Hz:782;Gain:0.21;Decay:0.17),
     (Hz:1173;Gain:0.24;Decay:0.26),(Hz:1739;Gain:0.20;Decay:0.105),
     (Hz:2579;Gain:0.16;Decay:0.073),(Hz:3712;Gain:0.11;Decay:0.039)),
    ((Hz:249;Gain:0.38;Decay:0.018),(Hz:524;Gain:0.29;Decay:0.013),
     (Hz:855;Gain:0.15;Decay:0.010),(Hz:1441;Gain:0.12;Decay:0.008),
     (Hz:2288;Gain:0.085;Decay:0.006),(Hz:3167;Gain:0.041;Decay:0.005)),
    ((Hz:302;Gain:0.31;Decay:0.021),(Hz:622;Gain:0.23;Decay:0.018),
     (Hz:1032;Gain:0.22;Decay:0.017),(Hz:1562;Gain:0.15;Decay:0.011),
     (Hz:2461;Gain:0.10;Decay:0.010),(Hz:3251;Gain:0.058;Decay:0.007)));

function Noise(Sample: Int64; Seed: Cardinal): Double;
var
  Bits: Cardinal;
begin
  Bits := Cardinal(Sample and $FFFFFFFF) xor Seed;
  Bits := Bits xor (Bits shl 13);
  Bits := Bits xor (Bits shr 17);
  Bits := Bits xor (Bits shl 5);
  Result := ((Bits shr 12) and $FFFF)/32767.5-1;
end;

function VoiceSample(Voice: TVoice; T,Pitch,Nyquist: Double; Index: Int64; Seed: Cardinal): Double;
var
  Mode: TMode;
  F: Double;
begin
  Result := NoiseGain[Voice]*(Noise(Index,Seed)-0.68*Noise(Index-1,Seed))*Exp(-T/0.006);
  for Mode in Modes[Voice] do
  begin
    F := Mode.Hz*Pitch;
    if F<Nyquist then Result := Result+Mode.Gain*Exp(-T/Mode.Decay)*Sin(2*Pi*F*T);
  end;
end;

procedure RenderSanpaiAudio(const Settings: TSanpaiSettings; FirstSample: Int64;
  Rate: Integer; var Samples: TArray<Single>);
var
  I: Integer;
  P,V: Double;
  Cue: TOfferingCue;

  procedure Mix(Voice: TVoice; Phase,Gain,Pitch: Double; Seed: Cardinal);
  var
    StartAt,FinishAt,T,Fade,X: Double;
    Head,Tail,Sample: Int64;
    J: Integer;
  begin
    StartAt := Settings.Timing.Delay+Settings.Timing.Duration*Phase;
    FinishAt := Min(Settings.Timing.Delay+Settings.Timing.Duration,StartAt+VoiceLength[Voice]);
    Head := Max(FirstSample,Ceil(StartAt*Rate));
    Tail := Min(FirstSample+Length(Samples),Ceil(FinishAt*Rate));
    for Sample := Head to Tail-1 do
    begin
      T := Sample/Rate-StartAt;
      Fade := Min(1.0,T/0.0008)*Min(1.0,(FinishAt-Sample/Rate)/0.023);
      X := VoiceSample(Voice,T,Pitch,Rate*0.47,Sample,Seed);
      J := Integer(Sample-FirstSample);
      Samples[J] := Samples[J]+Fade*Gain*X;
    end;
  end;

begin
  if Length(Samples)=0 then Exit;
  FillChar(Samples[0],Length(Samples)*SizeOf(Single),0);
  if not Settings.Sound or (Settings.Volume<=0) or (Settings.Timing.Duration<=0) or
    (FirstSample+Length(Samples)<=Settings.Timing.Delay*Rate) or
    (FirstSample>=(Settings.Timing.Delay+Settings.Timing.Duration)*Rate) then Exit;

  case Settings.Visual.Scene of
    ssOfferingBox,ssOfferingRear:
      for I := 0 to Settings.Visual.Coins-1 do
      begin
        Cue := OfferingCue(I,Settings.Visual.Coins,False);
        Mix(svCoin,Cue.Contact,0.49,0.89+Cue.Turn*0.22,91453+Cardinal(I)*47519);
        Mix(svCoin,Cue.Contact+0.025,0.22,1.03+Cue.Turn*0.18,61493+Cardinal(I)*37897);
        Mix(svBox,Cue.Drop-0.014,0.35,0.90+Cue.Turn*0.19,86843+Cardinal(I)*94603);
      end;
    ssBell,ssBellRear:
      if Settings.Visual.Strength>0 then
        for I := 0 to BellImpactCount-1 do
        begin
          P := BellImpact(I);
          V := ShakeEnvelope(P)*Settings.Visual.Strength/50;
          Mix(svBell,P,0.38*V,1.0+0.008*(2*Ord(Odd(I))-1),61789+Cardinal(I)*99817);
          Mix(svCoin,P+0.013,0.081*V,0.74,27527+Cardinal(I)*14779);
        end;
    ssTube:
      begin
        if Settings.Visual.Strength>0 then
          for I := 0 to High(TubeRattle) do
          begin
            P := TubeRattle[I];
            V := (0.35+0.65*ShakeEnvelope(P/0.65))*Settings.Visual.Strength/50;
            Mix(svWood,P,0.39*V,0.81+((I*7) mod 13)*0.032,71453+Cardinal(I)*45919);
            Mix(svWood,P+0.019,0.18*V,1.13,85751+Cardinal(I)*59809);
          end;
        Mix(svStick,TubeStickStart+0.042,0.43,0.94,78731);
      end;
  end;

  for I := 0 to High(Samples) do
  begin
    V := Samples[I];
    Samples[I] := (V/(1+Abs(V)))*Settings.Volume/100;
  end;
end;

end.
