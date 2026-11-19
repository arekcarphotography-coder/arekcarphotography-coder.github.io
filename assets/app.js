// Wspólne skrypty: język PL/EN, nagłówek, stopka, lightbox, animacje.
// Każdy język ma osobne adresy (/… po polsku, /en/… po angielsku) — strony generuje tools/build_site.rb.
// PAGE (ustawiane w każdej wygenerowanej stronie) = { type, slug, lang, alt: { pl: adres, en: adres } }.
const $ = s => document.querySelector(s), $$ = s => [...document.querySelectorAll(s)];
const PAGE = window.PAGE || {};
let LANG = (navigator.language || "pl").slice(0, 2) === "pl" ? "pl" : "en";
try { const s = localStorage.getItem("lang"); if (s === "pl" || s === "en") LANG = s; } catch (e) {}
if (PAGE.lang) LANG = PAGE.lang;   // na wygenerowanych stronach język wynika z adresu
// Adresy stron (względem <base href="/">)
const URLS = {
  home: (l = LANG) => l === "en" ? "en/" : "./",
  album: (s, l = LANG) => (l === "en" ? "en/albums/" : "albumy/") + s + "/",
  trip: (s, l = LANG) => (l === "en" ? "en/trips/" : "wyjazdy/") + s + "/",
  post: (s, l = LANG) => (l === "en" ? "en/blog/" : "blog/") + s + "/",
  privacy: (l = LANG) => l === "en" ? "en/privacy-policy/" : "polityka-prywatnosci/",
};
const t = k => I18N[LANG][k] ?? k;
const L = o => o[LANG] || o.pl;
const fmtDate = d => new Date(d).toLocaleDateString(LANG === "pl" ? "pl-PL" : "en-GB", { day: "numeric", month: "long", year: "numeric" });
const photosLabel = n => LANG === "en" ? `${n} photos`
  : `${n} ${n === 1 ? "zdjęcie" : (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) ? "zdjęcia" : "zdjęć"}`;
const albumsLabel = n => LANG === "en" ? `${n} albums`
  : `${n} ${n === 1 ? "album" : (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) ? "albumy" : "albumów"}`;
const icons = SOCIAL.map(([n, u, p]) => `<a href="${u}" aria-label="${n}" ${u.startsWith("http") ? 'target="_blank" rel="noopener"' : ""}><svg viewBox="0 0 24 24"><path d="${p}"/></svg></a>`).join("");

let io = null;
function observe() {
  io = io || new IntersectionObserver(es => es.forEach(e => {
    if (!e.isIntersecting) return;
    const el = e.target; setTimeout(() => el.classList.add("in"), +el.dataset.d || 0); io.unobserve(el);
  }), { threshold: .1 });
  $$(".reveal:not(.in)").forEach((el, i) => { el.dataset.d = (i % 4) * 90; io.observe(el); });
}

// ---- Nagłówek, stopka, lightbox ----
document.body.insertAdjacentHTML("afterbegin", `
<header id="top"><div class="wrap nav">
  <a class="logo" href="${URLS.home()}">Arek Carphotography</a>
  <nav class="links" id="menu">
    <a href="${URLS.home()}#work" data-i18n="nav.work"></a><a href="${URLS.home()}#albums" data-i18n="nav.albums"></a>
    <a href="${URLS.home()}#about" data-i18n="nav.about"></a><a href="${URLS.home()}#blog" data-i18n="nav.blog"></a>
    <a href="#contact" data-i18n="nav.contact"></a>
  </nav>
  <div class="right">
    <div class="lang" role="group" aria-label="Język / Language"><button data-l="pl">PL</button>/<button data-l="en">EN</button></div>
    <div class="social">${icons}</div>
    <button class="burger" aria-label="Menu"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M3 7h18M3 12h18M3 17h18"/></svg></button>
  </div>
</div></header>`);
document.body.insertAdjacentHTML("beforeend", `
<section id="contact" class="contact"><div class="wrap contact-grid">
  <div class="contact-info reveal">
    <div class="eyebrow" data-i18n="contact.eyebrow"></div><h2 data-i18n="contact.h"></h2>
    <p class="contact-lead" data-i18n="contact.p"></p>
    <p class="contact-or" data-i18n="form.or"></p>
    <a class="mail" href="mailto:${EMAIL}">${EMAIL}</a>
    <div class="social">${icons}</div>
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
    <label><span data-i18n="form.msg"></span><textarea name="message" rows="5" required data-i18n-ph="form.msg.ph"></textarea></label>
    <input name="_gotcha" class="hp" tabindex="-1" autocomplete="off" aria-hidden="true">
    <label class="check"><input type="checkbox" name="consent" required><span><span data-i18n="form.consent"></span> <a href="${URLS.privacy()}" data-i18n="form.privacy"></a></span></label>
    <button class="btn" type="submit" data-i18n="form.send"></button>
    <p class="fmsg" id="fmsg" role="status" aria-live="polite"></p>
  </form>
</div></section>
<footer><div class="wrap"><span>© 2026 Arek Carphotography · Rzeszów, Podkarpacie</span><a href="${URLS.privacy()}" data-i18n="footer.privacy"></a></div></footer>
<div class="lb" id="lb" role="dialog" aria-modal="true">
  <button class="x" aria-label="Zamknij">×</button><button class="prev" aria-label="Poprzednie">‹</button><button class="next-b" aria-label="Następne">›</button>
  <img alt=""><div class="cap"></div>
</div>`);

const menu = $("#menu");
$(".burger").onclick = () => menu.classList.toggle("open");
$$("#menu a").forEach(a => a.addEventListener("click", () => menu.classList.remove("open")));
const hd = $("#top");
const onScroll = () => hd.classList.toggle("solid", scrollY > (window.heroEnd ? heroEnd() : 60));
addEventListener("scroll", onScroll, { passive: true }); onScroll();

// ---- Język ----
function applyLang() {
  document.documentElement.lang = LANG;
  $$(".lang button").forEach(b => b.classList.toggle("on", b.dataset.l === LANG));
  if (window.renderPage) renderPage();
  $$("[data-i18n]").forEach(el => el.textContent = t(el.dataset.i18n));
  $$("[data-i18n-ph]").forEach(el => el.placeholder = t(el.dataset.i18nPh));
  observe();
}

// ---- Formularz kontaktowy ----
// FORM_ENDPOINT = "kontakt.php" → skrypt PHP na Hostido wysyła e-mail, "netlify" → Netlify Forms (wiadomości w panelu Netlify + powiadomienie e-mail),
// adres URL (np. Formspree) → wysyłka w tle, puste → program pocztowy z gotową treścią.
const cform = $("#cform"), fmsg = $("#fmsg");
// Strona otwarta lokalnie (ten Mac, sieć domowa, tunel) albo na GitHub Pages (tam nie ma PHP ani Netlify Forms) — formularz otwiera wtedy program pocztowy
const isLocal = /^(localhost|127\.0\.0\.1|\[::1\]|192\.168\.\d+\.\d+|10\.\d+\.\d+\.\d+|172\.(1[6-9]|2\d|3[01])\.\d+\.\d+)$/.test(location.hostname) || /\.(lhr\.life|localhost\.run|github\.io)$/.test(location.hostname) || location.protocol === "file:";
const FORM_MODE = isLocal ? "" : FORM_ENDPOINT;
cform.addEventListener("submit", async e => {
  e.preventDefault();
  fmsg.className = "fmsg";
  const bad = [...cform.querySelectorAll("[required]")].filter(el => el.type === "checkbox" ? !el.checked : !el.value.trim() || !el.checkValidity());
  cform.querySelectorAll(".invalid").forEach(el => el.classList.remove("invalid"));
  if (bad.length) { bad.forEach(el => (el.type === "checkbox" ? el.parentElement : el).classList.add("invalid")); bad[0].focus(); return; }
  const data = Object.fromEntries(new FormData(cform));
  if (data._gotcha) return; // pułapka na boty
  const typeLabel = cform.querySelector("[name=type]").selectedOptions[0].textContent;
  const btn = cform.querySelector("button"); btn.disabled = true; btn.textContent = t("form.sending");
  try {
    if (FORM_MODE === "netlify") {
      const r = await fetch("/", { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ "form-name": "kontakt", ...data, type: typeLabel, lang: LANG }).toString() });
      if (!r.ok) throw new Error(r.status);
      fmsg.textContent = t("form.ok"); fmsg.classList.add("ok"); cform.reset();
    } else if (FORM_MODE) {
      const r = await fetch(FORM_MODE, { method: "POST", headers: { Accept: "application/json", "Content-Type": "application/json" },
        body: JSON.stringify({ ...data, type: typeLabel, _subject: `Strona: ${typeLabel} — ${data.name}`, lang: LANG }) });
      if (!r.ok) throw new Error(r.status);
      fmsg.textContent = t("form.ok"); fmsg.classList.add("ok"); cform.reset();
    } else {
      const body = [`${t("form.name")}: ${data.name}`, `${t("form.email")}: ${data.email}`, data.phone && `${t("form.phone")}: ${data.phone}`,
        `${t("form.type")}: ${typeLabel}`, data.date && `${t("form.date")}: ${data.date}`, data.place && `${t("form.place")}: ${data.place}`, "", data.message]
        .filter(x => x !== undefined && x !== "").join("\n");
      location.href = `mailto:${EMAIL}?subject=${encodeURIComponent(`Strona: ${typeLabel} — ${data.name}`)}&body=${encodeURIComponent(body)}`;
      fmsg.textContent = t("form.mail"); fmsg.classList.add("ok");
    }
  } catch (err) {
    fmsg.innerHTML = `${t("form.err")} <a href="mailto:${EMAIL}">${EMAIL}</a>`; fmsg.classList.add("err");
  } finally { btn.disabled = false; btn.textContent = t("form.send"); }
});
$$(".lang button").forEach(b => b.onclick = () => {
  const l = b.dataset.l; try { localStorage.setItem("lang", l); } catch (e) {}
  // strona ma wersję w drugim języku pod innym adresem → przechodzimy tam (zachowując kotwicę #…)
  if (PAGE.alt && PAGE.alt[l]) { if (l !== LANG) location.href = PAGE.alt[l] + location.hash; return; }
  LANG = l; applyLang();
});
// Kotwice #kontakt itp. przewijają w obrębie strony (z <base href="/"> zwykły link #… prowadziłby na stronę główną)
document.addEventListener("click", e => {
  const a = e.target.closest('a[href^="#"]'); if (!a) return;
  const id = a.getAttribute("href").slice(1), el = id && document.getElementById(id);
  if (!el) return;
  e.preventDefault(); el.scrollIntoView({ behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth" });
  history.replaceState(null, "", location.pathname + location.search + "#" + id);  // pełna ścieżka — z <base href="/"> samo „#id” wskazywałoby stronę główną
});

// ---- Lightbox: items = [{src, alt, cap, href}] ----
const lb = $("#lb"), lbImg = lb.querySelector("img"), cap = lb.querySelector(".cap");
let LB = [], cur = 0;
function openLB(items, i) {
  LB = items; cur = (i + LB.length) % LB.length; const p = LB[cur];
  lbImg.src = p.src; lbImg.alt = p.alt;
  cap.innerHTML = `${p.cap} · ${cur + 1}/${LB.length}` + (p.href ? `<a href="${p.href}">${t("lb.album")}</a>` : "");
  lb.classList.add("open"); document.body.style.overflow = "hidden";
}
const closeLB = () => { lb.classList.remove("open"); document.body.style.overflow = ""; };
lb.querySelector(".x").onclick = closeLB;
lb.querySelector(".prev").onclick = () => openLB(LB, cur - 1);
lb.querySelector(".next-b").onclick = () => openLB(LB, cur + 1);
lb.onclick = e => { if (e.target === lb) closeLB(); };
addEventListener("keydown", e => {
  if (!lb.classList.contains("open")) return;
  if (e.key === "Escape") closeLB();
  if (e.key === "ArrowLeft") openLB(LB, cur - 1);
  if (e.key === "ArrowRight") openLB(LB, cur + 1);
});
let tx = 0;
lb.addEventListener("touchstart", e => tx = e.touches[0].clientX, { passive: true });
lb.addEventListener("touchend", e => { const d = e.changedTouches[0].clientX - tx; if (Math.abs(d) > 50) openLB(LB, cur + (d < 0 ? 1 : -1)); });

// ---- Zdjęcia: WebP w 3 rozmiarach, przeglądarka sama wybiera właściwy (srcset) ----
const photo = (album, name, s = 1280) => `assets/photos/${album}/${name}-${s}.webp`;
const srcset = (album, name) => [640, 1280, 2048].map(s => `${photo(album, name, s)} ${s}w`).join(", ");
const findAlbum = slug => ALBUMS.find(a => a.slug === slug);
const dims = (album, name) => { const p = findAlbum(album).photos.find(x => x[0] === name); return p ? [p[1], p[2]] : [3, 2]; };
// <img> z srcset; sizes = jaka część ekranu zajmuje zdjęcie
function pic(album, name, alt, sizes, extra = 'loading="lazy"') {
  const [w, h] = dims(album, name);
  return `<img src="${photo(album, name, 1280)}" srcset="${srcset(album, name)}" sizes="${sizes}" width="${w}" height="${h}" alt="${alt}" ${extra} decoding="async">`;
}
// Elementy galerii/lightboxa z albumu
function photoItems(a, list = a.photos, link = false) {
  const title = L(a.title);
  return list.map(([name, w, h]) => ({ album: a.slug, name, w, h, title, sub: L(a.place),
    alt: `${title} — ${L(a.place)} | fot. Arek Carphotography`, src: photo(a.slug, name, 2048), cap: title,
    href: link ? URLS.album(a.slug) : "" }));
}
const GRID_SIZES = "(max-width: 600px) 100vw, (max-width: 1000px) 50vw, (max-width: 1400px) 33vw, 25vw";
function gridHTML(items) {
  return items.map((p, i) => `<figure class="card reveal" data-i="${i}">
    ${pic(p.album, p.name, p.alt, GRID_SIZES)}
    <figcaption class="meta"><b>${p.title}</b><small>${p.sub}</small></figcaption></figure>`).join("");
}
// Kafle albumów i wyjazdów
const fmtRange = ([a, b]) => {
  const loc = LANG === "pl" ? "pl-PL" : "en-GB", A = new Date(a), B = new Date(b);
  const end = B.toLocaleDateString(loc, { day: "numeric", month: "long", year: "numeric" });
  // ten sam miesiąc: „15–17 maja 2026”, różne miesiące: „29 stycznia – 1 lutego 2026”
  if (A.getMonth() === B.getMonth()) return `${A.getDate()}–${end}`;
  return `${A.toLocaleDateString(loc, { day: "numeric", month: "long" })} – ${end}`;
};
const tripAlbums = tr => ALBUMS.filter(a => a.trip === tr.slug);
const tripPhotos = tr => tripAlbums(tr).reduce((n, a) => n + a.photos.length, 0);
function albumCard(a) {
  return `<a class="album reveal" href="${URLS.album(a.slug)}">
    ${pic(a.slug, a.cover, L(a.title), "(max-width: 700px) 100vw, 33vw")}
    <div><span class="badge">${L(KIND[a.kind])}</span><h3>${L(a.title)}</h3><p>${L(a.place)} · ${photosLabel(a.photos.length)}</p><span class="go">${LANG === "pl" ? "Otwórz album" : "Open album"} →</span></div></a>`;
}
function tripCard(tr) {
  const al = tripAlbums(tr);
  return `<a class="album trip reveal" href="${URLS.trip(tr.slug)}">
    ${pic(tr.cover[0], tr.cover[1], L(tr.title), "(max-width: 700px) 100vw, 66vw")}
    <div><span class="badge">${t("trip.label")} · ${albumsLabel(al.length)} · ${photosLabel(tripPhotos(tr))}</span><h3>${L(tr.title)}</h3>
    <p>${L(tr.place)} · ${fmtRange(tr.dates)}</p><p class="sub">${al.map(a => L(a.title)).join(" · ")}</p>
    <span class="go">${t("trip.open")} →</span></div></a>`;
}
function bindGrid(el, items) { el.onclick = e => { const c = e.target.closest(".card"); if (c) openLB(items, +c.dataset.i); }; }
