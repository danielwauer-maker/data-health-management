import base64
import hashlib
import hmac
import os

DEFAULT_ITERATIONS = 210_000
SCHEME = "pbkdf2_sha256"


def hash_api_token(token: str, *, iterations: int = DEFAULT_ITERATIONS) -> str:
    if not token or not token.strip():
        raise ValueError("API token must not be empty.")

    salt = os.urandom(16)
    digest = hashlib.pbkdf2_hmac("sha256", token.encode("utf-8"), salt, iterations)
    salt_b64 = base64.b64encode(salt).decode("ascii")
    digest_b64 = base64.b64encode(digest).decode("ascii")
    return f"{SCHEME}${iterations}${salt_b64}${digest_b64}"


def verify_api_token(token: str, stored_hash: str | None) -> bool:
    if not token or not stored_hash:
        return False

    parts = stored_hash.split("$")
    if len(parts) != 4:
        return False

    scheme, iteration_text, salt_b64, digest_b64 = parts
    if scheme != SCHEME:
        return False

    try:
        iterations = int(iteration_text)
        salt = base64.b64decode(salt_b64.encode("ascii"), validate=True)
        expected_digest = base64.b64decode(digest_b64.encode("ascii"), validate=True)
    except (ValueError, TypeError):
        return False

    calculated_digest = hashlib.pbkdf2_hmac(
        "sha256",
        token.encode("utf-8"),
        salt,
        iterations,
    )
    return hmac.compare_digest(expected_digest, calculated_digest)
