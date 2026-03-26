import hmac
import hashlib
import base64
import json
from datetime import datetime, timedelta, timezone

SECRET_KEY = "SUPER_SECRET_CHANGE_ME"


def create_token(payload: dict, expires_minutes: int = 5) -> str:
    data = payload.copy()
    data["exp"] = (
        datetime.now(timezone.utc) + timedelta(minutes=expires_minutes)
    ).timestamp()

    json_data = json.dumps(data, separators=(",", ":")).encode()
    signature = hmac.new(
        SECRET_KEY.encode(),
        json_data,
        hashlib.sha256
    ).digest()

    token = base64.urlsafe_b64encode(json_data + b"." + signature).decode()
    return token


def verify_token(token: str) -> dict | None:
    try:
        raw = base64.urlsafe_b64decode(token.encode())
        json_part, signature = raw.rsplit(b".", 1)

        expected_sig = hmac.new(
            SECRET_KEY.encode(),
            json_part,
            hashlib.sha256
        ).digest()

        if not hmac.compare_digest(signature, expected_sig):
            return None

        data = json.loads(json_part.decode())

        if datetime.now(timezone.utc).timestamp() > data["exp"]:
            return None

        return data

    except Exception:
        return None