# kindle_adjuster

## 電子化書籍 (pdf) を kindle 用に最適化したいなあ

電子化書籍 (pdf) をKindle で読もうとすると余白のために全体が縮小されて読みづらくなってしまいます。既に [Kindlizer](https://github.com/tdtds/kindlizer) という立派な車輪があることは知っていますが、勉強も兼ねて新たな車輪を再発明してみました。

## 必要なもの

変換の根本は Kindlizer のままなので、必要なソフトウェアも同じです。
FreeBSD 上で以下のソフトウェアを使用しています。

- lang/ruby25
- graphics/ImageMagick
- graphics/poppler
- graphics/sam2p
- graphics/pdftk

## 使い方

`% ruby kindle_adjuster [book.pdf or pdf_directory]`

これで同じディレクトリに `book.pdf` から `book_kindle.pdf` が作成されます。

## オプションなど

オプションはスクリプト本体に書き込むようにしています。

- device_name
  + 最適化対象のデバイス名を選択します。現状は Kindle paperwhite (5th Gen, 2012: 212ppi), Kindle paperwhite3 (7th Gen, 2015: 300ppi) の設定がありますが、設定を追加する場合は `Device` class 定義内の `pix` に端末名と解像度の hash を追加するだけです。
- crop_nombre
  + ノンブル(ページ番号など)を切り落とすか。標準では切り落とす設定ですが、false にするとノンブルは残るはずです。
- cleanup_tmpfiles
  + 作業途中で `/tmp` 以下にランダムな名前のディレクトリを作成します。変換終了後にこのディレクトリを削除するかどうかを設定します。
- edge_lines_enable
  + 余白が多い場合 Kindle が自動的に余白を削除することがありますが、この場合文字の大きさが拡大されてしまいます。これを抑制するためにページの上端に線を描くようにします。

## To adjust DIY-scanned books (pdf) to a Kindle

### usage

`% ruby kindle_adjuster [book.pdf or pdf_directory]`

it makes a pdf file "book_kindle.pdf" from "book.pdf" in the same directory.

### requires

I tested this script on FreeBSD. It requires ports/pkgs as below.

- lang/ruby25
- graphics/ImageMagick
- graphics/poppler
- graphics/sam2p
- graphics/pdftk

