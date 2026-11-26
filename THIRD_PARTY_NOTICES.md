# ライセンスと共通基盤の由来

参拝演出（SYNC_Sanpai） Copyright (c) 2026 VRAMの魔術師

本体のソースコードのライセンスは GNU General Public License v3.0（GPL-3.0-only）です。[ライセンス全文](LICENSE)

## AviUtl ExEdit2 Plugin SDK

- 著作権表記は Copyright (c) 2025 Kenkun。
- MIT ライセンスの適用対象は Source/Lib/AviUtl2FilterTypes.pas の SDK 型、コールバックと編集 API の ABI 定義です。[MIT ライセンス全文](ThirdParty/LICENSE.AviUtl2-SDK.txt)

## 継承元

- SYNC_WeatherFX から Delphi プロジェクト設定、DLL の公開関数、SDK 型定義、項目登録処理と Setup を継承しています。
- SYNC_WeatherFX の共通基盤は SYNC_AquaFX、SYNC_ParticleFX、SYNC_Mine、SYNC_PhotoShot、SYNC_Nicomea に由来します。項目登録処理は Syncroh2 と SYNC_Lyrics を継承しています。

本体の描画には Windows の Direct2D と Windows Imaging Component、実装には Delphi RTL を使用しています。
