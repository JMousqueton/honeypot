#!/usr/bin/env bash
#
# letsencrypt.sh - Issue / renew a Let's Encrypt certificate for the T-Pot / Cohesity One
#                  nginx web UI on port 64297, using the HTTP-01 challenge.
#
# Because honeypots occupy ports 80 and 443, this script temporarily stops the
# honeypot that binds host port 80 (snare / Tanner), runs certbot in standalone
# mode on port 80, then restarts it and reloads nginx. Run it on the T-Pot HOST.
#
# The resulting fullchain.pem / privkey.pem are copied to:
#   <data>/nginx/cert/<domain>/   ->  mounted read-only in nginx at
#   /etc/nginx/cert/<domain>/     ->  referenced by tpotweb.conf
#
# Requirements:
#   - DNS A/AAAA record for the domain must point at this host's PUBLIC IP.
#   - Inbound TCP/80 must be reachable from the internet during issuance.
#   - Docker + docker compose, run as root (or a docker-capable user).
#
# Usage:
#   sudo ./letsencrypt.sh                 # issue/renew (production)
#   sudo ./letsencrypt.sh -s              # use Let's Encrypt STAGING (for testing)
#   sudo ./letsencrypt.sh -e me@dom.tld   # override contact email
#   sudo ./letsencrypt.sh -h              # help
#
# Renewal: LE certs last ~90 days. Re-run this script (e.g. from cron/systemd timer)
#   0 3 * * 1  cd /home/<user>/tpotce && ./letsencrypt.sh >> data/nginx/letsencrypt/renew.log 2>&1
#

set -euo pipefail

# --- Config -----------------------------------------------------------------
DOMAIN="pot-de-miel.julien.io"
EMAIL="admin@julien.io"          # change or override with -e
PORT80_SERVICE="snare"           # honeypot binding host port 80 (Tanner frontend)
NGINX_CONTAINER="nginx"
STAGING=false

usage() {
    awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"
    exit "${1:-0}"
}

while getopts ":se:h" opt; do
    case "$opt" in
        s) STAGING=true ;;
        e) EMAIL="$OPTARG" ;;
        h) usage 0 ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage 1 ;;
    esac
done

# --- Resolve paths (run from project root so docker compose finds the stack) -
cd "$(dirname "$0")"

# Derive the data path from .env (default ./data), then the cert + LE state dirs.
DATA_PATH="./data"
if [ -f .env ]; then
    v=$(grep -E '^TPOT_DATA_PATH=' .env | tail -1 | cut -d= -f2-)
    [ -n "${v:-}" ] && DATA_PATH="$v"
fi
CERT_DIR="${DATA_PATH}/nginx/cert/${DOMAIN}"
LE_ETC="${DATA_PATH}/nginx/letsencrypt/etc"
LE_LIB="${DATA_PATH}/nginx/letsencrypt/lib"
mkdir -p "$CERT_DIR" "$LE_ETC" "$LE_LIB"

STAGING_FLAG=""
$STAGING && STAGING_FLAG="--staging"

echo "###########################################"
echo "# Let's Encrypt (HTTP-01) for ${DOMAIN}"
echo "#   email:     ${EMAIL}"
echo "#   port-80 hp: ${PORT80_SERVICE} (stopped during issuance)"
echo "#   staging:   ${STAGING}"
echo "#   cert out:  ${CERT_DIR}"
echo "###########################################"
echo

# --- Always restart the honeypot, even on error ------------------------------
restart_hp() {
    echo "==> Restarting honeypot '${PORT80_SERVICE}' ..."
    docker compose start "$PORT80_SERVICE" >/dev/null 2>&1 \
        || docker compose up -d "$PORT80_SERVICE" >/dev/null 2>&1 \
        || echo "WARNING: could not restart ${PORT80_SERVICE} - do it manually!" >&2
}
trap restart_hp EXIT

# --- 1. Free port 80 --------------------------------------------------------
echo "==> Stopping honeypot '${PORT80_SERVICE}' to free port 80 ..."
docker compose stop "$PORT80_SERVICE"

# --- 2. Obtain / renew the certificate --------------------------------------
echo "==> Running certbot (standalone, HTTP-01) ..."
docker run --rm \
    -p 80:80 \
    -v "$(pwd)/${LE_ETC}:/etc/letsencrypt" \
    -v "$(pwd)/${LE_LIB}:/var/lib/letsencrypt" \
    certbot/certbot certonly \
        --standalone \
        --preferred-challenges http \
        --non-interactive --agree-tos \
        -m "$EMAIL" \
        ${STAGING_FLAG} \
        -d "$DOMAIN"

# --- 3. Deploy certs into the nginx-mounted cert dir ------------------------
LIVE="${LE_ETC}/live/${DOMAIN}"
if [ ! -f "${LIVE}/fullchain.pem" ]; then
    echo "ERROR: certbot did not produce ${LIVE}/fullchain.pem" >&2
    exit 1
fi
echo "==> Deploying certificate to ${CERT_DIR} ..."
cp -L "${LIVE}/fullchain.pem" "${CERT_DIR}/fullchain.pem"
cp -L "${LIVE}/privkey.pem"   "${CERT_DIR}/privkey.pem"
chmod 644 "${CERT_DIR}/fullchain.pem"
chmod 600 "${CERT_DIR}/privkey.pem"

# --- 4. Reload nginx to pick up the new cert --------------------------------
echo "==> Reloading nginx ..."
if docker exec "$NGINX_CONTAINER" nginx -t >/dev/null 2>&1; then
    docker exec "$NGINX_CONTAINER" nginx -s reload
elif docker kill -s HUP "$NGINX_CONTAINER" >/dev/null 2>&1; then
    echo "    (sent SIGHUP to ${NGINX_CONTAINER})"
else
    echo "WARNING: could not reload ${NGINX_CONTAINER}; restart it manually." >&2
fi

echo
echo "###########################################"
echo "# Done. https://${DOMAIN}:64297/map/ now uses the Let's Encrypt cert."
echo "###########################################"
