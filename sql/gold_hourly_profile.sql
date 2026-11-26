SELECT sydney_date, sydney_hour, SUM(active_vehicle_runs) AS vehicle_runs, SUM(positions) AS positions
FROM vehicle_activity_hourly
GROUP BY 1, 2
ORDER BY 1, 2;