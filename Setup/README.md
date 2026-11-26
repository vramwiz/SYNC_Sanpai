# SYNC_Sanpai の配布ZIP

配布対象の Win64 Release 本体を用意し、使用するタグとカタログの末尾バージョンを合わせます。初回の公開バージョンは v1.0.0 です。公開日をカタログの release_date に設定します。

ハッシュには [xxHash 公式 Windows 64ビット版 v0.8.4](https://github.com/Cyan4973/xxHash/releases/download/v0.8.4/xxhsum_win64_v0_8_4.zip) の xxhsum.exe を使用します。Win64\Dependencies\xxHash-0.8.4 に置くか、PATH に登録します。

~~~bat
Setup\make_release_zip.bat
~~~

通常は C:\ProgramData\aviutl2\Plugin\SYNC_Sanpai から本体を読み込みます。別の場所を指定する場合は次のように実行します。

~~~bat
Setup\make_release_zip.bat -ReleaseDirectory "D:\Release\SYNC_Sanpai" -XxhsumPath "D:\Tools\xxhsum.exe"
~~~

同じフォルダーに SYNC_Sanpai.zip を作成し、SYNC_Sanpai.catalog.json に梱包済みAUF2の XXH3-128 を記録します。

## ZIPの内容

~~~text
SYNC_Sanpai/
  SYNC_Sanpai.auf2
  README.md
  LICENSE
  THIRD_PARTY_NOTICES.md
  ThirdParty/
    LICENSE.AviUtl2-SDK.txt
~~~

同梱READMEはリポジトリのREADMEから生成し、画像は公開タグを参照します。GitHubのリリースには、ZIPとカタログJSONの両方を添付します。
