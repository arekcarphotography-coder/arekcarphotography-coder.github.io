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
  const img = pic(h.a, h.n, altFor(h.a, h.n), sizes,
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

// Jedna pętla przewijania dla wszystkich efektów (heroFns czyścimy przy przebudowie hero, np. po obróceniu telefonu)
const scrollFns = [], heroFns = [];
let ticking = false;
const runScroll = () => { ticking = false; scrollFns.forEach(f => f()); heroFns.forEach(f => f()); };
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
        sizes="${w > hh ? "100vw" : "70vh"}" width="${w}" height="${hh}" alt="${altFor(h.a, n)}"
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
  heroFns.push(update);
  requestAnimationFrame(update);
  const ro = new ResizeObserver(() => { lastW = 0; update(); }); ro.observe(head);
  // zdjęcia taśmy pobieramy stopniowo — te, które są najwyżej ~2 ekrany przed widokiem
  const ahead = () => items.forEach(it => { const im = it.querySelector("img"); if (im && im.loading === "lazy" && it.getBoundingClientRect().left < innerWidth * 3) im.loading = "eager"; });
  heroFns.push(ahead);
  document.readyState === "complete" ? ahead() : addEventListener("load", ahead, { once: true });
  return { lang: () => { lastW = 0; update(); if (act >= 0) setCap(act, false); }, destroy: () => ro.disconnect() };
}

// =====================================================================
// TELEFON / TABLET (ekran dotykowy): ramka rozszerza się tak samo jak na komputerze, ale dalsze zdjęcia
// to zwykła karuzela — przesuwa się sama albo palcem w bok. Przewijanie w dół prowadzi od razu do #work.
// stacks = ekran pionowy: każdy kadr w wersji pionowej (pole mob w HERO); poziome bez wersji pionowej
// stają po 3 (lub 2) jedno pod drugim — slajd ma kształt ekranu.
// Karuzela działa dopiero po rozszerzeniu zdjęcia; wcześniej przesuwanie w bok jest zablokowane.
// =====================================================================
const CAROUSEL_MS = 3000;   // co ile przesuwa się karuzela
function heroCarousel(root, stacks) {
  root.className = "hero v2 vm";
  // na pionowym ekranie bierzemy pionową wersję kadru (mob); podpis i link zostają od kadru z HERO
  const shot = h => stacks && h.mob ? { a: h.mob.a || h.a, n: h.mob.n, w: h.mob.w, h: h.mob.h }
    : h.wide ? { a: h.a, n: h.wide.n, w: h.wide.w, h: h.wide.h } : { a: h.a, n: h.n };
  const size = h => { const s = shot(h); return s.w ? [s.w, s.h] : dims(s.a, s.n); };
  const rest = HERO.slice(1);
  let slides;
  if (stacks) {
    const land = rest.filter(h => { const [w, hh] = size(h); return w > hh; }), port = rest.filter(h => { const [w, hh] = size(h); return w <= hh; });
    const groups = [];
    for (let i = 0; i < land.length; i += 3) groups.push(land.slice(i, i + 3));
    // samotne zdjęcie poziome na końcu → dwa slajdy po 2
    if (groups.length > 1 && groups[groups.length - 1].length === 1) groups[groups.length - 1].unshift(groups[groups.length - 2].pop());
    // slajdy z kilkoma zdjęciami rozkładamy równo między pionowe
    const n = groups.length + port.length, at = new Set(groups.map((_, k) => Math.floor(k * n / groups.length)));
    let gi = 0, pi = 0; slides = [];
    for (let k = 0; k < n; k++) slides.push(at.has(k) && gi < groups.length ? groups[gi++] : pi < port.length ? [port[pi++]] : groups[gi++]);
  } else slides = rest.map(h => [h]);
  slides.unshift([HERO[0]]);

  const lab = h => `<span class="vm-lab"><b>${heroName(h)}</b>${heroMeta(h) ? `<small>${heroMeta(h)}</small>` : ""}</span>`;
  const ph = (h, few) => {
    const { a, n } = shot(h), [w, hh] = size(h);
    return `<a class="vm-ph" href="${URLS.album(h.a)}" style="--r:${(w / hh).toFixed(4)}">
      <img src="${photo(a, n, 1280)}" srcset="${[640, 1280, 2048].map(s => `${photo(a, n, s)} ${s}w`).join(", ")}"
        sizes="${few ? "92vw" : "100vw"}" width="${w}" height="${hh}" alt="${altFor(a, n)}"
        loading="lazy" decoding="async">${lab(h)}</a>`;
  };
  root.innerHTML = `<div class="v2-stick">
    <div class="v2-frame"><div class="vm-view">${slides.map((s, i) => i === 0
      ? `<div class="vm-slide first"><a class="vm-ph first" href="${URLS.album(s[0].a)}">${heroImg(s[0], 0)}${lab(s[0])}</a></div>`
      : `<div class="vm-slide n${s.length}">${s.map(h => ph(h, stacks)).join("")}</div>`).join("")}</div></div>
    <div class="wrap v2-head">${headHTML()}</div>
    <button class="vm-arrow vm-prev" type="button" aria-label="${LANG === "pl" ? "Poprzednie zdjęcie" : "Previous photo"}"><svg viewBox="0 0 24 24"><path d="M15 4l-8 8 8 8"/></svg></button>
    <button class="vm-arrow vm-next" type="button" aria-label="${LANG === "pl" ? "Następne zdjęcie" : "Next photo"}"><svg viewBox="0 0 24 24"><path d="M9 4l8 8-8 8"/></svg></button>
    <div class="wrap hero-ui vm-ui">
      <div class="hinfo">
        <div class="hcount"><span class="odo" aria-hidden="true"></span><span class="v4-tot">/ ${pad(slides.length)}</span></div>
        <span class="v4-bar"><i></i></span>
      </div>
    </div>
  </div>`;
  const head = root.querySelector(".v2-head"), stick = root.querySelector(".v2-stick"), view = root.querySelector(".vm-view");
  const slideEls = [...root.querySelectorAll(".vm-slide")], odoEl = root.querySelector(".odo");
  odoEl.innerHTML = `<span>${"0123456789".split("").map(d => `<i>${d}</i>`).join("")}</span>`.repeat(2);
  let E = 0, lastW = 0, act = -1, pausedTill = 0;

  function measure() {
    root.style.setProperty("--e", 0);
    const hb = head.getBoundingClientRect(), cs = getComputedStyle(head);
    root.style.setProperty("--ft", `${Math.round(hb.bottom - stick.getBoundingClientRect().top + 22)}px`);
    root.style.setProperty("--fs", `${Math.round(hb.left + parseFloat(cs.paddingLeft))}px`);
    root.style.setProperty("--fb", "16px");
    E = innerHeight * .7;                                   // odcinek przewijania na rozszerzenie ramki
    root.style.height = `${innerHeight + E + innerHeight * .1}px`;   // potem od razu sekcja #work
  }
  function setSlide(i) {
    if (i === act) return; act = i;
    odoEl.querySelectorAll(":scope > span").forEach((col, k) => col.style.transform = `translateY(-${+pad(i + 1)[k] * 1.2}em)`);
    root.style.setProperty("--p", slides.length > 1 ? (i / (slides.length - 1)).toFixed(4) : 0);
    // następny slajd pobieramy z wyprzedzeniem
    [i + 1, i + 2].forEach(k => slideEls[k] && slideEls[k].querySelectorAll("img[loading=lazy]").forEach(im => im.loading = "eager"));
  }
  function update() {
    // pasek adresu na telefonie zmienia wysokość okna przy przewijaniu — przeliczamy tylko przy zmianie szerokości
    if (innerWidth !== lastW) { lastW = innerWidth; measure(); }
    const y = Math.max(0, -root.getBoundingClientRect().top);
    const e = ease(clamp(y / E));
    root.style.setProperty("--e", e.toFixed(4));
    const full = e > .7, was = root.classList.contains("full");
    if (full && !was) lastMove = Date.now();   // po rozszerzeniu pierwsze zdjęcie chwilę stoi
    // po zwinięciu ramki karuzela wraca do pierwszego zdjęcia (w ramce zawsze jest główne zdjęcie)
    if (!full && was && view.scrollLeft) view.scrollTo({ left: 0, behavior: still ? "auto" : "smooth" });
    root.classList.toggle("full", full);
  }
  const go = i => { lastMove = Date.now(); view.scrollTo({ left: ((i + slides.length) % slides.length) * view.clientWidth, behavior: still ? "auto" : "smooth" }); };
  const onSwipe = () => { const i = Math.round(view.scrollLeft / Math.max(1, view.clientWidth)); if (i !== act) lastMove = Date.now(); setSlide(i); };
  view.addEventListener("scroll", onSwipe, { passive: true });
  ["pointerdown", "touchstart", "wheel"].forEach(ev => view.addEventListener(ev, () => { pausedTill = Date.now() + 6000; }, { passive: true }));
  // strzałki (działają tylko przy rozszerzonym zdjęciu); kliknięcie wstrzymuje automat na 6 s
  root.querySelector(".vm-arrow.vm-prev").onclick = () => { pausedTill = Date.now() + 6000; go(act - 1); };
  root.querySelector(".vm-arrow.vm-next").onclick = () => { pausedTill = Date.now() + 6000; go(act + 1); };
  // karuzela przesuwa się sama co CAROUSEL_MS, gdy ramka jest rozszerzona i hero jest na ekranie
  let lastMove = Date.now();
  const timer = still ? 0 : setInterval(() => {
    const r = root.getBoundingClientRect();
    if (!root.classList.contains("full") || Date.now() < pausedTill || document.hidden || r.bottom < innerHeight * .6) return;
    if (Date.now() - lastMove < CAROUSEL_MS) return;
    go(act + 1);
  }, 250);
  heroFns.push(update);
  requestAnimationFrame(update);
  setSlide(0);
  const ro = new ResizeObserver(() => { lastW = 0; update(); }); ro.observe(head);
  return {
    lang: () => rebuildHero(),   // podpisy są w slajdach — po zmianie języka budujemy hero od nowa
    destroy: () => { ro.disconnect(); clearInterval(timer); },
  };
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
// Ekran dotykowy (telefon, tablet) albo wąskie okno → karuzela; komputer → taśma przesuwana przewijaniem
const mqTouch = matchMedia("(hover: none) and (pointer: coarse), (max-width: 760px)"), mqPortrait = matchMedia("(orientation: portrait)");
let HERO_UI = { lang() {}, destroy() {} };
function rebuildHero() {
  try { HERO_UI.destroy(); } catch (e) {}
  heroFns.length = 0;
  try { HERO_UI = mqTouch.matches ? heroCarousel(heroRoot, mqPortrait.matches) : heroFrameStrip(heroRoot); }
  catch (e) { console.error("Hero:", e); heroRoot.style.height = "auto"; HERO_UI = { lang() {}, destroy() {} }; }
  heroRoot.querySelectorAll("[data-i18n]").forEach(el => el.textContent = t(el.dataset.i18n));
}
rebuildHero();
[mqTouch, mqPortrait].forEach(m => m.addEventListener ? m.addEventListener("change", rebuildHero) : m.addListener(rebuildHero));
window.heroLang = () => { try { HERO_UI.lang(); } catch (e) { console.error("Hero:", e); } };
// Pasek nagłówka strony robi się ciemny dopiero po wyjściu z hero
window.heroEnd = () => heroRoot.offsetTop + heroRoot.offsetHeight - 90;
