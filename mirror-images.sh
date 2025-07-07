#!/opt/homebrew/bin/bash
set -euo pipefail

AWS_PROFILE="gardener-poc"
ECR_REPO="ce-addon-images"
PATCH_DIR="patches"
KUSTOMIZATION_FILE="kustomization.yaml"

# Discover AWS account ID and region
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query "Account" --output text)
AWS_REGION=$(aws configure get region --profile "$AWS_PROFILE")
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"

echo "Using AWS profile: $AWS_PROFILE"
echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"
echo "Target ECR Registry: $ECR_REGISTRY"

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --profile "$AWS_PROFILE" \
  | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
echo "Login succeeded."

# Prepare patch directory and kustomization.yaml
mkdir -p "$PATCH_DIR"
echo "apiVersion: kustomize.config.k8s.io/v1beta1" > "$KUSTOMIZATION_FILE"
echo "kind: Kustomization" >> "$KUSTOMIZATION_FILE"
echo "" >> "$KUSTOMIZATION_FILE"
echo "patchesStrategicMerge:" >> "$KUSTOMIZATION_FILE"

# List of images to mirror
images=(
  "ghcr.io/fluxcd/helm-controller:v1.3.0"
  "ghcr.io/fluxcd/kustomize-controller:v1.6.0"
  "ghcr.io/fluxcd/notification-controller:v1.6.0"
  "ghcr.io/fluxcd/source-controller:v1.6.0"
  "openpolicyagent/gatekeeper:v3.14.0"
  "docker.io/istio/pilot:1.22.0"
  "ghcr.io/kedacore/keda-admission-webhooks:2.14.0"
  "ghcr.io/kedacore/keda:2.14.0"
  "ghcr.io/kedacore/keda-metrics-apiserver:2.14.0"
  "quay.io/jetstack/cert-manager-controller:v1.12.0"
  "quay.io/jetstack/cert-manager-cainjector:v1.12.0"
  "quay.io/jetstack/cert-manager-webhook:v1.12.0"
  "registry.k8s.io/external-dns/external-dns:v0.13.6"
  "docker.io/emberstack/kubernetes-reflector:9.1.7"
)

# Mirror images and generate patches
for image in "${images[@]}"; do
  image_name=$(basename "$image")
  image_repo=$(echo "$image" | cut -d/ -f2- | cut -d: -f1 | tr '/' '-')
  image_tag=$(echo "$image" | cut -d: -f2)
  target="${ECR_REGISTRY}/${image_repo}:${image_tag}"

  echo ""
  echo "==> Processing $image"
  echo "Target ECR Image: $target"

  echo "Pulling $image for linux/amd64..."
  docker pull --platform=linux/amd64 "$image"

  echo "Tagging as $target"
  docker tag "$image" "$target"

  echo "Ensuring ECR repo ${ECR_REPO}/${image_repo} exists..."
  aws ecr describe-repositories --repository-names "${ECR_REPO}/${image_repo}" --profile "$AWS_PROFILE" >/dev/null 2>&1 || \
    aws ecr create-repository --repository-name "${ECR_REPO}/${image_repo}" --profile "$AWS_PROFILE" >/dev/null

  echo "Pushing to ECR..."
  docker push "$target"

  # Derive deployment name (fallback: repo name without registry)
  deployment_name=$(echo "$image_repo" | cut -d- -f2-)

  patch_file="${PATCH_DIR}/${deployment_name}-image-patch.yaml"
  echo "Creating patch file: $patch_file"

  cat > "$patch_file" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${deployment_name}
spec:
  template:
    spec:
      containers:
        - name: manager
          image: ${target}
EOF

  echo "  - ${patch_file}" >> "$KUSTOMIZATION_FILE"
  echo "✔ Done: $image -> $target"
done

echo ""
echo "✅ All images mirrored and patch files created."
