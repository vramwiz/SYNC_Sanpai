unit Sanpai_Drawing;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// Direct2D の図形、グラデーション、木目と座標変換を描画レイヤーで共有する。

interface

uses
  System.Math, Winapi.D2D1;

type
  TPose = record
    X, Y, Scale, Angle: Single;
    class function At(X, Y: Single; Scale: Single = 1; Angle: Single = 0): TPose; static;
  end;

  TGrain = record
    State: Cardinal;
    function Next: Single;
  end;

  TMaterialTint = record
    Base, Target: Cardinal;
  end;

  TSanpaiCanvas = class
  private
    FFactory: ID2D1Factory;
    FTarget: ID2D1RenderTarget;
    FSolid: ID2D1SolidColorBrush;
    FOpacityLayer: ID2D1Layer;
    FTint: TMaterialTint;
    function MaterialColor(Color: Cardinal): Cardinal;
    function GradientColors(const Stops: array of TD2D1GradientStop): ID2D1GradientStopCollection;
    function Solid(Color: Cardinal; Alpha: Single): ID2D1Brush;
  public
    // BeginDraw と EndDraw は呼出元が管理する。ポーズは現在の変換に合成する。
    constructor Create(const Factory: ID2D1Factory; const Target: ID2D1RenderTarget);
    function Push(const Pose: TPose): TD2DMatrix3x2F;
    function PushBasis(X, Y, XX, XY, YX, YY: Single): TD2DMatrix3x2F;
    procedure Restore(const Matrix: TD2DMatrix3x2F);
    // 描画する材質の基準色を Target に対応させる。呼出元は返された設定を復元する。
    function UseTint(Base,Target: Cardinal): TMaterialTint;
    procedure RestoreTint(const Tint: TMaterialTint);
    procedure Clip(L,T,R,B: Single);
    procedure Unclip;
    // 重なった図形も一枚の面として透過させる。Push/Popは組で呼ぶ。
    procedure PushOpacity(L,T,R,B,Opacity: Single);
    procedure PopOpacity;
    function Linear(X1,Y1,X2,Y2: Single; const Stops: array of TD2D1GradientStop): ID2D1Brush;
    function Radial(X,Y,RX,RY: Single; const Stops: array of TD2D1GradientStop): ID2D1Brush;
    procedure Rect(L,T,R,B: Single; Color: Cardinal; Alpha: Single = 1); overload;
    procedure Rect(L,T,R,B: Single; const Brush: ID2D1Brush); overload;
    procedure Oval(X,Y,RX,RY: Single; Color: Cardinal; Alpha: Single = 1); overload;
    procedure Oval(X,Y,RX,RY: Single; const Brush: ID2D1Brush); overload;
    procedure Line(X1,Y1,X2,Y2,Width: Single; Color: Cardinal; Alpha: Single = 1);
    procedure Poly(const XY: array of Single; Color: Cardinal; Alpha: Single = 1); overload;
    procedure Poly(const XY: array of Single; const Brush: ID2D1Brush); overload;
    // XY は開始点に続けて各ベジェ区間の制御点2個・終点1個を指定する。
    procedure Shape(const XY: array of Single; Color: Cardinal; Alpha: Single = 1); overload;
    procedure Shape(const XY: array of Single; const Brush: ID2D1Brush); overload;
    procedure Curve(const XY: array of Single; Width: Single; Color: Cardinal; Alpha: Single = 1);
    // ローカル横方向に木目を引く。垂直面や斜面は呼出元で基底を変換する。
    procedure Timber(W,H: Single; Dark,Light: Cardinal; Seed: Cardinal; GrainCount: Integer);
  end;

function Stop(P: Single; Color: Cardinal; Alpha: Single = 1): TD2D1GradientStop;

implementation

uses
  System.Win.ComObj;

class function TPose.At(X, Y, Scale, Angle: Single): TPose;
begin
  Result.X := X;
  Result.Y := Y;
  Result.Scale := Scale;
  Result.Angle := Angle;
end;

function TGrain.Next: Single;
begin
  State := State xor (State shl 13);
  State := State xor (State shr 17);
  State := State xor (State shl 5);
  Result := (State and $FFFFFF) / 16777216.0;
end;

function RGB(Color: Cardinal; Alpha: Single): TD2D1ColorF;
begin
  Result := D2D1ColorF(((Color shr 16) and $FF) / 255, ((Color shr 8) and $FF) / 255,
    (Color and $FF) / 255, Alpha);
end;

function Stop(P: Single; Color: Cardinal; Alpha: Single): TD2D1GradientStop;
begin
  Result := D2D1GradientStop(P, RGB(Color, Alpha));
end;

constructor TSanpaiCanvas.Create(const Factory: ID2D1Factory; const Target: ID2D1RenderTarget);
begin
  inherited Create;
  FFactory := Factory;
  FTarget := Target;
  OleCheck(FTarget.CreateSolidColorBrush(RGB(0, 1), nil, FSolid));
end;

function TSanpaiCanvas.Solid(Color: Cardinal; Alpha: Single): ID2D1Brush;
begin
  FSolid.SetColor(RGB(MaterialColor(Color), Alpha));
  Result := FSolid;
end;

function TSanpaiCanvas.Push(const Pose: TPose): TD2DMatrix3x2F;
var
  C, S: Single;
begin
  C := Cos(DegToRad(Pose.Angle)) * Pose.Scale;
  S := Sin(DegToRad(Pose.Angle)) * Pose.Scale;
  Result := PushBasis(Pose.X, Pose.Y, C, S, -S, C);
end;

function TSanpaiCanvas.PushBasis(X, Y, XX, XY, YX, YY: Single): TD2DMatrix3x2F;
var
  M: TD2DMatrix3x2F;
begin
  FTarget.GetTransform(Result);
  M._11 := XX * Result._11 + XY * Result._21;
  M._12 := XX * Result._12 + XY * Result._22;
  M._21 := YX * Result._11 + YY * Result._21;
  M._22 := YX * Result._12 + YY * Result._22;
  M._31 := X * Result._11 + Y * Result._21 + Result._31;
  M._32 := X * Result._12 + Y * Result._22 + Result._32;
  FTarget.SetTransform(M);
end;

procedure TSanpaiCanvas.Restore(const Matrix: TD2DMatrix3x2F);
begin
  FTarget.SetTransform(Matrix);
end;

function TSanpaiCanvas.UseTint(Base,Target: Cardinal): TMaterialTint;
begin
  Result := FTint;
  FTint.Base := Base;
  FTint.Target := Target;
end;

procedure TSanpaiCanvas.RestoreTint(const Tint: TMaterialTint);
begin
  FTint := Tint;
end;

function TSanpaiCanvas.MaterialColor(Color: Cardinal): Cardinal;
var
  I,Shift,Original,Base,Target,Channel: Integer;
begin
  if FTint.Base=FTint.Target then Exit(Color);
  Result := 0;
  for I := 0 to 2 do
  begin
    Shift := 8*I;
    Original := Integer((Color shr Shift) and $FF);
    Base := Integer((FTint.Base shr Shift) and $FF);
    Target := Integer((FTint.Target shr Shift) and $FF);
    // 影側は黒から基準色へ、光側は基準色から白へ補間する。
    if Original=Base then Channel := Target
    else if Original<Base then Channel := (Original*Target+Base div 2) div Base
    else Channel := Target+((Original-Base)*(255-Target)+(255-Base) div 2) div (255-Base);
    Result := Result or (Cardinal(Channel) shl Shift);
  end;
end;

function TSanpaiCanvas.GradientColors(const Stops: array of TD2D1GradientStop): ID2D1GradientStopCollection;
var
  Adjusted: array of TD2D1GradientStop;
  I: Integer;
  Color: Cardinal;
begin
  if FTint.Base=FTint.Target then
    OleCheck(FTarget.CreateGradientStopCollection(@Stops[0], Length(Stops), D2D1_GAMMA_2_2,
      D2D1_EXTEND_MODE_CLAMP, Result))
  else
  begin
    SetLength(Adjusted,Length(Stops));
    for I := 0 to High(Stops) do
    begin
      Color := (Cardinal(Round(Stops[I].color.r*255)) shl 16) or
        (Cardinal(Round(Stops[I].color.g*255)) shl 8) or Cardinal(Round(Stops[I].color.b*255));
      Adjusted[I] := Stop(Stops[I].position,MaterialColor(Color),Stops[I].color.a);
    end;
    OleCheck(FTarget.CreateGradientStopCollection(@Adjusted[0], Length(Adjusted), D2D1_GAMMA_2_2,
      D2D1_EXTEND_MODE_CLAMP, Result));
  end;
end;

procedure TSanpaiCanvas.Clip(L,T,R,B: Single);
begin
  FTarget.PushAxisAlignedClip(D2D1RectF(L,T,R,B), D2D1_ANTIALIAS_MODE_ALIASED);
end;

procedure TSanpaiCanvas.Unclip;
begin
  FTarget.PopAxisAlignedClip;
end;

procedure TSanpaiCanvas.PushOpacity(L,T,R,B,Opacity: Single);
var
  Parameters: TD2D1LayerParameters;
begin
  if FOpacityLayer=nil then OleCheck(FTarget.CreateLayer(nil,FOpacityLayer));
  Parameters := Default(TD2D1LayerParameters);
  Parameters.contentBounds := D2D1RectF(L,T,R,B);
  Parameters.maskAntialiasMode := D2D1_ANTIALIAS_MODE_PER_PRIMITIVE;
  Parameters.maskTransform := TD2DMatrix3x2F.Identity;
  Parameters.opacity := Opacity;
  Parameters.layerOptions := D2D1_LAYER_OPTIONS_NONE;
  FTarget.PushLayer(Parameters,FOpacityLayer);
end;

procedure TSanpaiCanvas.PopOpacity;
begin
  FTarget.PopLayer;
end;

function TSanpaiCanvas.Linear(X1,Y1,X2,Y2: Single; const Stops: array of TD2D1GradientStop): ID2D1Brush;
var
  Colors: ID2D1GradientStopCollection;
  Brush: ID2D1LinearGradientBrush;
begin
  Colors := GradientColors(Stops);
  OleCheck(FTarget.CreateLinearGradientBrush(D2D1LinearGradientBrushProperties(
    D2D1PointF(X1,Y1), D2D1PointF(X2,Y2)), nil, Colors, Brush));
  Result := Brush;
end;

function TSanpaiCanvas.Radial(X,Y,RX,RY: Single; const Stops: array of TD2D1GradientStop): ID2D1Brush;
var
  Colors: ID2D1GradientStopCollection;
  Brush: ID2D1RadialGradientBrush;
begin
  Colors := GradientColors(Stops);
  OleCheck(FTarget.CreateRadialGradientBrush(D2D1RadialGradientBrushProperties(
    D2D1PointF(X,Y), D2D1PointF(0,0), RX, RY), nil, Colors, Brush));
  Result := Brush;
end;

procedure TSanpaiCanvas.Rect(L,T,R,B: Single; Color: Cardinal; Alpha: Single);
begin
  Rect(L,T,R,B,Solid(Color,Alpha));
end;

procedure TSanpaiCanvas.Rect(L,T,R,B: Single; const Brush: ID2D1Brush);
begin
  FTarget.FillRectangle(D2D1RectF(L,T,R,B),Brush);
end;

procedure TSanpaiCanvas.Oval(X,Y,RX,RY: Single; Color: Cardinal; Alpha: Single);
begin
  Oval(X,Y,RX,RY,Solid(Color,Alpha));
end;

procedure TSanpaiCanvas.Oval(X,Y,RX,RY: Single; const Brush: ID2D1Brush);
begin
  FTarget.FillEllipse(D2D1Ellipse(D2D1PointF(X,Y),RX,RY),Brush);
end;

procedure TSanpaiCanvas.Line(X1,Y1,X2,Y2,Width: Single; Color: Cardinal; Alpha: Single);
begin
  FTarget.DrawLine(D2D1PointF(X1,Y1),D2D1PointF(X2,Y2),Solid(Color,Alpha),Width,nil);
end;

function Geometry(const Factory: ID2D1Factory; const XY: array of Single;
  IsCurve, Closed: Boolean): ID2D1PathGeometry;
var
  Sink: ID2D1GeometrySink;
  Bezier: TD2D1BezierSegment;
  I: Integer;
begin
  OleCheck(Factory.CreatePathGeometry(Result));
  OleCheck(Result.Open(Sink));
  if Closed then
    Sink.BeginFigure(D2D1PointF(XY[0], XY[1]), D2D1_FIGURE_BEGIN_FILLED)
  else
    Sink.BeginFigure(D2D1PointF(XY[0], XY[1]), D2D1_FIGURE_BEGIN_HOLLOW);
  I := 2;
  while I < Length(XY) do
    if IsCurve then
    begin
      Bezier.point1 := D2D1PointF(XY[I], XY[I+1]);
      Bezier.point2 := D2D1PointF(XY[I+2], XY[I+3]);
      Bezier.point3 := D2D1PointF(XY[I+4], XY[I+5]);
      Sink.AddBezier(Bezier);
      Inc(I,6);
    end
    else
    begin
      Sink.AddLine(D2D1PointF(XY[I], XY[I+1]));
      Inc(I,2);
    end;
  if Closed then Sink.EndFigure(D2D1_FIGURE_END_CLOSED)
  else Sink.EndFigure(D2D1_FIGURE_END_OPEN);
  OleCheck(Sink.Close);
end;

procedure TSanpaiCanvas.Poly(const XY: array of Single; Color: Cardinal; Alpha: Single);
begin
  Poly(XY,Solid(Color,Alpha));
end;

procedure TSanpaiCanvas.Poly(const XY: array of Single; const Brush: ID2D1Brush);
begin
  FTarget.FillGeometry(Geometry(FFactory,XY,False,True),Brush,nil);
end;

procedure TSanpaiCanvas.Shape(const XY: array of Single; Color: Cardinal; Alpha: Single);
begin
  Shape(XY,Solid(Color,Alpha));
end;

procedure TSanpaiCanvas.Shape(const XY: array of Single; const Brush: ID2D1Brush);
begin
  FTarget.FillGeometry(Geometry(FFactory,XY,True,True),Brush,nil);
end;

procedure TSanpaiCanvas.Curve(const XY: array of Single; Width: Single; Color: Cardinal; Alpha: Single);
begin
  FTarget.DrawGeometry(Geometry(FFactory,XY,True,False),Solid(Color,Alpha),Width,nil);
end;

procedure TSanpaiCanvas.Timber(W,H: Single; Dark,Light: Cardinal; Seed: Cardinal; GrainCount: Integer);
var
  Grain: TGrain;
  I: Integer;
  X,Y,L,A,KnotX,KnotY,KnotW: Single;
begin
  Rect(0,0,W,H,Linear(0,0,H*0.6,H,[Stop(0,Dark),Stop(0.24,Light),
    Stop(0.62,Light),Stop(1,Dark)]));
  Grain.State := Seed;
  for I := 1 to GrainCount do
  begin
    X := Grain.Next * W * 0.85;
    Y := 2 + Grain.Next * Max(0,H - 4);
    L := Min(W-X, (0.04 + Grain.Next * 0.52)*W);
    A := (Grain.Next - 0.5)*Min(5,H*0.13);
    Curve([X,Y,X+L*0.26,Y+A,X+L*0.70,Y-A,X+L,Y+A*0.2],0.5+Grain.Next,
      $2D170F,0.10+Grain.Next*0.15);
    if Y < H-2 then
      Curve([X,Y+1.1,X+L*0.26,Y+A+1.1,X+L*0.70,Y-A+1.1,X+L,Y+A*0.2+1.1],
        0.65,$FFCF91,0.12);
  end;
  if (H > 14) and (W > 70) then
  begin
    KnotX := W*(0.21+Grain.Next*0.58);
    KnotY := H*(0.34+Grain.Next*0.29);
    KnotW := Min(W*0.08,H*1.2);
    for I := 1 to 4 do
    begin
      L := KnotW * (0.35+I*0.2);
      A := I*1.4;
      Curve([KnotX-L,KnotY,KnotX-L*0.3,KnotY-A,KnotX+L*0.39,KnotY-A,
        KnotX+L,KnotY,KnotX+L*0.38,KnotY+A,KnotX-L*0.34,KnotY+A,KnotX-L,KnotY],
        0.65,$3C2118,0.23);
    end;
    Oval(KnotX,KnotY,KnotW*0.16,0.85,$412419,0.32);
  end;
end;

end.
