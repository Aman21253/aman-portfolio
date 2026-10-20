# Aman Bansal: portfolio

A dark-first, interactive portfolio with a contact form and an AI chat assistant, served through an Nginx load balancer in front of three Node.js API replicas.

## Run it

You need Docker Desktop (running). Then, from this folder:

- Mac / Linux: `bash start.sh`
- Windows (PowerShell): `powershell -ExecutionPolicy Bypass -File start.ps1`

The script creates `.env` with random database passwords, asks for an optional Anthropic API key, builds everything and opens nothing else on your machine except **http://localhost:8080**.
Other commands: `down` (stop), `logs`, `reset` (stop and delete saved messages). Example: `bash start.sh logs`.

## What is inside

| Path | What it does |
| --- | --- |
| `site/index.html` | The whole website (content, styling, interactions, chat window). Edit the `const D=` block to change text. |
| `server/` | Express API: `/api/contact`, `/api/chat`, `/api/health`. |
| `nginx/` | Load balancer (least connections across `api1`, `api2`, `api3`) and first layer of rate limiting. |
| `scripts/make-knowledge.mjs` | Rebuilds what the AI chat knows from `site/index.html`. |
| `docker-compose.yml` | Nginx, three API replicas, MongoDB, Redis. Only port 8080 is exposed. |

## Security notes

- Every secret lives in `.env` (git-ignored). Compose refuses to start if a database password is missing.
- MongoDB and Redis require passwords and are not reachable from outside Docker.
- Rate limits: Nginx per IP (contact 6/min, chat 10/min, other API 10/s), plus the API per IP using Redis so the limits are shared by all replicas (contact 5/hour, chat 20 per 10 minutes).
- The Anthropic key stays on the server. The browser never sees it. Without a key the chat still works using built-in answers.

## After you edit the portfolio

1. Change `site/index.html`.
2. If you changed the content, run `node scripts/make-knowledge.mjs` so the AI chat knows the new facts.
3. Rebuild: `bash start.sh`.

## Checks

`cd server && npm install && npm test` runs quick tests of the contact and chat routes (no database needed).

## Troubleshooting

| Message or symptom | Fix |
| --- | --- |
| `Docker Compose is missing` | Install Docker Desktop, or with Homebrew run `brew install docker-compose` and `mkdir -p ~/.docker/cli-plugins && ln -sfn "$(brew --prefix)/opt/docker-compose/bin/docker-compose" ~/.docker/cli-plugins/docker-compose`. |
| `failed to connect to the docker API` | No Docker engine is running. Open Docker Desktop and wait for "Engine running" (or run `colima start` if you use Colima). Check with `docker info`. |
| Mac keychain pop-up on first start | Enter your Mac login password and click Always Allow. You do not need a Docker account: click Skip on the sign-in screen. |
| Port 8080 is already in use | In `docker-compose.yml` change `"8080:80"` to another port such as `"8081:80"`, set `CORS_ORIGIN` in `.env` to match, then run `bash start.sh` again. |
| The site never becomes ready | Run `bash start.sh logs` and read the last lines. |
| Database authentication failed | You deleted `.env` after the first run. Run `bash start.sh reset`, then `bash start.sh`. |

## Good to know

- If you delete `.env` after the first run, the new database password will not match the saved database. Run `bash start.sh reset` first.
- Contact messages are stored in MongoDB (database `portfolio`, collection `messages`). Set the `SMTP_*` values in `.env` to also receive them by email.
- To go live on a server, put HTTPS in front (for example Caddy or a cloud load balancer) and set `CORS_ORIGIN` to your domain.