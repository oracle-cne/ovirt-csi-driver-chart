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

Basic post-install checks:

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
