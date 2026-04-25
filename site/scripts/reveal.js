document.addEventListener('DOMContentLoaded', () => {
  const targets = document.querySelectorAll('.anim-hidden');

  const io = new IntersectionObserver((entries, obs) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('anim-visible');
        obs.unobserve(entry.target);
      }
    });
  }, { threshold: 0.15 });

  targets.forEach(el => io.observe(el));

  // Hide hero scroll cue on first scroll
  const scrollCue = document.querySelector('.scroll-cue');
  if (scrollCue) {
    const hideScrollCue = () => {
      scrollCue.classList.add('is-hidden');
      window.removeEventListener('scroll', hideScrollCue, { passive: true });
    };
    window.addEventListener('scroll', hideScrollCue, { passive: true });
  }
});
