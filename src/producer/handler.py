import json
import os
import time
import urllib.request
from datetime import datetime, timezone

import boto3
from google.transit import gtfs_realtime_pb2

FEED_URL = os.environ["FEED_URL"]
STREAM_NAME = os.environ["STREAM_NAME"]
RAW_BUCKET = os.environ["RAW_BUCKET"]
API_KEY_PARAM = os.environ["API_KEY_PARAM"]
POLL_INTERVAL_SECONDS = int(os.environ.get("POLL_INTERVAL_SECONDS", "15"))
POLLS_PER_RUN = int(os.environ.get("POLLS_PER_RUN", "4"))

ssm = boto3.client("ssm")
kinesis = boto3.client("kinesis")
s3 = boto3.client("s3")

API_KEY = ssm.get_parameter(Name=API_KEY_PARAM, WithDecryption=True)["Parameter"]["Value"]
last_feed_ts = 0


def fetch_feed():
    request = urllib.request.Request(FEED_URL, headers={"Authorization": f"apikey {API_KEY}"})
    with urllib.request.urlopen(request, timeout=10) as response:
        return response.read()


def to_records(feed_bytes):
    feed = gtfs_realtime_pb2.FeedMessage()
    feed.ParseFromString(feed_bytes)
    feed_ts = feed.header.timestamp
    records = []
    for entity in feed.entity:
        if not entity.HasField("vehicle"):
            continue
        v = entity.vehicle
        records.append({
            "vehicle_id": v.vehicle.id,
            "trip_id": v.trip.trip_id,
            "route_id": v.trip.route_id,
            "latitude": v.position.latitude,
            "longitude": v.position.longitude,
            "bearing": v.position.bearing,
            "speed": v.position.speed,
            "vehicle_ts": v.timestamp,
            "feed_ts": feed_ts,
        })
    return feed_ts, records


def save_raw(feed_bytes, feed_ts):
    dt = datetime.fromtimestamp(feed_ts, tz=timezone.utc)
    key = f"vehicle_positions/date={dt:%Y-%m-%d}/hour={dt:%H}/{feed_ts}.pb"
    s3.put_object(Bucket=RAW_BUCKET, Key=key, Body=feed_bytes)


def put_records(records):
    pending = [
        {"Data": json.dumps(r).encode("utf-8"), "PartitionKey": r["vehicle_id"] or "unknown"}
        for r in records
    ]
    for attempt in range(3):
        failed = []
        for i in range(0, len(pending), 500):
            batch = pending[i:i + 500]
            response = kinesis.put_records(StreamName=STREAM_NAME, Records=batch)
            if response["FailedRecordCount"]:
                failed.extend(rec for rec, res in zip(batch, response["Records"]) if "ErrorCode" in res)
        if not failed:
            return 0
        pending = failed
        time.sleep(0.2 * 2 ** attempt)
    return len(pending)


def lambda_handler(event, context):
    global last_feed_ts
    stats = {"polls": 0, "skipped": 0, "sent": 0, "dropped": 0, "errors": 0}
    for poll in range(POLLS_PER_RUN):
        started = time.monotonic()
        try:
            feed_bytes = fetch_feed()
            feed_ts, records = to_records(feed_bytes)
            stats["polls"] += 1
            if feed_ts == last_feed_ts:
                stats["skipped"] += 1
            else:
                save_raw(feed_bytes, feed_ts)
                stats["dropped"] += put_records(records)
                stats["sent"] += len(records)
                last_feed_ts = feed_ts
        except Exception as exc:
            stats["errors"] += 1
            print(json.dumps({"poll": poll, "error": str(exc)}))
        if poll < POLLS_PER_RUN - 1:
            wait = POLL_INTERVAL_SECONDS - (time.monotonic() - started)
            if wait > 0 and context.get_remaining_time_in_millis() > (wait + 15) * 1000:
                time.sleep(wait)
    print(json.dumps(stats))
    return stats