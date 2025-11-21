# Authentication Guide

This document explains the different authentication mechanisms used in this project.

## Table of Contents
1. [Kubernetes Service Account vs GCP Service Account](#kubernetes-service-account-vs-gcp-service-account)
2. [Service Account JSON Keys vs Workload Identity Federation](#service-account-json-keys-vs-workload-identity-federation)

---

## Kubernetes Service Account vs GCP Service Account

### Overview

These are two completely different authentication systems that serve different purposes:

| Aspect | Kubernetes Service Account (KSA) | GCP Service Account (GSA) |
|--------|----------------------------------|---------------------------|
| **Where** | Inside Kubernetes cluster | Google Cloud Platform |
| **Purpose** | Identity for pods in K8s | Identity for GCP API access |
| **Authenticates to** | Kubernetes API Server | Google Cloud APIs |
| **Controls** | What pods can do in K8s | What can access GCP resources |
| **Permissions** | Kubernetes RBAC | GCP IAM roles |
| **Example** | `pickstream` | `gcp-terraform-demo@...` |

### Kubernetes Service Account (KSA)

**What it is:**
- An identity that pods run as inside the Kubernetes cluster
- Every pod must have a KSA (uses `default` if not specified)
- Token is automatically mounted into pods at `/var/run/secrets/kubernetes.io/serviceaccount/token`

**Used for:**
- Authenticating to the Kubernetes API server
- Controlling what Kubernetes resources the pod can access
- Reading ConfigMaps, Secrets, listing Pods, etc.

**In this project:**
```yaml
# helm/pickstream/values.yaml
serviceAccount:
  create: true
  name: "pickstream"
  annotations:
    iam.gke.io/gcp-service-account: "pickstream-sa@gcp-terraform-demo-474514.iam.gserviceaccount.com"
```

**Created by Helm as:**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pickstream
  namespace: pickstream
```

**Pods use it:**
```yaml
spec:
  serviceAccountName: pickstream  # Both backend and frontend pods
  containers:
  - name: backend
    ...
```

### GCP Service Account (GSA)

**What it is:**
- An identity for accessing Google Cloud services
- Like a "robot user" with specific permissions in GCP
- Has IAM roles that define what GCP resources it can access

**Used for:**
- Authenticating to Google Cloud APIs
- Accessing Cloud Storage, BigQuery, Pub/Sub, etc.
- Deploying to GKE, pushing to Artifact Registry

**In this project:**
```
gcp-terraform-demo@gcp-terraform-demo-474514.iam.gserviceaccount.com
```

**Permissions (IAM roles):**
- `roles/container.developer` - Deploy to GKE
- `roles/artifactregistry.writer` - Push Docker images
- `roles/iam.serviceAccountUser` - Act as other service accounts

### How They Work Together (GKE Workload Identity)

In GKE, you can link a KSA to a GSA so pods can access GCP services:

```
┌─────────────────────────────────────┐
│ Pod (runs in GKE)                   │
│ Uses KSA: pickstream                │
│   ↓                                 │
│   KSA has annotation:               │
│   iam.gke.io/gcp-service-account    │
│   ↓                                 │
│   Points to GSA:                    │
│   pickstream-sa@...                 │
└─────────────┬───────────────────────┘
              │
              ↓ Workload Identity exchanges tokens
┌─────────────────────────────────────┐
│ Google Cloud (Outside K8s)          │
│ Pod can now access:                 │
│ - Cloud Storage                     │
│ - BigQuery                          │
│ - Pub/Sub                           │
│ Using GSA permissions               │
└─────────────────────────────────────┘
```

**Steps to enable:**
1. Create KSA in Kubernetes (✅ done in this project)
2. Create GSA in GCP (⚠️ `pickstream-sa@...` not created yet)
3. Grant GSA the needed IAM roles
4. Bind KSA to GSA using Workload Identity
5. Add annotation to KSA (✅ done in this project)

### Example: When You Need Which

**Scenario 1: Pod wants to list other pods**
```java
// Uses: Kubernetes Service Account (KSA)
// Requires: Kubernetes RBAC Role granting pods.list permission
KubernetesClient client = new KubernetesClientBuilder().build();
client.pods().inNamespace("pickstream").list();
```

**Scenario 2: Pod wants to upload file to Cloud Storage**
```java
// Uses: GCP Service Account (GSA) via Workload Identity
// Requires: GSA with roles/storage.objectCreator role
Storage storage = StorageOptions.getDefaultInstance().getService();
storage.create(BlobInfo.newBuilder("my-bucket", "file.txt").build());
```

**Scenario 3: Both!**
```java
// Pod reads a Kubernetes Secret (uses KSA + RBAC)
Secret secret = client.secrets().inNamespace("pickstream").withName("my-secret").get();

// Then uploads to Cloud Storage (uses GSA via Workload Identity)
storage.create(BlobInfo.newBuilder("my-bucket", "data.txt").build(), 
               secret.getData().get("data"));
```

### Summary

| Need to... | Use | Permissions |
|------------|-----|-------------|
| Access Kubernetes resources (pods, configmaps, secrets) | KSA | Kubernetes RBAC |
| Access GCP services (Storage, BigQuery, Pub/Sub) | GSA | GCP IAM roles |
| Access both | KSA linked to GSA via Workload Identity | Both RBAC + IAM |

**In this project:**
- ✅ KSA `pickstream` exists and is used by all pods
- ✅ GSA `gcp-terraform-demo@...` exists and is used by GitHub Actions (CI/CD)
- ⚠️ GSA `pickstream-sa@...` is referenced but not created (not needed yet since pods don't access GCP services)

---

## Service Account JSON Keys vs Workload Identity Federation

### Overview

Both methods authenticate **external systems** (like GitHub Actions) to Google Cloud, but they work very differently.

### Service Account JSON Keys (Old Method ❌)

**What it is:**
- A downloadable JSON file containing a private key
- Acts like a long-lived password for a service account
- Must be stored securely (e.g., GitHub Secrets)

**How it works:**
```
┌─────────────────────────────────┐
│ GitHub Actions                  │
│                                 │
│ 1. Reads JSON key from secret   │
│    (Contains private key!)      │
│                                 │
│ 2. Uses key to authenticate     │
└────────────┬────────────────────┘
             │
             ↓ Send credentials
┌─────────────────────────────────┐
│ Google Cloud                    │
│                                 │
│ 3. Verifies signature           │
│ 4. Grants access as SA          │
└─────────────────────────────────┘
```

**JSON Key file structure:**
```json
{
  "type": "service_account",
  "project_id": "gcp-terraform-demo-474514",
  "private_key_id": "abc123def456...",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkq...",
  "client_email": "gcp-terraform-demo@gcp-terraform-demo-474514.iam.gserviceaccount.com",
  "client_id": "123456789012345678901",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/..."
}
```

**GitHub Actions workflow (old method):**
```yaml
- name: Authenticate to Google Cloud
  uses: google-github-actions/auth@v2
  with:
    credentials_json: ${{ secrets.GCP_SA_KEY }}  # ← Entire JSON key stored as secret
```

**Problems:**

| Issue | Description | Impact |
|-------|-------------|--------|
| **Long-lived** | Keys don't expire | Stolen key = permanent access until revoked |
| **Rotation burden** | Must manually rotate every 90 days | Easy to forget, security risk |
| **Secrets management** | Actual credentials stored in GitHub | If GitHub is compromised, attacker has keys |
| **Broad scope** | Key works from anywhere | Stolen key can be used outside GitHub Actions |
| **Audit trail** | All actions appear as same SA | Hard to distinguish GitHub vs other uses |
| **Revocation impact** | Revoking key breaks all workflows | Must update secret immediately |

**Security risks:**
- ❌ If leaked, attacker can use it forever (until you rotate)
- ❌ Can be used from anywhere (not limited to GitHub)
- ❌ No automatic expiration
- ❌ If repo is compromised, attacker gets full GCP access
- ❌ Hard to audit: "Was this GitHub or a stolen key?"

### Workload Identity Federation (New Method ✅)

**What it is:**
- A trust relationship between Google Cloud and external identity provider (GitHub)
- Uses short-lived OIDC tokens instead of keys
- No credentials stored anywhere

**How it works:**
```
┌─────────────────────────────────────────┐
│ GitHub Actions                          │
│                                         │
│ 1. GitHub auto-generates OIDC token     │
│    Token contains:                      │
│    - repository: gcpt0801/pickstream-app│
│    - workflow: CI/CD Pipeline           │
│    - actor: ramesh                      │
│    - expires: 1 hour                    │
└────────────┬────────────────────────────┘
             │
             ↓ Send token (not credentials!)
┌─────────────────────────────────────────┐
│ Workload Identity Pool                  │
│ (github-actions-pool)                   │
│                                         │
│ 2. Verifies token:                      │
│    ✓ Is it really from GitHub?          │
│    ✓ Is issuer token.actions.github.com?│
│    ✓ Does repo match allowed pattern?   │
│    ✓ Is repository_owner gcpt0801?      │
└────────────┬────────────────────────────┘
             │
             ↓ Token verified ✓
┌─────────────────────────────────────────┐
│ Google Cloud IAM                        │
│                                         │
│ 3. Checks IAM binding:                  │
│    Does this principal have             │
│    workloadIdentityUser role?           │
│                                         │
│ 4. Issues temporary credentials         │
│    Valid for ~1 hour                    │
└────────────┬────────────────────────────┘
             │
             ↓ Temporary credentials
┌─────────────────────────────────────────┐
│ GitHub Actions (continued)              │
│                                         │
│ 5. Uses temp credentials to:            │
│    - Push images to Artifact Registry   │
│    - Deploy to GKE                      │
│                                         │
│ 6. Credentials expire after workflow    │
└─────────────────────────────────────────┘
```

**GitHub Secrets (new method):**
```bash
# Just identifiers, not credentials!
WIF_PROVIDER=projects/410476324289/locations/global/workloadIdentityPools/github-actions-pool/providers/github-actions-provider
WIF_SERVICE_ACCOUNT=gcp-terraform-demo@gcp-terraform-demo-474514.iam.gserviceaccount.com
GCP_PROJECT_ID=gcp-terraform-demo-474514
```

**GitHub Actions workflow (new method):**
```yaml
- name: Authenticate to Google Cloud
  uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: ${{ secrets.WIF_PROVIDER }}     # ← Just a path
    service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}         # ← Just an email
```

**Advantages:**

| Benefit | Description | Impact |
|---------|-------------|--------|
| **Keyless** | No private keys anywhere | Nothing to steal or leak |
| **Short-lived** | Credentials expire in ~1 hour | Stolen token useless after expiration |
| **No rotation** | Tokens generated fresh each time | Zero maintenance |
| **Scoped** | Only works from specific GitHub repo | Can't be used elsewhere |
| **Auditable** | Clear attribution to GitHub workflow | Easy to trace actions |
| **Automatic** | GitHub handles token generation | No manual steps |

**Security benefits:**
- ✅ No keys to manage, rotate, or leak
- ✅ Credentials expire automatically after ~1 hour
- ✅ Only works from your specific GitHub repository
- ✅ Even if "secrets" are stolen, they're useless (just identifiers)
- ✅ Cannot be used outside GitHub Actions
- ✅ Clear audit trail: "This came from GitHub repo X, workflow Y"

### Side-by-Side Comparison

| Aspect | JSON Keys (Old) | Workload Identity Federation (New) |
|--------|-----------------|-----------------------------------|
| **Authentication** | Private key (like password) | OIDC token (like badge) |
| **Storage** | Key stored in GitHub Secrets | Only identifiers stored |
| **Validity** | Forever (until manually rotated) | ~1 hour (auto-expires) |
| **Rotation** | Manual every 90 days | Automatic (no action needed) |
| **Scope** | Works from anywhere | Only from specified GitHub repo |
| **If leaked** | Full access until revoked | Useless without GitHub OIDC context |
| **Maintenance** | High (track expiration, rotate) | Zero (fully automatic) |
| **Security** | ⚠️ Medium risk | ✅ High security |
| **Google recommendation** | ❌ Deprecated for CI/CD | ✅ Recommended |
| **Setup complexity** | Simple (download JSON) | Moderate (3 gcloud commands) |
| **Audit trail** | "Service account was used" | "GitHub repo X, workflow Y, user Z" |

### Real-World Example

**Scenario: GitHub repo is compromised**

**With JSON Keys:**
```
Attacker gets: Private key from GitHub Secrets
Attacker can: 
  - Use key from their own computer
  - Access GCP resources forever (until you notice and revoke)
  - Deploy malicious code to your GKE cluster
  - Delete production data
  - Download sensitive data from Cloud Storage
```

**With Workload Identity Federation:**
```
Attacker gets: Just identifiers (WIF_PROVIDER path, SA email)
Attacker can:
  - Nothing! These aren't credentials
  - Can't generate GitHub OIDC tokens (only GitHub can)
  - Can't use them outside GitHub Actions
  - Even if they run workflow in the repo, you see it in logs
```

### Why Google Recommends WIF

From Google's official documentation:

> "Service account keys are a security risk if not managed correctly. You should choose a more secure alternative to service account keys whenever possible, such as Workload Identity Federation."

**Reasons:**
1. **Keys are long-lived** - Perfect target for attackers
2. **Keys are portable** - Work from anywhere, hard to restrict
3. **Keys are forgettable** - Developers forget to rotate them
4. **Keys are powerful** - One key = full service account access
5. **Keys are auditable poorly** - Can't tell if it's CI/CD or attacker

**WIF solves all these problems** by eliminating keys entirely and using short-lived, contextual tokens instead.

### Migration Path

If you're currently using JSON keys, here's how to migrate:

**Step 1: Set up Workload Identity Federation**
```bash
# Create pool
gcloud iam workload-identity-pools create github-actions-pool \
  --location=global \
  --project=YOUR_PROJECT_ID

# Create provider
gcloud iam workload-identity-pools providers create-oidc github-actions-provider \
  --location=global \
  --workload-identity-pool=github-actions-pool \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --attribute-condition="assertion.repository_owner == 'YOUR_GITHUB_ORG'" \
  --project=YOUR_PROJECT_ID

# Bind service account
gcloud iam service-accounts add-iam-policy-binding YOUR_SA@YOUR_PROJECT.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/attribute.repository/YOUR_ORG/YOUR_REPO" \
  --project=YOUR_PROJECT_ID
```

**Step 2: Update GitHub Secrets**
```bash
# Remove old secret
GCP_SA_KEY (delete this)

# Add new secrets
WIF_PROVIDER=projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/providers/github-actions-provider
WIF_SERVICE_ACCOUNT=YOUR_SA@YOUR_PROJECT.iam.gserviceaccount.com
```

**Step 3: Update workflow**
```yaml
# Old
- uses: google-github-actions/auth@v2
  with:
    credentials_json: ${{ secrets.GCP_SA_KEY }}

# New
- uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
    service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}
```

**Step 4: Delete old service account key**
```bash
# List keys
gcloud iam service-accounts keys list --iam-account=YOUR_SA@YOUR_PROJECT.iam.gserviceaccount.com

# Delete key
gcloud iam service-accounts keys delete KEY_ID --iam-account=YOUR_SA@YOUR_PROJECT.iam.gserviceaccount.com
```

### This Project's Setup

**Current method:** ✅ Workload Identity Federation

**Configured in:**
- Pool: `github-actions-pool`
- Provider: `github-actions-provider`
- Service Account: `gcp-terraform-demo@gcp-terraform-demo-474514.iam.gserviceaccount.com`
- Allowed Repository: `gcpt0801/pickstream-app`

**GitHub Secrets:**
```bash
WIF_PROVIDER=projects/410476324289/locations/global/workloadIdentityPools/github-actions-pool/providers/github-actions-provider
WIF_SERVICE_ACCOUNT=gcp-terraform-demo@gcp-terraform-demo-474514.iam.gserviceaccount.com
GCP_PROJECT_ID=gcp-terraform-demo-474514
```

**Workflow (`.github/workflows/ci-cd.yml`):**
```yaml
- name: Authenticate to Google Cloud
  uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
    service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}
```

**Benefits in this project:**
- ✅ No service account keys to manage
- ✅ Automatic credential rotation
- ✅ Limited to this specific repository
- ✅ Clear audit trail in GCP logs
- ✅ Secure by default

---

## Summary

### Key Takeaways

1. **KSA vs GSA:**
   - KSA = Identity inside Kubernetes (for K8s API access)
   - GSA = Identity in Google Cloud (for GCP API access)
   - They can be linked via GKE Workload Identity

2. **JSON Keys vs WIF:**
   - JSON Keys = Old method (long-lived, risky, manual rotation)
   - WIF = New method (keyless, automatic, secure)
   - Google strongly recommends WIF for all CI/CD pipelines

3. **This project uses:**
   - ✅ KSA `pickstream` for pod identity
   - ✅ GSA `gcp-terraform-demo@...` for CI/CD (via WIF)
   - ✅ Workload Identity Federation (no keys!)

### Best Practices

1. **Never commit service account keys to git**
2. **Use Workload Identity Federation for CI/CD**
3. **Use GKE Workload Identity to link KSA to GSA**
4. **Apply least privilege principle to all service accounts**
5. **Regularly audit service account permissions**
6. **Delete unused service account keys**

### Further Reading

- [Google Cloud: Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [GKE: Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [Best practices for service accounts](https://cloud.google.com/iam/docs/best-practices-service-accounts)
