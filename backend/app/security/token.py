import hmac
import hashlib
import base64
import json
from datetime import datetime, timedelta, timezone
from jose import jwt
from app.core.settings import settings

ALGORITHM = "HS256"


def create_token(data: dict):
    to_encode = data.copy()

    expire = datetime.utcnow() + timedelta(minutes=settings.TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})

    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


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