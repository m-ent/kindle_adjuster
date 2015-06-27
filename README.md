# kindle_adjuster

## 電子化書籍 (pdf) を kindle 用に最適化したいなあ

電子化書籍 (pdf) をKindle で読もうとすると余白のために全体が縮小されて読みづらくなってしまいます。既に [Kindlizer](https://github.com/tdtds/kindlizer) という立派な車輪があることは知っていますが、勉強も兼ねて新たな車輪を再発明してみました。

## 必要なもの

変換の根本は Kindlizer のままなので、必要なソフトウェアも同じです。
FreeBSD 上で以下のソフトウェアを使用しています。

- lang/ruby21
- graphics/ImageMagick
- graphics/poppler
- graphics/sam2p
- graphics/pdftk

## 使い方

`% ruby kindle_adjuster [book.pdf]`

これで同じディレクトリに `book_kindle.pdf` が作成されます。

## オプションなど

オプションはスクリプト本体に書き込むようにしています。

- device
  + 最適化対象のデバイス名を選択します。現状は Kindle paperwhite (212ppi) のみ設定がありますが、設定を追加する場合はすぐ上の `pixels` に端末名と解像度の hash を追加するだけです。
- crop_nombre
  + ノンブル(ページ番号など)を切り落とすか。標準では切り落とす設定ですが、false にするとノンブルは残るはずです。
- cleanup_tmpfiles
  + 作成途中で 'png'、'conv' のディレクトリに一時ファイルを作成します。変換終了後に一時ファイルを削除するかどうか設定します。

## To adjust DIY-scanned books (pdf) to a Kindle

### usage

`% ruby kindle_adjuster [book.pdf]`

it makes a file book_kindle.pdf in the same directory.

### requires

I tested this script on FreeBSD. It requires ports/pkgs as below.

- lang/ruby21
- graphics/ImageMagick
- graphics/poppler
- graphics/sam2p
- graphics/pdftk

