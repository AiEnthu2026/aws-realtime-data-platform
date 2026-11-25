WITH latest AS (
  SELECT MAX(feed_ts) AS ts
  FROM vehicle_positions
  WHERE "date" = CAST(current_date AS varchar)
)
SELECT v.vehicle_id,
       v.route_id,
       ROUND(great_circle_distance(v.latitude, v.longitude, -33.8732, 151.2069) * 1000) AS metres
FROM vehicle_positions v
JOIN latest l ON v.feed_ts = l.ts
WHERE v."date" = CAST(current_date AS varchar)
  AND great_circle_distance(v.latitude, v.longitude, -33.8732, 151.2069) <= 0.5
ORDER BY metres;