document.addEventListener('DOMContentLoaded', () => {
  if (!navigator.clipboard) {
    document.querySelectorAll('.copy-btn').forEach(btn => { btn.hidden = true; });
    return;
  }

  document.querySelectorAll('.copy-btn').forEach(btn => {
    btn.addEventListener('click', async () => {
      const wrap = btn.closest('.code-wrap');
      const code = wrap?.querySelector('code')?.innerText;
      if (!code) return;
      try {
        await navigator.clipboard.writeText(code);
        btn.dataset.state = 'copied';
        btn.textContent = 'copied!';
        setTimeout(() => {
          delete btn.dataset.state;
          btn.textContent = 'copy';
        }, 1500);
      } catch (_) {
        // clipboard write failed silently
      }
    });
  });
});
