# Kindle adjuster
#   requires graphics/ImageMagick
#            graphics/poppler
#            graphics/sam2p
#            graphics/pdftk

pixels = {:kindle_paperwhite => "658x905"} 

device = :kindle_paperwhite
crop_nombre = true  # ノンブルなどを削除するか
cleanup_tmpfiles = true  # 最後に一時ファイルを削除するか
edge_lines_enable = true # ページの端に線を描き、Kindleによる自動的な
                         # 余白削除を抑制する

fuzz_level = 50  # 余白切り取りのための設定値 default: 50%
setting1 = "40%,90%.0.4" # やや地が濃いデータ用
setting2 = "25%,90%,0.3" # やや地が白いデータ用
level_settings = setting1
offset_top = 0   # ノンブルを除去しない場合の値
offset_buttom = 0

def search_breakpoint(side)
  sample_height = `convert png/output.jpg -format "%H" info:`.to_i
  if side == :top
    start_offset = 0
    dir = 1       # 探索方向は下
  else
    start_offset = sample_height
    dir = -1      # 探索方向は上
  end

  trend = Array.new
  trend << {:offset => 0, :value => 65536, :sign => 1}
  20.times do |i|
    offset = i * 10 + 10
    y = start_offset + dir * offset
    value = `convert ./png/output.jpg -crop x#{offset}+0+#{dir>0? 0: y} -format "%[mean]" info:`.to_f
    sign = (value - trend.last[:value] ) > -250? 1: -1
                          # sign は範囲内の画素値の平均値が黒くなれば負
                          # 白くなるか、余り変わらなければ正とする
    trend << {:offset => offset, :value => value, :sign => sign}
  end

  i = 0
  while (trend[i][:sign] > 0) do  # 最初は白いままで
    i += 1
    return 0 if i > 20
  end
  while (trend[i][:sign] < 0) do  # 次に黒くなる(ノンブルなどで)
    i += 1                        # 20回目(200px)まで黒いままなら本文に
    return 0 if i > 20            # 入っていると考える
  end

  return trend[i-1][:offset]
end

def elapsed_time(start_time)
  t = Time.now - start_time
  "#{(t/60).floor}min #{(t % 60).floor}sec"
end

book = ARGV.shift
if not book
  puts "Usage: ruby kindle_adjuster bookname.pdf"
  exit
end

start_time = Time.now

Dir.mkdir("./png") if not Dir.exist?("./png")
puts "splitting #{book} into png images...  #{elapsed_time(start_time)}"
system("pdfimages -png #{book} ./png/page") # ページごとに png に切り分け

puts "selecting pages... #{elapsed_time(start_time)}"
pages = Array.new
Dir.glob('./png/*.png').each do |f|  # ページごとのファイル名と横幅を記録
  w = `identify -format '%w' #{f}`
  pages << [f, w.to_i]
end

ww = 0
pages.each do |p|
  ww += p[1]
end
mean_w = ww / pages.length   # 平均のページ横幅を計算

(pages.length - 1).downto(0) do |i|
  if pages[i][1] < mean_w * 0.85 or pages[i][1] > mean_w * 1.7
    File.delete(pages[i][0])
    pages.delete_at(i)       # 平均から大きく外れるファイルを除外
  end
end

sample_page_list = ""

skips = 101     # 100ページほどを抽出して、最初と最後を除いてリスト作成
skip_rate = 0
while (skip_rate % 2 == 0) do
  skips -= 1
  skip_rate = pages.length / skips
end
if pages.length < 100  # 100ページ未満のpdfの場合は全てのページをリスト化
  skips = page.length
  skip_rate = 1
end

i =0
5.upto(skips - 5) do |i|
  sample_page_list << " #{pages[i * skip_rate][0]}"
end

puts "calculating effective size... #{elapsed_time(start_time)}"
system("convert #{sample_page_list} -level #{level_settings} -background none -compose darken -flatten ./png/output.jpg") # リストのページをすべて重ね合わせる

crop_geometry = `convert png/output.jpg -fuzz #{fuzz_level}% -trim -format "%wx%h%X%Y" info:`  # 重ね合わせ画像の余白を検出

if crop_nombre # ノンブル除去するなら上下のオフセット値で切り出し範囲を調整
  sample_height = `convert png/output.jpg -format "%H" info:`.to_i
  sample_width = `convert png/output.jpg -format "%W" info:`.to_i
  offset_top = search_breakpoint(:top)
  offset_buttom = search_breakpoint(:buttom)
  if offset_top == 0
    top_fill = ""
  else
    top_fill = " -fill white -draw \"rectangle #{sample_width} #{offset_top} 0 0\" "
  end
  if offset_buttom == 0
    buttom_fill = ""
  else
    buttom_fill = " -fill white -draw \"rectangle #{sample_width} #{offset_buttom} 0 #{sample_height - offset_buttom - 1}\" "
  end
  system("convert ./png/output.jpg #{top_fill} #{buttom_fill} ./png/output2.jpg")     # ノンブル部分を白で埋める
  crop_geometry = `convert png/output2.jpg -fuzz #{fuzz_level}% -trim -format "%wx%h%X%Y" info:`  # 再度余白を検出
end

Dir.mkdir("./conv") if not Dir.exist?("./conv")
i = 0
puts "cropping/converting png images... #{elapsed_time(start_time)}"
edge_lines = ""
if edge_lines_enable
  /(\d+)x(\d+)/.match(pixels[device])
  output_x = $1.to_i
  output_y = $2.to_i
  if (output_y / output_x.to_f) > (sample_height / sample_width.to_f) 
    output_y = (output_x * sample_height / sample_width.to_f).round
  else
    output_x = (output_y * sample_width / sample_height.to_f).round
  end
  edge_lines = "-strokewidth 10 -draw 'line 0,0 658,0'"
end
pages.each do |p|
  case i
  when 0, (pages.length-1)  # 最初と最後のページ(表紙と裏表紙)はcropしない
    system("convert #{p[0]} -resize #{pixels[device]} -type Grayscale ./conv/#{'%04d' % i}.png")
  when 1..(pages.length-2)  # 他はcropしてから処理
    system("convert #{p[0]} -crop #{crop_geometry} -resize #{pixels[device]} -type Grayscale -level #{level_settings} #{edge_lines} ./conv/#{'%04d' % i}.png")
  else
  end
  i += 1
end

puts "making pdf from png files... #{elapsed_time(start_time)}"
Dir.glob('./conv/*.png').each do |f|
  system("sam2p -j:quiet #{f} #{f}.pdf")
end
system("pdftk ./conv/*.pdf cat output ./#{book.sub('.pdf','_kindle.pdf')}")

if cleanup_tmpfiles
  Dir.glob("./png/*") do |f|
    File.delete(f)
  end
  Dir.glob("./conv/*") do |f|
    File.delete(f)
  end
end
