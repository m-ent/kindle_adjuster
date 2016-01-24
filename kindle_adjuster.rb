# Kindle adjuster
#   requires graphics/ImageMagick
#            graphics/poppler
#            graphics/sam2p
#            graphics/pdftk

Device_name = :kindle_paperwhite
Crop_nombre = true # ノンブルなどを削除するか
cleanup_tmpfiles = true  # 最後に一時ファイルを削除するか
edge_lines_enable = true # ページの端に線を描き、Kindleによる自動的な
                         # 余白削除を抑制する
setting1 = "40%,90%.0.4" # やや地が濃いデータ用
setting2 = "25%,90%,0.3" # やや地が白いデータ用
level_settings = setting1

class Device
  attr_reader :name, :pixels, :x, :y, :aspect

  def initialize(device_name)
    pix = {:kindle_paperwhite => "658x905"}
    @name = device_name.to_s
    @pixels = pix[device_name]
    @pixels.match(/(\d+)x(\d+)/)
    @x = $1.to_i
    @y = $2.to_i
    @aspect = @x.to_f/@y.to_f
  end
end

def get_breakpoint(filename, axis, sample_n, step, threshold)
  case axis
  when :x
    g = ['', 'x0+', '+0']  # #{step}x0+#{ofs}+0
  when :y
    g = ['0x', '+0+', '']  # 0x#{step}+0+#{ofs}
  end
  white = 65535
  start_p = 0
  breakpoints = Array.new
  sample_n.times do |i|
    ofs = (step * i).to_i
    value = \
      `convert #{filename} -crop #{g[0]}#{step}#{g[1]}#{ofs}#{g[2]}\
       -format "%[mean]" info:`.to_f
    white = value if i == 0
    if (start_p == 0) && (value/white < threshold)
      start_p = ofs
    end
    if (start_p != 0) && (value/white >= threshold)
      breakpoints << start_p
      breakpoints << ofs
      start_p = 0
    end
  end
  return breakpoints[0]-step.to_i, breakpoints[-1]+step.to_i
end

def get_crop_area(f)
  org_size = `convert #{f} -format "%Wx%H" info:`.match(/(\d+)x(\d+)/)
  x = org_size[1].to_f
  y = org_size[2].to_f
  sample_n = 150
  dx = x/sample_n
  dy = y/sample_n
  threshold_x = 0.75
  threshold_y = Crop_nombre ? 0.66: 0.90

  dev_aspect = Device.new(Device_name).aspect

  start_x, end_x = get_breakpoint(f, :x, sample_n, dx, threshold_x)
  start_y, end_y = get_breakpoint(f, :y, sample_n, dy, threshold_y)

  if ((end_x-start_x).to_f/(end_y-start_y)) < dev_aspect
    adjust = (end_y - start_y) * dev_aspect - (end_x - start_x)
    start_x -= adjust.to_i / 2
    end_x += adjust.to_i / 2
  else
    adjust = (end_x - start_x) / dev_aspect - (end_y - start_y)
    start_y -= adjust.to_i / 2
    end_y += adjust.to_i / 2
  end

  return {x1: end_x - start_x, y1: end_y - start_y,\
          x2: start_x, y2: start_y}
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

dev = Device.new(Device_name)

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

i = 0
5.upto(skips - 5) do |i|
  sample_page_list << " #{pages[i * skip_rate][0]}"
end

puts "calculating effective size... #{elapsed_time(start_time)}"
system("convert #{sample_page_list} -level #{level_settings} -background none -compose darken -flatten ./png/output.jpg") # リストのページをすべて重ね合わせる

g = get_crop_area('./png/output.jpg')
crop_geometry = "#{g[:x1]}x#{g[:y1]}+#{g[:x2]}+#{g[:y2]}"

Dir.mkdir("./conv") if not Dir.exist?("./conv")
i = 0
puts "cropping/converting png images... #{elapsed_time(start_time)}"
edge_lines = ""
if edge_lines_enable
  edge_lines = "-strokewidth 10 -draw 'line 0,0 #{dev.x},0'"
end
pages.each do |p|
  case i
  when 0, (pages.length-1)  # 最初と最後のページ(表紙と裏表紙)はcropしない
    system("convert #{p[0]} -resize #{dev.pixels} -type Grayscale ./conv/#{'%04d' % i}.png")
  when 1..(pages.length-2)  # 他はcropしてから処理
    system("convert #{p[0]} -rotate \"90>\" -crop #{crop_geometry} -resize #{dev.pixels} -type Grayscale -level #{level_settings} #{edge_lines} ./conv/#{'%04d' % i}.png")
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
