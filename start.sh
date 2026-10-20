#!/usr/bin/env bash
# Mac / Linux launcher.   bash start.sh [up|down|logs|reset]
set -euo pipefail
cd "$(dirname "$0")"
cmd="${1:-up}"

command -v docker >/dev/null 2>&1 || { echo "Docker is not installed. Install Docker Desktop (https://www.docker.com/products/docker-desktop), start it, then run this again."; exit 1; }
if docker compose version >/dev/null 2>&1; then
  DC="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  DC="docker-compose"; echo "Note: using the older docker-compose command. Docker Compose v2 is recommended."
else
  echo "Docker Compose is missing. Fix it with ONE of these, then open a new terminal and run: bash start.sh"
  echo "  1) Install Docker Desktop for Mac (it includes Compose): https://www.docker.com/products/docker-desktop"
  echo "  2) If you installed Docker with Homebrew, run:"
  echo "       brew install docker-compose"
  echo "       mkdir -p ~/.docker/cli-plugins && ln -sfn \"\$(brew --prefix)/opt/docker-compose/bin/docker-compose\" ~/.docker/cli-plugins/docker-compose"
  exit 1
fi
docker info >/dev/null 2>&1 || { echo "Docker is installed but not running. Start Docker Desktop and try again."; exit 1; }

case "$cmd" in
  down)  $DC down; exit 0 ;;
  logs)  $DC logs -f --tail=100; exit 0 ;;
  reset) read -r -p "This stops everything and deletes saved contact messages. Continue? [y/N] " a; [ "$a" = "y" ] && $DC down -v; exit 0 ;;
  up)    ;;
  *)     echo "Usage: bash start.sh [up|down|logs|reset]"; exit 1 ;;
esac

rand() { if command -v openssl >/dev/null 2>&1; then openssl rand -hex 24; else head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n'; fi; }
get_env() { grep -E "^$1=" .env | head -1 | cut -d= -f2- || true; }
set_env() { if grep -qE "^$1=" .env; then sed -i.bak -E "s|^$1=.*|$1=$2|" .env && rm -f .env.bak; else echo "$1=$2" >> .env; fi; }

if [ ! -f .env ]; then
  echo "Creating .env with fresh random passwords..."
  sed -e "s|^MONGO_PASSWORD=.*|MONGO_PASSWORD=$(rand)|" -e "s|^REDIS_PASSWORD=.*|REDIS_PASSWORD=$(rand)|" .env.example > .env
  chmod 600 .env
fi

if [ -z "$(get_env ANTHROPIC_API_KEY)" ]; then
  key="${ANTHROPIC_API_KEY:-}"
  if [ -z "$key" ] && [ -t 0 ]; then
    read -r -s -p "Anthropic API key for the AI chat (press Enter to skip): " key; echo
  fi
  if [ -n "$key" ]; then set_env ANTHROPIC_API_KEY "$key"; fi
fi

echo "Building and starting. The first run takes a few minutes..."
$DC up --build -d

printf "Waiting for the site"
for _ in $(seq 1 60); do
  if curl -fsS http://localhost:8080/api/health >/dev/null 2>&1; then
    echo; echo "Your portfolio is running at http://localhost:8080"
    if [ -z "$(get_env ANTHROPIC_API_KEY)" ]; then echo "AI chat: using built-in answers. Add ANTHROPIC_API_KEY to .env and run this script again for live AI answers."; else echo "AI chat: live AI answers are on."; fi
    echo "Stop: bash start.sh down   |   Logs: bash start.sh logs"
    exit 0
  fi
  printf "."; sleep 2
done
echo; echo "The site did not become ready in time. See what went wrong with: bash start.sh logs"; exit 1