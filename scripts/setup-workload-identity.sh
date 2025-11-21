#!/bin/bash

# Setup Workload Identity Federation for GitHub Actions
# This script creates the WIF pool, provider, and binds the service account

set -e

PROJECT_ID="gcp-terraform-demo-474514"
PROJECT_NUMBER="410476324289"
POOL_ID="github-pool"
PROVIDER_ID="github-provider"
SERVICE_ACCOUNT="gcp-terraform-demo@gcp-terraform-demo-474514.iam.gserviceaccount.com"
GITHUB_REPO="gcpt0801/pickstream-app"
GITHUB_ORG="gcpt0801"

echo "🔧 Setting up Workload Identity Federation..."

# Create Workload Identity Pool
echo "Creating Workload Identity Pool: $POOL_ID"
gcloud iam workload-identity-pools create $POOL_ID \
    --project="$PROJECT_ID" \
    --location="global" \
    --description="Workload Identity Pool for GitHub Actions" \
    --display-name="GitHub Pool" \
    2>/dev/null || echo "Pool already exists"

# Create OIDC Provider
echo "Creating OIDC Provider: $PROVIDER_ID"
gcloud iam workload-identity-pools providers create-oidc $PROVIDER_ID \
    --project="$PROJECT_ID" \
    --location="global" \
    --workload-identity-pool="$POOL_ID" \
    --issuer-uri="https://token.actions.githubusercontent.com" \
    --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
    --attribute-condition="assertion.repository_owner == '$GITHUB_ORG'" \
    2>/dev/null || echo "Provider already exists"

# Bind Service Account to Workload Identity
echo "Binding service account to Workload Identity..."
gcloud iam service-accounts add-iam-policy-binding "$SERVICE_ACCOUNT" \
    --project="$PROJECT_ID" \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/attribute.repository/$GITHUB_REPO"

# Get the Workload Identity Provider for GitHub Actions
WIF_PROVIDER="projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/providers/$PROVIDER_ID"

echo ""
echo "✅ Workload Identity Federation setup complete!"
echo ""
echo "📋 Add these secrets to your GitHub repository:"
echo "   Repository: https://github.com/$GITHUB_REPO/settings/secrets/actions"
echo ""
echo "WIF_PROVIDER:"
echo "$WIF_PROVIDER"
echo ""
echo "WIF_SERVICE_ACCOUNT:"
echo "$SERVICE_ACCOUNT"
echo ""
echo "GCP_PROJECT_ID:"
echo "$PROJECT_ID"
