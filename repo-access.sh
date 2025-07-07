#!/bin/bash
set -euo pipefail

AWS_PROFILE="gardener-poc"
AWS_REGION="us-west-2"
ECR_REPO_PREFIX="ce-helm-charts"
AWS_ACCOUNT_ID="043309336908"

echo "Fetching repositories under ${ECR_REPO_PREFIX}..."

repos=$(aws ecr describe-repositories \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --query "repositories[?starts_with(repositoryName, \`${ECR_REPO_PREFIX}/\`)].repositoryName" \
  --output text)

if [ -z "$repos" ]; then
  echo "No repositories found under prefix '$ECR_REPO_PREFIX'."
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

# Apply policy to each repo
for repo in $repos; do
  echo "Setting public read policy for: $repo"
  aws ecr set-repository-policy \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION" \
    --repository-name "$repo" \
    --policy-text "$read_policy"
done

echo "✅ All repositories under '$ECR_REPO_PREFIX/' are now public."

