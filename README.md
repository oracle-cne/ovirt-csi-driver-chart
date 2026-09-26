# oVirt CSI Driver Helm Chart

This repository contains the Helm chart for deploying the oVirt CSI Driver.

## Installation

The chart can be installed via the [Oracle Cloud Native Environment Application Catalog](https://github.com/oracle-cne/catalog), the [Oracle CNE CLI](https://github.com/oracle-cne/ocne), or via [Helm](https://helm.sh/docs/helm/helm_install/).


Install with default values:

```bash
ocne application install \
  --name ovirt-csi-driver \
  --release ovirt-csi-drvier \
  --namespace kube-system
```

Install with a custom values file:

```bash
ocne application install \
  --name ovirt-csi-driver \
  --release ovirt-csi-driver \
  --namespace kube-system \
  -f values.override.yaml
```

Via Helm:

```bash
helm install ovirt-csi-driver ./chart \
  --namespace kube-system \
  --create-namespace \
  --wait --timeout 5m
```

## Health Probes

In most cases, a CSI driver uses an controller health check as a liveness probe.
That is the default behavior of this chart.  If there is a need to separate the
liveness and readiness probes, a configuration option is available.  If no
readiness probe is configured, the liveness probe points to the typical /healthz
endpoint.  If a readiness proble *is* configured, the readiness probe checks
checks /healthz while the liveness probe checks /livez.  In this configuration,
the liveness probe will check only for process liveness but not service and the
readiness probe will check that the storage backend is available.  These values
can be configured via the `probes` section of the values.

## Validation

The driver controller and node pods use the CSI health endpoint for readiness.
With `--wait`, Helm waits for controller readiness and fails on timeout if, for
example, its image cannot be pulled. A successful install without `--wait` only
means Kubernetes accepted the resources. Check both rollouts (including the
DaemonSet) after installation or upgrade:

```bash
kubectl -n kube-system rollout status deployment/ovirt-csi-controller-plugin --timeout=5m
kubectl -n kube-system rollout status daemonset/ovirt-csi-node-plugin --timeout=5m
```

Use the configured controller and node names if they have been overridden.
Readiness checks the CSI endpoint; it does not prove storage operations work.
Run the chart's functional storage test after both rollouts complete:

```bash
helm test ovirt-csi-driver --namespace kube-system --timeout 6m --logs
```

The test requests a new volume, attaches and mounts it, then verifies a write
and read. It fails if provisioning, attachment, mounting or I/O fails, or if the
test pod cannot start within the timeout. It exercises the node selected for the
test pod, not every node or every driver operation.

An existing StorageClass using this driver is required. Set
`pvc.1GOvirtCowDisk.storageClass` (default `ovirt-csi-sc`) and
`pvc.1GOvirtCowDisk.storageRequest` (default `1Gi`) to the storage class and volume
size to test. The test image defaults to Oracle Linux 8 slim and can be overridden
with `tests.image.repository`, `tests.image.tag` and `tests.image.pullPolicy`.
It must provide `/bin/sh`, `printf`, `sync`, `cat` and `test`. The chart's
`imagePullSecrets` also apply to the test pod.

The test creates an ephemeral PVC owned by its pod. Successful test pods are
deleted automatically; failed pods and their claims remain for diagnosis until
the pod is deleted or the test is rerun. Inspect failures with:

```bash
kubectl -n kube-system get pods,pvc
kubectl -n kube-system describe pod ovirt-csi-driver-storage-test
kubectl -n kube-system logs ovirt-csi-driver-storage-test
```

To clean up a failed test, delete its pod:

```bash
kubectl -n kube-system delete pod ovirt-csi-driver-storage-test
```

The example pod name assumes the release name above; use the name reported by
`helm test` for other releases. PVC deletion follows pod cleanup; backend volume
cleanup follows the StorageClass reclaim policy (`Retain` requires manual
cleanup). The test is run explicitly by `helm test`, not automatically by install
or upgrade.

## Optional install and upgrade preflight

Set `preflight.enabled=true` to run a Helm `pre-install` and `pre-upgrade` hook.
The hook pulls and starts every configured CSI image, then confirms each driver
can connect to oVirt before the chart workload resources are applied. Validation
reads the same `OVIRT_*` Secret and CA ConfigMap inputs used by
`--prepare-ovirt-config`, but does not run preparation or write configuration
files. Helm fails the install or upgrade when the preflight Job fails. Use
`--wait` and a timeout longer than the configured preflight deadline:

```bash
helm upgrade --install ovirt-csi-driver ./chart \
  --namespace kube-system \
  --set preflight.enabled=true \
  --wait --timeout 10m
```

`preflight.activeDeadlineSeconds` defaults to `300`. Connection validation is
performed by the CSI driver using its `--validate-ovirt-config` mode; the driver
image does not need to contain a shell.

The hook receives oVirt credentials only through Secret environment references.
The validator logs only fixed progress and pass/fail messages. Credentials are
passed through Secret environment references and are neither rendered into a
command nor written to a log. The generated configuration is stored only in
memory. Hook resources are deleted on a successful run. On failure, the Job is retained for its non-sensitive status
logs; Helm deletes it before a later hook run. The Job runs as a dedicated,
temporary ServiceAccount. Its hook ClusterRoleBinding grants only `nodes/list`,
which the driver uses during startup; it does not grant Secret read access or
privileged execution.

## Contributing

See [`CONTRIBUTING.md`](./CONTRIBUTING.md)

## Security

See [`SECURITY.md`](./SECURITY.md)

## License

Released under the Universal Permissive License v1.0. See [`LICENSE.txt`](./LICENSE.txt).
