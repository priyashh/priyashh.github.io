document.addEventListener("DOMContentLoaded", () => {
  const root = document.documentElement;
  const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  if (prefersReducedMotion) {
    root.style.setProperty("--star-offset-y", "0px");
    return;
  }

  let rafScheduled = false;

  const updateStarOffset = () => {
    const scrollY = window.scrollY || window.pageYOffset || 0;
    root.style.setProperty("--star-offset-y", `${scrollY * -0.22}px`);
    rafScheduled = false;
  };

  const onScroll = () => {
    if (!rafScheduled) {
      rafScheduled = true;
      requestAnimationFrame(updateStarOffset);
    }
  };

  window.addEventListener("scroll", onScroll, { passive: true });
  updateStarOffset();
});
