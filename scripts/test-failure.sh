#!/usr/bin/env sh
# Demonstrates an association rejection caused by a wrong called AE Title.
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root_dir"

docker compose up -d --wait
config=orthanc-a/orthanc.json
backup=orthanc-a/orthanc.json.good
broken=orthanc-a/orthanc.json.broken
cleanup() {
  if [ -f "$backup" ]; then
    mv -f "$backup" "$config"
    rm -f "$broken"
    docker compose up -d --force-recreate orthanc-a >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

# Keep a valid JSON configuration but change only the called AET of the target.
sed 's/\["ORTHANC_B", "orthanc-b", 4242\]/["WRONG_AET", "orthanc-b", 4242]/' \
  "$config" > "$broken"

echo "Temporarily injecting a bad target AET and recreating ORTHANC_A..."
mv "$config" "$backup"
mv "$broken" "$config"
docker compose up -d --force-recreate orthanc-a >/dev/null

if curl --silent --show-error --fail -X POST http://localhost:8044/modalities/ORTHANC-B/echo >/dev/null; then
  echo "Unexpected success: the invalid AET should have been rejected." >&2
  exit 1
fi
echo "Expected failure observed: called AE Title does not match ORTHANC_B."

cleanup
trap - EXIT INT TERM
echo "Configuration restored. Verify with: ./scripts/run-lab.sh"

