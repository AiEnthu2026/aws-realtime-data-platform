import importlib.util
import os
import pathlib

import pytest

os.environ.setdefault("AWS_DEFAULT_REGION", "ap-southeast-2")
os.environ.setdefault("CURATED_BUCKET", "test-curated")
os.environ.setdefault("FEED_URL", "https://example.test/feed")
os.environ.setdefault("STREAM_NAME", "test-stream")
os.environ.setdefault("RAW_BUCKET", "test-raw")
os.environ.setdefault("API_KEY_PARAM", "/test/api-key")

ROOT = pathlib.Path(__file__).resolve().parents[1]


def load(name, rel_path):
    spec = importlib.util.spec_from_file_location(name, ROOT / rel_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@pytest.fixture
def consumer():
    return load("consumer_handler", "src/consumer/handler.py")

@pytest.fixture
def producer():
    return load("producer_handler", "src/producer/handler.py")