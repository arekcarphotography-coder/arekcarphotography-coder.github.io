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
KIND     = js_literal("KIND")
OFFER    = js_literal("OFFER")
OFFER_PAGE = js_literal("OFFER_PAGE")
FAQ      = js_literal("FAQ")
ALTS     = js_literal("ALTS")   # klucze „album/zdjęcie” (w Ruby jako symbole)
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
  offer:   ->(l, _ = nil) { l == "en" ? "en/car-photoshoot/" : "sesja-samochodowa/" },
}
def srcset(a, n)
  [640, 1280, 2048].map { |s| "#{photo(a, n, s)} #{s}w" }.join(", ")
end
def dims(a, n)
  p = FIND[a] && FIND[a][:photos].find { |x| x[0] == n }
  p ? [p[1], p[2]] : [3, 2]
end
# <img> jak pic() w assets/app.js
def pic_html(a, n, alt, sizes, extra = 'loading="lazy"')
  w, hh = dims(a, n)
  %Q|<img src="#{photo(a, n, 1280)}" srcset="#{srcset(a, n)}" sizes="#{sizes}" width="#{w}" height="#{hh}" alt="#{h alt}" #{extra} decoding="async">|
end
# ALT jak altFor() w assets/app.js: opis z ALTS, a bez niego „Album — miejsce, zdjęcie X z N”
def alt_for(slug, name, l)
  x = ALTS[:"#{slug}/#{name}"]
  return L(x, l) if x
  a = FIND[slug] or return "Arek Carphotography"
  i = a[:photos].index { |p| p[0] == name }
  place = a[:tbc] ? "" : " — #{L(a[:place], l)}"
  return "#{L(a[:title], l)}#{place}" unless i
  "#{L(a[:title], l)}#{place}, #{l == "pl" ? "zdjęcie #{i + 1} z #{a[:photos].size}" : "photo #{i + 1} of #{a[:photos].size}"}"
end
def fill_i18n(html, l)
  html.gsub(/(<(\w+)\b[^>]*\sdata-i18n="([^"]+)"[^>]*>)(.*?)(<\/\2>)/m) do
    m = Regexp.last_match
    m[1] + h(t(m[3], l)) + m[5]
  end
end
def nalbums(n, l)
  return "#{n} albums" if l == "en"
  "#{n} #{n == 1 ? "album" : (n % 10).between?(2, 4) && !(n % 100).between?(12, 14) ? "albumy" : "albumów"}"
end
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
def seo_block(l, title:, desc:, path:, alt:, og:, type: "website", ld: [], page: {}, extra: "")
  pl, en = alt["pl"], alt["en"]
  ld_json = ld.map { |o| %Q|<script type="application/ld+json">#{JSON.generate(o).gsub("</", "<\\/")}</script>| }.join("\n")
  <<~HTML.chomp
    <!-- SEO:START (generowane przez tools/build_site.rb — nie edytuj ręcznie) -->
    <title>#{h title}</title>#{extra.empty? ? "" : "\n" + extra}
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
# Strona główna ma wzorzec w tools/templates/index.html (index.html w katalogu głównym jest gotową, wypełnioną stroną —
# zmiany układu strony głównej rób we wzorcu). Pozostałe wzorce: album.html, trip.html, post.html.
TPL = %w[index album trip post].to_h { |n| [n, File.read(n == "index" ? "tools/templates/index.html" : "#{n}.html", encoding: "UTF-8")] }
TPL.each { |n, s| abort "#{n}.html: brak znaczników <!-- SEO:START --> / <!-- SEO:END -->" unless s.include?("<!-- SEO:START") && s.include?("<!-- SEO:END -->") }
# strona bez własnego skryptu (polityka, 404): wzorzec albumu bez skryptu renderującego
PLAIN = TPL["album"].sub(%r{<script>\s*const slug.*?</script>\n?}m, "<script>applyLang();</script>\n")
# sekcja kontaktu i stopka jak w assets/app.js — w HTML, żeby e-mail i obszar działania były widoczne bez JavaScriptu
def contact_html(l)
  icons = SOCIAL.map do |n, u, p|
    blank = u.start_with?("http") ? ' target="_blank" rel="noopener"' : ""
    %Q(<a href="#{h u}" aria-label="#{h n}"#{blank}><svg viewBox="0 0 24 24"><path d="#{p}"/></svg></a>)
  end.join
  fill_i18n(<<~HTML, l)
    <section id="contact" class="contact"><div class="wrap contact-grid">
      <div class="contact-info reveal">
        <div class="eyebrow" data-i18n="contact.eyebrow"></div><h2 data-i18n="contact.h"></h2>
        <p class="contact-lead" data-i18n="contact.p"></p>
        <p class="contact-or" data-i18n="form.or"></p>
        <a class="mail" href="mailto:#{EMAIL}">#{EMAIL}</a>
        <div class="social">#{icons}</div>
      </div>
      <form class="cform reveal" id="cform" novalidate>
        <div class="row2">
          <label><span data-i18n="form.name"></span><input name="name" autocomplete="name" required></label>
          <label><span data-i18n="form.email"></span><input name="email" type="email" autocomplete="email" required></label>
        </div>
        <div class="row2">
          <label><span data-i18n="form.phone"></span><input name="phone" type="tel" autocomplete="tel"></label>
          <label><span data-i18n="form.type"></span><select name="type">
            <option value="session" data-i18n="form.type.session"></option><option value="event" data-i18n="form.type.event"></option>
            <option value="collab" data-i18n="form.type.collab"></option><option value="other" data-i18n="form.type.other"></option></select></label>
        </div>
        <div class="row2">
          <label><span data-i18n="form.date"></span><input name="date" type="date"></label>
          <label><span data-i18n="form.place"></span><input name="place"></label>
        </div>
        <label><span data-i18n="form.msg"></span><textarea name="message" rows="5" required data-i18n-ph="form.msg.ph" placeholder="#{h t("form.msg.ph", l)}"></textarea></label>
        <input name="_gotcha" class="hp" tabindex="-1" autocomplete="off" aria-hidden="true">
        <button class="btn" type="submit" data-i18n="form.send"></button>
        <p class="fmsg" id="fmsg" role="status" aria-live="polite"></p>
      </form>
    </div></section>
    <footer><div class="wrap"><span>© 2026 Arek Carphotography · Rzeszów, Podkarpacie</span></div></footer>
  HTML
end
def with_contact(html, l)
  html.sub("</main>") { "</main>\n" + contact_html(l) }
end


# ---------- wspólne: firma (JSON-LD), FAQ ----------
BIZ_ID = abs("") + "#firma"
def business_ld(l)
  { "@context" => "https://schema.org", "@type" => "ProfessionalService", "@id" => BIZ_ID, "name" => "Arek Carphotography",
    "description" => t("meta.desc", l), "url" => abs(PATHS[:home].(l)), "image" => abs(HOME_OG),
    "logo" => abs("assets/apple-touch-icon.png"), "email" => EMAIL,
    "address" => { "@type" => "PostalAddress", "addressLocality" => "Rzeszów", "addressRegion" => "podkarpackie", "addressCountry" => "PL" },
    "areaServed" => [{ "@type" => "City", "name" => "Rzeszów" },
                     { "@type" => "AdministrativeArea", "name" => l == "pl" ? "województwo podkarpackie" : "Podkarpackie Voivodeship" },
                     { "@type" => "Country", "name" => l == "pl" ? "Polska" : "Poland" }],
    "founder" => { "@type" => "Person", "name" => "Arek", "jobTitle" => l == "pl" ? "Fotograf motoryzacyjny" : "Automotive photographer" },
    "knowsLanguage" => %w[pl en], "sameAs" => SOCIAL.map { |s| s[1] }.select { |u| u.start_with?("http") } }
end
def faq_ld(l)
  { "@context" => "https://schema.org", "@type" => "FAQPage",
    "mainEntity" => FAQ.map { |f| { "@type" => "Question", "name" => L(f[:q], l), "acceptedAnswer" => { "@type" => "Answer", "text" => L(f[:a], l) } } } }
end
def faq_html(l)
  FAQ.map do |f|
    link = f[:post] ? %Q| <a href="#{PATHS[:post].(l, f[:post])}">#{l == "pl" ? "Przeczytaj poradnik →" : "Read the guide →"}</a>| : ""
    %Q|<details class="faq-item"><summary><h3>#{h L(f[:q], l)}</h3></summary><p>#{h L(f[:a], l)}#{link}</p></details>|
  end.join("\n")
end

# ---------- strona główna: treść w HTML (bez czekania na JavaScript) ----------
def fill_id(html, id, inner)
  html.sub(%r{(<div[^>]*\sid="#{id}"[^>]*>)(</div>)}) { m = Regexp.last_match; m[1] + inner + m[2] } or abort("brak ##{id}")
end
def album_card(a, l)
  %Q|<a class="album reveal" href="#{PATHS[:album].(l, a[:slug])}">
    #{pic_html(a[:slug], a[:cover], alt_for(a[:slug], a[:cover], l), "(max-width: 700px) 100vw, 33vw")}
    <div><span class="badge">#{h L(KIND[a[:kind].to_sym], l)}</span><h3>#{h L(a[:title], l)}</h3><p>#{h L(a[:place], l)} · #{nphotos(a[:photos].size, l)}</p><span class="go">#{l == "pl" ? "Otwórz album" : "Open album"} →</span></div></a>|
end
def trip_card(tr, l)
  al = ALBUMS.select { |a| a[:trip] == tr[:slug] }
  %Q|<a class="album trip reveal" href="#{PATHS[:trip].(l, tr[:slug])}">
    #{pic_html(tr[:cover][0], tr[:cover][1], alt_for(tr[:cover][0], tr[:cover][1], l), "(max-width: 700px) 100vw, 66vw")}
    <div><span class="badge">#{h t("trip.label", l)} · #{nalbums(al.size, l)} · #{nphotos(al.sum { |a| a[:photos].size }, l)}</span><h3>#{h L(tr[:title], l)}</h3>
    <p>#{h L(tr[:place], l)} · #{frange(tr[:dates], l)}</p><p class="sub">#{h al.map { |a| L(a[:title], l) }.join(" · ")}</p>
    <span class="go">#{h t("trip.open", l)} →</span></div></a>|
end
def hero_static(l)
  x = HERO[0]; a, n = x[:a], x[:n]
  src = x[:m] ? %Q|<source media="(max-aspect-ratio: 4/5)" sizes="100vw" width="#{dims(a, x[:m])[0]}" height="#{dims(a, x[:m])[1]}" srcset="#{srcset(a, x[:m])}">| : ""
  img = pic_html(a, n, alt_for(a, n, l), "100vw", %Q|fetchpriority="high" style="object-position:#{x[:pos] || "50% 50%"}"|)
  head = %Q|<div class="hh"><div class="hh-l"><div class="hero-eyebrow"><span data-i18n="hero.eyebrow"></span></div>
  <h1><span><i data-i18n="hero.l1"></i></span> <span><i data-i18n="hero.l2"></i></span></h1></div>
  <div class="hh-r"><p data-i18n="hero.p"></p>
  <div class="hero-cta"><a class="btn" href="#work" data-i18n="hero.cta1"></a><a class="lnk" href="#contact" data-i18n="hero.cta2"></a></div></div></div>|
  %Q|<div class="v2-stick"><div class="v2-frame"><div class="hero-static"><picture>#{src}#{img}</picture></div></div><div class="wrap v2-head">#{head}</div></div>|
end
def hero_preload
  x = HERO[0]; a = x[:a]
  out = []
  out << %Q|<link rel="preload" as="image" imagesrcset="#{srcset(a, x[:m])}" imagesizes="100vw" media="(max-aspect-ratio: 4/5)" fetchpriority="high">| if x[:m]
  out << %Q|<link rel="preload" as="image" imagesrcset="#{srcset(a, x[:n])}" imagesizes="100vw"#{x[:m] ? ' media="(min-aspect-ratio: 801/1000)"' : ""} fetchpriority="high">|
  out.join("\n")
end

sitemap = [] # [ścieżka PL, ścieżka EN, [obrazki]]
LANGS.each do |l|
  alt = { "pl" => PATHS[:home].("pl"), "en" => PATHS[:home].("en") }
  ld = [business_ld(l),
        { "@context" => "https://schema.org", "@type" => "WebSite", "name" => "Arek Carphotography", "url" => abs(alt[l]), "inLanguage" => l },
        faq_ld(l)]
  block = seo_block(l, title: t("meta.title", l), desc: t("meta.desc", l), path: alt[l], alt: alt, og: HOME_OG, ld: ld,
                    page: { type: "home" }, extra: hero_preload)
  html = set_lang(set_seo(TPL["index"], block), l)
  html = html.sub(%r{(<section class="hero v2" id="hero"[^>]*>).*?(</section>)}m) { m = Regexp.last_match; m[1] + hero_static(l) + m[2] }
  html = html.sub(%Q|id="offerMore" href="sesja-samochodowa/"|, %Q|id="offerMore" href="#{PATHS[:offer].(l)}"|)
  html = fill_id(html, "albumList", TRIPS.map { |tr| trip_card(tr, l) }.join + ALBUMS.reject { |a| a[:trip] }.map { |a| album_card(a, l) }.join)
  html = fill_id(html, "offerList", OFFER.map { |o| %Q|<div class="offer-item reveal"><h3>#{h L(o[:h], l)}</h3><p>#{h L(o[:p], l)}</p></div>| }.join)
  html = fill_id(html, "faqList", faq_html(l))
  html = fill_id(html, "posts", POSTS.sort_by { |p| p[:date] }.reverse.map { |p|
    %Q|<article class="post reveal"><a href="#{PATHS[:post].(l, p[:slug])}">
    #{pic_html(p[:img][0], p[:img][1], L(p[:t], l), "(max-width: 700px) 100vw, 33vw")}<time datetime="#{p[:date]}">#{fdate(p[:date], l)}</time>
    <h3><span>#{h L(p[:t], l)}</span></h3><p>#{h L(p[:d], l)}</p><span class="more">#{h t("blog.more", l)}</span></a></article>| }.join)
  html = fill_id(html, "aboutImg", pic_html("koenigsegg-cc850", "dsc07731", "Arek Carphotography — fotograf samochodowy", "(max-width: 860px) 100vw, 50vw"))
  html = fill_i18n(html, l)
  html = with_contact(html, l)
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
      <div class="seo-pics">#{a[:photos].first(12).map { |n, w, hh| %Q|<img src="#{photo(a[:slug], n, 640)}" width="#{w}" height="#{hh}" alt="#{h alt_for(a[:slug], n, l)}" loading="lazy" decoding="async">| }.join}</div>
      </div></section>
    HTML
    write(alt[l], with_contact(set_main(set_lang(set_seo(TPL["album"], block), l), pre), l))
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
    write(alt[l], with_contact(set_main(set_lang(set_seo(TPL["trip"], block), l), pre), l))
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
    write(alt[l], with_contact(set_main(set_lang(set_seo(TPL["post"], block), l), pre), l))
  end
  sitemap << [PATHS[:post].("pl", p[:slug]), PATHS[:post].("en", p[:slug]), []]
end

# ---------- oferta: /sesja-samochodowa/ i /en/car-photoshoot/ (strona statyczna, bez skryptu renderującego) ----------
OP = OFFER_PAGE
LANGS.each do |l|
  alt = LANGS.to_h { |x| [x, PATHS[:offer].(x)] }
  types = OFFER.map do |o|
    ex = (o[:albums] || []).map { |s| FIND[s] }.compact.map { |a| %Q|<a href="#{PATHS[:album].(l, a[:slug])}">#{h L(a[:title], l)}</a>| } +
         (o[:trips] || []).map { |s| TRIPS.find { |x| x[:slug] == s } }.compact.map { |tr| %Q|<a href="#{PATHS[:trip].(l, tr[:slug])}">#{h L(tr[:title], l)}</a>| }
    %Q|<div class="offer-item"><h3>#{h L(o[:h], l)}</h3><p>#{h L(o[:p], l)}</p>#{ex.empty? ? "" : %Q|<p class="ex">#{h L(OP[:examples], l)}: #{ex.join(" · ")}</p>|}</div>|
  end.join("\n")
  steps = OP[:steps].map { |s| %Q|<li><b>#{h L(s[:h], l)}</b> #{h L(s[:p], l)}</li>| }.join
  service = { "@context" => "https://schema.org", "@type" => "Service", "name" => L(OP[:h1], l), "description" => L(OP[:desc], l),
              "serviceType" => l == "pl" ? "Fotografia motoryzacyjna" : "Automotive photography", "url" => abs(alt[l]),
              "provider" => { "@id" => BIZ_ID, "@type" => "ProfessionalService", "name" => "Arek Carphotography" },
              "areaServed" => business_ld(l)["areaServed"] }
  block = seo_block(l, title: L(OP[:title], l), desc: L(OP[:desc], l), path: alt[l], alt: alt, og: HOME_OG,
                    ld: [service, faq_ld(l), crumbs(l, [[t("album.home", l), PATHS[:home].(l)], [L(OP[:h1], l), alt[l]]])], page: { type: "offer" })
  pre = <<~HTML
    <section class="seo-pre offer-page"><div class="wrap">
    <nav class="crumbs" aria-label="breadcrumb"><a href="#{PATHS[:home].(l).then { |p| p.empty? ? "./" : p }}">#{h t("album.home", l)}</a> / #{h L(OP[:h1], l)}</nav>
    <h1>#{h L(OP[:h1], l)}</h1>
    <p class="lead">#{h L(OP[:lead], l)}</p>
    <h2>#{h L(OP[:types], l)}</h2>
    <div class="offer-grid">#{types}</div>
    <h2>#{h L(OP[:steps_h], l)}</h2>
    <ol class="steps">#{steps}</ol>
    <h2>#{h L(OP[:where_h], l)}</h2>
    <p>#{h L(OP[:where], l)}</p>
    <h2>#{h L(OP[:price_h], l)}</h2>
    <p>#{h L(OP[:price], l)}</p>
    <p><a class="btn" href="#contact">#{h L(OP[:cta], l)}</a></p>
    <h2>#{h t("faq.h", l)}</h2>
    <div class="faq">#{faq_html(l)}</div>
    </div></section>
  HTML
  write(alt[l], with_contact(set_main(set_lang(set_seo(PLAIN, block), l), pre), l))
end
sitemap << [PATHS[:offer].("pl"), PATHS[:offer].("en"), []]

# ---------- 404 ----------
nf = set_seo(PLAIN, <<~HTML.chomp)
  <!-- SEO:START (generowane przez tools/build_site.rb — nie edytuj ręcznie) -->
  <title>Nie ma takiej strony | Arek Carphotography</title>
  <meta name="description" content="">
  <meta name="robots" content="noindex">
  <!-- SEO:END -->
HTML
File.write("404.html", with_contact(set_main(nf, <<~HTML), "pl"))
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
File.write("robots.txt", "User-agent: *\nAllow: /\n\nSitemap: #{SITE_URL}/sitemap.xml\n")

puts "Strony: #{WRITTEN.size} (+ 404), sitemap: #{sitemap.size * 2} adresów, zdjęć w sitemap: #{sitemap.sum { |_, _, i| i.size }}"
puts "Domena: #{SITE_URL}#{SITE_URL.include?("twojadomena") ? "  ← zmień SITE_URL w assets/data.js, gdy będziesz mieć domenę" : ""}"
