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
  --create-namespace
```

## Validation

Run the included storage test after installing the driver:

```bash
helm test ovirt-csi-driver --namespace kube-system --timeout 6m
```

Use the release name and namespace chosen during installation. The test creates a
new volume, mounts it, and checks that data can be written and read. It uses the
`pvc.1GOvirtCowDisk.storageClass` and `pvc.1GOvirtCowDisk.storageRequest` chart
values (defaults: `ovirt-csi-sc` and `1Gi`). The selected StorageClass must already
exist and use this deployment’s oVirt CSI provisioner (`driver.name`, normally
`csi.ovirt.org`); the driver needs working oVirt credentials and available storage.
The test can run on any eligible node and uses an Oracle Linux 8 image from OCR.

The test has a five-minute deadline. Successful test Pods are removed
automatically. Failed test Pods remain for inspection and are removed before the
next test run. To remove one manually, delete the test Pod named in the
`helm test` output from the release namespace. Its ephemeral PVC is removed with
the Pod; the StorageClass reclaim policy determines whether the backing volume
is deleted or retained.

Additional post-install checks:

```bash
kubectl -n kube-system get deployment,daemonset,serviceaccount
kubectl get csidriver csi.ovirt.org
```

## Contributing

See [`CONTRIBUTING.md`](./CONTRIBUTING.md)

## Security

See [`SECURITY.md`](./SECURITY.md)

## License

Released under the Universal Permissive License v1.0. See [`LICENSE.txt`](./LICENSE.txt).
