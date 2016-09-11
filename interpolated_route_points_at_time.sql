SELECT
  trip_id,
  route_id,
  ST_X(geom) as lon,
  ST_Y(geom) as lat
FROM
(SELECT
  trip_id,
  route_id,
  departure_time,
  arrival_time,
  (arrival_time - departure_time) interval_length,
  ST_Line_Interpolate_Point(
    ST_Line_Substring(geom, LEAST(start_percent, end_percent), GREATEST( start_percent, end_percent) ),
    EXTRACT( epoch FROM (time '09:01' - departure_time)) / EXTRACT( epoch from(arrival_time - departure_time))
  ) as geom
FROM
(SELECT
  gtfs_trips.route_id,
  current_stops.trip_id,
  current_stops.departure_time,
  next_stops.arrival_time,
  ST_Line_Locate_Point( gtfs_shape_lines.geom, ST_ClosestPoint(gtfs_shape_lines.geom, current_stops.geom)) start_percent,
  ST_Line_Locate_Point( gtfs_shape_lines.geom, ST_ClosestPoint(gtfs_shape_lines.geom, next_stops.geom)) as end_percent,
  gtfs_shape_lines.geom
FROM
  gtfs_shape_lines,
  gtfs_trips,
  (SELECT DISTINCT ON (trip_id)
    gtfs_stop_times.trip_id, gtfs_stop_times.departure_time, gtfs_stops.geom
  FROM
    gtfs_stop_times,
    gtfs_stops,
    (SELECT
      trip_id
    FROM
      gtfs_trips t
    WHERE
      t.start_time <= time '09:01' AND
      t.end_time >= time '09:01'
    ) AS active_trips
  WHERE
    gtfs_stop_times.trip_id = active_trips.trip_id AND
    gtfs_stop_times.stop_id = gtfs_stops.stop_id AND
    gtfs_stop_times.departure_time <= time '09:01'
  ORDER BY
    trip_id, stop_sequence DESC
  ) as current_stops,
   (SELECT DISTINCT ON (trip_id)
    gtfs_stop_times.trip_id, gtfs_stop_times.arrival_time, gtfs_stops.geom
  FROM
    gtfs_stop_times,
    gtfs_stops,
    (SELECT
      trip_id
    FROM
      gtfs_trips t
    WHERE
      t.start_time <= time '09:01' AND
      t.end_time >= time '09:01'
    ) AS active_trips
  WHERE
    gtfs_stop_times.trip_id = active_trips.trip_id AND
    gtfs_stop_times.stop_id = gtfs_stops.stop_id AND
    gtfs_stop_times.departure_time >= time '09:01'
  ORDER BY
    trip_id, stop_sequence ASC
  ) as next_stops
WHERE
  gtfs_shape_lines.shape_id = gtfs_trips.shape_id AND
  gtfs_trips.trip_id = current_stops.trip_id AND
  gtfs_trips.trip_id = next_stops.trip_id AND
  departure_time != time '09:01' AND
  gtfs_trips.service_id IN ('1511-Collier-Weekday-24','1511-Liberty-Weekday-22','1511-Mifflin-Weekday-26','1511-Ross-Weekday-22','1511-Village-Weekday-22')
) AS stop_percents
WHERE
  departure_time != time '09:01'
) AS t2;