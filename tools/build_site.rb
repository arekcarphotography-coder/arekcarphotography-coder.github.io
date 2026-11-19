# encoding: utf-8
# Generator stron pod SEO. Uruchamiaj po każdej zmianie albumów, wpisów albo domeny:
#   ruby -E UTF-8 tools/build_site.rb
#
# Co robi:
#  • każda strona ma własny adres w dwóch językach:
#      /                     /en/                      strona główna
#      /albumy/<album>/      /en/albums/<album>/       album
#      /wyjazdy/<wyjazd>/    /en/trips/<wyjazd>/       wyjazd (event)
#      /blog/<wpis>/         /en/blog/<wpis>/          wpis na blogu
#  • w <head>: tytuł, opis, adres kanoniczny, hreflang PL/EN, podgląd linku (Open Graph), dane strukturalne (JSON-LD)
#  • w treści: nagłówek, opis i linki widoczne także bez JavaScriptu (dla wyszukiwarek i podglądów)
#  • sitemap.xml (ze zdjęciami — Google Grafika), robots.txt, 404.html, obrazki podglądu linków (assets/og/*.jpg)
# Wzorce stron: index.html, album.html, trip.html, post.html (blok między <!-- SEO:START --> a <!-- SEO:END --> jest generowany).
require "json"; require "fileutils"; require "cgi"

ROOT = File.expand_path("..", __dir__)
Dir.chdir(ROOT)

# ---------- dane z assets/data.js i assets/photos.js ----------
# data.js to JavaScript, ale literały obiektów { klucz: "wartość" } są też poprawnym Ruby — wycinamy je i wczytujemy.
DATA_SRC = File.read("assets/data.js", encoding: "UTF-8")
def js_literal(name)
  start = DATA_SRC.index("const #{name} = ") or abort "Brak „const #{name}” w data.js"
  k = start + "const #{name} = ".size
  out = +""; depth = 0; str = nil
  while k < DATA_SRC.size
    c = DATA_SRC[k]
    if str
      if c == "\\" then out << c << DATA_SRC[k + 1]; k += 2; next end
      out << (c == "#" && str == '"' ? "\\#" : c)
      str = nil if c == str
      k += 1; next
    end
    if c == '"' || c == "'" then str = c; out << c; k += 1; next end
    if DATA_SRC[k, 2] == "//" then k = DATA_SRC.index("\n", k) || DATA_SRC.size; next end
    if DATA_SRC[k, 2] == "/*" then k = DATA_SRC.index("*/", k) + 2; next end
    depth += 1 if "[{(".include?(c)
    depth -= 1 if "]})".include?(c)
    out << c; k += 1
    break if depth.zero? && (out.lstrip.start_with?("[", "{", "(") ? "]})".include?(c) : c == ";" || c == "\n")
  end
  eval(out.sub(/;\s*\z/, "").gsub(/\bnull\b/, "nil"))
end
SITE_URL = js_literal("SITE_URL").to_s.chomp("/")
EMAIL    = js_literal("EMAIL")
SOCIAL   = js_literal("SOCIAL")
TRIPS    = js_literal("TRIPS")
ALBUMS   = js_literal("ALBUMS")
HERO     = js_literal("HERO")
POSTS    = js_literal("POSTS")
I18N     = js_literal("I18N")
PHOTOS   = JSON.parse(File.read("assets/photos.js", encoding: "UTF-8")[/\{.*\}/m])
ALBUMS.each do |a|
  a[:photos] = PHOTOS[a[:slug]] || []
  a[:cover] = a[:photos][0] && a[:photos][0][0]
  a[:hero] = (a[:photos].find { |_, w, h| w > h * 1.2 } || a[:photos][0] || [])[0]
end
ALBUMS.reject! { |a| a[:photos].empty? }
FIND = ALBUMS.to_h { |a| [a[:slug], a] }

# ---------- pomocnicze ----------
LANGS = %w[pl en]
def h(s)
  CGI.escapeHTML(s.to_s)
end
def L(o, l)
  o.is_a?(Hash) ? (o[l.to_sym] || o[:pl]).to_s : o.to_s
end
def t(k, l)
  I18N[l.to_sym][k.to_sym] || k
end
def abs(path)
  "#{SITE_URL}/#{path}"
end
def photo(a, n, s = 2048)
  "assets/photos/#{a}/#{n}-#{s}.webp"
end
PATHS = {
  home:    ->(l, _ = nil) { l == "en" ? "en/" : "" },
  album:   ->(l, s) { (l == "en" ? "en/albums/" : "albumy/") + "#{s}/" },
  trip:    ->(l, s) { (l == "en" ? "en/trips/" : "wyjazdy/") + "#{s}/" },
  post:    ->(l, s) { (l == "en" ? "en/blog/" : "blog/") + "#{s}/" },
}
MONTHS = { "pl" => %w[stycznia lutego marca kwietnia maja czerwca lipca sierpnia września października listopada grudnia],
           "en" => %w[January February March April May June July August September October November December] }
def fdate(d, l)
  y, m, dd = d.split("-").map(&:to_i)
  l == "pl" ? "#{dd} #{MONTHS["pl"][m - 1]} #{y}" : "#{dd} #{MONTHS["en"][m - 1]} #{y}"
end
def frange((a, b), l)
  ya, ma, da = a.split("-").map(&:to_i); yb, mb, db = b.split("-").map(&:to_i)
  ma == mb ? "#{da}–#{fdate(b, l)}" : (l == "pl" ? "#{da} #{MONTHS["pl"][ma - 1]} – #{fdate(b, l)}" : "#{da} #{MONTHS["en"][ma - 1]} – #{fdate(b, l)}")
end
def nphotos(n, l)
  return "#{n} photos" if l == "en"
  word = n == 1 ? "zdjęcie" : (n % 10).between?(2, 4) && !(n % 100).between?(12, 14) ? "zdjęcia" : "zdjęć"
  "#{n} #{word}"
end
def short(s, max = 158)
  s = s.gsub(/\s+/, " ").strip
  s.size <= max ? s : s[0, max].sub(/\s+\S*\z/, "") + "…"
end

# ---------- obrazki podglądu linków (1200×630 JPG) ----------
FileUtils.mkdir_p("assets/og")
def og_image(key, album, name)
  out = "assets/og/#{key}.jpg"
  return out if File.exist?(out)
  src = photo(album, name, 2048)
  return "assets/og/home.jpg" unless File.exist?(src)
  tmp = "assets/og/.tmp-#{key}.jpg"
  system("sips", "-s", "format", "jpeg", "-s", "formatOptions", "82", "--resampleWidth", "1200", src, "--out", tmp, out: File::NULL, err: File::NULL)
  system("sips", "-c", "630", "1200", tmp, "--out", out, out: File::NULL, err: File::NULL)
  File.delete(tmp) if File.exist?(tmp)
  File.exist?(out) ? out : "assets/og/home.jpg"
end
HOME_OG = og_image("home", HERO[0][:a], HERO[0][:n])

# ---------- <head> ----------
def seo_block(l, title:, desc:, path:, alt:, og:, type: "website", ld: [], page: {})
  pl, en = alt["pl"], alt["en"]
  ld_json = ld.map { |o| %Q|<script type="application/ld+json">#{JSON.generate(o).gsub("</", "<\\/")}</script>| }.join("\n")
  <<~HTML.chomp
    <!-- SEO:START (generowane przez tools/build_site.rb — nie edytuj ręcznie) -->
    <title>#{h title}</title>
    <meta name="description" content="#{h desc}">
    <link rel="canonical" href="#{abs path}">
    <link rel="alternate" hreflang="pl" href="#{abs pl}">
    <link rel="alternate" hreflang="en" href="#{abs en}">
    <link rel="alternate" hreflang="x-default" href="#{abs pl}">
    <meta property="og:type" content="#{type}">
    <meta property="og:site_name" content="Arek Carphotography">
    <meta property="og:locale" content="#{l == "pl" ? "pl_PL" : "en_GB"}">
    <meta property="og:locale:alternate" content="#{l == "pl" ? "en_GB" : "pl_PL"}">
    <meta property="og:title" content="#{h title}">
    <meta property="og:description" content="#{h desc}">
    <meta property="og:url" content="#{abs path}">
    <meta property="og:image" content="#{abs og}">
    <meta property="og:image:width" content="1200">
    <meta property="og:image:height" content="630">
    <meta name="twitter:card" content="summary_large_image">
    #{ld_json}
    <script>window.PAGE = #{JSON.generate(page.merge(lang: l, alt: alt))};</script>
    <!-- SEO:END -->
  HTML
end
LEGACY_SEO = <<~HTML.chomp
  <!-- SEO:START (generowane przez tools/build_site.rb — nie edytuj ręcznie) -->
  <title>Arek Carphotography</title>
  <meta name="description" content="">
  <meta name="robots" content="noindex,follow">
  <!-- SEO:END -->
HTML
def set_seo(html, block)
  html.sub(/<!-- SEO:START.*?<!-- SEO:END -->/m) { block } || abort("brak znaczników SEO")
end
def set_lang(html, l)
  html.sub(/<html lang="[a-z]+">/, %Q|<html lang="#{l}">|)
end
def set_main(html, inner)
  html.sub(%r{<main id="page">.*?</main>}m) { %Q|<main id="page">#{inner}</main>| }
end
WRITTEN = []
def write(path, html)
  file = path.empty? ? "index.html" : File.join(path, "index.html")
  FileUtils.mkdir_p(File.dirname(file)); File.write(file, html); WRITTEN << path
end
PERSON = ->(l) { { "@type" => "Person", "name" => "Arek", "url" => abs(PATHS[:home].(l)) } }
def crumbs(l, items) # [[nazwa, ścieżka], ...]
  { "@context" => "https://schema.org", "@type" => "BreadcrumbList",
    "itemListElement" => items.each_with_index.map { |(n, p), i| { "@type" => "ListItem", "position" => i + 1, "name" => n, "item" => abs(p) } } }
end

# ---------- wzorce ----------
TPL = %w[index album trip post].to_h { |n| [n, File.read("#{n}.html", encoding: "UTF-8")] }
TPL.each { |n, s| abort "#{n}.html: brak znaczników <!-- SEO:START --> / <!-- SEO:END -->" unless s.include?("<!-- SEO:START") && s.include?("<!-- SEO:END -->") }
# strona bez własnego skryptu (polityka, 404): wzorzec albumu bez skryptu renderującego
PLAIN = TPL["album"].sub(%r{<script>\s*const slug.*?</script>\n?}m, "")

# ---------- strona główna ----------
sitemap = [] # [ścieżka PL, ścieżka EN, [obrazki]]
LANGS.each do |l|
  alt = { "pl" => PATHS[:home].("pl"), "en" => PATHS[:home].("en") }
  ld = [{ "@context" => "https://schema.org", "@type" => "ProfessionalService", "name" => "Arek Carphotography",
          "description" => t("meta.desc", l), "url" => abs(alt[l]), "image" => abs(HOME_OG), "email" => EMAIL,
          "address" => { "@type" => "PostalAddress", "addressLocality" => "Rzeszów", "addressRegion" => "Podkarpackie", "addressCountry" => "PL" },
          "areaServed" => [{ "@type" => "AdministrativeArea", "name" => l == "pl" ? "Województwo podkarpackie" : "Podkarpackie Voivodeship" },
                           { "@type" => "Country", "name" => l == "pl" ? "Polska" : "Poland" }, { "@type" => "Place", "name" => "Europe" }],
          "knowsLanguage" => %w[pl en], "sameAs" => SOCIAL.map { |s| s[1] }.select { |u| u.start_with?("http") } },
        { "@context" => "https://schema.org", "@type" => "WebSite", "name" => "Arek Carphotography", "url" => abs(alt[l]), "inLanguage" => l }]
  block = seo_block(l, title: t("meta.title", l), desc: t("meta.desc", l), path: alt[l], alt: alt, og: HOME_OG, ld: ld, page: { type: "home" })
  html = set_lang(set_seo(TPL["index"], block), l)
  if l == "pl" then File.write("index.html", html); WRITTEN << "" else write(alt[l], html) end
end
sitemap << [PATHS[:home].("pl"), PATHS[:home].("en"), HERO.map { |x| [photo(x[:a], x[:n]), L(FIND[x[:a]]&.dig(:title) || "", "pl")] }]

# ---------- albumy ----------
ALBUMS.each do |a|
  tr = TRIPS.find { |x| x[:slug] == a[:trip] }
  og = og_image("album-#{a[:slug]}", a[:slug], a[:hero])
  LANGS.each do |l|
    alt = LANGS.to_h { |x| [x, PATHS[:album].(x, a[:slug])] }
    title, place = L(a[:title], l), L(a[:place], l)
    place_known = !a[:tbc]
    head_title = place_known ? "#{title} — #{place} | Arek Carphotography" : "#{title} | Arek Carphotography"
    desc = short(L(a[:desc], l))
    imgs = a[:photos].first(20).map { |n, w, hh| { "@type" => "ImageObject", "contentUrl" => abs(photo(a[:slug], n)), "width" => w, "height" => hh,
             "creator" => PERSON.(l), "creditText" => "Arek Carphotography", "copyrightNotice" => "© Arek Carphotography" } }
    gallery = { "@context" => "https://schema.org", "@type" => "ImageGallery", "name" => title, "description" => L(a[:desc], l),
                "url" => abs(alt[l]), "inLanguage" => l, "author" => PERSON.(l), "image" => imgs }
    gallery["contentLocation"] = { "@type" => "Place", "name" => place } if place_known
    gallery["dateCreated"] = a[:date] unless a[:tbc] || a[:noDate]
    bc = [[t("album.home", l), PATHS[:home].(l)]]
    bc << [L(tr[:title], l), PATHS[:trip].(l, tr[:slug])] if tr
    bc << [title, alt[l]]
    block = seo_block(l, title: head_title, desc: desc, path: alt[l], alt: alt, og: og, ld: [gallery, crumbs(l, bc)], page: { type: "album", slug: a[:slug] })
    sib = tr ? ALBUMS.select { |x| x[:trip] == tr[:slug] && x != a } : []
    meta = [place_known ? place : nil, a[:tbc] || a[:noDate] ? nil : fdate(a[:date], l), nphotos(a[:photos].size, l)].compact.join(" · ")
    pre = <<~HTML
      <section class="seo-pre"><div class="wrap">
      <nav class="crumbs" aria-label="breadcrumb">#{bc[0..-2].map { |n, p| %Q|<a href="#{p.empty? ? "./" : p}">#{h n}</a>| }.join(" / ")} / #{h title}</nav>
      <h1>#{h title}</h1><p>#{h meta}</p><p>#{h L(a[:desc], l)}</p>
      #{tr ? %Q|<p><a href="#{PATHS[:trip].(l, tr[:slug])}">#{h L(tr[:title], l)}</a></p>| : ""}
      #{sib.empty? ? "" : "<ul>" + sib.map { |x| %Q|<li><a href="#{PATHS[:album].(l, x[:slug])}">#{h L(x[:title], l)}</a></li>| }.join + "</ul>"}
      </div></section>
    HTML
    write(alt[l], set_main(set_lang(set_seo(TPL["album"], block), l), pre))
  end
  sitemap << [PATHS[:album].("pl", a[:slug]), PATHS[:album].("en", a[:slug]), a[:photos].map { |n, *| [photo(a[:slug], n), L(a[:title], "pl")] }]
end

# ---------- wyjazdy ----------
TRIPS.each do |tr|
  al = ALBUMS.select { |a| a[:trip] == tr[:slug] }
  next if al.empty?
  og = og_image("trip-#{tr[:slug]}", tr[:cover][0], tr[:cover][1])
  total = al.sum { |a| a[:photos].size }
  LANGS.each do |l|
    alt = LANGS.to_h { |x| [x, PATHS[:trip].(x, tr[:slug])] }
    title, place = L(tr[:title], l), L(tr[:place], l)
    ld = [{ "@context" => "https://schema.org", "@type" => "CollectionPage", "name" => title, "description" => L(tr[:desc], l), "url" => abs(alt[l]),
            "inLanguage" => l, "author" => PERSON.(l),
            "about" => { "@type" => "Event", "name" => title, "startDate" => tr[:dates][0], "endDate" => tr[:dates][1],
                         "location" => { "@type" => "Place", "name" => place } },
            "hasPart" => al.map { |a| { "@type" => "ImageGallery", "name" => L(a[:title], l), "url" => abs(PATHS[:album].(l, a[:slug])) } } },
          crumbs(l, [[t("album.home", l), PATHS[:home].(l)], [title, alt[l]]])]
    block = seo_block(l, title: "#{title} — #{place} | Arek Carphotography", desc: short(L(tr[:desc], l)), path: alt[l], alt: alt, og: og,
                      ld: ld, page: { type: "trip", slug: tr[:slug] })
    pre = <<~HTML
      <section class="seo-pre"><div class="wrap">
      <nav class="crumbs" aria-label="breadcrumb"><a href="#{PATHS[:home].(l).then { |p| p.empty? ? "./" : p }}">#{h t("album.home", l)}</a> / #{h title}</nav>
      <h1>#{h title}</h1><p>#{h [place, frange(tr[:dates], l), nphotos(total, l)].join(" · ")}</p><p>#{h L(tr[:desc], l)}</p>
      <ul>#{al.map { |a| %Q|<li><a href="#{PATHS[:album].(l, a[:slug])}">#{h L(a[:title], l)}</a></li>| }.join}</ul>
      </div></section>
    HTML
    write(alt[l], set_main(set_lang(set_seo(TPL["trip"], block), l), pre))
  end
  sitemap << [PATHS[:trip].("pl", tr[:slug]), PATHS[:trip].("en", tr[:slug]), []]
end

# ---------- wpisy na blogu ----------
POSTS.each do |p|
  og = og_image("post-#{p[:slug]}", p[:img][0], p[:img][1])
  LANGS.each do |l|
    alt = LANGS.to_h { |x| [x, PATHS[:post].(x, p[:slug])] }
    title = L(p[:t], l)
    ld = [{ "@context" => "https://schema.org", "@type" => "BlogPosting", "headline" => title, "description" => L(p[:d], l),
            "datePublished" => p[:date], "inLanguage" => l, "url" => abs(alt[l]), "image" => abs(photo(p[:img][0], p[:img][1])),
            "author" => PERSON.(l), "publisher" => { "@type" => "Organization", "name" => "Arek Carphotography" } },
          crumbs(l, [[t("album.home", l), PATHS[:home].(l)], ["Blog", PATHS[:home].(l) + "#blog"], [title, alt[l]]])]
    block = seo_block(l, title: "#{title} | Arek Carphotography", desc: short(L(p[:d], l)), path: alt[l], alt: alt, og: og,
                      type: "article", ld: ld, page: { type: "post", slug: p[:slug] })
    body = (p[:body] || []).map do |b|
      [b[:h] ? "<h2>#{h L(b[:h], l)}</h2>" : nil, b[:p] ? "<p>#{h L(b[:p], l)}</p>" : nil,
       b[:album] && FIND[b[:album]] ? %Q|<p><a href="#{PATHS[:album].(l, b[:album])}">#{h L(FIND[b[:album]][:title], l)}</a></p>| : nil].compact.join("\n")
    end.join("\n")
    pre = <<~HTML
      <section class="seo-pre"><div class="wrap"><article>
      <h1>#{h title}</h1><p><time datetime="#{p[:date]}">#{fdate(p[:date], l)}</time> · Arek Carphotography</p>
      #{body}
      </article></div></section>
    HTML
    write(alt[l], set_main(set_lang(set_seo(TPL["post"], block), l), pre))
  end
  sitemap << [PATHS[:post].("pl", p[:slug]), PATHS[:post].("en", p[:slug]), []]
end

# ---------- 404 ----------
nf = set_seo(PLAIN, <<~HTML.chomp)
  <!-- SEO:START (generowane przez tools/build_site.rb — nie edytuj ręcznie) -->
  <title>Nie ma takiej strony | Arek Carphotography</title>
  <meta name="description" content="">
  <meta name="robots" content="noindex">
  <!-- SEO:END -->
HTML
File.write("404.html", set_main(nf, <<~HTML))
  <section class="seo-pre"><div class="wrap"><h1>404</h1>
  <p>Nie ma takiej strony. <a href="./">Wróć na stronę główną</a>.</p>
  <p>Page not found. <a href="en/">Go to the home page</a>.</p></div></section>
HTML

# ---------- wzorce w katalogu głównym (stare adresy album.html?a=… przekierowują na nowe) ----------
%w[album trip post].each { |n| File.write("#{n}.html", set_lang(set_seo(TPL[n], LEGACY_SEO), "pl")) }

# ---------- sitemap.xml i robots.txt ----------
xml = +%Q|<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml" xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">\n|
sitemap.each do |pl, en, imgs|
  [pl, en].each_with_index do |path, i|
    xml << "  <url><loc>#{h abs(path)}</loc>\n"
    xml << %Q|    <xhtml:link rel="alternate" hreflang="pl" href="#{h abs(pl)}"/>\n    <xhtml:link rel="alternate" hreflang="en" href="#{h abs(en)}"/>\n|
    xml << %Q|    <xhtml:link rel="alternate" hreflang="x-default" href="#{h abs(pl)}"/>\n|
    imgs.first(1000).each { |u, cap| xml << "    <image:image><image:loc>#{h abs(u)}</image:loc></image:image>\n" } if i.zero?
    xml << "  </url>\n"
  end
end
xml << "</urlset>\n"
File.write("sitemap.xml", xml)
File.write("robots.txt", "User-agent: *\nAllow: /\nDisallow: /admin.html\n\nSitemap: #{SITE_URL}/sitemap.xml\n")

puts "Strony: #{WRITTEN.size} (+ 404), sitemap: #{sitemap.size * 2} adresów, zdjęć w sitemap: #{sitemap.sum { |_, _, i| i.size }}"
puts "Domena: #{SITE_URL}#{SITE_URL.include?("twojadomena") ? "  ← zmień SITE_URL w assets/data.js, gdy będziesz mieć domenę" : ""}"
