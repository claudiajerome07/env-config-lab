# Testing & Validation Guide

## Summary of Fixes

### 1. **Removed Hardcoded Secrets** ✅

- **Problem**: `ENV API_KEY=super-secret-key` in Dockerfile exposed sensitive data
- **Fix**: Removed from Dockerfile; secrets injected at runtime via `-e API_KEY=$API_KEY`
- **Why**: Secrets baked into images are copied into every layer, visible in `docker history`, and shipped everywhere the image goes

### 2. **Fixed Environment Variable Typo** ✅

- **Problem**: Dockerfile had `ENV LOGLEVEL=info` but app reads `process.env.LOG_LEVEL`
- **Fix**: Removed `LOGLEVEL` typo from Dockerfile; now `LOG_LEVEL` injected via `--env-file .env`
- **Why**: Typos cause undefined variables, even if set; app falls back to error state

### 3. **Added Missing DATABASE_URL** ✅

- **Problem**: App required `DATABASE_URL` but nothing provided it
- **Fix**: Created `.env` with `DATABASE_URL=postgresql://...`; loaded via `--env-file .env`
- **Why**: Missing config causes immediate crashes; must be injected from outside

### 4. **Protected .env from Git** ✅

- **Problem**: .env can contain real secrets, accidental commits leak credentials
- **Fix**: Added `.env` to `.gitignore`
- **Why**: Once committed, Git history keeps secrets forever; rotation is the only remedy

### 5. **Created .env.example** ✅

- **Problem**: Without an example, teammates don't know what config to set
- **Fix**: Committed `.env.example` with placeholders; `.env` with actual values in `.gitignore`
- **Why**: Example shows structure; real file stays local and private

### 6. **Mapped to Cloud Run** ✅

- **Problem**: Local `--env-file` doesn't work on Cloud Run
- **Fix**: Documented `--set-env-vars` for config, `--set-secrets` for API keys
- **Why**: Same principle (config outside image), different plumbing

---

## Local Testing Steps

### Before Fix (demonstrates the failures)

```bash
# Show the broken state
docker build -t envlab-broken .  # (using old Dockerfile with hardcoded secrets)
docker run --name app-broken envlab-broken

# Observe:
# Error: DATABASE_URL is undefined
docker logs app-broken
docker history envlab-broken | grep API_KEY  # Secret visible in image layers
docker exec app-broken printenv | grep LOG_LEVEL  # Will show LOGLEVEL (typo) or nothing
```

### After Fix (clean startup)

```bash
# Build the fixed image
docker build -t envlab .

# Run with config injected via --env-file
docker run --name app-fixed --env-file .env envlab

# Verify clean startup
docker logs app-fixed
# Expected output:
#   Starting app with log level: info
#   Server is running on port 3000

# Verify variables are present
docker exec app-fixed printenv | grep -E "DATABASE_URL|LOG_LEVEL|API_KEY"
# Should show all three (or at least DATABASE_URL and LOG_LEVEL)

# Verify clean history (no secrets baked in)
docker history envlab | grep -i "api_key"
# Should show nothing (clean)

# Test the health endpoint
curl http://localhost:3000/health
# Should return: {"status":"ok"}
```

### Cleanup

```bash
docker rm app-broken app-fixed 2>/dev/null
docker rmi envlab-broken envlab 2>/dev/null
```

---

## The Four Faults Addressed

| Fault             | Symptom                                 | Fix                                       | Verification                                       |
| ----------------- | --------------------------------------- | ----------------------------------------- | -------------------------------------------------- |
| **Missing**       | `DATABASE_URL is undefined`             | Add to `.env`                             | `docker exec app printenv \| grep DATABASE_URL`    |
| **Wrong value**   | `ECONNREFUSED` to old host              | Update `.env`                             | `docker exec app printenv DATABASE_URL`            |
| **Typo**          | `LOG_LEVEL` undefined, uses fallback    | Remove `LOGLEVEL`, inject `LOG_LEVEL`     | `docker exec app printenv \| grep LOG_LEVEL`       |
| **Leaked secret** | `docker history` shows `API_KEY=sk_...` | Remove from Dockerfile, inject at runtime | `docker history \| grep API_KEY` (should be empty) |

---

## Files Changed

| File                           | Change                                           | Reason                                    |
| ------------------------------ | ------------------------------------------------ | ----------------------------------------- |
| **Dockerfile**                 | Removed `ENV API_KEY=...` and `ENV LOGLEVEL=...` | Config lives outside image                |
| **.env**                       | Created with real values                         | Dev/test environment config (git-ignored) |
| **.env.example**               | Created with placeholders                        | Template for teammates to copy and fill   |
| **.gitignore**                 | Added `.env`                                     | Prevent accidental secret commits         |
| **docs/cloud-run-template.md** | Filled with `--set-env-vars` and `--set-secrets` | Map local fix to cloud deployment         |

---

## Debugging Toolkit Reference

```bash
# See which variables the running container actually sees
docker exec <container> printenv

# See one specific variable
docker exec <container> printenv DATABASE_URL

# See the startup logs and errors
docker logs <container>

# Check if a secret was baked into the image layers
docker history <image>

# Re-run with corrected config and verify
docker run --env-file .env -e API_KEY=$API_KEY <image>
```

---

## Summary

✅ **Config principle**: One image, many environments. Config lives outside the build.  
✅ **Secrets principle**: Never hardcode; inject at runtime, keep out of git.  
✅ **Verification**: `docker logs` + `docker exec printenv` catch all four faults.  
✅ **Cloud mapping**: Local `--env-file` → `--set-env-vars` on Cloud Run; local `-e API_KEY=$API_KEY` → `--set-secrets` with Secret Manager.

The fixes are complete, tested locally, and documented for Cloud Run.
