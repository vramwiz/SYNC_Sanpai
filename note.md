# SYNC_Sanpai 作業ノート

## プロジェクトの前提

- 作業フォルダーは D:\DelphiProg\MyApp\SYNC_Sanpai。プロジェクト名は SYNC_Sanpai、AviUtl2 のグループは「SYNC」、表示名は「参拝演出」。
- SYNC_WeatherFX から、Win64 プロジェクトのビルド設定、SDK 型、項目登録の共通コード、ライセンスと作業規則を引き継いだ。
- 本番ファイルは SYNC_Sanpai.dproj から作る SYNC_Sanpai.auf2。第一段階の描画検証版 v0.1.0 を基に正式仕様 v1.0.0 へ改修する。

## ビルドと検査

Delphi 37.0 を使う。プロジェクトルートから Win64 Debug と Release を順にビルドする。

~~~powershell
cmd /c 'call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" && msbuild SYNC_Sanpai.dproj /t:Rebuild /p:Config=Debug /p:Platform=Win64'
cmd /c 'call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" && msbuild SYNC_Sanpai.dproj /t:Rebuild /p:Config=Release /p:Platform=Win64'
~~~

- Debug / Release の出力先は C:\ProgramData\aviutl2\Plugin\SYNC_Sanpai\。ビルド後イベントで DLL を AUF2 にコピーし、成功後に DLL を削除する。Release イベントは RSM も削除する。
- DCU は Win64\Debug\DCU と Win64\Release\DCU。デバッガーホストは両構成とも D:\aviutl2_v2.1.16\aviutl2.exe。
- 最後に Release をビルドして配置する。両構成の警告・エラー数と AUF2 の更新を確認する。
- 本番 AUF2 を読み込む検査は Tests\run_tests.ps1 で実行する。構成別コピーを検査する場合は -PluginPath、画像出力先を指定する場合は -ImageDirectory、鈴の動画プレビューも出力する場合は -MotionPreview を指定する。
- 検査は 1280 × 720 の PNG、鈴の周期と順不同の描画、上下の構図で重なる背景、解像度の切り替えを確認し、1920 × 1080 の描画時間を計測する。通常の確認はコマンドラインで行う。IDE と AviUtl2 の画面操作はユーザーから依頼を受けて行う。
- Setup は SYNC_Sanpai の配布ZIP作成スクリプトとカタログを持つ。初版の配布手順は Setup/README.md に記載する。

## ソースの配置

- SYNC_Sanpai.dpr は DLL の初期化、最低対応バージョン、公開関数を扱う。
- Source\Lib は SDK 型とフィルターテーブル登録を扱う。型・配置を変更する場合は公式の ABI を確認する。
- Source\Plugin\Filter はメディアオブジェクトと「シーン」の登録、インスタンス単位の描画器管理、初期画像の生成を扱う。
- Source\Common では、拝殿、賽銭箱、鈴と鈴緒、おみくじ、字形を独立して描画する。描画位置・縮尺・回転は TPose で指定する。
- 描画器は解像度ごとの Direct2D 背景と直近の静止場面を各エフェクト内で再利用する。鈴緒と鈴はオブジェクト時間から計算するため、シークや逆順描画に対応する。

## ソースの保守

- 新規ユニットは .dpr の uses と .dproj の DCCReference に登録する。検索パスは Source\Common、Source\Lib、Source\Lib\FilterTable、Source\Plugin\Filter。
- ユニット先頭に目的を記載し、公開処理の入力、出力、所有権、副作用を必要に応じて示す。1ユニット約1,500行を目安に責務で分割する。
- 日本語を含む .pas、.dpr、.ps1 は UTF-8 BOM と CRLF を使用する。
- ホスト所有ポインターはコールバック内だけで借用する。Delphi 例外は DLL 境界で捕捉する。

## 第一段階の初回実装時の検査結果

- Delphi 37.0 で Win64 Debug / Release の Rebuild が完了し、両構成とも警告0・エラー0。配置済みの Release AUF2 は 1,729,536 バイト。
- 本番 AUF2 を読み込む検査で、登録と初期値、背景の一致、鈴の周期と順不同の再描画、別スレッドからの描画、寸法切り替えを確認した。Debug と Release の確認用 PNG 4枚はそれぞれ SHA-256 が一致した。
- Core i7-1260P で Release を 1920 × 1080、各48フレーム計測した。平均は賽銭箱 0.48 ms、鈴 9.52 ms、おみくじ 0.49 ms。静止シーンは初回描画後のキャッシュを使用し、計測にはホスト代替の画像受け取り処理を含む。AviUtl2 上での表示とタイムライン再生は未確認。
- ビルドと計測のログは Win64\BuildLogs、PNG と鈴の動画プレビューは Win64\Verification\Release\Images を参照。
- Setup の5ファイルと SDK・登録ユニット・ライセンスはコピー元と SHA-256 が一致した。

## 第一段階の描画修正とメディアオブジェクト登録

- 賽銭箱は正面で左右対称に描き、格子を確認できるよう上面の奥行きを浅く見せる。拝殿の下部と石畳を背景にする。
- 鈴では同じ拝殿の上部に構図を移し、軒下にしめ縄を掛ける。双方の背景が重なる範囲は同じ座標の拝殿を描く。
- おみくじは上から「開運」、運勢、横書きの「おみくじ」。5枚目の「末」は上の横画を下より長く描く。
- メディアオブジェクトとして FLAG_INPUT で登録し、シーン寸法で初期画像を生成する。将来、プログラムで効果音を合成する場合は FLAG_AUDIO と func_proc_audio を追加し、オブジェクトの SampleIndex とシーンの SampleRate から時刻を求め、チャンネル別の32ビット浮動小数点 PCM を set_sample_data で渡せる。映像と音声は別スレッドで呼ばれるため、音声生成を動画の描画順に依存させない。[SDK の filter2.h](https://github.com/aviutl2/aviutl2_sdk_mirror/blob/main/include/aviutl2_sdk/filter2.h)
- Debug / Release とも警告0・エラー0。確認用 PNG 4枚の SHA-256 は両構成で一致した。Release の1080p計測では鈴が平均9.00 ms。AviUtl2 の実画面は未確認。
- 再検査のログは Win64\BuildLogs の RevisionDebug、RevisionRelease、構成別の画像と鈴のGIFは Win64\Verification\Revision に保存した。

## 写真を参考にした拝殿と鈴の描き直し

- 賽銭箱と鈴で木格子、縦木目の板張り、打ちっぱなし風のコンクリート段を共通化した。賽銭箱のすぐ奥から段が立ち上がる。鈴の画面は軒下から段の途中までを描き、鈴本体は従来より小さい円形にした。
- おみくじは DrawFortunes に TFortuneColors を渡して、RGB の Paper と Text を独立に指定できる。和紙の濃淡と繊維、見出しと運勢の濃淡は基準色からの差分で描画する。初期色の確認画像は前版と SHA-256 が一致した。別の色を指定した検査では和紙と字形の画素を確認した。
- Win64 Debug / Release は警告0・エラー0。両構成の確認用 PNG 4枚が一致し、1080p の Release で鈴は平均8.92 ms。ログは Win64\BuildLogs の ShrineDetailDebug と ShrineDetailRelease、画像とGIFは Win64\Verification\ShrineDetail\Release\Images に保存した。AviUtl2 の実画面は未確認。

## 鈴緒の延長と第一段階の描画テスト完了

- 鈴緒の編み目を画面下端の先まで描画する。16:9、4:3、縦長の出力で最下行に鈴緒が続くことを確認した。20 fps の確認GIFも1周期84フレームすべてで最下行を検査した。
- Win64 Debug / Release は警告0・エラー0。両構成で確認用PNG 4枚が一致し、賽銭箱とおみくじのPNGは前版とも一致。1080pのReleaseで鈴は平均11.13 ms。
- 起動中のAviUtl2が前版を読み込んでいたため、コマンドラインの出力先を Win64\Verification\RopeFinal に指定して検証した。配置済みの前版を同じフォルダーの SYNC_Sanpai.previous-305b4308.bak に退避し、標準パスに検証済みReleaseを配置した。AviUtl2の次回起動から新版が読み込まれる。
- ビルドログは Win64\BuildLogs の RopeFinalDebug と RopeFinalRelease、確認画像とGIFは Win64\Verification\RopeFinal\Release\Images に保存した。

## 正式仕様の実装

- 賽銭箱と鈴の正面・背面、おみくじ筒、おみくじの6シーンを独立したメディアオブジェクトとして登録した。旧版の選択値0～2を維持し、表示順で正面・背面を隣接させた。
- 背面はストレートRGBAの透明画面で、箱の背板と鈴の背面の意匠を個別に描く。補助物の座標は主描画物に合わせた初期配置からのオフセットとして解釈する。
- Sanpai_Timeline が共通時刻、硬貨・紙幣の投入時刻、鈴・筒の作動時刻を管理する。投入軌道は固定で、開始・終了・シークは描画順から独立する。画像面と背景、最新の静止フレームをインスタンスで再利用する。
- Sanpai_Offerings が硬貨と紙幣を描き、Sanpai_Tube が木の筒と棒を描く。Sanpai_Fortunes は独自の字形を使い、運勢1枚を5つの方法で表示する。紙と文字色を別々に指定でき、二重枠は文字色に連動する。
- Sanpai_Audio が同じ時刻情報を参照して硬貨、鈴、筒の32ビット浮動小数点PCMを生成する。ホストには両チャンネルへ同じ信号を渡す。瞬時の演出では完了画面へ切り替える。
- ビルドと検査の出力は Win64\Verification\Production。出力先の切り替えは DCC_ExeOutput のコマンドライン指定で行う。

### 正式仕様の検証と配置

- Delphi 37.0 の Win64 Debug / Release は警告0・エラー0。登録順、初期値、シーン別の表示条件、透過、補助座標、6運勢、5表示方法、開始時刻、0秒・0.01秒、完了後、シークを本番AUF2で検査した。両構成のPNG/WAV 20ファイルは SHA-256 が一致した。
- 1080pのReleaseは1フレーム平均7.05～11.37 ms。賽銭箱は硬貨30枚・紙幣10枚で計測した。
- 効果音は無音区間、相対音量、硬貨接触との同期、音声ブロック境界でサンプルが一致することを確認した。WAVの波形には3種類で異なる周波数成分があり、クリッピングは検出されなかった。実際の聴感とAviUtl2画面での表示・再生は未確認。
- 標準パスに検証済みReleaseを配置した。旧版は同じフォルダーの SYNC_Sanpai.pre-production-96748945.bak に退避した。Setupはコピー元の全5ファイルと一致。
- Win64\Verification\Production\Release\Results に6シーンの一覧、場面別のPNG、4種類のGIF、3種類のWAVがある。Win64\BuildLogs の ProductionDebug と ProductionRelease がビルド・検査記録。

## 投入位置・おみくじ筒・共通色の調整

- 一覧は賽銭箱（正面・背面）、鈴（正面・背面）、おみくじ筒、おみくじの演出順。保存済みのシーン番号は維持する。
- 賽銭投入X座標・Y座標は1280×720を基準とした、箱の格子中央からの相対値。Xは−230～230、Yは−22～22で初期値はともに0。硬貨1枚は格子の中央に着地し、複数枚は指定位置の周囲に散る。
- おみくじ筒は取り出し口が下を向くよう回転し、傾いた筒の下側から棒が出る。
- 共通の「色設定」に木、土台、賽銭箱、鈴、鈴緒、おみくじ筒、文字、紙をまとめた。拝殿は木と土台の色ごとに背景キャッシュを更新する。基準色を境に影とハイライトを補間し、模様・陰影を保つ。
- Debug / Release の出力、確認画像とGIFは Win64\Verification\PaletteAndPlacement。ログは Win64\BuildLogs の PaletteAndPlacementDebug と PaletteAndPlacementRelease。
- 本番AUF2で投入の初期位置とX・Yの移動、棒の下向きの伸び、8色と背景キャッシュの反映を検査した。両構成は警告0・エラー0で、PNG/WAV 30出力が一致した。1080p Releaseは平均9.19～12.57 ms/フレーム。
- 検証済みReleaseを標準パスへ配置した。前版は同じフォルダーの SYNC_Sanpai.pre-palette-706931bb.bak に退避した。AviUtl2の実画面は未確認。

## AviUtl2ドロップダウンの並び順

- ユーザーの画面では、登録配列の順序ではなく選択値の数値順で表示された。列挙値を0～5の演出順にし、正面・背面を隣接させた。
- 最後の2項目は「おみくじをひく」と「おみくじの結果」。AviUtl2 2.1.16で作成した参考プロジェクトでは選択肢が表示名で保存されていたため、旧名「おみくじ筒」「おみくじ」を使用した箇所の選び直しをREADMEに記載した。
- ビルドと検査は Win64\BuildLogs の SceneOrderDebug と SceneOrderRelease、出力は Win64\Verification\SceneOrder。
- Debug・Releaseともに警告0・エラー0。登録値0～5、表示名、各シーンの表示条件を検査し、PNG/WAV 30出力が両構成および前版と一致した。Releaseを標準パスに配置し、前版は SYNC_Sanpai.pre-scene-order-1fad7e09.bak に退避した。修正後のAviUtl2の実画面は未確認。

## おみくじの位置・拡大率と結果演出

- 「おみくじをひく」と「おみくじの結果」に「おみくじ共通」を追加。X・Yは既定位置からのオフセット、拡大率は対象の中心を基準とした1～500%で、既定値は0・0・100%。筒と紙はそれぞれのオブジェクトで設定する。
- 「結果演出」の既定値は「ふわっと登場」。選択肢は「なし」「ふわっと登場」「フェードイン」「軽く弾む」。表示方法と組み合わせて共通の演出時間内に完了する。折り開き等でのフェードインは枠と文字に適用する。
- 専用項目の非表示条件は連続したシーン番号の範囲で登録する。結果演出は結果にだけ、おみくじの座標・拡大率は筒と結果の両方に表示する。
- 出力は Win64\Verification\FortuneEffects。ログは Win64\BuildLogs の FortuneEffectsDebug と FortuneEffectsRelease、登場の確認GIFは Release\Results\fortune-entrance.gif。
- Debug・Releaseとも警告0・エラー0。筒と紙の移動・拡縮、各結果演出と「なし」、表示方法との組み合わせ、0秒での完了、シークを検査した。両構成のPNG/WAV 35出力が一致し、旧設定の30出力も前版と一致した。Releaseを標準パスに配置し、前版を SYNC_Sanpai.pre-fortune-effects-53563af7.bak に退避した。AviUtl2の実画面は未確認。

## v1.0.0 配布用の整理

- 公開処理の引数、座標系、キャッシュの更新条件、ホスト所有データの寿命をコメントで補足した。描画と音声の処理は維持し、本番ソースで最長のユニットは484行。
- README は導入と操作の説明にまとめ、確認済みの描画から6シーンの一覧を Sample/scenes.png に作成した。
- Delphi 37.0 Win64 Debug / Release は警告0・エラー0。本番AUF2での検査を通過し、両構成のPNG/WAV 35出力が前版と一致した。ログは Win64\BuildLogs の DistributionDebug と DistributionRelease。
- Setup の作成スクリプトを Sanpai 用に変更した。配布ZIPには Release 本体、README、ライセンス類を収録する。同梱READMEの画像は v1.0.0 タグを参照する。
- ZIP内のAUF2の SHA-256 は DF06CDFA802BF0C642048C2DF3E276A572A647B12D14F88291DC79B382AA5904。カタログの XXH3-128 は 2ddbbc8a79fbcc88f91385d8229619b6 で、展開したAUF2と一致した。

## 音声生成の削除と v1.0.0 の更新

- 映像専用のメディアオブジェクトとして登録する。合成音、音声コールバック、「効果音関連」「効果音」「音量」を削除した。「鈴を鳴らす強さ」は揺れ幅を調整する保存項目として使う。
- Delphi 37.0 の Win64 Debug・Release は警告0・エラー0。本番AUF2で映像専用の登録と6シーンの描画を検査した。ビルド・検査ログは Win64\BuildLogs の SilentReleaseDebug と SilentReleaseRelease、結果は Win64\Verification\SilentRelease に保存した。
- 公開済み v1.0.0 と比較し、両構成で PNG 32枚とプレビュー5本分の描画直後のRGBA 215フレームが一致した。AviUtl2 の実画面は未確認。
- 検証済みReleaseを標準パスに配置した。Setup の配布ZIPとカタログを更新した。ZIP内のAUF2の SHA-256 は 9AFCE13AAEB0C90AFC1FCF3CBEDDBC3B5B146AE3F16215E0C3A908552CA3ED19、カタログの XXH3-128 は f17be42a95905d6cab97e089f11c3af2。
