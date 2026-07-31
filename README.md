# Portfolio Docker App
A **practice / learning project** that demonstrates a simple static website containerized with Docker and deployed to AWS EC2 using CI/CD pipelines (GitHub Actions and GitLab CI).
> This codebase is intentionally minimal. The focus is on DevOps workflow concepts — not a production portfolio frontend.
---
## What This Project Demonstrates
| Concept | How it appears here |
|--------|----------------------|
| Containerization | Nginx serves static HTML/CSS/JS inside a Docker image |
| Immutable artifacts | Each build produces a tagged Docker image pushed to Docker Hub |
| CI/CD | Push to Git → automatic build, push, and deploy |
| Environments | `main` → production path; `develop` → development path |
| Remote deploy | GitHub Actions SSHs into EC2 and runs Docker Compose |
| Rollback | Manual workflow pins a previous image tag by Git SHA |
| Health checks | Docker `HEALTHCHECK` probes the Nginx HTTP endpoint |
| Secrets management | Credentials stored as GitHub Secrets / CI variables |
---
## Project Structure
```
portfolio-docker-app/
├── index.html                 # Static portfolio / demo page
├── style.css                  # Basic page styling
├── script.js                  # Client-side console log
├── Dockerfile                 # Image definition (Nginx + app files)
├── .dockerignore              # Files excluded from build context
├── .gitlab-ci.yml             # GitLab CI: build & push image
└── .github/workflows/
    ├── docker-build.yml       # Production: build → push → deploy (main)
    ├── deploy-dev.yml         # Development: build → push → deploy (develop)
    └── rollback.yml           # Manual rollback to a previous image tag
```
---
## Application Layer
A static site (no backend framework):
- **HTML** — page structure and content
- **CSS** — centered layout, simple typography
- **JavaScript** — logs a load message in the browser console
The site is served by **Nginx** inside the container (not Node, Python, etc.).
---
## Containerization (Docker)
### Dockerfile logic
1. **Base image** — `nginx:latest` (official Nginx image)
2. **Install tooling** — `wget` for the health check probe
3. **Clear default site** — remove Nginx’s default HTML
4. **Copy app files** — project files → `/usr/share/nginx/html`
5. **Expose port** — container listens on port `80`
6. **Foreground process** — `nginx -g "daemon off;"` so Docker keeps the container alive (PID 1 pattern)
7. **Health check** — every 30s, `wget --spider` against `http://localhost`; fail after 3 retries
### Key Docker terms used
| Term | Meaning in this project |
|------|-------------------------|
| **Image** | Immutable package of Nginx + your static files |
| **Container** | Running instance of that image on EC2 |
| **Tag** | Label such as `latest`, `dev-latest`, or a Git commit SHA |
| **Build context** | Files sent to the Docker daemon (filtered by `.dockerignore`) |
| **Layer cache** | Each Dockerfile instruction can reuse a previous layer |
| **EXPOSE** | Documents the container port (does not publish it by itself) |
| **HEALTHCHECK** | Docker marks the container healthy/unhealthy based on a probe |
| **Image prune** | Removes unused images after deploy to free disk |
### `.dockerignore`
Excludes `.git`, `.gitignore`, `README.md`, and `.vscode` from the build context so images stay smaller and builds stay faster.
---
## CI/CD Overview
### Dual CI platforms (practice)
This repo shows **two** CI systems for learning:
| Platform | File | What it does |
|----------|------|--------------|
| **GitHub Actions** | `.github/workflows/*.yml` | Build, push, deploy, rollback |
| **GitLab CI** | `.gitlab-ci.yml` | Build and push (no deploy step) |
---
## GitHub Actions Workflows
### 1. Production — `docker-build.yml`
**Trigger:** `push` to `main`
**Pipeline logic:**
```
Checkout → Login Docker Hub → Build (latest + SHA) → Push → SSH to EC2 → Compose pull/up → Prune
```
Steps in order:
1. **Checkout** (`actions/checkout@v4`) — clone the repo onto the runner
2. **Docker Hub login** (`docker/login-action@v3`) — use secrets for auth
3. **Build** — tag as:
   - `{user}/portfolio-app:latest`
   - `{user}/portfolio-app:{github.sha}`
4. **Push** both tags to Docker Hub
5. **Deploy** via `appleboy/ssh-action`:
   - `cd /opt/portfolio-app`
   - `docker compose pull`
   - `docker compose up -d`
   - `docker image prune -f`
   - `docker ps`
### 2. Development — `deploy-dev.yml`
**Trigger:** `push` to `develop`
Same pattern as production, with differences:
| Aspect | Production (`main`) | Development (`develop`) |
|--------|---------------------|-------------------------|
| Image tags | `latest`, `{sha}` | `dev-latest`, `dev-{sha}` |
| EC2 path | `/opt/portfolio-app` | `/opt/portfolio-dev` |
| Env file | (compose default) | Writes `IMAGE_TAG=dev-latest` to `.env` |
This is a simple **environment separation** pattern: same image name, different tags and deploy directories.
### 3. Rollback — `rollback.yml`
**Trigger:** `workflow_dispatch` (manual) with input `image_tag` (Git SHA)
**Logic:**
1. SSH into EC2
2. Use `sed` to rewrite the `image:` line in `docker-compose.yml` to the chosen tag
3. `docker compose pull` + `docker compose up -d`
4. Prune unused images
This is a **manual rollback** to a previously pushed immutable image — no rebuild required.
---
## GitLab CI — `.gitlab-ci.yml`
**Image / service:** `docker:24` + **Docker-in-Docker (DinD)** (`docker:24-dind`)
**Stage:** `build` (only)
**Logic on `main`:**
1. Login to Docker Hub with `DOCKER_USERNAME` / `DOCKER_PASSWORD`
2. Build `$IMAGE_NAME:latest`
3. Tag with `$CI_COMMIT_SHORT_SHA`
4. Push both tags
**Terms:**
| Term | Meaning |
|------|---------|
| **DinD** | Docker daemon inside a CI job container so `docker build` works |
| **overlay2** | Storage driver for Docker layers |
| **`$CI_COMMIT_SHORT_SHA`** | GitLab predefined variable — short commit hash |
| **`only: main`** | Job runs only for the `main` branch |
---
## Deployment Architecture (Logical Flow)
```
Developer
   │  git push
   ▼
GitHub / GitLab
   │  CI trigger
   ▼
Runner (ubuntu-latest / docker:24-dind)
   │  docker build + docker push
   ▼
Docker Hub (image registry)
   │  pull on server
   ▼
AWS EC2
   │  docker compose up -d
   ▼
Nginx container (port 80)
   │  (optional host reverse proxy + SSL — mentioned in page content)
   ▼
Browser
```
Typical end-to-end path described in the HTML content:
1. Edit locally (e.g. VS Code)
2. Commit and push to GitHub
3. Actions checks out the repo and builds a new image
4. Authenticates to Docker Hub via secrets
5. Pushes the image
6. SSHs to EC2
7. `docker compose pull` + `docker compose up -d`
8. Site updates with no manual server login for day-to-day deploys
---
## Tools & Technologies
| Category | Tool / Tech |
|----------|-------------|
| Version control | Git, GitHub, GitLab |
| Editor (example workflow) | VS Code |
| Container runtime | Docker, Docker Compose |
| Web server (in container) | Nginx |
| CI/CD | GitHub Actions, GitLab CI |
| Registry | Docker Hub |
| Cloud host | AWS EC2 |
| Remote access | SSH (`appleboy/ssh-action`) |
| Reverse proxy / TLS (host-side, referenced) | Nginx + SSL |
---
## GitHub Secrets Expected
These are referenced by the Actions workflows (configure in repo **Settings → Secrets and variables → Actions**):
| Secret | Purpose |
|--------|---------|
| `DOCKERHUB_USERNAME` | Docker Hub account name |
| `DOCKERHUB_TOKEN` | Docker Hub access token |
| `EC2_HOST` | EC2 public IP or DNS |
| `EC2_USERNAME` | SSH user (e.g. `ubuntu`) |
| `EC2_SSH_KEY` | Private SSH key for the instance |
GitLab CI expects CI/CD variables: `DOCKER_USERNAME`, `DOCKER_PASSWORD`.
---
## Image Tagging Strategy
| Tag pattern | When | Use |
|-------------|------|-----|
| `latest` | Push to `main` | Convenience / current production pointer |
| `{full Git SHA}` | Push to `main` | Immutable production artifact (rollback target) |
| `dev-latest` | Push to `develop` | Current development pointer |
| `dev-{SHA}` | Push to `develop` | Immutable development artifact |
**Why tag with SHA?**  
`latest` moves; a commit SHA never changes. Rollback and audits rely on immutable tags.
---
## Core DevOps Terms (Glossary)
| Term | Short definition |
|------|------------------|
| **CI (Continuous Integration)** | Automatically build/test on every push |
| **CD (Continuous Delivery/Deployment)** | Automatically ship artifacts / update the server |
| **Pipeline** | Ordered stages/jobs (checkout → build → push → deploy) |
| **Runner** | Machine that executes CI jobs (`ubuntu-latest`, etc.) |
| **Artifact** | Build output — here, a Docker image |
| **Registry** | Store for images (Docker Hub) |
| **Infrastructure as Code (light)** | Deploy steps declared in YAML workflows |
| **Immutable deployment** | Deploy by changing which image tag runs, not by editing files on the server |
| **Rollback** | Redeploy a known-good previous image tag |
| **Reverse proxy** | Host Nginx (or similar) in front of the app for routing/SSL |
| **SSL/TLS** | HTTPS encryption terminating at the proxy |
| **Secrets** | Credentials injected at runtime, not committed to Git |
| **Branch strategy** | `main` = prod path; `develop` = dev path |
| **Idempotent-ish deploy** | `compose pull` + `up -d` brings the desired state without unique one-off scripts |
---
## Local Quick Start (optional practice)
```bash
# Build
docker build -t portfolio-app:local .
# Run
