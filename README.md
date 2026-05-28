# se-pipeline-setup

Installer and service manager for the [se-pipeline](https://github.com/drakvai-sudo/se-pipeline) AI software engineering backend. Runs the full server stack locally via Docker Compose and installs the `se-pipeline` CLI binary in one step.

---

## What This Repo Contains

| File | Purpose |
|---|---|
| `setup.bat` / `setup.sh` | Fresh install — start server stack + install CLI binary |
| `update.bat` / `update.sh` | Pull latest server image + update CLI binary |
| `uninstall.bat` / `uninstall.sh` | Stop all services and remove data volumes |
| `docker-compose.yml` | Defines the 6-service stack |
| `.env.example` | Configuration template — copied to `.env` on first install |

---

## Prerequisites

- **Docker Desktop** — must be installed and running before any script is executed
  - Download: https://www.docker.com/products/docker-desktop/
- **Internet connection** — required to pull the server image and download the CLI binary
- **A Groq API key** — required to run the AI pipeline
  - Get one free at: https://console.groq.com

No Python, Git, or other tools are required on the user's machine.

---

## Quick Start

### Windows

Double-click `setup.bat`, or run from PowerShell:

```
.\setup.bat
```

### macOS / Linux

```bash
chmod +x setup.sh
./setup.sh
```

The script will:
1. Verify Docker Desktop is installed and running
2. Create `.env` from the template (if not already present)
3. Pull the latest `se-pipeline` server image
4. Start all services
5. Wait up to 80 seconds for the API to be ready
6. Prompt for your Groq API key and save it to `.env`
7. Download the `se-pipeline` CLI binary from GitHub Releases
8. Add the CLI to your PATH

After setup completes, open a **new terminal** and run:

```bash
se-pipeline --help
```

---

## Server Stack

The following services run as Docker containers on your machine:

| Service | Image | Port | Role |
|---|---|---|---|
| `api` | `drakvai/drakvai-sudo:se-pipeline-latest` | `8000` | FastAPI server — the CLI connects here |
| `worker` | `drakvai/drakvai-sudo:se-pipeline-latest` | — | Celery worker — executes pipeline tasks (concurrency: 2) |
| `beat` | `drakvai/drakvai-sudo:se-pipeline-latest` | — | Celery beat — periodic task scheduler |
| `migrate` | `drakvai/drakvai-sudo:se-pipeline-latest` | — | Runs database migrations on startup, then exits |
| `postgres` | `pgvector/pgvector:pg16` | — | PostgreSQL with pgvector — stores pipeline runs, history, RAG index |
| `redis` | `redis:7-alpine` | — | Message broker for Celery task queue |

The API is accessible at `http://localhost:8000`. To verify it is running:

```bash
curl http://localhost:8000/docs
```

A 200 response means the API is ready. The OpenAPI documentation is available at `http://localhost:8000/docs` in a browser.

### Service startup order

```
postgres (healthy) ──┐
                     ├──► migrate (runs + exits) ──► api
redis (healthy) ─────┘                          └──► worker ──► beat
```

`api` and `worker` do not start until `migrate` completes successfully. This guarantees the database schema is always up to date before the API accepts requests.

### Persistent data

Two Docker volumes are created and persist across restarts and updates:

| Volume | Contents |
|---|---|
| `pgdata` | PostgreSQL database — pipeline run history, agent state, RAG code index |
| `hf_cache` | HuggingFace model cache — avoids re-downloading embedding models |

---

## Configuration

### API keys and settings

All user-configurable values live in `.env` in this directory. The file is mounted into the running containers, so changes take effect on the next pipeline run — **no container restart is needed**.

Edit `.env` directly, or use the CLI once services are running:

```bash
se-pipeline config set GROQ_API_KEY gsk_...
se-pipeline config set DEEPSEEK_API_KEY sk-...
se-pipeline config list
```

### Available configuration keys

| Key | Required | Description |
|---|---|---|
| `GROQ_API_KEY` | Yes | Groq API key — used by the requirements and standards agents. All pipeline runs require this. Get one free at https://console.groq.com |
| `DEEPSEEK_API_KEY` | No (recommended) | DeepSeek API key — used by the coder agent for higher quality code generation. Without this the coder agent falls back to Groq (lower code quality). Get one at https://platform.deepseek.com |
| `SLACK_WEBHOOK_URL` | No | Slack incoming webhook URL — sends a notification when each pipeline run completes |
| `LLM_PRIMARY_PROVIDER` | No | Primary LLM provider (`deepseek` or `groq`). Default: `deepseek` |
| `LLM_FALLBACK_PROVIDER` | No | Fallback LLM provider if primary is unavailable. Default: `groq` |
| `SECRET_KEY` | No | Application secret key. Change this in any internet-facing deployment |

---

## Updating

To pull the latest server image and update the CLI binary:

### Windows

```
.\update.bat
```

### macOS / Linux

```bash
./update.sh
```

The update script:
1. Verifies Docker is running
2. Pulls the latest `se-pipeline` image (`docker compose pull`)
3. Restarts all services with the new image (`docker compose up -d --force-recreate`)
4. Waits for the API to be ready
5. Downloads the latest `se-pipeline` CLI binary from GitHub Releases and overwrites the existing one

Your `.env` configuration and all pipeline data in `pgdata` are preserved.

---

## Checking Service Status

```bash
# View running containers and their status
docker compose ps

# View live logs for a specific service
docker compose logs -f api
docker compose logs -f worker

# View logs for all services
docker compose logs -f
```

---

## Stopping and Starting Services

```bash
# Stop all services (data is preserved)
docker compose stop

# Start all services again
docker compose start

# Stop and remove containers (data volumes are preserved)
docker compose down

# Full restart
docker compose down && docker compose up -d
```

---

## Uninstalling

To stop all services and remove all data:

### Windows

```
.\uninstall.bat
```

### macOS / Linux

```bash
./uninstall.sh
```

The uninstall script:
1. Requires you to type `YES` to confirm
2. Runs `docker compose down -v` — stops containers and **deletes all data volumes** (pipeline history, RAG index, model cache)
3. Removes the `se-pipeline` CLI binary from `~/.local/bin`

Your `.env` file is **not deleted** — it is kept so you can reconfigure easily if you reinstall. Delete it manually if you no longer need it.

---

## Troubleshooting

### `setup.bat` / `setup.sh` fails with Docker error

Ensure Docker Desktop is open and fully started (the whale icon in the system tray should not be animating). Then re-run the setup script.

### API did not respond within 80s

The API may still be starting. Check service status:

```bash
docker compose ps
docker compose logs migrate
docker compose logs api
```

If `migrate` exited with a non-zero code, there was a database migration error. Check the logs and re-run `setup.bat` / `setup.sh`.

### CLI download failed during setup

The binary download requires internet access to GitHub. If it fails, the Docker services are still running — you can download the CLI manually from:

```
https://github.com/drakvai-sudo/se-pipeline-releases/releases
```

Save the appropriate binary for your platform to `~/.local/bin/`:

| Platform | Binary name | Save as |
|---|---|---|
| Windows | `se-pipeline-windows.exe` | `%USERPROFILE%\.local\bin\se-pipeline.exe` |
| macOS (Apple Silicon) | `se-pipeline-darwin-arm64` | `~/.local/bin/se-pipeline` |
| macOS (Intel) | `se-pipeline-darwin-x86_64` | `~/.local/bin/se-pipeline` |
| Linux | `se-pipeline-linux` | `~/.local/bin/se-pipeline` |

On macOS/Linux, make the binary executable:

```bash
chmod +x ~/.local/bin/se-pipeline
```

### `se-pipeline` command not found after install

The install script adds `~/.local/bin` to your PATH, but this only takes effect in new terminals. Open a new terminal window and try again.

On Windows, if it still does not work, add the directory manually:

```powershell
setx PATH "$env:USERPROFILE\.local\bin;$env:PATH"
```

Then open a new terminal.

### Pipeline run returns an error about missing API key

Set your Groq API key:

```bash
se-pipeline config set GROQ_API_KEY gsk_...
```

Or edit `.env` directly and save — the change takes effect on the next run.
