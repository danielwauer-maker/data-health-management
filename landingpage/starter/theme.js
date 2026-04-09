(function () {
  const STORAGE_KEY = "bcsentinel-theme";

  function setTheme(theme) {
    const selected = theme === "dark" ? "dark" : "light";
    document.documentElement.setAttribute("data-theme", selected);
    localStorage.setItem(STORAGE_KEY, selected);
  }

  function toggleTheme() {
    const current = document.documentElement.getAttribute("data-theme") === "dark" ? "dark" : "light";
    setTheme(current === "dark" ? "light" : "dark");
  }

  function initTheme() {
    const saved = localStorage.getItem(STORAGE_KEY);
    setTheme(saved === "dark" ? "dark" : "light");

    document.addEventListener("click", (event) => {
      const btn = event.target.closest("[data-toggle-theme]");
      if (!btn) return;
      toggleTheme();
    });
  }

  window.BCSentinelTheme = { setTheme, toggleTheme, initTheme };
})();
