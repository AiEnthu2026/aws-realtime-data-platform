import json
import os
import time

import boto3

WORKGROUP = os.environ["ATHENA_WORKGROUP"]
DATABASE = os.environ["GLUE_DATABASE"]
POLL_SECONDS = 20

athena = boto3.client("athena")

LATEST = """
WITH latest AS (
  SELECT MAX(feed_ts) AS ts FROM vehicle_positions
  WHERE "date" = CAST(current_date AS varchar)
)
"""

QUERIES = {
    "cbd": LATEST + """
SELECT COUNT(DISTINCT v.vehicle_id) AS buses_in_cbd
FROM vehicle_positions v JOIN latest l ON v.feed_ts = l.ts
WHERE v."date" = CAST(current_date AS varchar)
  AND ST_Within(ST_Point(v.longitude, v.latitude),
      ST_Polygon('polygon ((151.195 -33.880, 151.215 -33.880, 151.215 -33.855, 151.195 -33.855, 151.195 -33.880))'))
""",
    "near": LATEST + """
SELECT v.vehicle_id, v.route_id,
       ROUND(great_circle_distance(v.latitude, v.longitude, ?, ?) * 1000) AS metres
FROM vehicle_positions v JOIN latest l ON v.feed_ts = l.ts
WHERE v."date" = CAST(current_date AS varchar)
  AND great_circle_distance(v.latitude, v.longitude, ?, ?) * 1000 <= ?
ORDER BY metres
LIMIT 200
""",
}


def near_params(qs):
    try:
        lat = float(qs["lat"])
        lon = float(qs["lon"])
        radius = int(qs.get("radius_m", 500))
    except (KeyError, ValueError):
        raise ValueError("lat and lon are required numbers; radius_m must be an integer")
    if not (-34.2 <= lat <= -33.4 and 150.5 <= lon <= 151.5):
        raise ValueError("lat/lon must be inside Sydney")
    if not 50 <= radius <= 2000:
        raise ValueError("radius_m must be between 50 and 2000")
    return [str(lat), str(lon), str(lat), str(lon), str(radius)]


def run_query(sql, params=None):
    kwargs = {"QueryString": sql, "WorkGroup": WORKGROUP,
              "QueryExecutionContext": {"Database": DATABASE}}
    if params:
        kwargs["ExecutionParameters"] = params
    qid = athena.start_query_execution(**kwargs)["QueryExecutionId"]
    deadline = time.monotonic() + POLL_SECONDS
    while time.monotonic() < deadline:
        state = athena.get_query_execution(QueryExecutionId=qid)["QueryExecution"]["Status"]["State"]
        if state == "SUCCEEDED":
            return rows(qid)
        if state in ("FAILED", "CANCELLED"):
            raise RuntimeError(f"query {qid} {state}")
        time.sleep(0.5)
    athena.stop_query_execution(QueryExecutionId=qid)
    raise TimeoutError(qid)


def rows(qid):
    data = athena.get_query_results(QueryExecutionId=qid)["ResultSet"]["Rows"]
    header = [c["VarCharValue"] for c in data[0]["Data"]]
    return [dict(zip(header, [c.get("VarCharValue") for c in r["Data"]])) for r in data[1:]]


def response(status, body):
    return {"statusCode": status, "headers": {"Content-Type": "application/json"},
            "body": json.dumps(body)}


def lambda_handler(event, context):
    route = event.get("routeKey", "")
    try:
        if route == "GET /buses/cbd":
            result = run_query(QUERIES["cbd"])
            return response(200, {"buses_in_cbd": int(result[0]["buses_in_cbd"])})
        if route == "GET /buses/near":
            params = near_params(event.get("queryStringParameters") or {})
            buses = run_query(QUERIES["near"], params)
            for b in buses:
                b["metres"] = int(float(b["metres"]))
            return response(200, {"buses": buses})
        return response(404, {"error": "not found"})
    except ValueError as exc:
        return response(400, {"error": str(exc)})
    except TimeoutError:
        return response(504, {"error": "query timed out"})
    except Exception as exc:
        print(json.dumps({"error": str(exc), "route": route}))
        return response(500, {"error": "internal error"})