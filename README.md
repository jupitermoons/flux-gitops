# Flux GitOps Repository

This repository manages the GitOps-based deployment of core infrastructure components and services across multiple Kubernetes clusters using [Flux CD](https://fluxcd.io/). It is structured for scalability, modularity, and ease of management across a fleet of production clusters, along with separate POC and test environments.

## 📁 Repository Structure
```text
├── clusters/
│   ├── tools/
│   │   └── kustomization.yaml
│   ├── receipt/
│   │   └── kustomization.yaml
│   ├── mobile/
│   │   └── kustomization.yaml
│   ├── front/
│   │   └── kustomization.yaml
│   ├── observe/
│   │   └── kustomization.yaml
│   ├── pubsub/
│   │   └── kustomization.yaml
│   ├── travel/
│   │   └── kustomization.yaml
│   └── spend/
│       └── kustomization.yaml
│
├── infrastructure/
│   ├── base/
│   │   ├── cert-manager/
│   │   ├── external-dns/
│   │   ├── gatekeeper/
│   │   ├── istio/
│   │   ├── keda/
│   │   └── reflector/
│   │
│   └── overlays/
│       ├── gs1/
│       │   ├── patch-ecr.yaml
│       │   ├── patch-deploy.yaml
│       │   ├── patch-config.yaml
│       │   └── kustomization.yaml
│       ├── eu2/
│       │   ├── patch-ecr.yaml
│       │   ├── patch-deploy.yaml
│       │   ├── patch-config.yaml
│       │   └── kustomization.yaml
│       ├── fabianemea/
│       │   ├── patch-ecr.yaml
│       │   ├── patch-deploy.yaml
│       │   ├── patch-config.yaml
│       │   └── kustomization.yaml
│       ├── us2/
│       │   ├── patch-ecr.yaml
│       │   ├── patch-deploy.yaml
│       │   ├── patch-config.yaml
│       │   └── kustomization.yaml
│       ├── fabian/
│       │   ├── patch-ecr.yaml
│       │   ├── patch-deploy.yaml
│       │   ├── patch-config.yaml
│       │   └── kustomization.yaml
│       ├── uspscc/
│       │   ├── patch-ecr.yaml
│       │   ├── patch-deploy.yaml
│       │   ├── patch-config.yaml
│       │   └── kustomization.yaml
│       ├── apj1/
│       │   ├── patch-ecr.yaml
│       │   ├── patch-deploy.yaml
│       │   ├── patch-config.yaml
│       │   └── kustomization.yaml
│       └── poc/
│           ├── patch-ecr.yaml
│           ├── patch-deploy.yaml
│           ├── patch-config.yaml
│           └── kustomization.yaml
│
├── flux/
│   └── bootstrap/
│       └── gotk-components.yaml     # Flux self-bootstrap configuration
│
└── README.md
```

## 🌍 Cluster Types and Strategy
### Production Clusters
- Organized per region and per cluster (clusters/cluster-name/).
- All production clusters must include the infrastructure/overlays/<env>
- Managed using Kustomize-based layering to avoid code repetition.

### POC Clusters
- Hosted under clusters/poc.
- Used for exploring new tools or configurations.
- May selectively include only specific addons or custom configurations.

## 🧱 Add-on Deployment Strategy
### Base Charts
Each addon lives under infrastructure/base/ and defines:
- A HelmRepository (if needed)
- A HelmRelease with minimal config
- Kustomization.yaml

### Overlays

## 🔁 Reuse & Maintainability

## 🚀 Getting Started

### Bootstrap a new cluster

### Customizing Per Cluster

## 🛡️ Naming Conventions

## 📌 Notes

## 📣 Contributing
- Always test changes 
- Keep all HelmRelease specs in sync and clean.
- Use overlays and patches to minimize base modification.

## 📞 Support
Reach out to the platform team for:
- Adding new addons
- Cluster bootstrapping
- Troubleshooting non-ready HelmReleases