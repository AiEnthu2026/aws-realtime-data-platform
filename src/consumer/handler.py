import base64
import json
import os
import uuid
from collections import defaultdict
from datetime import datetime, timezone

import boto3
import pyarrow as pa
import pyarrow.parquet as pq

CURATED_BUCKET = os.environ["CURATED_BUCKET"]
s3 = boto3.client("s3")

SCHEMA = pa.schema([
    ("vehicle_id", pa.string()),
    ("trip_id", pa.string()),
    ("route_id", pa.string()),
    ("latitude", pa.float64()),
    ("longitude", pa.float64()),
    ("bearing", pa.float32()),
    ("speed", pa.float32()),
    ("vehicle_ts", pa.int64()),
    ("feed_ts", pa.int64()),
])


def parse(record):
    return json.loads(base64.b64decode(record["kinesis"]["data"]))


def partition_of(row):
    dt = datetime.fromtimestamp(row["feed_ts"], tz=timezone.utc)
    return f"date={dt:%Y-%m-%d}/hour={dt:%H}"


def write_partition(partition, rows):
    table = pa.Table.from_pylist(rows, schema=SCHEMA)
    sink = pa.BufferOutputStream()
    pq.write_table(table, sink, compression="snappy")
    key = f"vehicle_positions/{partition}/{uuid.uuid4()}.parquet"
    s3.put_object(Bucket=CURATED_BUCKET, Key=key, Body=sink.getvalue().to_pybytes())


def lambda_handler(event, context):
    failures = []
    rows_by_partition = defaultdict(list)
    seqs_by_partition = defaultdict(list)

    for record in event["Records"]:
        seq = record["kinesis"]["sequenceNumber"]
        try:
            row = parse(record)
            partition = partition_of(row)
            rows_by_partition[partition].append(row)
            seqs_by_partition[partition].append(seq)
        except Exception as exc:
            print(json.dumps({"bad_record": seq, "error": str(exc)}))
            failures.append(seq)

    for partition, rows in rows_by_partition.items():
        try:
            write_partition(partition, rows)
        except Exception as exc:
            print(json.dumps({"partition": partition, "error": str(exc)}))
            failures.extend(seqs_by_partition[partition])

    print(json.dumps({
        "records": len(event["Records"]),
        "partitions": len(rows_by_partition),
        "failed": len(failures),
    }))
    return {"batchItemFailures": [{"itemIdentifier": s} for s in failures]}