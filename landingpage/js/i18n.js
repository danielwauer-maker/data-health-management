(function () {
  const DEFAULT_LANG = 'en';
  const SUPPORTED_LANGS = ['en', 'de'];

  function getInitialLanguage() {
    const url = new URL(window.location.href);
    const fromQuery = url.searchParams.get('lang');
    if (SUPPORTED_LANGS.includes(fromQuery)) return fromQuery;

    const saved = localStorage.getItem('bcsentinel_lang');
    if (SUPPORTED_LANGS.includes(saved)) return saved;

    const browser = (navigator.language || navigator.userLanguage || DEFAULT_LANG).toLowerCase();
    return browser.startsWith('de') ? 'de' : 'en';
  }

  async function loadLanguage(lang) {
    if (!SUPPORTED_LANGS.includes(lang)) lang = DEFAULT_LANG;

    const response = await fetch(`lang/${lang}.json`, { cache: 'no-cache' });
    if (!response.ok) throw new Error(`Could not load language file: ${lang}`);
    const translations = await response.json();

    applyTranslations(translations);
    updateLanguageButtons(lang);
    document.documentElement.lang = lang;
    localStorage.setItem('bcsentinel_lang', lang);

    const url = new URL(window.location.href);
    url.searchParams.set('lang', lang);
    window.history.replaceState({}, '', url);
  }

  function applyTranslations(translations) {
    document.querySelectorAll('[data-i18n]').forEach((el) => {
      const key = el.getAttribute('data-i18n');
      if (translations[key] !== undefined) {
        el.textContent = translations[key];
      }
    });

    document.querySelectorAll('[data-i18n-alt]').forEach((el) => {
      const key = el.getAttribute('data-i18n-alt');
      if (translations[key] !== undefined) {
        el.setAttribute('alt', translations[key]);
      }
    });

    document.querySelectorAll('[data-i18n-content]').forEach((el) => {
      const key = el.getAttribute('data-i18n-content');
      if (translations[key] !== undefined) {
        el.setAttribute('content', translations[key]);
      }
    });

    if (translations.meta_title) {
      document.title = translations.meta_title;
    }
  }

  function updateLanguageButtons(activeLang) {
    document.querySelectorAll('.lang-btn').forEach((btn) => {
      btn.classList.toggle('active', btn.dataset.lang === activeLang);
      btn.setAttribute('aria-pressed', btn.dataset.lang === activeLang ? 'true' : 'false');
    });
  }

  document.addEventListener('click', (event) => {
    const button = event.target.closest('.lang-btn');
    if (!button) return;
    loadLanguage(button.dataset.lang).catch(console.error);
  });

  document.addEventListener('DOMContentLoaded', () => {
    loadLanguage(getInitialLanguage()).catch(console.error);
  });
})();
