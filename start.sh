
wait-for-db


alias get_maxmind_csv="curl -O -J -L --user ${MAXMIND_USERNAME}:${MAXMIND_PASSWORD} 'https://download.maxmind.com/geoip/databases/GeoLite2-City-CSV/download?suffix=zip'"

ZIP_FILE_NAME_PATTERN="/app/GeoLite2-City-CSV*.zip"
EXTRACTED_DIR="/app/GeoLite2-City-CSV"


function main() {

  # Search for any ZIP files in the /app directory
  file_count=$(find /app -maxdepth 1 -type f -name "*.zip" | wc -l)

  # Path to the file storing the last download timestamp
  timestamp_file="last_download.txt"

  # Current Unix timestamp
  current_time=$(date +%s)

  # Check if the timestamp file exists
  if [[ ! -f "$timestamp_file" || "$file_count" -eq 0 ]]; then
      echo "Timestamp file or ZIP FILE does not exist. Running the command as this seems to be the first run."
      get_maxmind_csv
      unzip_maxmind_csv
      load_maxmind_database_tables

      echo $current_time > $timestamp_file
  else
      # Read the timestamp from the file
      last_download=$(cat "$timestamp_file")

      # Calculate the difference in seconds
      let "diff = current_time - last_download"

      # 30 days in seconds
      thirty_days_seconds=$((30 * 24 * 60 * 60))

      # Check if the last download was 30 days ago or more
      if [[ $diff -ge $thirty_days_seconds ]]; then
          echo "30 days have passed since last download. Running the command."
          get_maxmind_csv
          unzip_maxmind_csv
          load_maxmind_database_tables

          # Update the timestamp in the file
          echo $current_time > $timestamp_file
      else
          echo "Less than 30 days have passed since the last download. No Maxmind update needed."
      fi
  fi

}

function unzip_maxmind_csv() {
  unzip -jo GeoLite2-City-CSV*.zip -d ${EXTRACTED_DIR}
  cd ${EXTRACTED_DIR}
}


function load_maxmind_database_tables() {

psql <<EOF
DROP TABLE IF EXISTS geoip_network;
CREATE TABLE geoip_network (
    network CIDR NOT NULL,
    geoname_id INT,
    registered_country_geoname_id INT,
    represented_country_geoname_id INT,
    is_anonymous_proxy BOOL,
    is_satellite_provider BOOL,
    postal_code TEXT,
    latitude NUMERIC,
    longitude NUMERIC,
    accuracy_radius INT,
    is_anycast BOOL
);

DROP TABLE IF EXISTS geoip_locations;

CREATE TABLE geoip_locations (
    geoname_id INT PRIMARY KEY,
    locale_code CHAR(2),
    continent_code CHAR(2),
    continent_name TEXT,
    country_iso_code CHAR(2),
    country_name TEXT,
    subdivision_1_iso_code CHAR(3),
    subdivision_1_name TEXT,
    subdivision_2_iso_code CHAR(3),
    subdivision_2_name TEXT,
    city_name TEXT,
    metro_code INT,
    time_zone TEXT,
    is_in_european_union BOOL
);

\COPY geoip_network FROM './GeoLite2-City-Blocks-IPv6.csv' DELIMITER ',' CSV HEADER;
\COPY geoip_network FROM './GeoLite2-City-Blocks-IPv4.csv' DELIMITER ',' CSV HEADER;
\COPY geoip_locations FROM './GeoLite2-City-Locations-en.csv' DELIMITER ',' CSV HEADER;

CREATE INDEX idx_network_gist ON geoip_network USING gist (network inet_ops);
CREATE INDEX idx_geoip_locations_geoname_id ON geoip_locations(geoname_id);

EOF

cd /app
rm -rf ${EXTRACTED_DIR}

}

main