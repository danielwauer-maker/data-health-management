from urllib.parse import urljoin, urlparse

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # === CORE ===
    ENV: str = "dev"

    # === SECURITY ===
    SECRET_KEY: str
    ADMIN_USERNAME: str
    ADMIN_PASSWORD: str

    # === DATABASE ===
    DATABASE_URL: str

    # === TOKEN ===
    TOKEN_EXPIRE_MINUTES: int = 60
    CORS_ALLOW_ORIGINS: str | None = None
    APP_BASE_URL: str | None = None
    PARTNER_RESET_URL_BASE: str | None = None
    SMTP_HOST: str | None = None
    SMTP_PORT: int = 587
    SMTP_USERNAME: str | None = None
    SMTP_PASSWORD: str | None = None
    SMTP_USE_TLS: bool = True
    SMTP_FROM_EMAIL: str | None = None
    SMTP_FROM_NAME: str = "BCSentinel"

    # === BILLING (STRIPE) ===
    # Checkout uses Stripe Price objects (amount + interval). When list prices in
    # config/pricing_canonical.json or license_pricing_config change, create matching
    # new Prices in Stripe and update these env vars — see backend/README.md.
    STRIPE_SECRET_KEY: str | None = None
    STRIPE_WEBHOOK_SECRET: str | None = None
    STRIPE_PRICE_ID_PREMIUM: str | None = None
    STRIPE_PRICE_ID_PREMIUM_YEARLY: str | None = None
    STRIPE_PRICE_ID_PREMIUM_BASE_MONTHLY: str | None = None
    STRIPE_PRICE_ID_PREMIUM_BASE_YEARLY: str | None = None
    STRIPE_PRICE_ID_PREMIUM_PACK_MONTHLY: str | None = None
    STRIPE_PRICE_ID_PREMIUM_PACK_YEARLY: str | None = None
    BILLING_SUCCESS_URL: str | None = None
    BILLING_CANCEL_URL: str | None = None
    BILLING_PORTAL_RETURN_URL: str | None = None

    model_config = SettingsConfigDict(
        case_sensitive=True,
        extra="ignore",
    )


settings = Settings()


def _normalize_url(value: str | None) -> str | None:
    normalized = (value or "").strip()
    if not normalized:
        return None

    parsed = urlparse(normalized)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise RuntimeError(f"Invalid URL configured: {normalized}")
    return normalized.rstrip("/")


def _default_dev_app_base_url() -> str:
    return "http://localhost:3000"


def _resolve_base_url() -> str | None:
    base_url = _normalize_url(settings.APP_BASE_URL)
    if base_url:
        return base_url

    if (settings.ENV or "").strip().lower() != "prod":
        return _default_dev_app_base_url()

    return None


def resolve_billing_url(setting_name: str) -> str:
    explicit_mapping = {
        "BILLING_SUCCESS_URL": settings.BILLING_SUCCESS_URL,
        "BILLING_CANCEL_URL": settings.BILLING_CANCEL_URL,
        "BILLING_PORTAL_RETURN_URL": settings.BILLING_PORTAL_RETURN_URL,
    }
    fallback_paths = {
        "BILLING_SUCCESS_URL": "/billing/success?session_id={CHECKOUT_SESSION_ID}",
        "BILLING_CANCEL_URL": "/billing/cancel",
        "BILLING_PORTAL_RETURN_URL": "/billing",
    }

    if setting_name not in explicit_mapping:
        raise RuntimeError(f"Unsupported billing URL setting: {setting_name}")

    explicit_url = _normalize_url(explicit_mapping[setting_name])
    if explicit_url:
        return explicit_url

    base_url = _resolve_base_url()
    if base_url:
        return urljoin(f"{base_url}/", fallback_paths[setting_name].lstrip("/"))

    raise RuntimeError(
        f"{setting_name} is required. Set {setting_name} or APP_BASE_URL."
    )


def validate_settings() -> None:
    missing: list[str] = []

    if not settings.SECRET_KEY or not settings.SECRET_KEY.strip():
        missing.append("SECRET_KEY")

    if not settings.ADMIN_USERNAME or not settings.ADMIN_USERNAME.strip():
        missing.append("ADMIN_USERNAME")

    if not settings.ADMIN_PASSWORD or not settings.ADMIN_PASSWORD.strip():
        missing.append("ADMIN_PASSWORD")

    if not settings.DATABASE_URL or not settings.DATABASE_URL.strip():
        missing.append("DATABASE_URL")

    if missing:
        raise RuntimeError(
            f"Missing required environment variables: {', '.join(missing)}"
        )

    if settings.APP_BASE_URL:
        _normalize_url(settings.APP_BASE_URL)

    for setting_name in (
        "BILLING_SUCCESS_URL",
        "BILLING_CANCEL_URL",
        "BILLING_PORTAL_RETURN_URL",
    ):
        configured_value = getattr(settings, setting_name)
        if configured_value:
            _normalize_url(configured_value)

    insecure_secret_values = {"changeme", "change-me", "dev_only_secret_key_change_me"}
    insecure_admin_password_values = {"changeme", "changeme-now", "admin", "password"}

    if settings.ENV.lower() == "prod":
        if settings.SECRET_KEY in insecure_secret_values or len(settings.SECRET_KEY) < 32:
            raise RuntimeError(
                "SECRET_KEY is insecure for production. Use a strong random value with at least 32 characters."
            )

        if settings.ADMIN_USERNAME.strip().lower() == "admin":
            # erlaubt, aber bewusst nur als Hinweis im Code-Kommentar dokumentiert;
            # kein Runtime-Block, damit dein bestehender Admin-Zugang weiter funktioniert
            pass

        if settings.ADMIN_PASSWORD in insecure_admin_password_values or len(settings.ADMIN_PASSWORD) < 16:
            raise RuntimeError(
                "ADMIN_PASSWORD is insecure for production. Use a strong password with at least 16 characters."
            )
