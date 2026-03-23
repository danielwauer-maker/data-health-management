(function () {
    let rootContainer = null;
    let iframe = null;
    let titleBar = null;
    let emptyState = null;
    let initialized = false;
    let pendingUrl = "";
    let pendingTitle = "Analytics";

    function whenBodyReady(callback) {
        if (document.body) {
            callback();
            return;
        }

        document.addEventListener(
            "DOMContentLoaded",
            function onReady() {
                document.removeEventListener("DOMContentLoaded", onReady);
                callback();
            },
            { once: true }
        );
    }

    function ensureDom() {
        if (initialized) {
            return;
        }

        if (!document.body) {
            return;
        }

        document.documentElement.style.height = "100%";
        document.body.style.height = "100%";
        document.body.style.margin = "0";
        document.body.style.padding = "0";
        document.body.style.overflow = "hidden";
        document.body.style.background = "#f5f6f8";
        document.body.style.fontFamily = "Segoe UI, Arial, sans-serif";

        rootContainer = document.createElement("div");
        rootContainer.className = "dhm-analytics-root";

        titleBar = document.createElement("div");
        titleBar.className = "dhm-analytics-title";
        titleBar.textContent = pendingTitle || "Analytics";

        const content = document.createElement("div");
        content.className = "dhm-analytics-content";

        iframe = document.createElement("iframe");
        iframe.className = "dhm-analytics-iframe";
        iframe.setAttribute("frameborder", "0");
        iframe.setAttribute("allowfullscreen", "true");
        iframe.setAttribute("referrerpolicy", "strict-origin-when-cross-origin");
        iframe.src = "about:blank";

        emptyState = document.createElement("div");
        emptyState.className = "dhm-analytics-empty";
        emptyState.innerHTML = `
            <div class="dhm-analytics-empty-box">
                <div class="dhm-analytics-empty-title">Dashboard wird geladen ...</div>
                <div class="dhm-analytics-empty-text">Bitte warten.</div>
            </div>
        `;

        iframe.addEventListener("load", function () {
            if (emptyState) {
                emptyState.style.display = "none";
            }
        });

        content.appendChild(iframe);
        content.appendChild(emptyState);

        rootContainer.appendChild(titleBar);
        rootContainer.appendChild(content);
        document.body.appendChild(rootContainer);

        initialized = true;

        if (pendingUrl && pendingUrl.trim()) {
            iframe.src = pendingUrl;
        }
    }

    function initializeIfNeeded() {
        whenBodyReady(function () {
            ensureDom();

            if (
                window.Microsoft &&
                window.Microsoft.Dynamics &&
                window.Microsoft.Dynamics.NAV &&
                typeof window.Microsoft.Dynamics.NAV.InvokeExtensibilityMethod === "function"
            ) {
                window.Microsoft.Dynamics.NAV.InvokeExtensibilityMethod("ControlReady", []);
            }
        });
    }

    function SetAnalyticsUrl(url) {
        pendingUrl = String(url || "").trim();

        whenBodyReady(function () {
            ensureDom();

            if (!iframe || !emptyState) {
                return;
            }

            if (!pendingUrl) {
                iframe.src = "about:blank";
                emptyState.style.display = "flex";
                emptyState.innerHTML = `
                    <div class="dhm-analytics-empty-box">
                        <div class="dhm-analytics-empty-title">Keine Analytics-URL konfiguriert</div>
                        <div class="dhm-analytics-empty-text">Bitte prüfe die BaseUrl in der AL-Page.</div>
                    </div>
                `;
                return;
            }

            emptyState.style.display = "flex";
            emptyState.innerHTML = `
                <div class="dhm-analytics-empty-box">
                    <div class="dhm-analytics-empty-title">Dashboard wird geladen ...</div>
                    <div class="dhm-analytics-empty-text">${escapeHtml(pendingUrl)}</div>
                </div>
            `;

            iframe.src = pendingUrl;
        });
    }

    function SetTitle(title) {
        pendingTitle = String(title || "").trim() || "Analytics";

        whenBodyReady(function () {
            ensureDom();

            if (titleBar) {
                titleBar.textContent = pendingTitle;
            }
        });
    }

    function escapeHtml(value) {
        return String(value || "")
            .replaceAll("&", "&amp;")
            .replaceAll("<", "&lt;")
            .replaceAll(">", "&gt;")
            .replaceAll('"', "&quot;")
            .replaceAll("'", "&#039;");
    }

    window.SetAnalyticsUrl = SetAnalyticsUrl;
    window.SetTitle = SetTitle;

    initializeIfNeeded();
})();