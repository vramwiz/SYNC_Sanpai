unit Sanpai_Renderer;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// WIC のオフスクリーン面へ Direct2D で描き、AviUtl2 用 RGBA を返す。

interface

uses
  Winapi.D2D1, Winapi.Wincodec, AviUtl2FilterTypes, Sanpai_Drawing, Sanpai_Shrine, Sanpai_Timeline;

type
  TSanpaiRenderer = class
  private
    FFactory: ID2D1Factory;
    FWic: IWICImagingFactory;
    FSurface: IWICBitmap;
    FTarget: ID2D1RenderTarget;
    FBackground: ID2D1Bitmap;
    FBackgroundView: TShrineView;
    FBackgroundWood,FBackgroundFoundation: Cardinal;
    FCanvas: TSanpaiCanvas;
    FPixels: TArray<TPIXEL_RGBA>;
    FWidth, FHeight: Integer;
    FLastVisual: TSanpaiVisual;
    FLastProgress: Double;
    FFrameReady: Boolean;
    procedure ResetSurface;
    procedure EnsureSurface(Width,Height: Integer);
    procedure BuildBackground(View: TShrineView; const Palette: TSanpaiPalette);
    procedure DrawFrame(const Visual: TSanpaiVisual; Progress: Double);
    procedure ReadPixels(Transparent: Boolean);
  public
    destructor Destroy; override;
    // Time はオブジェクト内の秒数。無効な画像寸法では nil を返す。
    // 返す RGBA の所有権は描画器にある。次の Render 呼出しまで使用できる。
    // 同じ描画器の呼出しはホスト側で直列化する。
    function Render(Width,Height: Integer; const Settings: TSanpaiSettings; Time: Double): PPIXEL_RGBA;
  end;

const
  SANPAI_MAX_SIDE = 8192;
  SANPAI_MAX_PIXELS = 33554432;

implementation

uses
  System.Math, System.SysUtils, System.Win.ComObj, Winapi.Windows, Winapi.ActiveX,
  Winapi.DXGIFormat, Sanpai_OfferingBox, Sanpai_Offerings, Sanpai_Bell, Sanpai_Fortunes, Sanpai_Tube;

function CenteredPose(Width,Height: Integer; Cover: Boolean): TPose;
var
  Scale: Single;
begin
  if Cover then Scale := Max(Width/ShrineWidth,Height/ShrineHeight)
  else Scale := Min(Width/ShrineWidth,Height/ShrineHeight);
  Result := TPose.At((Width-ShrineWidth*Scale)/2,(Height-ShrineHeight*Scale)/2,Scale);
end;

function ShrinePose(Width,Height: Integer; View: TShrineView): TPose;
begin
  Result := CenteredPose(Width,Height,True);
  // 横長でも、鈴の取り付け位置が画面内に入る高さを確保する。
  if View=svUpper then
    Result.Y := Max(Result.Y, Height*0.1-ShrineBellScreenY*Result.Scale);
end;

destructor TSanpaiRenderer.Destroy;
begin
  ResetSurface;
  inherited;
end;

procedure TSanpaiRenderer.ResetSurface;
begin
  FreeAndNil(FCanvas);
  FBackground := nil;
  FTarget := nil;
  FSurface := nil;
  FPixels := nil;
  FFrameReady := False;
end;

procedure TSanpaiRenderer.EnsureSurface(Width,Height: Integer);
var
  Properties: TD2D1RenderTargetProperties;
begin
  if Assigned(FCanvas) and (FWidth=Width) and (FHeight=Height) then Exit;
  ResetSurface;
  if FFactory=nil then
    OleCheck(D2D1CreateFactory(D2D1_FACTORY_TYPE_MULTI_THREADED,IID_ID2D1Factory,nil,FFactory));
  if FWic=nil then
    OleCheck(CoCreateInstance(CLSID_WICImagingFactory,nil,CLSCTX_INPROC_SERVER,
      IID_IWICImagingFactory,FWic));
  OleCheck(FWic.CreateBitmap(Width,Height,@GUID_WICPixelFormat32bppPBGRA,WICBitmapCacheOnLoad,FSurface));
  Properties := D2D1RenderTargetProperties(D2D1_RENDER_TARGET_TYPE_SOFTWARE,
    D2D1PixelFormat(DXGI_FORMAT_B8G8R8A8_UNORM,D2D1_ALPHA_MODE_PREMULTIPLIED),96,96);
  OleCheck(FFactory.CreateWicBitmapRenderTarget(FSurface,Properties,FTarget));
  FCanvas := TSanpaiCanvas.Create(FFactory,FTarget);
  FWidth := Width;
  FHeight := Height;
  SetLength(FPixels,Width*Height);
end;

// 同じ構図・木の色・土台の色で再利用できるよう、背景を独立した面へ描く。
procedure TSanpaiRenderer.BuildBackground(View: TShrineView; const Palette: TSanpaiPalette);
var
  Target: ID2D1BitmapRenderTarget;
  BackCanvas: TSanpaiCanvas;
begin
  OleCheck(FTarget.CreateCompatibleRenderTarget(nil,nil,nil,D2D1_COMPATIBLE_RENDER_TARGET_OPTIONS_NONE,Target));
  BackCanvas := TSanpaiCanvas.Create(FFactory,Target);
  try
    Target.BeginDraw;
    try
      Target.Clear(D2D1ColorF(0.20,0.17,0.13,1));
      DrawShrine(BackCanvas,ShrinePose(FWidth,FHeight,View),View,Palette);
    finally
      OleCheck(Target.EndDraw);
    end;
    OleCheck(Target.GetBitmap(FBackground));
    FBackgroundView := View;
    FBackgroundWood := Palette.Wood;
    FBackgroundFoundation := Palette.Foundation;
  finally
    BackCanvas.Free;
  end;
end;

procedure TSanpaiRenderer.DrawFrame(const Visual: TSanpaiVisual; Progress: Double);
const
  BellScale = 0.95;
  BoxY = 329;
  PaperCenter = 360;
  PaperScale = 1.05;
var
  Zoom: TD2D1RectF;
  M: TD2DMatrix3x2F;
  View: TShrineView;
  Foreground,Background,BoxPose,BellPose,FortunePose: TPose;
  BellY,FrameBottom: Single;
  Rear: Boolean;
  PaperColors: TFortuneColors;

  procedure DrawBellAt(const Pose: TPose; P,Strength: Double);
  begin
    if Rear then DrawBellCeiling(FCanvas,Pose,Visual.Palette.Wood);
    DrawBell(FCanvas,Pose,P,Strength,(FrameBottom-Pose.Y)/Pose.Scale,Rear,Visual.Palette);
  end;

begin
  Rear := IsRear(Visual.Scene);
  case Visual.Scene of
    ssBell: View := svUpper;
    ssTube,ssFortunes: View := svFortunes;
  else
    View := svLower;
  end;
  if not Rear and ((FBackground=nil) or (FBackgroundView<>View) or
    (FBackgroundWood<>Visual.Palette.Wood) or (FBackgroundFoundation<>Visual.Palette.Foundation)) then
    BuildBackground(View,Visual.Palette);
  FTarget.SetTransform(TD2DMatrix3x2F.Identity);
  FTarget.BeginDraw;
  try
    if Rear then
      FTarget.Clear(D2D1ColorF(0,0,0,0))
    else if View=svFortunes then
    begin
      Zoom := D2D1RectF(-FWidth*0.45,-FHeight*0.28,FWidth*1.45,FHeight*1.57);
      FTarget.DrawBitmap(FBackground,@Zoom);
      FCanvas.Rect(0,0,FWidth,FHeight,FCanvas.Radial(FWidth*0.47,FHeight*0.42,FWidth*0.62,FHeight*0.78,
        [Stop(0,$513C31,0.21),Stop(0.65,$34251E,0.47),Stop(1,$1D1C17,0.72)]));
    end
    else
      FTarget.DrawBitmap(FBackground,nil,1,D2D1_BITMAP_INTERPOLATION_MODE_NEAREST_NEIGHBOR);

    Foreground := CenteredPose(FWidth,FHeight,False);
    FrameBottom := (FHeight-Foreground.Y)/Foreground.Scale;
    M := FCanvas.Push(Foreground);
    try
      case Visual.Scene of
        ssOfferingBox,ssOfferingRear:
          begin
            BoxPose := TPose.At(640,BoxY,1.1);
            if Visual.Auxiliary then
              DrawBellAt(TPose.At(BoxPose.X+Visual.AuxiliaryX,
                BoxPose.Y+(ShrineBellScreenY-BoxY)+Visual.AuxiliaryY,BellScale),0,0);
            DrawOfferingBox(FCanvas,BoxPose,Rear,Visual.Palette.Box);
            DrawOfferings(FCanvas,BoxPose,Progress,Visual.Coins,Visual.Bills,Rear,Visual.OfferingX,Visual.OfferingY);
          end;
        ssBell,ssBellRear:
          begin
            BellY := ShrineBellScreenY;
            if not Rear then
            begin
              Background := ShrinePose(FWidth,FHeight,svUpper);
              BellY := (Background.Y+ShrineBellScreenY*Background.Scale-Foreground.Y)/Foreground.Scale;
            end;
            BellPose := TPose.At(640,BellY,BellScale);
            if Visual.Auxiliary then
              DrawOfferingBox(FCanvas,TPose.At(BellPose.X+Visual.AuxiliaryX,
                BellPose.Y+(BoxY-ShrineBellScreenY)+Visual.AuxiliaryY,1.1),Rear,Visual.Palette.Box);
            DrawBellAt(BellPose,Progress,Visual.Strength);
          end;
        ssTube:
          DrawFortuneTube(FCanvas,TPose.At(640+Visual.FortuneX,366+Visual.FortuneY,
            1.24*Visual.FortuneScale),Progress,Visual.Strength,Visual.Palette.Tube);
        ssFortunes:
          begin
            PaperColors.Paper := Visual.Palette.Paper;
            PaperColors.Text := Visual.Palette.Text;
            FortunePose := TPose.At(640+Visual.FortuneX,PaperCenter+Visual.FortuneY,
              PaperScale*Visual.FortuneScale);
            DrawFortune(FCanvas,FortunePose,Visual.Fortune,PaperColors,Visual.Reveal,
              Visual.FortuneEffect,Progress,(FrameBottom-FortunePose.Y)/FortunePose.Scale);
          end;
      end;
    finally
      FCanvas.Restore(M);
    end;
  finally
    OleCheck(FTarget.EndDraw);
  end;
end;

procedure TSanpaiRenderer.ReadPixels(Transparent: Boolean);
var
  Area: WICRect;
  Lock: IWICBitmapLock;
  Stride,BufferSize,Pixel,A,R,G,B: Cardinal;
  Data: WICInProcPointer;
  Src,Dest: PCardinal;
  X,Y: Integer;
begin
  Area.X := 0;
  Area.Y := 0;
  Area.Width := FWidth;
  Area.Height := FHeight;
  OleCheck(FSurface.Lock(Area,WICBitmapLockRead,Lock));
  OleCheck(Lock.GetStride(Stride));
  OleCheck(Lock.GetDataPointer(BufferSize,Data));
  if (Data=nil) or (Stride<Cardinal(FWidth*4)) or
    (BufferSize<Stride*Cardinal(FHeight-1)+Cardinal(FWidth*4)) then
    raise Exception.Create('Invalid WIC bitmap stride or buffer');
  Dest := PCardinal(@FPixels[0]);
  for Y := 0 to FHeight-1 do
  begin
    Src := PCardinal(PByte(Data)+Cardinal(Y)*Stride);
    for X := 0 to FWidth-1 do
    begin
      Pixel := Src^;
      A := Pixel shr 24;
      if not Transparent or (A=255) then
        Dest^ := (Pixel and $FF00FF00) or ((Pixel and $00FF0000) shr 16) or ((Pixel and $FF) shl 16)
      else if A=0 then
        Dest^ := 0
      else
      begin
        // Direct2D の PBGRA をホストへ渡すストレート RGBA に戻す。
        R := Min(Cardinal(255),(((Pixel shr 16) and $FF)*255+A div 2) div A);
        G := Min(Cardinal(255),(((Pixel shr 8) and $FF)*255+A div 2) div A);
        B := Min(Cardinal(255),((Pixel and $FF)*255+A div 2) div A);
        Dest^ := (A shl 24) or (B shl 16) or (G shl 8) or R;
      end;
      Inc(Src);
      Inc(Dest);
    end;
  end;
end;

function TSanpaiRenderer.Render(Width,Height: Integer; const Settings: TSanpaiSettings;
  Time: Double): PPIXEL_RGBA;
var
  ComStatus: HResult;
  Progress: Double;
begin
  Result := nil;
  if (Width<=0) or (Height<=0) or (Width>SANPAI_MAX_SIDE) or (Height>SANPAI_MAX_SIDE) or
    (Int64(Width)*Height>SANPAI_MAX_PIXELS) then Exit;

  Progress := Settings.Timing.Progress(Time);
  case Settings.Visual.Scene of
    ssOfferingBox,ssOfferingRear:
      if (Progress<=0) or (Progress>=1) or (Settings.Visual.Coins+Settings.Visual.Bills=0) then
        Progress := 0;
    ssBell,ssBellRear:
      if (Progress<=0) or (Progress>=1) or (Settings.Visual.Strength=0) then
        Progress := 0;
    ssTube: Progress := Max(0,Progress);
    ssFortunes:
      if (Settings.Visual.Reveal=frShow) and (Settings.Visual.FortuneEffect=feNone) and
        (Progress>=0) then Progress := 1;
  end;
  if FFrameReady and (FWidth=Width) and (FHeight=Height) and (FLastProgress=Progress) and
    CompareMem(@FLastVisual,@Settings.Visual,SizeOf(FLastVisual)) then Exit(@FPixels[0]);

  ComStatus := CoInitializeEx(nil,COINIT_MULTITHREADED);
  if ComStatus<>RPC_E_CHANGED_MODE then OleCheck(ComStatus);
  try
    try
      EnsureSurface(Width,Height);
      FFrameReady := False;
      DrawFrame(Settings.Visual,Progress);
      ReadPixels(IsRear(Settings.Visual.Scene));
      FLastVisual := Settings.Visual;
      FLastProgress := Progress;
      FFrameReady := True;
      Result := @FPixels[0];
    except
      ResetSurface;
      raise;
    end;
  finally
    if Succeeded(ComStatus) then CoUninitialize;
  end;
end;

end.
