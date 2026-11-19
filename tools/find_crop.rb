# Szuka, jaki wycinek oryginału (ten sam kształt) daje przysłany kadr: ruby tools/find_crop.rb <tmp> <oryginał> <kadr>
# Wypisuje x y szer wys w pikselach oryginału.
tmp, orig, crop = ARGV
def gray(path, w, h, out)
  system("sips", "-s", "format", "bmp", "-z", h.to_s, w.to_s, path, "--out", out, out: File::NULL, err: File::NULL)
  b = File.binread(out); off = b[10, 4].unpack1("V"); bw = b[18, 4].unpack1("l<"); bh = b[22, 4].unpack1("l<"); step = b[28, 2].unpack1("v") / 8
  row = ((bw * step + 3) / 4) * 4; flip = bh > 0; bh = bh.abs
  Array.new(bh) { |y| yy = flip ? bh - 1 - y : y; Array.new(bw) { |x| i = off + yy * row + x * step; c = b[i, 3].bytes; (c[0] + c[1] * 2 + c[2]) / 4 } }
end
ow, oh = `sips -g pixelWidth -g pixelHeight "#{orig}"`.scan(/\d+$/).map(&:to_i)
O = gray(orig, 240, 360, "#{tmp}/o.bmp"); C = gray(crop, 40, 60, "#{tmp}/c.bmp")
def score(z, ox, oy)
  w = 240.0 / z; h = 360.0 / z; s = 0
  60.times { |y| sy = (oy + (y + 0.5) * h / 60).to_i; r = O[sy]; cr = C[y]; 40.times { |x| s += (r[(ox + (x + 0.5) * w / 40).to_i] - cr[x]).abs } }
  s
end
best = [1e18]
(100..160).step(2).each { |zi| z = zi / 100.0; mx = (240 - 240 / z).floor; my = (360 - 360 / z).floor
  (0..mx).step(3).each { |ox| (0..my).step(3).each { |oy| sc = score(z, ox, oy); best = [sc, z, ox, oy] if sc < best[0] } } }
_, z, ox, oy = best
((z * 100 - 2).round..(z * 100 + 2).round).each { |zi| zz = zi / 100.0; mx = (240 - 240 / zz).floor; my = (360 - 360 / zz).floor
  ([ox - 4, 0].max..[ox + 4, mx].min).each { |x| ([oy - 4, 0].max..[oy + 4, my].min).each { |y| sc = score(zz, x, y); best = [sc, zz, x, y] if sc < best[0] } } }
sc, z, ox, oy = best
k = ow / 240.0
puts "zoom #{z} score/px #{(sc / 2400.0).round(1)}"
puts [(ox * k).round, (oy * k).round, (ow / z).round, (oh / z).round].join(" ")
