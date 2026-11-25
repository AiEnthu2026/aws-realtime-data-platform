WITH latest AS (
  SELECT MAX(feed_ts) AS ts
  FROM vehicle_positions
  WHERE "date" = CAST(current_date AS varchar)
)
SELECT COUNT(DISTINCT v.vehicle_id) AS buses_in_cbd_now
FROM vehicle_positions v
JOIN latest l ON v.feed_ts = l.ts
WHERE v."date" = CAST(current_date AS varchar)
  AND ST_Within(
        ST_Point(v.longitude, v.latitude),
        ST_Polygon('polygon ((151.195 -33.880, 151.215 -33.880, 151.215 -33.855, 151.195 -33.855, 151.195 -33.880))')
      );