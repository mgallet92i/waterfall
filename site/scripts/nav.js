document.addEventListener('DOMContentLoaded', () => {
  const sections = document.querySelectorAll('main > section[id]');
  const links = document.querySelectorAll('.nav-menu a[href^="#"]');

  const linkFor = (id) => [...links].find(a => a.getAttribute('href') === '#' + id);

  const io = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        links.forEach(a => {
          a.classList.remove('is-active');
          a.removeAttribute('aria-current');
        });
        const link = linkFor(entry.target.id);
        if (link) {
          link.classList.add('is-active');
          link.setAttribute('aria-current', 'true');
        }
      }
    });
  }, { rootMargin: '-40% 0px -55% 0px', threshold: 0 });

  sections.forEach(s => io.observe(s));
});
