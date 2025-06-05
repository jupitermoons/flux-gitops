# Flux GitOps Repository

This repository manages the GitOps-based deployment of core infrastructure components and services across multiple Kubernetes clusters using [Flux CD](https://fluxcd.io/). It is structured for scalability, modularity, and ease of management across a fleet of 60+ production clusters, along with separate POC and test environments.

## 📁 Repository Structure
```text
├── clusters/
│   ├── prod-region-1/
│   │   ├── cluster-a/
│   │   │   └── kustomization.yaml
│   │   └── cluster-b/
│   │       └── kustomization.yaml
│   ├── prod-region-2/
│   ├── prod-region-3/
│   ├── poc/
│   └── test/
├── infrastructure/
│   ├── base/
│   │   ├── cert-manager/
│   │   ├── external-dns/
│   │   ├── gatekeeper/
│   │   ├── istio/
│   │   ├── keda/
│   │   ├── metrics-server/
│   │   └── reflector/
│   └── overlays/
│       ├── production/
│       │   └── management-addons/
│       ├── test/
│       └── poc/
├── flux/
│   └── bootstrap/
│       └── gotk-components.yaml
└── README.md
```

## 🌍 Cluster Types and Strategy
### Production Clusters
- Organized per region and per cluster (clusters/prod-region-{1,2,3}/cluster-name/).
- All production clusters must include the infrastructure/overlays/production/management-addons overlay which bundles core components:
    - cert-manager
    - external-dns
    - gatekeeper
    - istio
    - keda
    - metrics-server
    - reflector
- Managed using Kustomize-based layering to avoid code repetition.

### POC Clusters
- Hosted under clusters/poc/.
- Used for exploring new tools or configurations.
- May selectively include only specific addons or custom configurations.

### Test Clusters
- Hosted under clusters/test/.
- Used for validating upgrades or new versions of core addons before production rollouts.

## 🧱 Add-on Deployment Strategy
### Base Charts
Each addon lives under infrastructure/base/ and defines:
- A HelmRepository (if needed)
- A HelmRelease with minimal config
- Kustomization.yaml

### Overlays
The infrastructure/overlays/production/management-addons folder aggregates these base resources into a unified bundle:
```yaml
resources:
  - ../../base/cert-manager
  - ../../base/external-dns
  - ../../base/gatekeeper
  - ../../base/istio
  - ../../base/keda
  - ../../base/metrics-server
  - ../../base/reflector
```
POC or test overlays may omit or modify these.

## 🔁 Reuse & Maintainability
- All clusters include only one line to reference the shared overlay:
```yaml
resources:
  - ../../../infrastructure/overlays/production/management-addons
```
- Component upgrades are made in one place under base/, automatically propagating to all clusters.

## 🚀 Getting Started

### Bootstrap a new cluster
1. Fork this repo and set up your own Flux bootstrap manifests.
2. Define the new cluster under clusters/<env>/<cluster-name>/kustomization.yaml.
3. Point the kustomization to the shared production overlay:
```yaml
resources:
  - ../../../infrastructure/overlays/production/management-addons
```

### Customizing Per Cluster
Add a patchesStrategicMerge entry in the cluster’s kustomization to override values for specific HelmReleases.

## 🛡️ Naming Conventions
| Component        | Namespace                                               |
| ---------------- | ------------------------------------------------------- |
| All Addons       | `shared-system`                                         |
| Flux Controllers | `flux-system`                                           |
| Istio            | `istio-system`                                          |
| Gatekeeper       | `gatekeeper-system`                                     |

## 📌 Notes
- All critical clusters are bootstrapped with Flux and monitored continuously.
- CRDs (like ServiceMonitor) must be installed ahead of time or via Helm values in base charts.
- Values like region-specific DNS zones or Istio ingress class are injected via overlays.

## 📣 Contributing
- Always test changes in clusters/test/ before merging to production overlays.
- Keep all HelmRelease specs in sync and clean.
- Use overlays and patches to minimize base modification.

## 📞 Support
Reach out to the platform team for:
- Adding new addons
- Cluster bootstrapping
- Troubleshooting non-ready HelmReleases