#!/usr/bin/env bash
# Download one day of air quality data for every location and load it into
# raw.downloads in a single transaction: all locations or none.
#
# Usage: scripts/load_day.sh YYYY-MM-DD

# Stop on any error (-e), on unset variables (-u) and on failures inside pipes.
set -euo pipefail

# --- Setup -------------------------------------------------------------------

# The day to load, in UTC. Fail with a usage message if it is missing.
day="${1:?usage: scripts/load_day.sh YYYY-MM-DD}"

# Run from the repository root, wherever the script is called from.
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

# Load database credentials from .env (never committed).
set -a; source .env; set +a

api="https://air-quality-api.open-meteo.com/v1/air-quality"
vars="pm10,pm2_5,nitrogen_dioxide,ozone"
out="data/$day"          # downloads for this day (ignored by Git)
sql="$out/load.sql"      # the SQL we build, then run in one go
mkdir -p "$out"

# --- 1. Extract: download every location before touching the database --------

echo "begin;" > "$sql"

# Read the locations seed, skipping its header. The "|| [[ -n $id ]]" keeps
# the last line even when the file does not end with a newline.
while IFS=, read -r id name lat lon || [[ -n "$id" ]]; do
  lon="${lon%$'\r'}"     # drop a Windows line ending, if any

  url="$api?latitude=$lat&longitude=$lon&hourly=$vars&domains=cams_europe&timezone=GMT&start_date=$day&end_date=$day&format=csv"
  file="$out/$id.csv"

  # --fail: treat HTTP errors as failures instead of saving the error page.
  curl -sS --fail --retry 3 -o "$file" "$url"

  # Minimal sanity check: the hourly data section must be there.
  grep -q '^time,' "$file" || { echo "Unexpected format: $file" >&2; exit 1; }

  # The content is quoted with $csv$ below, so it must not contain that tag.
  ! grep -q '\$csv\$' "$file" || { echo "Unsafe content: $file" >&2; exit 1; }

  # Add one insert per location. The file is stored as is (ELT: no parsing here).
  echo "insert into raw.downloads (location_id, data_date, content, _source_url)
        values ('$id', '$day', \$csv\$$(cat "$file")\$csv\$, '$url');" >> "$sql"

  echo "Downloaded $id"
done < <(tail -n +2 air_quality/seeds/locations.csv)

echo "commit;" >> "$sql"

# --- 2. Load: one transaction, all locations or none -------------------------

# ON_ERROR_STOP makes psql exit before "commit;" on any error,
# so Postgres rolls back every insert of this run.
docker compose exec -T postgres \
  psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -q < "$sql"

echo "Loaded $day"