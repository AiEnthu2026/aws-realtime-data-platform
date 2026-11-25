SELECT COUNT(*) AS no_trip_rows,
       COUNT(*) * 100.0 / (SELECT COUNT(*) FROM vehicle_positions WHERE "date" = '2026-11-24') AS pct
FROM vehicle_positions
WHERE "date" = '2026-11-24' AND (trip_id IS NULL OR trip_id = '');