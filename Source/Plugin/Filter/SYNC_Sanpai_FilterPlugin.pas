unit SYNC_Sanpai_FilterPlugin;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// AviUtl2 のメディア入力として、シーン設定と映像コールバックを登録する。

interface

uses
  AviUtl2FilterTypes;

// 返すテーブルと設定項目は DLL が所有する。
function GetSanpaiFilterTable: PFILTER_PLUGIN_TABLE;

const
  SANPAI_REQUIRED_VERSION = 2011600;

implementation

uses
  System.Math, System.SysUtils, System.SyncObjs, Winapi.Windows, PluginFilterTable,
  Sanpai_Timeline, Sanpai_Renderer, Sanpai_Fortunes;

const
  SceneName = 'シーン';
  HideNotEqual = 1;
  HideGreater = 2;
  HideLess = 3;
  // 項目と選択値を同じ演出順で登録する。
  SceneOptions: array[0..6] of TFILTER_ITEM_SELECT_ITEM = (
    (Name:'賽銭箱（正面）'; Value:Ord(ssOfferingBox)),
    (Name:'賽銭箱（背面）'; Value:Ord(ssOfferingRear)),
    (Name:'鈴（正面）'; Value:Ord(ssBell)),
    (Name:'鈴（背面）'; Value:Ord(ssBellRear)),
    (Name:'おみくじをひく'; Value:Ord(ssTube)),
    (Name:'おみくじの結果'; Value:Ord(ssFortunes)),
    (Name:nil; Value:0));
  FortuneOptions: array[0..6] of TFILTER_ITEM_SELECT_ITEM = (
    (Name:'大吉'; Value:0), (Name:'吉'; Value:1), (Name:'中吉'; Value:2),
    (Name:'小吉'; Value:3), (Name:'末吉'; Value:4), (Name:'凶'; Value:5),
    (Name:nil; Value:0));
  RevealOptions: array[0..5] of TFILTER_ITEM_SELECT_ITEM = (
    (Name:'そのまま表示'; Value:Ord(frShow)),
    (Name:'折り畳まれた紙を開く'; Value:Ord(frFold)),
    (Name:'巻かれた紙を広げる'; Value:Ord(frRoll)),
    (Name:'裏返して結果を表示する'; Value:Ord(frFlip)),
    (Name:'下から引き出す'; Value:Ord(frPull)),
    (Name:nil; Value:0));

  EffectOptions: array[0..4] of TFILTER_ITEM_SELECT_ITEM = (
    (Name:'なし'; Value:Ord(feNone)),
    (Name:'ふわっと登場'; Value:Ord(feFloat)),
    (Name:'フェードイン'; Value:Ord(feFade)),
    (Name:'軽く弾む'; Value:Ord(feBounce)),
    (Name:nil; Value:0));

var
  PluginTableInitialized: Boolean;
  SceneItem, FortuneItem, RevealItem, FortuneEffectItem: TFILTER_ITEM_SELECT;
  DelayItem, DurationItem, CoinsItem, BillsItem, OfferingXItem,OfferingYItem,
    BellXItem,BellYItem, BoxXItem,BoxYItem,
    BellStrengthItem, TubeStrengthItem, FortuneXItem,FortuneYItem,FortuneScaleItem: TFILTER_ITEM_TRACK;
  ShowBellItem, ShowBoxItem: TFILTER_ITEM_CHECK;
  WoodColorItem,FoundationColorItem,BoxColorItem,BellColorItem,RopeColorItem,TubeColorItem,
    PaperItem,TextItem: TFILTER_ITEM_COLOR;
  BoxGroup,BellGroup,TubeGroup,FortuneGroup,FortuneSharedGroup,ColorGroup: TFILTER_ITEM_GROUP;
  GroupRules: array[0..27] of TFILTER_ITEM_HIDE_RULE;
  RuleCount: Integer;

type
  TSanpaiSession = class
  private
    FLock: TCriticalSection;
    FRenderer: TSanpaiRenderer;
  public
    constructor Create;
    destructor Destroy; override;
    // Video とそのメンバーはコールバック中のみ借用する。
    function Render(Video: PFILTER_PROC_VIDEO; const Settings: TSanpaiSettings): Byte;
  end;

function Number(const Item: TFILTER_ITEM_TRACK; Fallback: Double): Double;
begin
  if IsNan(Item.Value) then Exit(Fallback);
  Result := EnsureRange(Item.Value,Item.S,Item.E);
end;

function RGBValue(const Item: TFILTER_ITEM_COLOR): Cardinal;
begin
  Result := (Cardinal(Item.R) shl 16) or (Cardinal(Item.G) shl 8) or Item.B;
end;

// ホストが渡す現在値を、このコールバック内だけで使う設定へ読み込む。
function SnapshotSettings: TSanpaiSettings;
var
  Scene, Reveal, Effect: Integer;
begin
  Result := Default(TSanpaiSettings);
  Scene := SceneItem.Value;
  if (Scene>=Ord(Low(TSanpaiScene))) and (Scene<=Ord(High(TSanpaiScene))) then
    Result.Visual.Scene := TSanpaiScene(Scene);
  Result.Timing.Delay := Number(DelayItem,1);
  Result.Timing.Duration := Number(DurationItem,1);
  Result.Visual.Palette.Wood := RGBValue(WoodColorItem);
  Result.Visual.Palette.Foundation := RGBValue(FoundationColorItem);
  Result.Visual.Palette.Box := RGBValue(BoxColorItem);
  Result.Visual.Palette.Bell := RGBValue(BellColorItem);
  Result.Visual.Palette.Rope := RGBValue(RopeColorItem);
  Result.Visual.Palette.Tube := RGBValue(TubeColorItem);
  Result.Visual.Palette.Text := RGBValue(TextItem);
  Result.Visual.Palette.Paper := RGBValue(PaperItem);
  if Result.Visual.Scene in [ssTube,ssFortunes] then
  begin
    Result.Visual.FortuneX := Number(FortuneXItem,0);
    Result.Visual.FortuneY := Number(FortuneYItem,0);
    Result.Visual.FortuneScale := Number(FortuneScaleItem,100)/100;
  end;
  case Result.Visual.Scene of
    ssOfferingBox,ssOfferingRear:
      begin
        Result.Visual.Coins := Round(Number(CoinsItem,1));
        Result.Visual.Bills := Round(Number(BillsItem,0));
        Result.Visual.OfferingX := Number(OfferingXItem,0);
        Result.Visual.OfferingY := Number(OfferingYItem,0);
        Result.Visual.Auxiliary := ShowBellItem.Value<>0;
        if Result.Visual.Auxiliary then
        begin
          Result.Visual.AuxiliaryX := Number(BellXItem,0);
          Result.Visual.AuxiliaryY := Number(BellYItem,0);
        end;
      end;
    ssBell,ssBellRear:
      begin
        Result.Visual.Strength := Number(BellStrengthItem,50);
        Result.Visual.Auxiliary := ShowBoxItem.Value<>0;
        if Result.Visual.Auxiliary then
        begin
          Result.Visual.AuxiliaryX := Number(BoxXItem,0);
          Result.Visual.AuxiliaryY := Number(BoxYItem,0);
        end;
      end;
    ssTube: Result.Visual.Strength := Number(TubeStrengthItem,50);
    ssFortunes:
      begin
        Result.Visual.Fortune := EnsureRange(FortuneItem.Value,0,5);
        Reveal := RevealItem.Value;
        if (Reveal>=Ord(Low(TFortuneReveal))) and (Reveal<=Ord(High(TFortuneReveal))) then
          Result.Visual.Reveal := TFortuneReveal(Reveal);
        Effect := FortuneEffectItem.Value;
        Result.Visual.FortuneEffect := DefaultFortuneEffect;
        if (Effect>=Ord(Low(TFortuneEffect))) and (Effect<=Ord(High(TFortuneEffect))) then
          Result.Visual.FortuneEffect := TFortuneEffect(Effect);
      end;
  end;
end;

constructor TSanpaiSession.Create;
begin
  inherited;
  FLock := TCriticalSection.Create;
  FRenderer := TSanpaiRenderer.Create;
end;

destructor TSanpaiSession.Destroy;
begin
  FRenderer.Free;
  FLock.Free;
  inherited;
end;

function TSanpaiSession.Render(Video: PFILTER_PROC_VIDEO; const Settings: TSanpaiSettings): Byte;
var
  Width,Height: Integer;
  Pixels: PPIXEL_RGBA;
begin
  Result := 0;
  if (Video^.Scene=nil) or not Assigned(Video^.SetImageData) then Exit;
  Width := Video^.Scene^.Width;
  Height := Video^.Scene^.Height;
  FLock.Acquire;
  try
    Pixels := FRenderer.Render(Width,Height,Settings,Video^.Object_^.Time);
    if Pixels=nil then Exit;
    Video^.SetImageData(Pixels,Width,Height);
    Result := 1;
  finally
    FLock.Release;
  end;
end;

function SanpaiProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
begin
  Result := 0;
  if (Video=nil) or (Video^.Object_=nil) or (Video^.UserData=nil) then Exit;
  try
    Result := TSanpaiSession(Video^.UserData).Render(Video,SnapshotSettings);
  except
    on E: Exception do OutputDebugString(PWideChar('SYNC_Sanpai render: '+E.Message));
  end;
end;

// 映像の描画器はインスタンス単位で確保し、func_destroy で解放する。
function SanpaiCreate(EffectID: Int64): Pointer; cdecl;
begin
  Result := nil;
  try
    Result := TSanpaiSession.Create;
  except
  end;
end;

procedure SanpaiDestroy(EffectID: Int64; UserData: Pointer); cdecl;
begin
  try
    TSanpaiSession(UserData).Free;
  except
  end;
end;

procedure HideWhen(const Names: array of PWideChar; Comparison: Integer; Scene: TSanpaiScene);
var
  Name: PWideChar;
begin
  for Name in Names do
  begin
    AddHideRule(GroupRules[RuleCount],Name,SceneName,Comparison,Ord(Scene));
    Inc(RuleCount);
  end;
end;

// グループ名と配下の項目名には同じ範囲条件を登録する。
procedure HideOutside(const Names: array of PWideChar; First,Last: TSanpaiScene);
begin
  if First=Last then HideWhen(Names,HideNotEqual,First)
  else
  begin
    if First>Low(TSanpaiScene) then HideWhen(Names,HideLess,First);
    if Last<High(TSanpaiScene) then HideWhen(Names,HideGreater,Last);
  end;
end;

procedure RegisterParameters;

  procedure AddPaletteColor(var Item: TFILTER_ITEM_COLOR; Name: PWideChar; Value: Cardinal);
  begin
    AddColor(Item,Name,Byte(Value and $FF),Byte((Value shr 8) and $FF),Byte((Value shr 16) and $FF));
  end;

begin
  AddSelect(SceneItem,SceneName,Ord(ssOfferingBox),@SceneOptions[0]);
  AddTrack(DelayItem,'演出開始までの時間',1,0,3600,0.01);
  AddTrack(DurationItem,'演出の時間',1,0,3600,0.01);

  AddGroup(BoxGroup,'賽銭箱関連',1);
  AddTrack(CoinsItem,'硬貨枚数',1,0,30,1);
  AddTrack(BillsItem,'紙幣枚数',0,0,10,1);
  AddTrack(OfferingXItem,'賽銭投入X座標',0,-230,230,1);
  AddTrack(OfferingYItem,'賽銭投入Y座標',0,-22,22,1);
  AddCheck(ShowBellItem,'鈴の表示',0);
  AddTrack(BellXItem,'鈴のX座標',0,-2000,2000,1);
  AddTrack(BellYItem,'鈴のY座標',0,-2000,2000,1);

  AddGroup(BellGroup,'鈴関連',1);
  AddTrack(BellStrengthItem,'鈴を鳴らす強さ',50,0,100,1);
  AddCheck(ShowBoxItem,'賽銭箱の表示',0);
  AddTrack(BoxXItem,'賽銭箱のX座標',0,-2000,2000,1);
  AddTrack(BoxYItem,'賽銭箱のY座標',0,-2000,2000,1);

  AddGroup(FortuneSharedGroup,'おみくじ共通',1);
  AddTrack(FortuneXItem,'おみくじX',0,-2000,2000,1);
  AddTrack(FortuneYItem,'おみくじY',0,-2000,2000,1);
  AddTrack(FortuneScaleItem,'おみくじ拡大率',100,1,500,0.1);

  AddGroup(TubeGroup,'おみくじ筒関連',1);
  AddTrack(TubeStrengthItem,'筒を振る強さ',50,0,100,1);

  AddGroup(FortuneGroup,'おみくじ関連',1);
  AddSelect(FortuneItem,'運勢',0,@FortuneOptions[0]);
  AddSelect(RevealItem,'表示方法',Ord(frShow),@RevealOptions[0]);
  AddSelect(FortuneEffectItem,'結果演出',Ord(DefaultFortuneEffect),@EffectOptions[0]);

  AddGroup(ColorGroup,'色設定',0);
  AddPaletteColor(WoodColorItem,'木の色',DefaultPalette.Wood);
  AddPaletteColor(FoundationColorItem,'土台の色',DefaultPalette.Foundation);
  AddPaletteColor(BoxColorItem,'賽銭箱の色',DefaultPalette.Box);
  AddPaletteColor(BellColorItem,'鈴の色',DefaultPalette.Bell);
  AddPaletteColor(RopeColorItem,'鈴緒の色',DefaultPalette.Rope);
  AddPaletteColor(TubeColorItem,'おみくじ筒の色',DefaultPalette.Tube);
  AddPaletteColor(TextItem,'文字の色',DefaultPalette.Text);
  AddPaletteColor(PaperItem,'紙の色',DefaultPalette.Paper);

  RuleCount := 0;
  HideOutside([BoxGroup.Name,CoinsItem.Name,BillsItem.Name,OfferingXItem.Name,OfferingYItem.Name,
    ShowBellItem.Name,BellXItem.Name,BellYItem.Name],ssOfferingBox,ssOfferingRear);
  HideOutside([BellGroup.Name,BellStrengthItem.Name,ShowBoxItem.Name,BoxXItem.Name,BoxYItem.Name],
    ssBell,ssBellRear);
  HideOutside([FortuneSharedGroup.Name,FortuneXItem.Name,FortuneYItem.Name,FortuneScaleItem.Name],
    ssTube,ssFortunes);
  HideOutside([TubeGroup.Name,TubeStrengthItem.Name],ssTube,ssTube);
  HideOutside([FortuneGroup.Name,FortuneItem.Name,RevealItem.Name,FortuneEffectItem.Name],
    ssFortunes,ssFortunes);
end;

function GetSanpaiFilterTable: PFILTER_PLUGIN_TABLE;
begin
  if not PluginTableInitialized then
  begin
    SetupPluginTable(FILTER_FLAG_VIDEO or FILTER_FLAG_INPUT or FILTER_FLAG_USERDATA,
      '参拝演出','SYNC','参拝演出 / SYNC_Sanpai v1.0.0',SanpaiProcVideo,nil);
    RegisterParameters;
    GetPluginTable^.Func_Create := SanpaiCreate;
    GetPluginTable^.Func_Destroy := SanpaiDestroy;
    PluginTableInitialized := True;
  end;
  Result := GetPluginTable;
end;

end.
