#!/bin/bash
set -euo pipefail

AWS_PROFILE="gardener-poc"
AWS_REGION="us-west-2"
ECR_REPO_PREFIX="ce-addon"
AWS_ACCOUNT_ID="043309336908"

echo "Fetching repositories under prefix '${ECR_REPO_PREFIX}'..."

# Fetch all repositories and filter in shell to support wildcards
repos=$(aws ecr describe-repositories \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --query 'repositories[].repositoryName' \
  --output text)

# Filter repositories starting with the given prefix
filtered_repos=()
for repo in $repos; do
  if [[ "$repo" == ${ECR_REPO_PREFIX}* ]]; then
    filtered_repos+=("$repo")
  fi
done

if [ ${#filtered_repos[@]} -eq 0 ]; then
  echo "No repositories found under prefix '${ECR_REPO_PREFIX}'."
  exit 0
fi

# Define public read policy
read_policy='{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "AllowPull",
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ]
    }
  ]
}'

# Apply the policy to each matching repo
for repo in "${filtered_repos[@]}"; do
  echo "Setting public read policy for: $repo"
  aws ecr set-repository-policy \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION" \
    --repository-name "$repo" \
    --policy-text "$read_policy"
done

echo "✅ Policy applied to ${#filtered_repos[@]} repositories."
