# Kindle adjuster
#   requires graphics/ImageMagick
#            graphics/poppler
#            graphics/sam2p
#            graphics/pdftk

pixels = {:kindle_paperwhite => "658x905"} 
device = :kindle_paperwhite

fuzz_level = 70  # 余白切り取りのための設定値 default: 70%
setting1 = "40%,90%.0.4" # やや地が濃いデータ用
setting2 = "25%,90%,0.3" # やや地が白いデータ用
level_settings = setting1

book = ARGV.shift
if not book
  puts "Usage: ruby kindle_adjuster bookname.pdf"
  exit
end

start_time = Time.now

Dir.mkdir("./png") if not Dir.exist?("./png")
puts "splitting #{book} into png images...  #{Time.now - start_time}sec"
system("pdfimages -png #{book} ./png/page") # ページごとに png に切り分け

puts "selecting pages... #{Time.now - start_time}sec"
pages = Array.new
Dir.glob('./png/*.png').each do |f|  # ページごとのファイル名と横幅を季肋
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

puts "calculating effective size... #{Time.now - start_time}sec"
system("convert #{sample_page_list} -background none -compose darken -flatten ./png/output.jpg") # リストのページをすべて重ね合わせる

crop_geometry = `convert png/output.jpg -fuzz #{fuzz_level}% -trim -format "%wx%h%X%Y" info:`  # 重ね合わせ画像の余白を検出

Dir.mkdir("./conv") if not Dir.exist?("./conv")
i = 0
puts "cropping/converting png images... #{Time.now - start_time}sec"
pages.each do |p|
  case i
  when 0, (pages.length-1)  # 最初と最後のページ(表紙と裏表紙)はcropしない
    system("convert #{p[0]} -resize #{pixels[device]} -type Grayscale ./conv/#{'%04d' % i}.png")
  when 1..(pages.length-2)  # 他はcropしてから処理
    system("convert #{p[0]} -crop #{crop_geometry} -resize #{pixels[device]} -type Grayscale -level #{level_settings} ./conv/#{'%04d' % i}.png")
  else
  end
  i += 1
end

puts "making pdf from png files... #{Time.now - start_time}sec"
Dir.glob('./conv/*.png').each do |f|
  system("sam2p #{f} #{f}.pdf")
end
system("pdftk ./conv/*.pdf cat output ./#{book.sub('.pdf','_kindle.pdf')}")

Dir.glob("./png/*") do |f|
    File.delete(f)
end
Dir.glob("./conv/*") do |f|
    File.delete(f)
end
