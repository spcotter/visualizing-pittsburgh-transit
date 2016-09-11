Allegheny County Parcels
=============
## Playing with Property Data

Data sources:
```
http://www.pasda.psu.edu/uci/SearchResults.aspx?searchType=mapservice&condition=OR&entry=PASDA&sessionID=4697542082012817175443
https://data.wprdc.org/dataset/property-assessments
http://www.portauthority.org/generaltransitfeed/GIS/
```


First, create a new Postgres Database with the template_gis template. Then, convert the shapefiles to SQL.

Bash
```bash
/Library/PostgreSQL/9.4/bin/shp2pgsql -I -s 2272 ~/Downloads/AlleghenyCounty_Parcels201602/AlleghenyCounty_Parcels201602.shp public.parcels | psql -p 5432 -d allegheny_county_parcels -U allegheny_county
```

Bash
```bash
/Library/PostgreSQL/9.4/bin/shp2pgsql -I -s 2272 ~/Downloads/PAAC_Routes_090615/PAAC_Routes_1509_Public.shp public.bus_routes | psql -p 5432 -d allegheny_county_parcels -U allegheny_county
```

Bash
```bash
/Library/PostgreSQL/9.4/bin/shp2pgsql -I -s 2272 ~/Downloads/PAAC_Stops_090615/PAAC_Stops_1509_Public.shp public.bus_stops | psql -p 5432 -d allegheny_county_parcels -U allegheny_county
```


SQL
```sql
DROP TABLE property_assessments;
CREATE TABLE property_assessments (
    parid varchar(30),
    propertyhousenum    varchar(10),
    propertyfraction    varchar(6),
    propertyaddress varchar(80),
    propertycity    varchar(50),
    propertystate   varchar(50),
    propertyunit    varchar(30),
    propertyzip varchar(10),
    municode    varchar(5),
    munidesc    varchar(50),
    schoolcode  varchar(30),
    schooldesc  varchar(50),
    legal1  varchar(60),
    legal2  varchar(60),
    legal3  varchar(60),
    neighcode   varchar(8),
    neighdesc   varchar(50),
    taxcode varchar(1),
    taxdesc varchar(50),
    taxsubcode  varchar(1),
    taxsubcode_desc varchar(50),
    ownercode   varchar(3),
    ownerdesc   varchar(50),
    class   varchar(2),
    classdesc   varchar(50),
    usecode varchar(4),
    usedesc varchar(50),
    lotarea numeric,
    homesteadflag   varchar(6),
    cleangreen  varchar(3),
    farmsteadflag   varchar(6),
    abatementflag   varchar(6),
    recorddate  varchar(10),
    saledate    varchar(10),
    saleprice   numeric,
    salecode    varchar(2),
    saledesc    varchar(50),
    deedbook    varchar(8),
    deedpage    varchar(8),
    prevsaledate    varchar(10),
    prevsaleprice   numeric,
    prevsaledate2   varchar(10),
    prevsaleprice2  numeric,
    changenoticeaddress1    varchar(100),
    changenoticeaddress2    varchar(100),
    changenoticeaddress3    varchar(100),
    changenoticeaddress4    varchar(100),
    countybuilding  numeric,
    countyland  numeric,
    countytotal numeric,
    countyexemptbldg    numeric,
    localbuilding   numeric,
    localland   numeric,
    localtotal  numeric,
    fairmarketbuilding  numeric,
    fairmarketland  numeric,
    fairmarkettotal numeric,
    style   varchar(2),
    styledesc   varchar(50),
    stories varchar(3),
    yearblt numeric,
    exteriorfinish  varchar(2),
    extfinish_desc  varchar(50),
    roof    varchar(20),
    roofdesc    varchar(50),
    basement    varchar(1),
    basementdesc    varchar(50),
    grade   varchar(3),
    gradedesc   varchar(50),
    condition   varchar(2),
    conditiondesc   varchar(50),
    cdu varchar(2),
    cdudesc varchar(50),
    totalrooms  numeric,
    bedrooms    numeric,
    fullbaths   numeric,
    halfbaths   numeric,
    heatingcooling  varchar(1),
    heatingcoolingdesc  varchar(50),
    fireplaces  numeric,
    bsmtgarage  varchar(1),
    finishedlivingarea  numeric,
    cardnumber  numeric,
    alt_id  varchar(30),
    taxyear numeric,
    asofdate    date
);
```


The property assessments file quotes everything. Run the code below to replace empty quotes (...,"",...) with nothing (...,,...).

Bash
```bash
export LANG=C
sed 's/""//g' /Users/Shared/alleghenycountymasterfile03022016.csv > /Users/Shared/alleghenycountymasterfile03022016_formatted.csv
```


The following line was an encoding problem. 

Bash
```bash
cd /Users/Shared
sed -n 79136p alleghenycountymasterfile03022016_formatted.csv
file alleghenycountymasterfile03022016_formatted.csv
```


Convert to UTF-8 encoding, skipping the problematic characters above.

Bash
```
iconv -c -f us-ascii -t utf-8 alleghenycountymasterfile03022016_formatted.csv > alleghenycountymasterfile03022016_formatted_char.csv
```


Finally load into the database.

Bash
```bash
psql -c "COPY property_assessments FROM '/Users/Shared/alleghenycountymasterfile03022016_formatted_char.csv' WITH DELIMITER ',' NULL '' CSV HEADER;" -p 5432 -d allegheny_county_parcels -U allegheny_county
```
