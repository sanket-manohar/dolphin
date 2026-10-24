(function () {
  var root = document.documentElement;
  var chapters = [].slice.call(document.querySelectorAll('.ch'));
  var links = [].slice.call(document.querySelectorAll('.toc a'));
  var side = document.getElementById('side');
  var opener = document.getElementById('open-toc');
  var roman = ['i', 'ii', 'iii', 'iv', 'v', 'vi', 'vii', 'viii', 'ix', 'x', 'xi', 'xii', 'xiii', 'xiv', 'xv', 'xvi', 'xvii', 'xviii', 'xix', 'xx', 'xxi', 'xxii'];
  var current = -1;

  function title(i) {
    var a = links[i];
    return a ? a.textContent.replace(/^[ivx]+\.\s*/, '') : '';
  }

  function show(i, push) {
    if (i < 0 || i >= chapters.length || i === current) return;
    if (current >= 0) chapters[current].classList.remove('on');
    current = i;
    var ch = chapters[i];
    ch.classList.add('on');
    ch.scrollTop = 0;
    links.forEach(function (a, k) { if (k === i) a.setAttribute('aria-current', 'page'); else a.removeAttribute('aria-current'); });
    if (links[i] && links[i].scrollIntoView) links[i].scrollIntoView({ block: 'nearest' });
    document.getElementById('run-part').textContent = ch.getAttribute('data-part') || 'dolphin';
    document.getElementById('folio').textContent = '— ' + roman[i] + ' —';
    var prev = document.getElementById('prev'), next = document.getElementById('next');
    prev.disabled = i === 0;
    next.disabled = i === chapters.length - 1;
    document.getElementById('prev-t').textContent = i > 0 ? title(i - 1) : '';
    document.getElementById('next-t').textContent = i < chapters.length - 1 ? title(i + 1) : '';
    if (push && history.replaceState) history.replaceState(null, '', '#' + ch.id);
  }

  function fromHash() {
    var id = (location.hash || '').slice(1);
    var i = chapters.findIndex(function (c) { return c.id === id; });
    show(i < 0 ? 0 : i, false);
  }

  links.forEach(function (a, i) {
    a.addEventListener('click', function (e) {
      e.preventDefault();
      show(i, true);
      closeSide();
    });
  });
  document.addEventListener('click', function (e) {
    var a = e.target.closest && e.target.closest('a[href^="#"]');
    if (!a || a.closest('.toc')) return;
    var i = chapters.findIndex(function (c) { return '#' + c.id === a.getAttribute('href'); });
    if (i >= 0) { e.preventDefault(); show(i, true); closeSide(); }
  });
  document.getElementById('prev').addEventListener('click', function () { show(current - 1, true); });
  document.getElementById('next').addEventListener('click', function () { show(current + 1, true); });
  window.addEventListener('hashchange', fromHash);

  document.addEventListener('keydown', function (e) {
    if (e.altKey || e.ctrlKey || e.metaKey || /INPUT|TEXTAREA/.test(document.activeElement.tagName)) return;
    if (e.key === 'ArrowRight' || e.key === 'PageDown') { show(current + 1, true); e.preventDefault(); }
    else if (e.key === 'ArrowLeft' || e.key === 'PageUp') { show(current - 1, true); e.preventDefault(); }
    else if (e.key === 'Home') { show(0, true); e.preventDefault(); }
    else if (e.key === 'End') { show(chapters.length - 1, true); e.preventDefault(); }
    else if (e.key === 'Escape') closeSide();
  });

  // A sideways swipe turns the page on touch screens.
  var sx = null, sy = null;
  var pages = document.querySelector('.pages');
  pages.addEventListener('touchstart', function (e) { sx = e.touches[0].clientX; sy = e.touches[0].clientY; }, { passive: true });
  pages.addEventListener('touchend', function (e) {
    if (sx === null) return;
    var dx = e.changedTouches[0].clientX - sx, dy = e.changedTouches[0].clientY - sy;
    if (Math.abs(dx) > 60 && Math.abs(dx) > Math.abs(dy) * 1.5) show(current + (dx < 0 ? 1 : -1), true);
    sx = null;
  });

  function closeSide() {
    side.classList.remove('open');
    if (opener) opener.setAttribute('aria-expanded', 'false');
  }
  if (opener) {
    opener.addEventListener('click', function () {
      var open = side.classList.toggle('open');
      opener.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
  }

  var toggle = document.querySelector('.theme-toggle');
  if (toggle) {
    toggle.addEventListener('click', function () {
      var dark = root.getAttribute('data-theme')
        ? root.getAttribute('data-theme') === 'dark'
        : window.matchMedia('(prefers-color-scheme: dark)').matches;
      var next = dark ? 'light' : 'dark';
      root.setAttribute('data-theme', next);
      try { localStorage.setItem('dolphin-theme', next); } catch (e) {}
    });
  }

  document.querySelectorAll('[data-copy]').forEach(function (b) {
    b.addEventListener('click', function () {
      var text = document.getElementById(b.getAttribute('data-copy')).textContent;
      navigator.clipboard.writeText(text).then(function () {
        b.textContent = 'Copied';
        setTimeout(function () { b.textContent = 'Copy'; }, 1500);
      }).catch(function () {});
    });
  });

  fromHash();
})();
