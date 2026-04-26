// Waterfall homepage — vanilla JS

(() => {
  // Sticky nav border on scroll
  const nav = document.getElementById('nav');
  const onScroll = () => {
    if (!nav) return;
    nav.classList.toggle('is-scrolled', window.scrollY > 8);
  };
  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  // Scroll reveals — promote chosen elements
  const revealSelectors = [
    '.section__head',
    '.problem__card',
    '.problem__pull',
    '.vphase',
    '.cycle__legend',
    '.glossary',
    '.agent',
    '.agents__lane',
    '.install__step',
    '.install__aside > div',
    '.tradeoff__chart',
    '.tradeoff__costs li',
    '.why__card',
    '.foot__grid > *'
  ];
  const reveals = document.querySelectorAll(revealSelectors.join(','));
  reveals.forEach((el, i) => {
    el.classList.add('reveal');
    el.style.transitionDelay = ((i % 6) * 40) + 'ms';
  });

  if ('IntersectionObserver' in window) {
    const io = new IntersectionObserver((entries) => {
      entries.forEach((e) => {
        if (e.isIntersecting) {
          e.target.classList.add('is-in');
          io.unobserve(e.target);
        }
      });
    }, { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });
    reveals.forEach((el) => io.observe(el));
  } else {
    reveals.forEach((el) => el.classList.add('is-in'));
  }

  // Copy buttons
  const toast = document.getElementById('copyToast');
  const showToast = (msg) => {
    if (!toast) return;
    toast.textContent = msg;
    toast.classList.add('is-visible');
    clearTimeout(showToast._t);
    showToast._t = setTimeout(() => toast.classList.remove('is-visible'), 1500);
  };

  document.querySelectorAll('[data-copy]').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const txt = btn.getAttribute('data-copy') || '';
      try {
        await navigator.clipboard.writeText(txt);
        showToast('copied');
      } catch {
        // Fallback
        const ta = document.createElement('textarea');
        ta.value = txt;
        document.body.appendChild(ta);
        ta.select();
        try { document.execCommand('copy'); showToast('copied'); }
        catch { showToast('copy failed'); }
        document.body.removeChild(ta);
      }
    });
  });

  // ─── Cascade scroll-pinned animation ───
  const cs = document.getElementById('cascadeScroll');
  if (cs) {
    const rows  = cs.querySelectorAll('.cascade__row');
    const progress = cs.querySelector('.cascade2__progress-fill');

    const update = () => {
      const r = cs.getBoundingClientRect();
      const vh = window.innerHeight || 800;
      const total = cs.offsetHeight - vh;
      const scrolled = Math.min(Math.max(-r.top, 0), Math.max(total, 1));
      const t = total > 0 ? scrolled / total : 0;

      progress.style.setProperty('--progress', (t * 100).toFixed(1) + '%');

      // Reveal rows progressively across [0.05 .. 0.92]
      const start = 0.05, end = 0.92;
      const span = (end - start) / rows.length;
      rows.forEach((row, i) => {
        const threshold = start + span * i;
        row.classList.toggle('is-active', t >= threshold);
      });
    };

    let ticking = false;
    const onCscroll = () => {
      if (!ticking) {
        ticking = true;
        requestAnimationFrame(() => { update(); ticking = false; });
      }
    };
    window.addEventListener('scroll', onCscroll, { passive: true });
    window.addEventListener('resize', update);
    update();
  }

  // Active section in nav
  const links = document.querySelectorAll('.nav__links a');
  const sectionMap = new Map();
  links.forEach((a) => {
    const id = a.getAttribute('href');
    if (id && id.startsWith('#')) {
      const el = document.querySelector(id);
      if (el) sectionMap.set(el, a);
    }
  });
  if ('IntersectionObserver' in window && sectionMap.size) {
    const io2 = new IntersectionObserver((entries) => {
      entries.forEach((e) => {
        const a = sectionMap.get(e.target);
        if (!a) return;
        if (e.isIntersecting) {
          links.forEach((l) => l.style.color = '');
          a.style.color = 'var(--ink-900)';
        }
      });
    }, { rootMargin: '-40% 0px -55% 0px', threshold: 0 });
    sectionMap.forEach((_, el) => io2.observe(el));
  }
})();
