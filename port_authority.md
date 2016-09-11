All the Buses
=============
## Pittsburgh Transit Data Visualization

SQL for the GTFS data:

```sql

DROP TABLE IF EXISTS gtfs_agency;

CREATE TABLE gtfs_agency (
	agency_id varchar(4),
	agency_name varchar(50),
	agency_url text,
	agency_timezone varchar(50),
	agency_lang varchar(2),
	agency_phone varchar(12),
	agency_fare_url text
);


DROP TABLE IF EXISTS gtfs_calendar;

CREATE TABLE gtfs_calendar (
	service_id varchar(50),
	monday boolean,
	tuesday boolean,
	wednesday boolean,
	thursday boolean,
	friday boolean,
	saturday boolean,
	sunday boolean,
	start_date date,
	end_date date
);


DROP TABLE IF EXISTS gtfs_calendar_dates;

CREATE TABLE gtfs_calendar_dates (
	service_id varchar(50),
	calendar_date date,
	exception integer
);


DROP TABLE IF EXISTS gtfs_routes;

CREATE TABLE gtfs_routes (
	route_id varchar(10),
	agency_id varchar(4),
	route_short_name varchar(5),
	route_long_name varchar(50),
	route_desc text,
	route_type integer,
	route_url text
);


DROP TABLE IF EXISTS gtfs_shapes;

CREATE TABLE gtfs_shapes (
	shape_id char(8),
	shape_pt_lat numeric,
	shape_pt_lon numeric,
	shape_pt_sequence integer
);


DROP TABLE IF EXISTS gtfs_stop_times;

CREATE TABLE gtfs_stop_times (
	trip_id varchar(20),
	arrival_time time,
	departure_time time,
	stop_id char(6),
	stop_sequence integer,
	pickup_type integer,
	drop_off_type integer
);


DROP TABLE IF EXISTS gtfs_stops;

CREATE TABLE gtfs_stops (
	stop_id char(6),
	stop_code integer,
	stop_name text,
	stop_desc text,
	stop_lat numeric, 
	stop_lon numeric,
	zone_id varchar(2)
);


DROP TABLE IF EXISTS gtfs_transfers;

CREATE TABLE gtfs_transfers (
	from_stop_id char(6),
	to_stop_id char(6),
	transfer_type integer
);


DROP TABLE IF EXISTS gtfs_trips;

CREATE TABLE gtfs_trips (
	route_id varchar(10),
	service_id varchar(50),
	trip_id varchar(20),
	trip_headsign text,
	direction_id integer,
	block_id varchar(12),
	shape_id char(8)
);
```

Replace times outside of the actual timeperiod in bash.

Bash
```ruby
ruby -pi.bak -e "gsub(/24:(\d{2}):(\d{2})/, '00:\1:\2')" stop_times.txt
ruby -pi.bak -e "gsub(/25:(\d{2}):(\d{2})/, '01:\1:\2')" stop_times.txt
ruby -pi.bak -e "gsub(/26:(\d{2}):(\d{2})/, '02:\1:\2')" stop_times.txt
```

Load the data into PostgreSQL.

Bash
```bash
cd /Users/Shared/general_transit_bing
psql -c "COPY gtfs_agency FROM '/Users/Shared/agency.txt' WITH DELIMITER ',' NULL '' CSV HEADER;" -p 5432 -d port_authority -U port_authority
psql -c "COPY gtfs_calendar FROM '/Users/Shared/calendar.txt' WITH DELIMITER ',' NULL '' CSV HEADER;" -p 5432 -d port_authority -U port_authority
psql -c "COPY gtfs_calendar_dates FROM '/Users/Shared/calendar_dates.txt' WITH DELIMITER ',' NULL '' CSV HEADER;" -p 5432 -d port_authority -U port_authority
psql -c "COPY gtfs_routes FROM '/Users/Shared/routes.txt' WITH DELIMITER ',' NULL '' CSV HEADER;" -p 5432 -d port_authority -U port_authority
psql -c "COPY gtfs_shapes FROM '/Users/Shared/shapes.txt' WITH DELIMITER ',' NULL '' CSV HEADER;" -p 5432 -d port_authority -U port_authority
psql -c "COPY gtfs_stop_times FROM '/Users/Shared/stop_times.txt' WITH DELIMITER ',' NULL '' CSV HEADER;" -p 5432 -d port_authority -U port_authority
psql -c "COPY gtfs_stops FROM '/Users/Shared/stops.txt' WITH DELIMITER ',' NULL '' CSV HEADER;" -p 5432 -d port_authority -U port_authority
psql -c "COPY gtfs_transfers FROM '/Users/Shared/transfers.txt' WITH DELIMITER ',' NULL '' CSV HEADER;" -p 5432 -d port_authority -U port_authority
psql -c "COPY gtfs_trips FROM '/Users/Shared/trips.txt' WITH DELIMITER ',' NULL '' CSV HEADER;" -p 5432 -d port_authority -U port_authority
```


Set the start and end time of each trip.

SQL
```sql
ALTER TABLE gtfs_trips ADD start_time time;
ALTER TABLE gtfs_trips ADD end_time time;
```


```sql
UPDATE gtfs_trips AS t1
SET start_time = t2.start_time
FROM (
	SELECT trip_id, arrival_time as start_time
	FROM gtfs_stop_times
	WHERE stop_sequence = 1
) AS t2
WHERE t1.trip_id = t2.trip_id;
```


```sql
UPDATE gtfs_trips AS t1
SET end_time = t2.end_time
FROM (
	SELECT m.trip_id, m.arrival_time as end_time
	FROM (
	    SELECT trip_id, MAX(stop_sequence) AS stop_sequence_max
	    FROM gtfs_stop_times
	    GROUP BY trip_id
	) t JOIN gtfs_stop_times m ON m.trip_id = t.trip_id AND t.stop_sequence_max = m.stop_sequence
) AS t2
WHERE t1.trip_id = t2.trip_id;
```


Example query to get active trips.


```sql
SELECT *
FROM gtfs_stop_times
WHERE trip_id IN (
	SELECT trip_id
	FROM gtfs_trips t
	WHERE 
	  t.start_time <= CURRENT_TIME AND 
	  t.end_time >= CURRENT_TIME
) AND
departure_time <= CURRENT_TIME;
```


Add PostGIS to our database.


```sql
CREATE EXTENSION postgis;
ALTER TABLE gtfs_shapes ADD COLUMN geom geometry(POINT,4326);
UPDATE gtfs_shapes SET geom = ST_SetSRID( ST_MakePoint(shape_pt_lon, shape_pt_lat), 4326);
ALTER TABLE gtfs_stops ADD COLUMN geom geometry(POINT,4326);
UPDATE gtfs_stops SET geom = ST_SetSRID( ST_MakePoint(stop_lon, stop_lat), 4326);

```


Create a new lines table for each of the shapes.


```sql
DROP TABLE IF EXISTS gtfs_shape_lines;
CREATE TABLE gtfs_shape_lines (
	route_id varchar(10),
	shape_id char(8),
	geom geometry(LINESTRING,4326)
);

INSERT INTO gtfs_shape_lines
SELECT DISTINCT t.route_id, s.shape_id, s.geom
FROM gtfs_trips AS t, 
(SELECT 
shape_id, ST_MakeLine(geom ORDER BY shape_pt_sequence) AS geom
FROM gtfs_shapes
GROUP BY shape_id
) AS s
WHERE s.shape_id = t.shape_id;
```


Export the route lines to geojson for the web app.


Bash
```bash
ogr2ogr -f GeoJSON out.json "PG:host=localhost dbname=port_authority user=port_authority password=port_authority" -sql 'select shape_id, geom from gtfs_shape_lines;'
```


Ruby code to get the current latitude and longitude for active trips at a given time. For trips that are at a stop, it returns the stop position. For trips that are between stops, it interpolates the position along the route path linearly. So if the last observed stop was at 08:58 and the next stop is at 09:02, at 09:00 you're halfway along the route to the next stop. This takes a while.


Ruby
```ruby
require 'pg'
require 'json'

exact_routes_sql = "SELECT trip_id, route_id, ST_X(geom) as lon, ST_Y(geom) as lat FROM ( SELECT gtfs_trips.route_id, current_stops.trip_id, ST_ClosestPoint(gtfs_shape_lines.geom, current_stops.geom) as geom FROM gtfs_shape_lines, gtfs_trips, ( SELECT DISTINCT ON (trip_id) gtfs_stop_times.trip_id, gtfs_stops.geom FROM gtfs_stop_times, gtfs_stops, (SELECT trip_id FROM gtfs_trips t WHERE t.start_time <= time '09:00' AND t.end_time >= time '09:00' ) AS active_trips WHERE gtfs_stop_times.trip_id = active_trips.trip_id AND gtfs_stop_times.stop_id = gtfs_stops.stop_id AND gtfs_stop_times.departure_time = time '09:00' ORDER BY trip_id, stop_sequence DESC ) AS current_stops WHERE gtfs_shape_lines.shape_id = gtfs_trips.shape_id AND gtfs_trips.trip_id = current_stops.trip_id AND gtfs_trips.service_id IN ('1511-Collier-Weekday-24','1511-Liberty-Weekday-22','1511-Mifflin-Weekday-26','1511-Ross-Weekday-22','1511-Village-Weekday-22')) AS t2;"

interpolated_routes_sql = "SELECT trip_id, route_id, ST_X(geom) as lon, ST_Y(geom) as lat FROM (SELECT trip_id, route_id, departure_time, arrival_time, (arrival_time - departure_time) interval_length, ST_Line_Interpolate_Point( ST_Line_Substring(geom, LEAST(start_percent, end_percent), GREATEST( start_percent, end_percent) ), EXTRACT( epoch FROM (time '09:00' - departure_time)) / EXTRACT( epoch from(arrival_time - departure_time)) ) as geom FROM (SELECT gtfs_trips.route_id, current_stops.trip_id, current_stops.departure_time, next_stops.arrival_time, ST_Line_Locate_Point( gtfs_shape_lines.geom, ST_ClosestPoint(gtfs_shape_lines.geom, current_stops.geom)) start_percent, ST_Line_Locate_Point( gtfs_shape_lines.geom, ST_ClosestPoint(gtfs_shape_lines.geom, next_stops.geom)) as end_percent, gtfs_shape_lines.geom FROM gtfs_shape_lines, gtfs_trips, (SELECT DISTINCT ON (trip_id) gtfs_stop_times.trip_id, gtfs_stop_times.departure_time, gtfs_stops.geom FROM gtfs_stop_times, gtfs_stops, (SELECT trip_id FROM gtfs_trips t WHERE t.start_time <= time '09:00' AND t.end_time >= time '09:00' ) AS active_trips WHERE gtfs_stop_times.trip_id = active_trips.trip_id AND gtfs_stop_times.stop_id = gtfs_stops.stop_id AND gtfs_stop_times.departure_time <= time '09:00' ORDER BY trip_id, stop_sequence DESC ) as current_stops, (SELECT DISTINCT ON (trip_id) gtfs_stop_times.trip_id, gtfs_stop_times.arrival_time, gtfs_stops.geom FROM gtfs_stop_times, gtfs_stops, (SELECT trip_id FROM gtfs_trips t WHERE t.start_time <= time '09:00' AND t.end_time >= time '09:00' ) AS active_trips WHERE gtfs_stop_times.trip_id = active_trips.trip_id AND gtfs_stop_times.stop_id = gtfs_stops.stop_id AND gtfs_stop_times.departure_time >= time '09:00' ORDER BY trip_id, stop_sequence ASC ) as next_stops WHERE gtfs_shape_lines.shape_id = gtfs_trips.shape_id AND gtfs_trips.trip_id = current_stops.trip_id AND gtfs_trips.trip_id = next_stops.trip_id AND departure_time != time '09:00' AND gtfs_trips.service_id IN ('1511-Collier-Weekday-24','1511-Liberty-Weekday-22','1511-Mifflin-Weekday-26','1511-Ross-Weekday-22','1511-Village-Weekday-22') ) AS stop_percents WHERE departure_time != time '09:00' ) AS t2;"

conn = PGconn.open( dbname: 'port_authority', user: 'port_authority', password: 'port_authority')

positions = []

0.upto(23) do |i|
  h = (i + 3) % 24
  0.upto(59) do |m|
    t = "#{ h.to_s.rjust(2, '0') }:#{ m.to_s.rjust(2, '0') }"

    puts t

    p = conn.exec(exact_routes_sql.gsub('09:00',t)).values
    p += conn.exec(interpolated_routes_sql.gsub('09:00',t)).values

    positions << p
    
  end
end

positions.map! do |p|
  t = {}
  p.each do |trip|
    t[ "#{ trip[0] }.#{ trip[1][0] }" ] = [ trip[3].to_f, trip[2].to_f ]
  end
  t
end

File.open('/Users/Shared/positions.json','wb') do |f|
  f.write( { start_time: 180, positions: positions } .to_json)
end

```

