# Arek — fotografia motoryzacyjna

Portfolio (PL/EN): https://arekcarphotography-coder.github.io

- Strona statyczna: HTML/CSS/JS, zdjęcia WebP w `assets/img/`.
- Dane albumów, wyjazdów i bloga: `assets/data.js`.
- Po każdej zmianie danych: `ruby -E UTF-8 tools/build_site.rb` (podstrony, sitemap, obrazki do udostępniania).
- Podgląd lokalny: `ruby tools/serve.rb` → http://localhost:8080
