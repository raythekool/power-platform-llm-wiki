(function () {
    'use strict';
    var panels = Array.prototype.slice.call(document.querySelectorAll('.wz-panel'));
    if (!panels.length) { return; }
    var wz = document.querySelector('.wz');
    var links = Array.prototype.slice.call(document.querySelectorAll('.wz-nav a'));
    var list = document.querySelector('.wz-nav ol');
    var pager = document.querySelector('.wz-pager');
    var prev = pager.querySelector('[data-wz-go="-1"]');
    var next = pager.querySelector('[data-wz-go="1"]');
    var reset = document.querySelector('.wz-reset');
    var bar = document.querySelector('.wz-bar i');
    var KEY = 'llmwiki-wizard';
    var done = {};
    var current = 0;
    try { done = JSON.parse(localStorage.getItem(KEY) || '{}') || {}; } catch (e) { done = {}; }

    function indexOf(hash) {
        var id = (hash || '').replace(/^#/, '');
        for (var i = 0; i < panels.length; i++) { if (panels[i].id === id) { return i; } }
        return -1;
    }

    function save() {
        try { localStorage.setItem(KEY, JSON.stringify(done)); } catch (e) { /* storage unavailable */ }
    }

    function render() {
        var n = 0;
        panels.forEach(function (p, i) {
            var ok = !!done[p.id];
            if (ok) { n++; }
            p.hidden = i !== current;
            p.querySelector('[data-wz-done]').checked = ok;
            links[i].classList.toggle('done', ok);
            if (i === current) { links[i].setAttribute('aria-current', 'step'); } else { links[i].removeAttribute('aria-current'); }
        });
        document.querySelectorAll('[data-wz-count]').forEach(function (el) { el.textContent = String(n); });
        bar.style.width = (n / panels.length * 100) + '%';
        prev.disabled = current === 0;
        next.disabled = current === panels.length - 1;
        reset.hidden = n === 0;
        // horizontal stepper on small screens
        if (list.scrollWidth > list.clientWidth) {
            list.scrollLeft += links[current].getBoundingClientRect().left - list.getBoundingClientRect().left - 12;
        }
    }

    function go(i, focus, push) {
        current = Math.max(0, Math.min(panels.length - 1, i));
        var hash = '#' + panels[current].id;
        if (push && location.hash !== hash) { history.pushState(null, '', hash); }
        render();
        if (focus) {
            if (wz.getBoundingClientRect().top < 0) { wz.scrollIntoView({ block: 'start' }); }
            panels[current].querySelector('h2').focus({ preventScroll: true });
        }
    }

    links.forEach(function (a, i) {
        a.addEventListener('click', function (e) { e.preventDefault(); go(i, true, true); });
    });
    pager.querySelectorAll('[data-wz-go]').forEach(function (b) {
        b.addEventListener('click', function () { go(current + Number(b.dataset.wzGo), true, true); });
    });
    panels.forEach(function (p) {
        p.querySelector('[data-wz-done]').addEventListener('change', function (e) {
            if (e.target.checked) { done[p.id] = true; } else { delete done[p.id]; }
            save();
            render();
        });
    });
    reset.addEventListener('click', function () {
        done = {};
        save();
        go(0, true, true);
    });
    window.addEventListener('popstate', function () {
        var i = indexOf(location.hash);
        if (i >= 0) { go(i, true, false); }
    });

    pager.hidden = false;
    var start = indexOf(location.hash);
    go(start < 0 ? 0 : start, false, false);
    if (start >= 0) { wz.scrollIntoView({ block: 'start' }); }
})();
