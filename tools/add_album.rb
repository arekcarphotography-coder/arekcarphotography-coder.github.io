# encoding: utf-8
# Dodaje nowy album ze zdjęć w folderze (koduje WebP, dopisuje assets/photos.js i tools/selection.rb).
# Wpis albumu (tytuł, miejsce, opis) dodaje się osobno w assets/data.js.
#
# Użycie (w folderze strony):
#   ruby -E UTF-8 tools/add_album.rb <slug-albumu> <folder w ~/Desktop/DoStronki> <numer okładki> [pliki do pominięcia,...]
#   np. ruby -E UTF-8 tools/add_album.rb koenigsegg-jesko JESKO 05004
#
# Bierze pliki DSC*.jpg (np. „tapeta.jpg” jest pomijana). Gdy numer DSC się powtarza (DSC05653 i DSC05653-1),
# nazwy w sieci biorą się z całej nazwy pliku (dsc05653, dsc05653-1). Okładka idzie na początek, reszta po numerach.
require "json"
SRC = File.expand_path("~/Desktop/DoStronki")
album, folder, cover, skip = ARGV
abort "Użycie: ruby -E UTF-8 tools/add_album.rb <slug> <folder> <numer okładki> [pomiń,...]" unless album && folder && cover
skip = (skip || "").split(",")
ENV["CWEBP"] ||= File.expand_path("tools/bin/cwebp")
abort "Brak cwebp: #{ENV["CWEBP"]}" unless File.executable?(ENV["CWEBP"])

def shot_date(f)
  File.binread(f, 300_000).scan(/(20\d\d):(\d\d):(\d\d) \d\d:\d\d:\d\d/).map { |y, m, d| "#{y}-#{m}-#{d}" }.min
end

files = Dir.glob(File.join(SRC, folder, "DSC*.jpg")).sort.reject { |f| skip.include?(File.basename(f)) }
abort "Brak zdjęć DSC*.jpg w #{File.join(SRC, folder)}" if files.empty?
nums = files.map { |f| File.basename(f)[/\d{5}/] }
dup = nums.group_by(&:itself).select { |_, v| v.size > 1 }.keys
jobs = files.map do |f|
  b = File.basename(f, ".*"); n = b[/\d{5}/]
  dup.include?(n) ? [f, b.downcase.gsub(/[^a-z0-9]+/, "-"), File.basename(f)] : [f, "dsc#{n}", n]
end
c = jobs.find { |_, name, _| name == "dsc#{cover}" } or abort "Nie ma okładki DSC#{cover} w folderze"
jobs = [c] + (jobs - [c])

ph = File.read("assets/photos.js", encoding: "UTF-8")
abort "Album #{album} już jest w assets/photos.js" if ph.include?(%Q|"#{album}":[|)

q = Queue.new; jobs.each { |j| q << j }; res = {}; m = Mutex.new
8.times.map { Thread.new { while (j = (q.pop(true) rescue nil))
  f, name, _ = j
  line = IO.popen(["tools/convert.sh", f, "assets/photos/#{album}", name, j.equal?(jobs.first) ? "cover" : ""], &:read).split
  m.synchronize { res[f] = [name, line[1].to_i, line[2].to_i, shot_date(f)] }
end } }.each(&:join)
list = jobs.map { |f, *| res[f] }
abort "Konwersja nie powiodła się" if list.any? { |_, w, h, _| w.to_i.zero? || h.to_i.zero? }

ph.sub!(/\]\]\};\s*\z/) { %Q|]],"#{album}":#{JSON.generate(list)}};\n| } or abort "Nie umiem dopisać do photos.js"
File.write("assets/photos.js", ph)

s = File.read("tools/selection.rb", encoding: "UTF-8")
tail = s.slice!(/\n\}\s*\z/) or abort "Nie umiem dopisać do selection.rb"
s << %Q|,\n  "#{album}" => [#{folder.inspect}, %w[#{jobs.map(&:last).join(" ")}]]| << tail
File.write("tools/selection.rb", s)

dates = list.map(&:last).compact
puts "#{album}: #{list.size} zdj., okładka #{list.first.first}, daty #{dates.minmax.join(' .. ')}"
puts "Teraz dodaj wpis albumu w assets/data.js (slug: \"#{album}\")."
