document.querySelectorAll("a").forEach((link) => {
  const isSameHost = link.hostname === window.location.hostname;
  const opensNewTab = link.target === "_blank";
  const hasHash = link.getAttribute("href")?.startsWith("#");

  if (isSameHost && !opensNewTab && !hasHash) {
    link.addEventListener("click", (e) => {
      e.preventDefault();
      document.body.style.opacity = 0;

      setTimeout(() => {
        window.location = link.href;
      }, 300);
    });
  }
});
