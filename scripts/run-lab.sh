#!/usr/bin/env sh
# Runs the full happy-path exercise using Orthanc's REST API.
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root_dir"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }; }
need curl
need docker

docker compose up -d --wait

api_a=http://localhost:8044
api_b=http://localhost:8045

echo "1/4 C-ECHO: ORTHANC_A -> ORTHANC_B"
curl --fail --silent --show-error -X POST "$api_a/modalities/ORTHANC-B/echo" >/dev/null
echo "    Association accepted."

echo "2/4 Creating a synthetic CT instance on ORTHANC_A"
instance_id=$(curl --fail --silent --show-error \
  -H 'Content-Type: application/json' \
  -X POST "$api_a/tools/create-dicom" \
  -d '{
    "Tags": {
      "PatientName": "CONNECTIVITY^TEST",
      "PatientID": "DICOM-LAB-001",
      "StudyDescription": "DICOM Connectivity Lab",
      "SeriesDescription": "Synthetic CT series",
      "Modality": "CT",
      "SOPClassUID": "1.2.840.10008.5.1.4.1.1.2"
    }
  }' | sed -n 's/.*"ID"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
[ -n "$instance_id" ] || { echo "Orthanc did not return an instance ID" >&2; exit 1; }

echo "3/4 C-STORE instance $instance_id: ORTHANC_A -> ORTHANC_B"
curl --fail --silent --show-error \
  -H 'Content-Type: application/json' \
  -X POST "$api_a/modalities/ORTHANC-B/store" \
  -d "[\"$instance_id\"]" >/dev/null

echo "4/4 Confirming the patient/study was received by ORTHANC_B"
received=$(curl --fail --silent --show-error \
  -H 'Content-Type: application/json' \
  -X POST "$api_b/tools/find" \
  -d '{"Level":"Study","Expand":true,"Query":{"PatientID":"DICOM-LAB-001"}}')
printf '%s\n' "$received" | grep -q 'DICOM-LAB-001' || {
  echo "Study was not found on ORTHANC_B" >&2
  exit 1
}
echo "    Success. Browse http://localhost:8045/app/explorer.html"

