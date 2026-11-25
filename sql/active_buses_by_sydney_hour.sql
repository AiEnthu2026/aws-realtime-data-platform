SELECT date_format(from_unixtime(feed_ts) AT TIME ZONE 'Australia/Sydney', '%Y-%m-%d %H:00') AS sydney_hour,
       COUNT(DISTINCT vehicle_id) AS active_vehicle_runs,
       COUNT(*) AS positions
FROM vehicle_positions
WHERE "date" IN (CAST(current_date - INTERVAL '1' DAY AS varchar), CAST(current_date AS varchar))
  AND feed_ts >= to_unixtime(current_timestamp) - 86400
GROUP BY 1
ORDER BY 1;