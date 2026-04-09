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

    # === BILLING (STRIPE) ===
    STRIPE_SECRET_KEY: str | None = None
    STRIPE_WEBHOOK_SECRET: str | None = None
    STRIPE_PRICE_ID_PREMIUM: str | None = None
    BILLING_SUCCESS_URL: str | None = None
    BILLING_CANCEL_URL: str | None = None

    model_config = SettingsConfigDict(
        case_sensitive=True,
        extra="ignore",
    )


settings = Settings()


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
