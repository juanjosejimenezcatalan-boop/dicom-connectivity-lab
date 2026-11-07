# Incident and recovery records

These records document integration exercises performed with synthetic data.
They complement, rather than replace, the automated checks in `scripts/`.

## Incorrect called AE Title

| Field | Record |
| --- | --- |
| Symptom | `C-ECHO` is rejected after the TCP connection is established. Orthanc B reports that the called AE Title is not recognised. |
| Root cause | The caller addresses `WRONG_AET` while B is configured with `DicomAet: ORTHANC_B` and checks called AE Titles. |
| Test | Run `./scripts/test-failure.sh`; it temporarily changes the configured destination AE Title and asserts that the echo fails. |
| Recovery | Restore `ORTHANC_B` in the modality configuration. The script's cleanup handler performs this restoration automatically. |
| Verification | Run `./scripts/run-lab.sh`; the C-ECHO and C-STORE complete and the synthetic CT study is listed on B. |

## Destination PACS unavailable

| Field | Record |
| --- | --- |
| Symptom | The echo request times out or reports connection refused; no DICOM association is accepted by B. |
| Root cause | `orthanc-b` is stopped, or its Docker-network endpoint/port is wrong. |
| Test | Stop B with `docker compose stop orthanc-b`, then run the echo request shown in the README. |
| Recovery | Start B with `docker compose start orthanc-b` and retain its Docker-network address as `orthanc-b:4242`. |
| Verification | `docker compose ps` reports B running, followed by a successful C-ECHO and C-STORE from `./scripts/run-lab.sh`. |

## Distinguishing the failures

An AE Title mismatch is a DICOM association-layer rejection: TCP connectivity
has succeeded, then the SCP rejects the called title. A network failure happens
before association negotiation, typically as a timeout or connection refusal.
The distinction directs troubleshooting either to AE configuration or to
service reachability and port mapping.
