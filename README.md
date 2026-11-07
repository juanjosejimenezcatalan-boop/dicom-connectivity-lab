# DICOM Connectivity & Routing Lab

A local, reproducible lab for practicing DICOM integration between two Orthanc
instances: a simulated modality (`ORTHANC_A`) and a destination PACS
(`ORTHANC_B`). It uses no clinical data: it creates a synthetic CT instance.

```
ORTHANC_A (SCU / modality) -- C-ECHO, C-STORE --> ORTHANC_B (SCP / PACS)
        :4242                                      :4242
 localhost:8044                                  localhost:8045
```

## Topology

| Node | AE Title | Internal DICOM port | Published port | Role |
| --- | --- | ---: | ---: | --- |
| A | `ORTHANC_A` | `4242` | `4244` | Simulated modality / SCU |
| B | `ORTHANC_B` | `4242` | `4245` | Destination PACS / SCP |

Both nodes know each other through `DicomModalities`. On the Docker network, A
reaches B as `orthanc-b:4242`; `4245` is only for connections from the host.

## Requirements

- Docker Desktop with Compose v2
- `curl`, `sed`, and `grep`

## Run the happy path

```sh
cd dicom-connectivity-lab
chmod +x scripts/*.sh
./scripts/run-lab.sh
```

The script starts both services, runs a **C-ECHO** from A, creates a synthetic
one-instance CT series (`Modality=CT`, CT Image Storage SOP Class), sends it
using **C-STORE**, and finds the study on B. Open the destination PACS at
<http://localhost:8045/app/explorer.html> to confirm it visually.

You can also inspect the resources through the API:

```sh
curl http://localhost:8045/studies
curl http://localhost:8045/system
```

## Reproducible failure: incorrect destination AE Title

```sh
./scripts/test-failure.sh
```

This exercise temporarily replaces B's called AET with `WRONG_AET`. C-ECHO must
fail because B has `DicomCheckCalledAet: true`. The script restores the
configuration even if it is interrupted.

### Quick diagnosis

| Symptom | Check | Fix |
| --- | --- | --- |
| `C-ECHO` rejected | Check `orthanc-b` logs; compare the called AET with `DicomAet` | Use `ORTHANC_B` in A's modality configuration |
| Timeout / connection refused | Run `docker compose ps`; test `orthanc-b:4242` from the Docker network | Start B and use its internal port 4242, not published port 4245 |
| C-STORE fails after C-ECHO | Run `docker compose logs orthanc-a orthanc-b` | Review presentation context/SOP Class and storage permissions |
| Study does not appear on B | Run `curl http://localhost:8045/studies` | Confirm that POST to `/modalities/ORTHANC-B/store` completed successfully |

To simulate a destination that is down:

```sh
docker compose stop orthanc-b
curl --fail -X POST http://localhost:8044/modalities/ORTHANC-B/echo
docker compose start orthanc-b
```

To view logs while running any test:

```sh
docker compose logs -f orthanc-a orthanc-b
```

## Clean up

```sh
docker compose down
# Also remove persisted synthetic studies:
rm -rf orthanc-a/data orthanc-b/data
```

## Background

In DICOM, each server is defined by its host, TCP port, and AE Title. C-ECHO
checks the end-to-end DICOM association; C-STORE sends instances. Orthanc can
operate as both SCU and SCP. See the [Orthanc connectivity guide](https://orthanc.uclouvain.be/book/integrations/modality.html)
and [DICOM guide](https://orthanc.uclouvain.be/book/dicom-guide.html).

