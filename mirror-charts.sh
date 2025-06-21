#!/opt/homebrew/bin/bash
set -euo pipefail

INFRA_DIR="infrastructure/base"
AWS_PROFILE="gardener-poc"
ECR_REPO="ce-helm-charts"

# Discover AWS account ID and region
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query "Account" --output text)
AWS_REGION=$(aws configure get region --profile "$AWS_PROFILE")
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"

echo "Using AWS profile: $AWS_PROFILE"
echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"
echo "Target ECR Registry: $ECR_REGISTRY"

# Check dependencies
command -v yq >/dev/null || { echo "Error: yq is required"; exit 1; }
command -v helm >/dev/null || { echo "Error: helm is required"; exit 1; }

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --profile "$AWS_PROFILE" \
  | helm registry login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
echo "Login succeeded."

declare -A REPOS

# First pass: collect HelmRepositories
echo "Collecting HelmRepositories..."
for file in $(find "$INFRA_DIR" -name "helmrelease.yaml"); do
  while read -r repo; do
    repo_name=$(echo "$repo" | jq -r '.metadata.name')
    repo_url=$(echo "$repo" | jq -r '.spec.url')
    if [[ -n "$repo_name" && -n "$repo_url" ]]; then
      REPOS["$repo_name"]="$repo_url"
      echo "Found HelmRepository: $repo_name => $repo_url"
    fi
  done < <(yq eval-all '. | select(.kind == "HelmRepository")' "$file" -o=json | jq -c '.')
done

# Second pass: process HelmReleases
echo "Processing HelmReleases..."
for file in $(find "$INFRA_DIR" -name "helmrelease.yaml"); do
  echo "Processing file: $file"
  while read -r release; do
    chart_name=$(echo "$release" | jq -r '.spec.chart.spec.chart')
    chart_version=$(echo "$release" | jq -r '.spec.chart.spec.version')
    source_name=$(echo "$release" | jq -r '.spec.chart.spec.sourceRef.name')

    echo ""
    echo "Chart: $chart_name"
    echo "Version: $chart_version"
    echo "Source repo: $source_name"

    repo_url="${REPOS[$source_name]}"
    if [[ -z "$repo_url" ]]; then
      echo "Warning: Repo $source_name not found. Skipping chart $chart_name."
      continue
    fi

    repo_alias="repo-${source_name}"
    chart_tarball="${chart_name}-${chart_version}.tgz"
    ecr_chart_ref="oci://${ECR_REGISTRY}/${chart_name}"

    # Add repo if not present
    if ! helm repo list | grep -q "$repo_alias"; then
      echo "Adding Helm repo: $repo_alias => $repo_url"
      helm repo add "$repo_alias" "$repo_url"
    fi

    helm repo update > /dev/null

    # Check if chart exists in ECR
    if helm show chart "${ecr_chart_ref}" --version "${chart_version}" > /dev/null 2>&1; then
      echo "Chart $chart_name:$chart_version already exists in ECR. Skipping push."
      continue
    fi

    echo "Pulling $chart_name@$chart_version from $repo_url"
    helm pull "$repo_alias/$chart_name" --version "$chart_version"

    # Ensure ECR repo exists
    ecr_repo_full="${ECR_REPO}/${chart_name}"
    if ! aws ecr describe-repositories --repository-names "$ecr_repo_full" --profile "$AWS_PROFILE" > /dev/null 2>&1; then
      echo "Creating ECR repository: $ecr_repo_full"
      aws ecr create-repository --repository-name "$ecr_repo_full" --profile "$AWS_PROFILE" > /dev/null
      echo "ECR repository created."
    fi

    echo "Pushing $chart_tarball to ECR"
    helm push "$chart_tarball" oci://"$ECR_REGISTRY"

    rm -f "$chart_tarball"
  done < <(yq eval-all '. | select(.kind == "HelmRelease")' "$file" -o=json | jq -c '.')
done

echo ""
echo "Helm chart mirroring completed."
