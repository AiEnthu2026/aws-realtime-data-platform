import base64
import json

ROW = {
    "vehicle_id": "v1", "trip_id": "t1", "route_id": "r1",
    "latitude": -33.87, "longitude": 151.21,
    "bearing": 90.0, "speed": 5.0,
    "vehicle_ts": 1795561200, "feed_ts": 1795561200,
}


def kinesis_record(payload, seq):
    data = payload if isinstance(payload, bytes) else json.dumps(payload).encode()
    return {"kinesis": {"data": base64.b64encode(data).decode(), "sequenceNumber": seq}}


def test_parse_roundtrip(consumer):
    assert consumer.parse(kinesis_record(ROW, "1")) == ROW


def test_partition_is_utc(consumer):
    assert consumer.partition_of(ROW) == "date=2026-11-24/hour=23"


def test_bad_record_reported_good_record_written(consumer, monkeypatch):
    calls = []
    monkeypatch.setattr(consumer.s3, "put_object", lambda **kw: calls.append(kw))
    event = {"Records": [kinesis_record(ROW, "100"), kinesis_record(b"this is not json", "101")]}

    result = consumer.lambda_handler(event, None)

    assert result == {"batchItemFailures": [{"itemIdentifier": "101"}]}
    assert len(calls) == 1
    assert calls[0]["Key"].startswith("vehicle_positions/date=2026-11-24/hour=23/")