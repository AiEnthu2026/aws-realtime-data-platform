import pytest
from google.transit import gtfs_realtime_pb2


def make_feed_bytes():
    feed = gtfs_realtime_pb2.FeedMessage()
    feed.header.gtfs_realtime_version = "2.0"
    feed.header.timestamp = 1795561200

    entity = feed.entity.add()
    entity.id = "1"
    v = entity.vehicle
    v.vehicle.id = "v1"
    v.trip.trip_id = "t1"
    v.trip.route_id = "r1"
    v.position.latitude = -33.87
    v.position.longitude = 151.21
    v.timestamp = 1795561190

    other = feed.entity.add()
    other.id = "2"
    other.trip_update.trip.trip_id = "t2"

    return feed.SerializeToString()


def test_to_records_maps_fields_and_skips_non_vehicle(producer):
    feed_ts, records = producer.to_records(make_feed_bytes())

    assert feed_ts == 1795561200
    assert len(records) == 1
    r = records[0]
    assert (r["vehicle_id"], r["trip_id"], r["route_id"]) == ("v1", "t1", "r1")
    assert r["latitude"] == pytest.approx(-33.87, abs=1e-5)
    assert r["longitude"] == pytest.approx(151.21, abs=1e-5)
    assert r["vehicle_ts"] == 1795561190
    assert r["feed_ts"] == 1795561200

def test_put_records_retries_only_failures(producer, monkeypatch):
    responses = [
        {"FailedRecordCount": 1, "Records": [{"SequenceNumber": "1"}, {"ErrorCode": "ProvisionedThroughputExceededException"}]},
        {"FailedRecordCount": 0, "Records": [{"SequenceNumber": "2"}]},
    ]
    sent_batches = []

    def fake_put_records(StreamName, Records):
        sent_batches.append(Records)
        return responses.pop(0)

    monkeypatch.setattr(producer.kinesis, "put_records", fake_put_records)
    monkeypatch.setattr(producer.time, "sleep", lambda s: None)

    dropped = producer.put_records([{"vehicle_id": "a"}, {"vehicle_id": "b"}])

    assert dropped == 0
    assert len(sent_batches[0]) == 2
    assert len(sent_batches[1]) == 1
    assert sent_batches[1][0]["PartitionKey"] == "b"
