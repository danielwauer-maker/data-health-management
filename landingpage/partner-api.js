(function () {
  function readConfiguredApiBase() {
    const meta = document.querySelector('meta[name="bcsentinel-api-base"]');
    const metaValue = meta && meta.getAttribute("content");
    if (metaValue && metaValue.trim()) {
      return metaValue.trim().replace(/\/+$/, "");
    }

    const windowValue = typeof window !== "undefined" ? window.__BCSENTINEL_API_BASE__ : "";
    if (typeof windowValue === "string" && windowValue.trim()) {
      return windowValue.trim().replace(/\/+$/, "");
    }

    return "";
  }

  function deriveApiBaseFromLocation() {
    if (typeof window === "undefined" || !window.location) {
      return "https://api.bcsentinel.com";
    }

    const { hostname, origin } = window.location;
    const normalizedHost = (hostname || "").toLowerCase();

    if (normalizedHost === "bcsentinel.com" || normalizedHost === "www.bcsentinel.com") {
      return "https://api.bcsentinel.com";
    }

    if (normalizedHost === "dev.bcsentinel.com") {
      return "https://dev-api.bcsentinel.com";
    }

    return origin;
  }

  function getApiBase() {
    return readConfiguredApiBase() || deriveApiBaseFromLocation();
  }

  window.BCSentinelPartnerApi = {
    getApiBase,
    buildUrl(path) {
      const normalizedPath = String(path || "").startsWith("/") ? path : "/" + String(path || "");
      return getApiBase() + normalizedPath;
    },
  };
})();
