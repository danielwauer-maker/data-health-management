(function () {
  const SUPPORTED = ["de", "en"];
  const STORAGE_KEY = "bcsentinel-lang";

  async function loadLocale(lang) {
    const selected = SUPPORTED.includes(lang) ? lang : "en";
    const response = await fetch(`./locales/${selected}.json`, { cache: "no-cache" });
    if (!response.ok) throw new Error("Locale not found: " + selected);
    return response.json();
  }

  function applyTranslations(dict, lang) {
    document.documentElement.lang = lang;
    if (dict.meta_title) document.title = dict.meta_title;
    document.querySelectorAll("[data-i18n]").forEach((el) => {
      const key = el.getAttribute("data-i18n");
      if (dict[key] !== undefined) el.textContent = dict[key];
    });
  }

  async function setLanguage(lang) {
    const selected = SUPPORTED.includes(lang) ? lang : "en";
    const dict = await loadLocale(selected);
    applyTranslations(dict, selected);
    localStorage.setItem(STORAGE_KEY, selected);
  }

  function initI18n() {
    const saved = localStorage.getItem(STORAGE_KEY);
    const initial = SUPPORTED.includes(saved) ? saved : "de";
    setLanguage(initial).catch(console.error);

    document.addEventListener("click", (event) => {
      const btn = event.target.closest("[data-set-lang]");
      if (!btn) return;
      setLanguage(btn.getAttribute("data-set-lang")).catch(console.error);
    });
  }

  window.BCSentinelI18n = { setLanguage, initI18n };
})();
