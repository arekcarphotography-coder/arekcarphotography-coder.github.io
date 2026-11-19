# Dopasowanie zdjęć przysłanych na czacie do zdjęć na stronie / oryginałów (porównanie miniatur 16×16).
#   ruby tools/match_photos.rb <katalog_tmp> <zdjęcie_szukane>... -- <kandydat>...
require "fileutils"
tmp = ARGV.shift; FileUtils.mkdir_p(tmp)
sep = ARGV.index("--"); wanted = ARGV[0...sep]; cands = ARGV[(sep + 1)..]

def sig(path, tmp)
  out = File.join(tmp, path.gsub(/[^A-Za-z0-9]/, "_") + ".bmp")
  system("sips", "-s", "format", "bmp", "-z", "16", "16", path, "--out", out, out: File::NULL, err: File::NULL) unless File.exist?(out)
  b = File.binread(out); off = b[10, 4].unpack1("V"); w = b[18, 4].unpack1("l<"); h = b[22, 4].unpack1("l<").abs; bpp = b[28, 2].unpack1("v")
  step = bpp / 8; row = ((w * step + 3) / 4) * 4
  (0...h).flat_map { |y| (0...w).map { |x| i = off + y * row + x * step; c = b[i, 3].bytes; [c[2], c[1], c[0]] } }.flatten
rescue => e
  nil
end

cs = cands.map { |c| [c, sig(c, tmp)] }.select { |_, s| s }
wanted.each do |wf|
  ws = sig(wf, tmp) or next
  best = cs.map { |c, s| [c, ws.zip(s).sum { |a, b| (a - b).abs } / ws.size.to_f] }.sort_by(&:last).first(3)
  puts "#{File.basename(wf)} → " + best.map { |c, d| "#{c.sub(/.*assets\/photos\//, "")} (#{d.round(1)})" }.join(", ")
end
