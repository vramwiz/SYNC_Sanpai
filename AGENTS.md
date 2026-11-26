# SYNC_Sanpai の作業規則

- 作業開始時に note.md を読む。プラグインの使い方は README.md を確認する。
- 本番には SYNC_Sanpai.dproj を使用する。検査用 EXE は本番 AUF2 を読み込む。
- Delphi 37.0 の rsvars.bat と MSBuild で Win64 Debug / Release をビルドし、警告・エラー数と AUF2 の更新を確認する。
- ユニット追加時は .dpr の in と .dproj の DCCReference を更新する。ユニットの配置、文字コードとコメントは note.md に従う。
- ホスト所有ポインターはコールバック内で借用し、Delphi 例外を DLL 境界で捕捉する。
- IDE と AviUtl2 の起動・画面操作はユーザーから依頼を受けて行う。
- Setup はコピー元と同じ内容を保持する。配布用への変更やスクリプトの実行は別途依頼を受けて行う。
