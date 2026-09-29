# Cloud Run Mapping

## Configuration Variables (Non-Secret)

These variables are application config that can be public. On Cloud Run, deploy with `--set-env-vars`:

```bash
gcloud run deploy app-service \
  --set-env-vars DATABASE_URL=postgresql://user:pass@host:5432/db \
  --set-env-vars LOG_LEVEL=info \
  --image gcr.io/project/envlab:latest
```

Or as a single comma-separated argument:

```bash
gcloud run deploy app-service \
  --set-env-vars DATABASE_URL=postgresql://...,LOG_LEVEL=info \
  --image gcr.io/project/envlab:latest
```

### Variables to inject at runtime:

- **DATABASE_URL** — database connection string (changes per environment: dev, staging, prod)
- **LOG_LEVEL** — logging verbosity level (info, debug, error, warn)

## Secrets (API Keys, Passwords)

Secrets are **never** baked into the image or passed as plaintext env vars. Store them in Secret Manager and reference them:

### 1. Create the secret in Google Cloud Secret Manager:

```bash
echo -n "sk_live_actual_api_key_here" | gcloud secrets create API_KEY --data-file=-
```

### 2. Grant Cloud Run service account access:

```bash
gcloud secrets add-iam-policy-binding API_KEY \
  --member=serviceAccount:PROJECT-compute@appspot.gserviceaccount.com \
  --role=roles/secretmanager.secretAccessor
```

### 3. Deploy with `--set-secrets`:

```bash
gcloud run deploy app-service \
  --set-secrets API_KEY=API_KEY:latest \
  --image gcr.io/project/envlab:latest
```

This injects `API_KEY` env var at runtime from Secret Manager; the actual value never appears in the image, command, or logs.

### Secrets to inject via Secret Manager:

- **API_KEY** — external API authentication token (rotated independently of code)

## Local Development → Cloud Run Mapping

| Local                                  | Cloud Run                                           | Why                                         |
| -------------------------------------- | --------------------------------------------------- | ------------------------------------------- |
| `docker run --env-file .env`           | `gcloud run deploy --set-env-vars`                  | Non-secret config injected at runtime       |
| `-e API_KEY=$API_KEY`                  | `--set-secrets API_KEY=<secret>:latest`             | Secrets from Secret Manager, never baked in |
| `docker exec … printenv`               | Cloud Run Console → Revisions → Variables & Secrets | Inspect what the service sees               |
| Remove hardcoded `ENV` from Dockerfile | Never bake secrets into image                       | Same principle: config outside the build    |

## Why this matters

1. **Config changes don't require rebuilds** — update --set-env-vars on Cloud Run and a new revision deploys instantly; no image rebuild.
2. **Secrets stay safe** — API keys in Secret Manager can be rotated with one command; if compromised, only Secret Manager needs an update, not a new image push to every environment.
3. **Same image everywhere** — build once, deploy to dev/staging/prod with different injected values; no per-environment images.

## Summary

- **Config (DATABASE_URL, LOG_LEVEL)** → `--set-env-vars` on Cloud Run (same as local `--env-file`)
- **Secrets (API_KEY)** → `--set-secrets` pointing to Secret Manager (same as local `-e API_KEY=$API_KEY` from shell)
- **Dockerfile** → Never `ENV` a secret; never hardcode config; let Cloud Run inject at runtime
