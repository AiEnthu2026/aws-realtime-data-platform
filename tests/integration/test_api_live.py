import base64
import json
import os
import urllib.error
import urllib.parse
import urllib.request

import pytest

pytestmark = pytest.mark.integration

API_URL = os.environ.get("API_URL")
TOKEN_URL = os.environ.get("TOKEN_URL")
CLIENT_ID = os.environ.get("CLIENT_ID")
CLIENT_SECRET = os.environ.get("CLIENT_SECRET")

if not all([API_URL, TOKEN_URL, CLIENT_ID, CLIENT_SECRET]):
    pytest.skip("live API environment variables not set", allow_module_level=True)


def get_token():
    creds = base64.b64encode(f"{CLIENT_ID}:{CLIENT_SECRET}".encode()).decode()
    data = urllib.parse.urlencode({"grant_type": "client_credentials", "scope": "rtdp-api/read"}).encode()
    req = urllib.request.Request(TOKEN_URL, data=data, headers={
        "Authorization": f"Basic {creds}",
        "Content-Type": "application/x-www-form-urlencoded",
    })
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return json.loads(r.read())["access_token"]
    except urllib.error.HTTPError as e:
        pytest.fail(f"token request failed: {e.code} {e.read().decode()}")


def call(path, token=None):
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    req = urllib.request.Request(f"{API_URL}{path}", headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


@pytest.fixture(scope="module")
def token():
    return get_token()


def test_no_token_is_401():
    status, _ = call("/buses/cbd")
    assert status == 401


def test_cbd_with_token_is_200(token):
    status, body = call("/buses/cbd", token)
    assert status == 200
    assert isinstance(body["buses_in_cbd"], int)


def test_outside_sydney_is_400(token):
    status, body = call("/buses/near?lat=0&lon=151.2&radius_m=300", token)
    assert status == 400
    assert "Sydney" in body["error"]