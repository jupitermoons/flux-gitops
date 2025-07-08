#!/opt/homebrew/bin/bash
set -euo pipefail

# Constants
AWS_PROFILE="gardener-poc"
ECR_REPO="ce-addon-charts"

# Get AWS account and region
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query "Account" --output text)
AWS_REGION=$(aws configure get region --profile "$AWS_PROFILE")
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"

echo "Using AWS Account ID: $AWS_ACCOUNT_ID"
echo "Region: $AWS_REGION"
echo "ECR registry: $ECR_REGISTRY"

# Prompt user for inputs
read -rp "Enter Helm Repo URL (e.g., https://emberstack.github.io/helm-charts): " HELM_REPO_URL
read -rp "Enter App Name (e.g., reflector): " APP_NAME
read -rp "Enter Chart Version (e.g., 9.2.0-develop.18): " CHART_VERSION

# Dependencies check
command -v helm >/dev/null || { echo "❌ helm CLI is required."; exit 1; }

# Login to ECR
echo "🔐 Logging in to ECR..."
aws ecr get-login-password --profile "$AWS_PROFILE" | helm registry login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
echo "✅ Login succeeded."

# Add Helm repo with a temporary alias
TEMP_REPO_NAME="user-supplied-repo"
if helm repo list | grep -q "$TEMP_REPO_NAME"; then
  helm repo remove "$TEMP_REPO_NAME"
fi
helm repo add "$TEMP_REPO_NAME" "$HELM_REPO_URL"
helm repo update > /dev/null

# Pull the chart
CHART_TGZ="${APP_NAME}-${CHART_VERSION}.tgz"
echo "📥 Pulling chart: $APP_NAME@$CHART_VERSION from $HELM_REPO_URL"
helm pull "$TEMP_REPO_NAME/$APP_NAME" --version "$CHART_VERSION"

# Ensure ECR repo exists
ECR_CHART_PATH="${ECR_REPO}/${APP_NAME}"
if ! aws ecr describe-repositories --repository-names "$ECR_CHART_PATH" --profile "$AWS_PROFILE" > /dev/null 2>&1; then
  echo "🛠️  Creating ECR repository: $ECR_CHART_PATH"
  aws ecr create-repository --repository-name "$ECR_CHART_PATH" --profile "$AWS_PROFILE"
fi

# Push to ECR
echo "🚀 Pushing $CHART_TGZ to oci://$ECR_REGISTRY/$APP_NAME"
helm push "$CHART_TGZ" oci://"$ECR_REGISTRY"

# Cleanup
rm -f "$CHART_TGZ"
helm repo remove "$TEMP_REPO_NAME"

echo "✅ Chart pushed to ECR successfully."
