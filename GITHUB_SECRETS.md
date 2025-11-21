# GitHub Secrets Configuration

This guide explains how to set up Workload Identity Federation and configure GitHub secrets for automated deployments.

## Step 1: Create Workload Identity Federation (GCP Cloud Shell)

Run these commands in GCP Cloud Shell to create the Workload Identity Federation setup:

```bash
# 1. Create Workload Identity Pool
gcloud iam workload-identity-pools create github-actions-pool \
  --location=global \
  --display-name="GitHub Actions Pool" \
  --description="Workload Identity Pool for GitHub Actions" \
  --project=gcp-terraform-demo-474514

# 2. Create OIDC Provider for GitHub Actions
gcloud iam workload-identity-pools providers create-oidc github-actions-provider \
  --location=global \
  --workload-identity-pool=github-actions-pool \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
  --attribute-condition="assertion.repository_owner == 'gcpt0801'" \
  --project=gcp-terraform-demo-474514

# 3. Bind Service Account to Workload Identity
gcloud iam service-accounts add-iam-policy-binding gcp-terraform-demo@gcp-terraform-demo-474514.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/410476324289/locations/global/workloadIdentityPools/github-actions-pool/attribute.repository/gcpt0801/pickstream-app" \
  --project=gcp-terraform-demo-474514
```

**Note:** If the pool or provider was previously deleted, undelete them first:
```bash
# Undelete pool (if needed)
gcloud iam workload-identity-pools undelete github-actions-pool \
  --location=global \
  --project=gcp-terraform-demo-474514

# Undelete provider (if needed)  
gcloud iam workload-identity-pools providers undelete github-actions-provider \
  --location=global \
  --workload-identity-pool=github-actions-pool \
  --project=gcp-terraform-demo-474514
```

## Step 2: Add GitHub Secrets

After running the commands above, add these secrets to your GitHub repository:

**Repository Settings URL:**
https://github.com/gcpt0801/pickstream-app/settings/secrets/actions

### 1. WIF_PROVIDER
```
projects/410476324289/locations/global/workloadIdentityPools/github-actions-pool/providers/github-actions-provider
```

### 2. WIF_SERVICE_ACCOUNT
```
gcp-terraform-demo@gcp-terraform-demo-474514.iam.gserviceaccount.com
```

### 3. GCP_PROJECT_ID
```
gcp-terraform-demo-474514
```

## How to Add Secrets

1. Go to: https://github.com/gcpt0801/pickstream-app/settings/secrets/actions
2. Click "New repository secret"
3. Add each secret:
   - **Name:** Enter the secret name exactly (e.g., `WIF_PROVIDER`)
   - **Value:** Copy and paste the value from above
4. Click "Add secret"
5. Repeat for all three secrets

## Step 3: Verify Setup

After adding the secrets:

1. Go to GitHub Actions: https://github.com/gcpt0801/pickstream-app/actions
2. Click "CI/CD Pipeline" workflow
3. Click "Run workflow" dropdown
4. Click "Run workflow" button

The workflow should now authenticate successfully using Workload Identity Federation!

## Troubleshooting

**Error: "invalid_target"**
- The pool or provider might be deleted
- Run the undelete commands above

**Error: "Resource not accessible by integration"**
- Check that all three secrets are added correctly
- Verify the service account has proper IAM roles

**Error: "ALREADY_EXISTS"**
- The resource already exists, this is fine
- Continue with the next command
