SELECT 
    ROUND(COUNT(DISTINCT next_day.player_id) * 1.0 / COUNT(DISTINCT a.player_id), 2) AS fraction
FROM Activity a
LEFT JOIN Activity next_day
  ON a.player_id = next_day.player_id
  AND DATEDIFF(next_day.event_date, a.event_date) = 1
WHERE a.event_date = (
    SELECT MIN(event_date)
    FROM Activity a2
    WHERE a2.player_id = a.player_id
);
