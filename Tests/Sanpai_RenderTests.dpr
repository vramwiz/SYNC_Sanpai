program Sanpai_RenderTests;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// 本番 AUF2 の登録テーブル、映像コールバックとシークを検査する。

{$APPTYPE CONSOLE}
{$R+}{$Q+}

uses
  System.SysUtils, System.Classes, System.Diagnostics, System.Math,
  Winapi.ActiveX, Winapi.Windows, Vcl.Graphics, Vcl.Imaging.GIFImg, Vcl.Imaging.pngimage,
  AviUtl2FilterTypes in '..\Source\Lib\AviUtl2FilterTypes.pas';

type
  TGetTable = function: PFILTER_PLUGIN_TABLE; cdecl;
  TInitialize = function(Version: Cardinal): Byte; cdecl;
  TRequired = function: Cardinal; cdecl;
  TUninitialize = procedure; cdecl;
  TOptions = array[0..6] of TFILTER_ITEM_SELECT_ITEM;
  POptions = ^TOptions;
  TItems = array[0..99] of Pointer;
  PItems = ^TItems;
  PHideRule = ^TFILTER_ITEM_HIDE_RULE;
  PItem = ^TItem;
  TItem = record ItemType,Name: PWideChar end;
  TPixels = TArray<TPIXEL_RGBA>;

const
  W = 1280;
  H = 720;
  SceneNames: array[0..5] of string =
    ('賽銭箱（正面）','賽銭箱（背面）','鈴（正面）','鈴（背面）','おみくじをひく','おみくじの結果');
  BoxFront = 0;
  BoxRear = 1;
  BellFront = 2;
  BellRear = 3;
  FortuneDraw = 4;
  FortuneResult = 5;
  SceneFiles: array[0..5] of string = ('box','box-rear','bell','bell-rear','tube','fortune');
  ColorNames: array[0..7] of string = ('木の色','土台の色','賽銭箱の色','鈴の色',
    '鈴緒の色','おみくじ筒の色','文字の色','紙の色');

var
  Table: PFILTER_PLUGIN_TABLE;
  Video: TFILTER_PROC_VIDEO;
  Obj: TOBJECT_INFO;
  Scene: TSCENE_INFO;
  Captured: TPixels;
  SetCount,ActualWidth,ActualHeight: Integer;
  OutputDir: string;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then raise Exception.Create(MessageText);
end;

function Item(const Name,Kind: string): Pointer;
var
  Items: PItems;
  I: Integer;
begin
  Items := Pointer(Table^.Items);
  for I := 0 to High(TItems) do
  begin
    if Items^[I]=nil then Break;
    if (string(PItem(Items^[I])^.Name)=Name) and (string(PItem(Items^[I])^.ItemType)=Kind) then
      Exit(Items^[I]);
  end;
  raise Exception.Create('Missing item '+Name);
end;

procedure SelectValue(const Name: string; Value: Integer);
begin
  PFILTER_ITEM_SELECT(Item(Name,'select'))^.Value := Value;
end;

function Track(const Name: string): PFILTER_ITEM_TRACK;
begin
  Result := Item(Name,'track');
end;

procedure Toggle(const Name: string; OnOff: Boolean);
begin
  PFILTER_ITEM_CHECK(Item(Name,'check'))^.Value := Ord(OnOff);
end;

procedure SetImage(Buffer: PPIXEL_RGBA; Width,Height: Integer); cdecl;
begin
  Inc(SetCount);
  ActualWidth := Width;
  ActualHeight := Height;
  SetLength(Captured,Width*Height);
  Move(Buffer^,Captured[0],Length(Captured)*SizeOf(TPIXEL_RGBA));
end;

function Frame(Time: Double): TPixels;
var
  Before: Integer;
begin
  Obj.Time := Time;
  Before := SetCount;
  Check(Table^.Func_Proc_Video(@Video)=1,'Render callback failed');
  Check(SetCount=Before+1,'Expected one image submission');
  Check((ActualWidth=Scene.Width) and (ActualHeight=Scene.Height),'Image dimension mismatch');
  Result := Copy(Captured);
end;

function Same(const A,B: TPixels): Boolean;
begin
  Result := (Length(A)=Length(B)) and CompareMem(@A[0],@B[0],Length(A)*SizeOf(TPIXEL_RGBA));
end;

procedure WriteBGR(const Pixels: TPixels; Row: PByte; Offset,Width: Integer);
var
  X: Integer;
begin
  for X := Offset to Offset+Width-1 do
  begin
    Row^ := Pixels[X].B;
    Inc(Row);
    Row^ := Pixels[X].G;
    Inc(Row);
    Row^ := Pixels[X].R;
    Inc(Row);
  end;
end;

procedure SavePNG(const Pixels: TPixels; const Name: string);
var
  PNG: TPngImage;
  X,Y: Integer;
begin
  PNG := TPngImage.CreateBlank(COLOR_RGBALPHA,8,Scene.Width,Scene.Height);
  try
    for Y := 0 to Scene.Height-1 do
    begin
      WriteBGR(Pixels,PNG.Scanline[Y],Y*Scene.Width,Scene.Width);
      for X := 0 to Scene.Width-1 do PNG.AlphaScanline[Y]^[X] := Pixels[Y*Scene.Width+X].A;
    end;
    PNG.SaveToFile(OutputDir+Name+'.png');
  finally
    PNG.Free;
  end;
end;

procedure CheckRopeAtImageEdge(const Pixels: TPixels);
var
  X, Count: Integer;
  P: TPIXEL_RGBA;
begin
  Count := 0;
  for X := 0 to Scene.Width-1 do
  begin
    P := Pixels[(Scene.Height-1)*Scene.Width+X];
    if (P.A>100) and (Integer(P.R)-P.G>=13) and (Integer(P.G)-P.B>=17) then Inc(Count);
  end;
  Check(Count>=Max(2,Scene.Width div 128),Format('Braided rope misses bottom at %.2f s (%dx%d)',
    [Obj.Time,Scene.Width,Scene.Height]));
end;

procedure CheckAlpha(const Pixels: TPixels; IsRear: Boolean);
var
  P: TPIXEL_RGBA;
  Clear,Partial,Opaque: Integer;
begin
  Clear := 0;
  Partial := 0;
  Opaque := 0;
  for P in Pixels do
    if P.A=0 then
    begin
      Inc(Clear);
      Check((P.R or P.G or P.B)=0,'Transparent pixels are not clear');
    end
    else if P.A=255 then Inc(Opaque)
    else Inc(Partial);
  if IsRear then
    Check((Pixels[0].A=0) and (Pixels[High(Pixels)].A=0) and
      (Clear>Length(Pixels) div 2) and (Opaque>500) and (Partial>0),'Incorrect rear transparency')
  else
    Check(Opaque=Length(Pixels),'Front backdrop is not opaque');
end;

procedure SaveGIF(SceneID: Integer; const Name: string);
const
  Frames = 43;
var
  GIF: TGIFImage;
  BMP: TBitmap;
  I,Y: Integer;
  Pixels: TPixels;
begin
  Scene.Width := 640;
  Scene.Height := 360;
  SelectValue('シーン',SceneID);
  GIF := TGIFImage.Create;
  BMP := TBitmap.Create;
  try
    BMP.PixelFormat := pf24bit;
    BMP.SetSize(Scene.Width,Scene.Height);
    for I := 0 to Frames-1 do
    begin
      Pixels := Frame(I/20);
      for Y := 0 to Scene.Height-1 do
        WriteBGR(Pixels,BMP.Scanline[Y],Y*Scene.Width,Scene.Width);
      TGIFGraphicControlExtension.Create(GIF.Add(BMP)).Delay := 5;
    end;
    TGIFAppExtNSLoop.Create(GIF.Images[0]).Loops := 0;
    GIF.SaveToFile(OutputDir+Name+'.gif');
  finally
    BMP.Free;
    GIF.Free;
  end;
end;

function HiddenFor(const Name: string; SceneID: Integer): Boolean;
var
  Items: PItems;
  I: Integer;
  Rule: PHideRule;
begin
  Items := Pointer(Table^.Items);
  for I := 0 to High(TItems) do
  begin
    if Items^[I]=nil then Break;
    if string(PItem(Items^[I])^.ItemType)<>'hiderule' then Continue;
    Rule := Items^[I];
    if (string(Rule^.Name)=Name) and
      (((Rule^.ConditionOperator=0) and (Rule^.ConditionValue=SceneID)) or
       ((Rule^.ConditionOperator=1) and (Rule^.ConditionValue<>SceneID)) or
       ((Rule^.ConditionOperator=2) and (SceneID>Rule^.ConditionValue)) or
       ((Rule^.ConditionOperator=3) and (SceneID<Rule^.ConditionValue))) then Exit(True);
  end;
  Result := False;
end;

procedure CheckRegistration;
var
  Items: PItems;
  Options: POptions;
  I,J,RuleCount,GroupIndex: Integer;
  Rule: PHideRule;
  ItemName: string;
begin
  Check((string(Table^.Name)='参拝演出') and (string(Table^.Label_)='SYNC') and
    (Table^.Flag=(FILTER_FLAG_VIDEO or FILTER_FLAG_INPUT or FILTER_FLAG_USERDATA)),
    'Unexpected filter registration');
  Check(Assigned(Table^.Func_Proc_Video) and
    Assigned(Table^.Func_Create) and Assigned(Table^.Func_Destroy),'Missing callbacks');
  Check(not Assigned(Table^.Func_Proc_Audio),'A video-only plugin registered an audio callback');
  Items := Pointer(Table^.Items);
  Check(Items^[0]=Item('シーン','select'),'First item is not scene selection');
  Check(Items^[1]=Track('演出開始までの時間'),'Second item is not delay');
  Check(Items^[2]=Track('演出の時間'),'Third item is not duration');
  Check((Track('演出開始までの時間')^.Value=1) and
    (Track('演出の時間')^.Value=1) and SameValue(Track('演出の時間')^.Step,0.01),'Incorrect timing defaults');
  Check(PFILTER_ITEM_SELECT(Items^[0])^.Value=0,'Wrong default scene');
  Options := Pointer(PFILTER_ITEM_SELECT(Items^[0])^.List);
  for I := 0 to High(SceneNames) do
    Check((string(Options^[I].Name)=SceneNames[I]) and (Options^[I].Value=I),
      'Scene selection text, order or ID is invalid');
  Check(Options^[6].Name=nil,'Invalid scene selection terminator');
  for I := 0 to High(SceneNames) do
    Check((HiddenFor('硬貨枚数',I)=not (I in [BoxFront,BoxRear])) and
      (HiddenFor('鈴を鳴らす強さ',I)=not (I in [BellFront,BellRear])) and
      (HiddenFor('筒を振る強さ',I)=(I<>FortuneDraw)) and
      (HiddenFor('運勢',I)=(I<>FortuneResult)) and
      (HiddenFor('おみくじX',I)=(I<FortuneDraw)) and
      (HiddenFor('おみくじY',I)=(I<FortuneDraw)) and
      (HiddenFor('おみくじ拡大率',I)=(I<FortuneDraw)) and
      (HiddenFor('結果演出',I)=(I<>FortuneResult)),
      'A dedicated control uses an old scene number');
  RuleCount := 0;
  GroupIndex := -1;
  for I := 3 to High(TItems) do
  begin
    if Items^[I]=nil then Break;
    ItemName := string(PItem(Items^[I])^.Name);
    Check((ItemName<>'効果音関連') and (ItemName<>'効果音') and (ItemName<>'音量'),
      'An audio control or visibility rule is registered');
    if Items^[I]=Item('色設定','group') then GroupIndex := I;
    if string(PItem(Items^[I])^.ItemType)<>'hiderule' then Continue;
    Rule := Items^[I];
    Check((string(Rule^.ConditionName)='シーン') and
      (Rule^.ConditionOperator in [0..3]) and (Rule^.ConditionValue in [0..5]),
      'Invalid scene visibility rule');
    for J := 0 to High(ColorNames) do
      Check(string(Rule^.Name)<>ColorNames[J],'A common color setting was hidden');
    Inc(RuleCount);
  end;
  Check(RuleCount=28,'Incomplete per-scene visibility rules');
  Check((Track('おみくじX')^.Value=0) and (Track('おみくじY')^.Value=0) and
    (Track('おみくじ拡大率')^.Value=100),'Wrong fortune position defaults');
  Check(PFILTER_ITEM_SELECT(Item('結果演出','select'))^.Value=1,'Entrance effect is not the default');
  Options := Pointer(PFILTER_ITEM_SELECT(Item('結果演出','select'))^.List);
  Check((Options^[0].Value=0) and (string(Options^[0].Name)='なし') and
    (Options^[1].Value=1) and (string(Options^[1].Name)='ふわっと登場') and
    (Options^[2].Value=2) and (string(Options^[2].Name)='フェードイン') and
    (Options^[3].Value=3) and (string(Options^[3].Name)='軽く弾む') and
    (Options^[4].Name=nil),'Invalid fortune effect choices');
  Check(GroupIndex>=0,'Missing common color group');
  for I := 0 to High(ColorNames) do
    Check(Items^[GroupIndex+1+I]=Item(ColorNames[I],'color'),'Color is outside the common group');
  Check((Track('賽銭投入X座標')^.Value=0) and (Track('賽銭投入Y座標')^.Value=0),
    'The initial offering target is not centered');
  Check((Track('硬貨枚数')^.E=30) and (Track('硬貨枚数')^.Value=1) and
    (Track('紙幣枚数')^.E=10) and (Track('紙幣枚数')^.Value=0) and
    (Track('鈴を鳴らす強さ')^.Value=50) and (Track('筒を振る強さ')^.Value=50),'Wrong parameter defaults');
  WriteLn('Video-only registration, scene settings and parameter defaults passed.');
end;

procedure CheckVideo;
var
  I,J,K: Integer;
  Pre,Mid,Final,Alt,WorkerFrame: TPixels;
  FortuneFrames: array[0..5] of TPixels;
  C: PFILTER_ITEM_COLOR;
  Worker: TThread;
begin
  Scene.Width := W;
  Scene.Height := H;
  Track('硬貨枚数')^.Value := 12;
  Track('紙幣枚数')^.Value := 5;
  for I := 0 to High(SceneNames) do
  begin
    SelectValue('シーン',I);
    Pre := Frame(0);
    Mid := Frame(1.39);
    Final := Frame(2);
    CheckAlpha(Mid,I in [1,3]);
    Check(Same(Pre,Frame(0.99)),'Scene moved before start');
    Check(not Same(Pre,Mid),'Scene is stationary during the effect');
    Check(Same(Final,Frame(5)),'Scene did not hold the final state');
    Check(Same(Mid,Frame(1.39)),'Rendering depends on seek order');
    if I in [0,1,2,3] then Check(Same(Pre,Final),'Box or bell did not return to rest')
    else Check(not Same(Pre,Final),'Tube or fortune did not retain its result');
    if I in [2,3] then CheckRopeAtImageEdge(Mid);
    if I in [0,1,2,3] then SavePNG(Mid,SceneFiles[I])
    else SavePNG(Final,SceneFiles[I]);
    Track('演出の時間')^.Value := 0;
    Check(Same(Final,Frame(1)),'Zero-duration effect did not switch at start');
    Track('演出の時間')^.Value := 0.01;
    Frame(1.005);
    Check(Same(Final,Frame(1.02)),'Very short effect did not reach final state');
    Track('演出開始までの時間')^.Value := 2.5;
    Track('演出の時間')^.Value := 1.6;
    Check(Same(Pre,Frame(2.49)) and Same(Final,Frame(4.11)),'Changed timing did not apply');
    Track('演出開始までの時間')^.Value := 1;
    Track('演出の時間')^.Value := 1;
  end;

  for I in [BoxFront,BoxRear] do
  begin
    SelectValue('シーン',I);
    Track('硬貨枚数')^.Value := 0;
    Track('紙幣枚数')^.Value := 0;
    Check(Same(Frame(0),Frame(1.39)),'Empty offering was animated');
    Track('硬貨枚数')^.Value := 12;
    Alt := Frame(1.39);
    Track('硬貨枚数')^.Value := 0;
    Track('紙幣枚数')^.Value := 5;
    Check(not Same(Alt,Frame(1.39)) and not Same(Frame(0),Frame(1.39)),'Paper-only offering was not drawn');
    Pre := Frame(0);
    Track('鈴のX座標')^.Value := 0;
    Track('鈴のY座標')^.Value := 0;
    Toggle('鈴の表示',True);
    Alt := Frame(0);
    Check(not Same(Pre,Alt),'Auxiliary bell missing');
    Track('鈴のX座標')^.Value := 160;
    Track('鈴のY座標')^.Value := -30;
    Check(not Same(Alt,Frame(0)),'Auxiliary bell did not move');
    Toggle('鈴の表示',False);
    Check(Same(Pre,Frame(0)),'Hidden bell offset affected the main scene');
  end;

  for I in [BellFront,BellRear] do
  begin
    SelectValue('シーン',I);
    Track('鈴を鳴らす強さ')^.Value := 0;
    Pre := Frame(0);
    Check(Same(Pre,Frame(1.39)),'Zero-strength bell moved');
    Track('賽銭箱のX座標')^.Value := 0;
    Track('賽銭箱のY座標')^.Value := 0;
    Toggle('賽銭箱の表示',True);
    Alt := Frame(0);
    Check(not Same(Pre,Alt),'Auxiliary box missing');
    Track('賽銭箱のX座標')^.Value := -130;
    Track('賽銭箱のY座標')^.Value := 60;
    Check(not Same(Alt,Frame(0)) and Same(Frame(1.39),Frame(0)),'Auxiliary box offset or rest failed');
    Toggle('賽銭箱の表示',False);
    Track('鈴を鳴らす強さ')^.Value := 50;
  end;
  SelectValue('シーン',BellFront);
  Alt := Frame(1.39);
  Worker := TThread.CreateAnonymousThread(procedure begin WorkerFrame := Frame(1.39) end);
  Worker.FreeOnTerminate := False;
  try
    Worker.Start;
    Worker.WaitFor;
    Check((Worker.FatalException=nil) and Same(Alt,WorkerFrame),'Frame differs on another thread');
  finally
    Worker.Free;
  end;

  SelectValue('シーン',FortuneResult);
  for I := 0 to 5 do
  begin
    SelectValue('運勢',I);
    FortuneFrames[I] := Frame(2);
    for J := 0 to I-1 do Check(not Same(FortuneFrames[I],FortuneFrames[J]),'Fortune glyphs did not change');
    SavePNG(FortuneFrames[I],'fortune-'+IntToStr(I));
  end;
  SelectValue('運勢',0);
  SelectValue('結果演出',0);
  for I := 1 to 4 do
  begin
    SelectValue('表示方法',I);
    Pre := Frame(0);
    Mid := Frame(1.42);
    Final := Frame(2);
    Check(not Same(Pre,Mid) and not Same(Mid,Final) and Same(Final,FortuneFrames[0]),
      'Fortune reveal failed: '+IntToStr(I));
    SavePNG(Mid,'fortune-reveal-'+IntToStr(I));
  end;
  SelectValue('表示方法',0);
  C := Item('文字の色','color');
  C^.R := 42; C^.G := 90; C^.B := 115;
  Alt := Frame(2);
  K := 113*W+569;
  Check(not Same(FortuneFrames[0],Alt) and (FortuneFrames[0][K].R<>Alt[K].R),'Ink color or border did not change');
  C := Item('紙の色','color');
  C^.R := 213; C^.G := 226; C^.B := 239;
  Check(not Same(Alt,Frame(2)),'Paper color did not change');
  SavePNG(Captured,'fortune-color');
  SelectValue('結果演出',1);

  Scene.Width := 480;
  Scene.Height := 720;
  SelectValue('シーン',BellRear);
  Track('鈴を鳴らす強さ')^.Value := 100;
  for I := 0 to 11 do CheckRopeAtImageEdge(Frame(1+I/12));
  Track('演出開始までの時間')^.Value := NaN;
  Check(Same(Frame(0),Frame(NaN)),'Nonfinite settings were not handled');
  Track('演出開始までの時間')^.Value := 1;
  Scene.Width := 8193;
  Check(Table^.Func_Proc_Video(@Video)=0,'Oversize scene was accepted');
  Track('鈴を鳴らす強さ')^.Value := 50;
  WriteLn('Six scenes, alpha, aux offsets, 5 reveals, 6 fortunes, colors and video timing passed.');
end;


function Differences(const A,B: TPixels; L,T,R,Bottom: Integer): Integer;
var
  X,Y,Index: Integer;
begin
  Result := 0;
  for Y := T to Bottom-1 do
    for X := L to R-1 do
    begin
      Index := Y*Scene.Width+X;
      if not CompareMem(@A[Index],@B[Index],SizeOf(TPIXEL_RGBA)) then Inc(Result);
    end;
end;

procedure CheckPlacementAndPalette;
var
  I: Integer;
  Base,ResultFrame: TPixels;
  InitialX,InitialY,ShiftedX,ShiftedY: Double;

  procedure OfferingCenter(const Current: TPixels; out CX,CY: Double);
  var
    N,X,Y: Integer;
    SumX,SumY: Int64;
  begin
    N := 0;
    SumX := 0;
    SumY := 0;
    for Y := 310 to 459 do
      for X := 300 to 979 do
        if not CompareMem(@Base[Y*W+X],@Current[Y*W+X],SizeOf(TPIXEL_RGBA)) then
        begin
          Inc(N);
          SumX := SumX+X;
          SumY := SumY+Y;
        end;
    Check(N>50,'Missing coin near the receiving grate');
    CX := SumX/N;
    CY := SumY/N;
  end;

  procedure VerifyColor(Index,SceneID,L,T,R,Bottom: Integer; Time: Double);
  var
    Setting: PFILTER_ITEM_COLOR;
    Saved: TFILTER_ITEM_COLOR;
    Before,After: TPixels;
  begin
    SelectValue('シーン',SceneID);
    Setting := Item(ColorNames[Index],'color');
    Saved := Setting^;
    Before := Frame(Time);
    try
      Setting^.R := 55;
      Setting^.G := 174;
      Setting^.B := 218;
      After := Frame(Time);
      Check(Differences(Before,After,L,T,R,Bottom)>100,'Color did not apply: '+ColorNames[Index]);
      SavePNG(After,'palette-'+IntToStr(Index));
    finally
      Setting^ := Saved;
    end;
    Check(Same(Before,Frame(Time)),'Cached surface kept the changed color');
  end;

begin
  Scene.Width := W;
  Scene.Height := H;
  Track('硬貨枚数')^.Value := 1;
  Track('紙幣枚数')^.Value := 0;
  for I in [BoxFront,BoxRear] do
  begin
    SelectValue('シーン',I);
    Track('賽銭投入X座標')^.Value := 0;
    Track('賽銭投入Y座標')^.Value := 0;
    Base := Frame(0);
    OfferingCenter(Frame(1.43),InitialX,InitialY);
    Check(Abs(InitialX-W/2)<4,'Single coin missed the center at the default X');
    Track('賽銭投入X座標')^.Value := 130;
    Track('賽銭投入Y座標')^.Value := -18;
    ResultFrame := Frame(1.43);
    OfferingCenter(ResultFrame,ShiftedX,ShiftedY);
    Check((Abs(ShiftedX-InitialX-130)<4) and (Abs(ShiftedY-InitialY+18)<4),
      'The contact point did not follow both coordinates');
    Check(Same(Base,Frame(2)),'Offering position changed the completed frame');
    SavePNG(ResultFrame,'offering-aim-'+IntToStr(I));
    Track('賽銭投入X座標')^.Value := -230;
    Track('賽銭投入Y座標')^.Value := 22;
    Check(not Same(Base,Frame(1.43)),'Offering at the far corner disappeared');
  end;
  Track('賽銭投入X座標')^.Value := 0;
  Track('賽銭投入Y座標')^.Value := 0;

  SelectValue('シーン',FortuneDraw);
  Base := Frame(0);
  ResultFrame := Frame(2);
  Check(Differences(Base,ResultFrame,765,617,856,664)>120,'The stick did not extend below the tube');
  Check(Differences(Base,ResultFrame,410,82,850,141)=0,'Tube still extended a stick upward');

  VerifyColor(0,BoxFront,80,175,260,270,0);
  VerifyColor(1,BoxFront,48,430,242,555,0);
  VerifyColor(2,BoxRear,407,450,571,553,0);
  VerifyColor(3,BellRear,586,189,687,293,0);
  VerifyColor(4,BellRear,619,420,660,615,0);
  VerifyColor(5,FortuneDraw,555,310,694,452,0);
  VerifyColor(6,FortuneResult,589,245,688,465,2);
  VerifyColor(7,FortuneResult,570,450,598,540,2);
  WriteLn('Centered offering, configurable X/Y, downward stick and all eight colors passed.');
end;

function BoundsOfChanges(const Background,Image: TPixels): TRect;
var
  X,Y,I: Integer;
begin
  Result.Left := W;
  Result.Top := H;
  Result.Right := 0;
  Result.Bottom := 0;
  for Y := 0 to H-1 do
    for X := 0 to W-1 do
    begin
      I := Y*W+X;
      if CompareMem(@Background[I],@Image[I],SizeOf(TPIXEL_RGBA)) then Continue;
      Result.Left := Min(Result.Left,X);
      Result.Right := Max(Result.Right,X+1);
      Result.Top := Min(Result.Top,Y);
      Result.Bottom := Max(Result.Bottom,Y+1);
    end;
end;

procedure CheckFortuneEffects;
var
  I,J: Integer;
  Backdrop,Final,Before,Mid: TPixels;
  Entrances: array[1..3] of TPixels;
  DefaultBounds,MovedBounds,SmallBounds: TRect;
  Color: PFILTER_ITEM_COLOR;
begin
  Color := Item('紙の色','color');
  Color^.R := $F3;
  Color^.G := $E8;
  Color^.B := $CC;
  Color := Item('文字の色','color');
  Color^.R := $91;
  Color^.G := $3D;
  Color^.B := $35;
  Scene.Width := W;
  Scene.Height := H;
  SelectValue('シーン',FortuneResult);
  SelectValue('表示方法',0);
  Backdrop := Frame(0);
  for I in [FortuneDraw,FortuneResult] do
  begin
    SelectValue('シーン',I);
    DefaultBounds := BoundsOfChanges(Backdrop,Frame(2));
    Track('おみくじX')^.Value := 135;
    Track('おみくじY')^.Value := -35;
    MovedBounds := BoundsOfChanges(Backdrop,Frame(2));
    Check((Abs(MovedBounds.Left-DefaultBounds.Left-135)<=2) and
      (Abs(MovedBounds.Top-DefaultBounds.Top+35)<=2),'Fortune subject position did not follow X/Y');
    Track('おみくじ拡大率')^.Value := 50;
    Mid := Frame(2);
    SmallBounds := BoundsOfChanges(Backdrop,Mid);
    Check((SmallBounds.Right-SmallBounds.Left>30) and
      (Abs(2*(SmallBounds.Right-SmallBounds.Left)-(MovedBounds.Right-MovedBounds.Left))<12) and
      (Abs(2*(SmallBounds.Bottom-SmallBounds.Top)-(MovedBounds.Bottom-MovedBounds.Top))<12),
      'Fortune subject did not scale around its center');
    SavePNG(Mid,'fortune-layout-'+IntToStr(I));
    Track('おみくじX')^.Value := 0;
    Track('おみくじY')^.Value := 0;
    Track('おみくじ拡大率')^.Value := 100;
  end;

  SelectValue('シーン',FortuneResult);
  Final := Frame(2);
  SelectValue('結果演出',0);
  Check(Same(Final,Frame(1)),'No entrance did not display the result immediately');
  for I := 1 to 3 do
  begin
    SelectValue('結果演出',I);
    Check(Same(Backdrop,Frame(1)),'Entrance started before the animation');
    Entrances[I] := Frame(1.33);
    Check(not Same(Backdrop,Entrances[I]) and not Same(Final,Entrances[I]),'Entrance has no intermediate state');
    for J := 1 to I-1 do
      Check(not Same(Entrances[I],Entrances[J]),'Entrance choices have identical output');
    Check(Same(Final,Frame(3)) and Same(Entrances[I],Frame(1.33)),'Entrance did not hold or seek deterministically');
    Track('演出の時間')^.Value := 0;
    Check(Same(Final,Frame(1)),'Zero-duration entrance did not reach the final state');
    Track('演出の時間')^.Value := 1;
    SavePNG(Entrances[I],'fortune-effect-'+IntToStr(I));
  end;

  for I := 1 to 4 do
  begin
    SelectValue('表示方法',I);
    SelectValue('結果演出',0);
    Before := Frame(0);
    Mid := Frame(1.67);
    SelectValue('結果演出',2);
    Check(Same(Before,Frame(0)) and not Same(Mid,Frame(1.67)) and Same(Final,Frame(2)),
      'The entrance did not combine with the paper reveal');
  end;
  Track('おみくじ拡大率')^.Value := 1;
  Track('おみくじY')^.Value := 2000;
  Frame(1.4);
  Track('おみくじY')^.Value := 0;
  SelectValue('表示方法',0);
  Track('おみくじ拡大率')^.Value := 500;
  Frame(1.4);
  Track('おみくじ拡大率')^.Value := 100;
  SelectValue('結果演出',1);
  WriteLn('Both fortune placements, three entrances, no entrance, compositing and final state passed.');
end;

procedure Benchmark;
const
  Frames = 36;
var
  I,J: Integer;
  Start: TStopwatch;
  Elapsed: Double;
begin
  Scene.Width := 1920;
  Scene.Height := 1080;
  Track('硬貨枚数')^.Value := 30;
  Track('紙幣枚数')^.Value := 10;
  SelectValue('表示方法',2);
  for I := 0 to High(SceneNames) do
  begin
    SelectValue('シーン',I);
    Frame(0);
    Start := TStopwatch.StartNew;
    for J := 0 to Frames-1 do
    begin
      Obj.Time := 1+J/Frames;
      Check(Table^.Func_Proc_Video(@Video)=1,'Benchmark render failed');
    end;
    Elapsed := Start.Elapsed.TotalMilliseconds;
    WriteLn(Format('%s 1080p: %.2f ms/frame',
      [SceneFiles[I],Elapsed/Frames],TFormatSettings.Invariant));
  end;
end;

procedure Run;
var
  Module: HMODULE;
  Initialize: TInitialize;
  Uninitialize: TUninitialize;
  Required: TRequired;
  GetTable: TGetTable;
begin
  Check((ParamCount in [2,3]) and ((ParamCount=2) or (ParamStr(3)='--motion-preview')),
    'Expected AUF2 path, output directory and optional --motion-preview');
  OutputDir := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(2)));
  ForceDirectories(OutputDir);
  Module := LoadLibrary(PChar(ExpandFileName(ParamStr(1))));
  Check(Module<>0,'Could not load the production AUF2');
  try
    @Initialize := GetProcAddress(Module,'InitializePlugin');
    @Uninitialize := GetProcAddress(Module,'UninitializePlugin');
    @Required := GetProcAddress(Module,'RequiredVersion');
    @GetTable := GetProcAddress(Module,'GetFilterPluginTable');
    Check(Assigned(Initialize) and Assigned(Uninitialize) and Assigned(Required) and
      Assigned(GetTable),'AUF2 exports are incomplete');
    Check(Required()=2011600,'Unsupported SDK version');
    Check((Initialize(Required()-1)=0) and (Initialize(Required())=1),'Version gate failed');
    try
      Table := GetTable();
      Check(Table<>nil,'No filter table');
      CheckRegistration;
      Video.Scene := @Scene;
      Video.Object_ := @Obj;
      Video.SetImageData := SetImage;
      Video.UserData := Table^.Func_Create(1);
      Check(Video.UserData<>nil,'Session creation failed');
      try
        CheckVideo;
        CheckPlacementAndPalette;
        CheckFortuneEffects;
        Benchmark;
        if ParamCount=3 then
        begin
          Track('演出開始までの時間')^.Value := 0.24;
          Track('演出の時間')^.Value := 1.45;
          Track('硬貨枚数')^.Value := 12;
          Track('紙幣枚数')^.Value := 5;
          SaveGIF(BoxFront,'offering-motion');
          SaveGIF(BellFront,'bell-motion');
          SaveGIF(FortuneDraw,'tube-motion');
          SaveGIF(FortuneResult,'fortune-motion');
          SelectValue('表示方法',0);
          SaveGIF(FortuneResult,'fortune-entrance');
        end;
      finally
        Table^.Func_Destroy(1,Video.UserData);
      end;
    finally
      Uninitialize;
    end;
  finally
    FreeLibrary(Module);
  end;
end;

begin
  try
    Check(Succeeded(CoInitializeEx(nil,COINIT_APARTMENTTHREADED)),'Could not initialize test STA');
    try
      Run;
    finally
      CoUninitialize;
    end;
  except
    on E: Exception do
    begin
      WriteLn(ErrOutput,E.Message);
      ExitCode := 1;
    end;
  end;
end.
