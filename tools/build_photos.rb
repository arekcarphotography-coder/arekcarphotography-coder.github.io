# Użycie: ruby tools/build_photos.rb <katalog-ze-źródłami> <katalog-strony>
# Konwertuje wybrane zdjęcia (tools/selection.rb) do assets/photos/<album>/ i zapisuje assets/photos.js (wymiary + data zdjęcia).
require "json"
require_relative "selection"
SRC, SITE = ARGV
OUT = File.join(SITE, "assets/photos")
CONVERT = File.join(__dir__, "convert.sh")

# Folder „@site/…” = folder w projekcie strony (np. tools/sources), inne — względem SRC
def src_dir(folder)
  folder.start_with?("@site/") ? File.join(SITE, folder.sub("@site/", "")) : File.join(SRC, folder)
end

def find(folder, num)
  return File.join(src_dir(folder), num) if num.include?(".")  # pełna nazwa pliku
  Dir.glob(File.join(src_dir(folder), "*.jpg")).sort.find { |f| File.basename(f)[/\d{5}/] == num } or abort "brak #{folder}/#{num}"
end

def shot_date(f)
  head = File.binread(f, 200_000)
  d = head.scan(/(20\d\d):(\d\d):(\d\d) \d\d:\d\d:\d\d/).map { |y, m, dd| "#{y}-#{m}-#{dd}" }.min
  d
end

jobs = []  # [album, src, name]
SEL.each do |album, spec|
  spec.each_slice(2) do |folder, nums|
    files = nums == :all ? Dir.glob(File.join(src_dir(folder), "*.jpg")).sort : nums.map { |n| find(folder, n) }
    files.each_with_index { |f, i| base = File.basename(f, ".*").unicode_normalize(:nfc)
      name = base[/D[SC]{2}\d{5}/].to_s.downcase
      # plik wskazany pełną nazwą (np. „bolideczarny.jpg”, „DSC09058-2.jpg”) → nazwa z całej nazwy pliku
      name = base.downcase.gsub(/[^a-z0-9]+/, "-") if nums != :all && nums[i].include?(".")
      jobs << [album, f, name] }
  end
end
jobs.each_with_index { |j, i| j[2] = "img-#{i}" if j[2].empty? }

COVERS = {}; jobs.each { |a, _, n| COVERS[a] ||= n }
q = Queue.new; jobs.each { |j| q << j }
res = {}; m = Mutex.new
10.times.map {
  Thread.new {
    while (j = (q.pop(true) rescue nil))
      album, f, name = j
      line = IO.popen([CONVERT, f, File.join(OUT, album), name, (name == COVERS[album] ? "cover" : "")], &:read).split
      m.synchronize { (res[album] ||= {})[name] = [name, line[1].to_i, line[2].to_i, shot_date(f)] }
    end
  }
}.each(&:join)

manifest = {}
jobs.each { |album, _, name| (manifest[album] ||= []) << res[album][name] }
File.write(File.join(SITE, "assets/photos.js"), "// Wygenerowane przez tools/build_photos.rb — [nazwa, szer., wys., data zdjęcia]\nconst PHOTOS = " + JSON.generate(manifest) + ";\n")
manifest.each { |a, l| puts "#{a}: #{l.size} zdj., daty #{l.map(&:last).compact.minmax.join(' .. ')}" }
