// Hero strony głównej „Ramka + taśma”: zdjęcie w ramce pod nagłówkiem rozszerza się przy przewijaniu na cały ekran,
// a dalsze przewijanie przesuwa kolejne zdjęcia w bok. Kadry i podpisy: HERO w assets/data.js.
// Zdjęcia nigdy nie są powiększane, rozmywane ani przyciemniane — zmienia się tylko maska (kadrowanie) i położenie.

const still = matchMedia("(prefers-reduced-motion: reduce)").matches;
const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
const ease = x => x < .5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2;
const pad = n => String(n).padStart(2, "0");

// ---- wspólne ----
// Pełnoekranowe zdjęcie: „m” = pionowe zdjęcie całego auta na telefony, „wide” = poziomy kadr na szerokie ekrany
const heroImg = (h, i, sizes = "100vw") => {
  const img = pic(h.a, h.n, `${L(findAlbum(h.a).title)} — Arek Carphotography`, sizes,
    `${i ? 'loading="lazy"' : 'fetchpriority="high"'} style="object-position:${h.pos || "50% 50%"}"`);
  const src = (media, name, [w, hh]) => `<source media="${media}" sizes="${sizes}" width="${w}" height="${hh}" srcset="${[640, 1280, 2048].map(s => `${photo(h.a, name, s)} ${s}w`).join(", ")}">`;
  if (!h.wide && !h.m) return img;
  return `<picture>${h.m ? src("(max-aspect-ratio: 4/5)", h.m, dims(h.a, h.m)) : ""}${h.wide ? src("(min-aspect-ratio: 1/1)", h.wide.n, [h.wide.w, h.wide.h]) : ""}${img}</picture>`;
};
// t = własny podpis kadru ({ pl, en }); domyślnie tytuł albumu
const heroName = h => (h.t ? L(h.t) : L(findAlbum(h.a).title)) + (h.detail ? ` · ${t("hero.detail")}` : "");
// Miejsce i miesiąc zdjęć (pomijamy, gdy album ma jeszcze dane do uzupełnienia)
const heroMeta = h => { const a = findAlbum(h.a); if (a.tbc) return ""; if (a.noDate) return L(a.place);
  return `${L(a.place)} · ${new Date(a.date).toLocaleDateString(LANG === "pl" ? "pl-PL" : "en-GB", { month: "long", year: "numeric" })}`; };
// Nagłówek: lewa część (nadtytuł + h1) i prawa (opis + przyciski)
const headHTML = () => `<div class="hh"><div class="hh-l"><div class="hero-eyebrow"><span data-i18n="hero.eyebrow"></span></div>
  <h1><span><i data-i18n="hero.l1"></i></span> <span><i data-i18n="hero.l2"></i></span></h1></div>
  <div class="hh-r"><p data-i18n="hero.p"></p>
  <div class="hero-cta"><a class="btn" href="#work" data-i18n="hero.cta1"></a><a class="lnk" href="#contact" data-i18n="hero.cta2"></a></div></div></div>`;

// Efekt dekodowania: litery najpierw losowe, potem od lewej układają się w nazwę
const GLYPHS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
function decode(el, text) {
  cancelAnimationFrame(el._raf);
  if (still) { el.textContent = text; return; }
  const D = 900, st = performance.now(), chars = [...text];
  const at = chars.map((_, i) => (i / chars.length) * D * .7 + Math.random() * D * .3);
  (function f(now) {
    const k = now - st; let out = "", done = true;
    chars.forEach((c, i) => {
      if (k >= at[i] || c === " ") out += c;
      else { done = false; out += `<i>${GLYPHS[Math.random() * GLYPHS.length | 0]}</i>`; }
    });
    el.innerHTML = out;
    if (!done) el._raf = requestAnimationFrame(f);
  })(st);
}

// Jedna pętla przewijania dla wszystkich efektów
const scrollFns = [];
let ticking = false;
const runScroll = () => { ticking = false; scrollFns.forEach(f => f()); };
addEventListener("scroll", () => { if (!ticking) { ticking = true; requestAnimationFrame(runScroll); } }, { passive: true });
addEventListener("resize", () => requestAnimationFrame(runScroll));

// =====================================================================
// „RAMKA + TAŚMA” — ramka rozszerza się na cały ekran, a dalsze przewijanie przesuwa zdjęcia w bok.
// Każde zdjęcie ma pełną wysokość ekranu i swoje proporcje — pionowe nie są przycinane, tylko stają obok siebie.
// =====================================================================
function heroFrameStrip(root) {
  root.className = "hero v2 v4";
  const item = (h, i) => {
    if (i === 0) return `<a class="v4-item first" href="${URLS.album(h.a)}">${heroImg(h, 0)}</a>`;
    const n = h.wide ? h.wide.n : h.n, [w, hh] = h.wide ? [h.wide.w, h.wide.h] : dims(h.a, h.n);
    return `<a class="v4-item" href="${URLS.album(h.a)}" style="--r:${(w / hh).toFixed(4)}">
      <img src="${photo(h.a, n, 1280)}" srcset="${[640, 1280, 2048].map(s => `${photo(h.a, n, s)} ${s}w`).join(", ")}"
        sizes="${w > hh ? "100vw" : "70vh"}" width="${w}" height="${hh}" alt="${L(findAlbum(h.a).title)} — Arek Carphotography"
        loading="lazy" decoding="async"></a>`;
  };
  root.innerHTML = `<div class="v2-stick">
    <div class="v2-frame v4-view"><div class="v4-track">${HERO.map(item).join("")}</div></div>
    <div class="wrap v2-head">${headHTML()}</div>
    <div class="wrap hero-ui v4-ui">
      <div class="hinfo">
        <div class="hcount"><span class="odo" aria-hidden="true"></span><span class="v4-tot">/ ${pad(HERO.length)}</span></div>
        <a class="hcap" href="#"><span class="hname"></span><span class="hmeta"></span></a>
        <span class="v4-bar"><i></i></span>
      </div>
    </div>
  </div>`;
  const head = root.querySelector(".v2-head"), stick = root.querySelector(".v2-stick"), track = root.querySelector(".v4-track");
  const items = [...root.querySelectorAll(".v4-item")], cap = root.querySelector(".hcap");
  const nameEl = root.querySelector(".hname"), metaEl = root.querySelector(".hmeta"), odoEl = root.querySelector(".odo");
  odoEl.innerHTML = `<span>${"0123456789".split("").map(d => `<i>${d}</i>`).join("")}</span>`.repeat(2);
  let E = 0, D = 0, lastW = 0, lastH = 0, act = -1;

  function measure() {
    root.style.setProperty("--e", 0);
    const hb = head.getBoundingClientRect(), cs = getComputedStyle(head);
    root.style.setProperty("--ft", `${Math.round(hb.bottom - stick.getBoundingClientRect().top + (innerWidth < 700 ? 22 : 34))}px`);
    root.style.setProperty("--fs", `${Math.round(hb.left + parseFloat(cs.paddingLeft))}px`);
    root.style.setProperty("--fb", innerWidth < 700 ? "16px" : "28px");
    E = innerHeight * .8;                                   // odcinek przewijania na rozszerzenie ramki
    D = Math.max(0, track.scrollWidth - innerWidth);         // odcinek na przesunięcie taśmy
    root.style.height = `${innerHeight + E + D + innerHeight * .15}px`;
  }
  function setCap(i, anim) {
    const h = HERO[i];
    cap.href = URLS.album(h.a); metaEl.textContent = heroMeta(h);
    if (anim) decode(nameEl, heroName(h)); else nameEl.textContent = heroName(h);
    odoEl.querySelectorAll(":scope > span").forEach((col, k) => col.style.transform = `translateY(-${+pad(i + 1)[k] * 1.2}em)`);
  }
  function update() {
    if (innerWidth !== lastW || innerHeight !== lastH) { lastW = innerWidth; lastH = innerHeight; measure(); }
    const y = Math.max(0, -root.getBoundingClientRect().top);
    const e = ease(clamp(y / E)), x = clamp(y - E, 0, D);
    root.style.setProperty("--e", e.toFixed(4));
    root.classList.toggle("full", e > .7);
    track.style.transform = `translate3d(${(-x).toFixed(1)}px,0,0)`;
    root.style.setProperty("--p", D ? (x / D).toFixed(4) : 0);
    // podpis: zdjęcie, które zajmuje środek ekranu
    let a = 0;
    items.forEach((it, i) => { if (it.getBoundingClientRect().left < innerWidth * .5) a = i; });
    if (a !== act) { const first = act < 0; act = a; setCap(a, !first); }
  }
  scrollFns.push(update);
  requestAnimationFrame(update);
  new ResizeObserver(() => { lastW = 0; update(); }).observe(head);
  // zdjęcia taśmy pobieramy stopniowo — te, które są najwyżej ~2 ekrany przed widokiem (oszczędność danych na telefonie)
  const ahead = () => items.forEach(it => { const im = it.querySelector("img"); if (im && im.loading === "lazy" && it.getBoundingClientRect().left < innerWidth * 3) im.loading = "eager"; });
  scrollFns.push(ahead);
  document.readyState === "complete" ? ahead() : addEventListener("load", ahead);
  return { lang: () => { lastW = 0; update(); if (act >= 0) setCap(act, false); } };
}

// ---- start ----
const heroRoot = $("#hero");
// Kadry z albumów, których nie ma w danych, pomijamy (literówka w HERO nie może zepsuć strony)
HERO.splice(0, HERO.length, ...HERO.filter(h => {
  const ok = findAlbum(h.a) && findAlbum(h.a).photos.some(p => p[0] === h.n);
  if (!ok) console.warn("Hero: pomijam kadr", h.a, h.n);
  return ok;
}));
// Błąd w hero nie może zablokować reszty strony (portfolio, albumy, blog)
let HERO_UI = { lang() {} };
try { HERO_UI = heroFrameStrip(heroRoot); }
catch (e) { console.error("Hero:", e); heroRoot.style.height = "auto"; }
window.heroLang = () => { try { HERO_UI.lang(); } catch (e) { console.error("Hero:", e); } };
// Pasek nagłówka strony robi się ciemny dopiero po wyjściu z hero
window.heroEnd = () => heroRoot.offsetTop + heroRoot.offsetHeight - 90;
