(function () {
    'use strict';
    var root = document.documentElement;
    var titles = {
        en: 'LLM Wiki - Documentation that stays aligned with the code',
        it: 'LLM Wiki - Documentazione sempre allineata al codice'
    };

    function setLang(lang) {
        root.dataset.lang = lang;
        root.lang = lang;
        document.title = titles[lang] || titles.en;
        try { localStorage.setItem('llmwiki-lang', lang); } catch (e) { /* storage unavailable */ }
        document.querySelectorAll('[data-set-lang]').forEach(function (b) {
            b.setAttribute('aria-pressed', String(b.dataset.setLang === lang));
        });
        document.querySelectorAll('img[data-alt-it]').forEach(function (img) {
            if (!img.dataset.altEn) { img.dataset.altEn = img.alt; }
            img.alt = lang === 'it' ? img.dataset.altIt : img.dataset.altEn;
        });
    }

    document.querySelectorAll('[data-set-lang]').forEach(function (b) {
        b.addEventListener('click', function () { setLang(b.dataset.setLang); });
    });
    setLang(root.dataset.lang === 'it' ? 'it' : 'en');

    document.querySelectorAll('.copy').forEach(function (btn) {
        btn.addEventListener('click', function () {
            var target = document.querySelector(btn.dataset.copy);
            if (!target || !navigator.clipboard) { return; }
            navigator.clipboard.writeText(target.textContent.trim()).then(function () {
                var old = btn.innerHTML;
                btn.textContent = '✓';
                setTimeout(function () { btn.innerHTML = old; }, 1400);
            });
        });
    });

    var items = document.querySelectorAll('.reveal');
    if (!('IntersectionObserver' in window)) {
        items.forEach(function (el) { el.classList.add('in'); });
        return;
    }
    var io = new IntersectionObserver(function (entries) {
        entries.forEach(function (e) {
            if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); }
        });
    }, { threshold: 0.12 });
    items.forEach(function (el) { io.observe(el); });
})();
