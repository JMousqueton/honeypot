#!/usr/bin/env bash
#
# letsencrypt.sh - Issue / renew a Let's Encrypt certificate for the T-Pot / Cohesity One
#                  nginx web UI on port 64297, using the HTTP-01 challenge.
#
# TARGET can be a DOMAIN or a public IP ADDRESS:
#   - Domain  -> standard ~90-day certificate.
#   - IP addr -> Let's Encrypt "shortlived" profile, 6-day validity (LE requirement,
#                GA since 2026-01-15). Only HTTP-01 / TLS-ALPN-01 are allowed for IPs.
#                => you MUST renew every ~2 days (run this from a daily timer).
#
# Because honeypots occupy ports 80 and 443, this script temporarily stops the
# honeypot that binds host port 80 (snare / Tanner), runs certbot in standalone
# mode on port 80, then restarts it and reloads nginx. Run it on the T-Pot HOST.
#
# The resulting cert is copied to the host cert dir as nginx.crt / nginx.key:
#   <data>/nginx/cert/nginx.crt|nginx.key  ->  bind-mounted read-only into nginx
#   at /etc/nginx/cert/  ->  referenced by tpotweb.conf. The cert stays on the
#   HOST and is only read through the mount; nothing cert-related is baked in.
#
# Requirements:
#   - TARGET must resolve/point to this host's PUBLIC IP (for a domain, an A/AAAA
#     record; for an IP cert, this host must actually own that public IP).
#   - Inbound TCP/80 must be reachable from the internet during issuance.
#   - Docker + docker compose, run as root. IP certs need certbot >= 5.3.0
#     (certbot/certbot:latest satisfies this).
#
# Usage:
#   sudo ./letsencrypt.sh                 # issue/renew (production)
#   sudo ./letsencrypt.sh -s              # use Let's Encrypt STAGING (for testing)
#   sudo ./letsencrypt.sh -f              # force renewal (e.g. switch staging -> prod)
#   sudo ./letsencrypt.sh -t 1.2.3.4      # override target (domain or IP)
#   sudo ./letsencrypt.sh -e me@dom.tld   # override contact email
#   sudo ./letsencrypt.sh -h              # help
#
# Renewal timer (IP cert = 6-day life, so run DAILY):
#   0 3 * * *  cd /home/<user>/tpotce && ./letsencrypt.sh >> data/nginx/letsencrypt/renew.log 2>&1
#

set -euo pipefail

# --- Config -----------------------------------------------------------------
TARGET="149.202.86.189"          # domain OR public IP; override with -t
EMAIL="admin@julien.io"          # change or override with -e
PORT80_SERVICE="snare"           # honeypot binding host port 80 (Tanner frontend)
NGINX_CONTAINER="nginx"
STAGING=false
FORCE=false

usage() {
    awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"
    exit "${1:-0}"
}

while getopts ":sft:e:h" opt; do
    case "$opt" in
        s) STAGING=true ;;
        f) FORCE=true ;;
        t) TARGET="$OPTARG" ;;
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
# nginx reads these two files from the host via the bind mount
# ${DATA_PATH}/nginx/cert/ -> /etc/nginx/cert/ (read-only). We overwrite the
# self-signed pair tpotinit created, so nothing cert-related is baked in the image.
CERT_DIR="${DATA_PATH}/nginx/cert"
LE_ETC="${DATA_PATH}/nginx/letsencrypt/etc"
LE_LIB="${DATA_PATH}/nginx/letsencrypt/lib"
mkdir -p "$CERT_DIR" "$LE_ETC" "$LE_LIB"

# --- Detect IP vs domain and build certbot identifier flags -----------------
# IP certs require the short-lived ACME profile; only HTTP-01/TLS-ALPN-01 work.
if [[ "$TARGET" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || [[ "$TARGET" == *:*:* ]]; then
    IS_IP=true
    CERT_ID_ARGS=(--ip-address "$TARGET" --preferred-profile shortlived)
    KIND="IP address (shortlived / 6-day profile)"
else
    IS_IP=false
    CERT_ID_ARGS=(-d "$TARGET")
    KIND="domain (~90-day)"
fi

STAGING_FLAG=""
$STAGING && STAGING_FLAG="--staging"
FORCE_FLAG=""
$FORCE && FORCE_FLAG="--force-renewal"

echo "###########################################"
echo "# Let's Encrypt (HTTP-01) for ${TARGET}"
echo "#   type:      ${KIND}"
echo "#   email:     ${EMAIL}"
echo "#   port-80 hp: ${PORT80_SERVICE} (stopped during issuance)"
echo "#   staging:   ${STAGING}"
echo "#   cert out:  ${CERT_DIR}/nginx.crt|nginx.key"
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
        --cert-name "$TARGET" \
        ${STAGING_FLAG} \
        ${FORCE_FLAG} \
        "${CERT_ID_ARGS[@]}"

# --- 3. Deploy certs into the nginx-mounted cert dir ------------------------
# certbot may report "not yet due for renewal" (cert already valid) - that is
# fine, we still deploy the existing cert. Resolve the live dir, tolerating a
# suffixed lineage name (e.g. <target>-0001) from earlier runs.
LIVE="${LE_ETC}/live/${TARGET}"
if [ ! -f "${LIVE}/fullchain.pem" ]; then
    LIVE=$(find "${LE_ETC}/live" -maxdepth 1 -type d -name "${TARGET}*" 2>/dev/null | sort | tail -1)
fi
if [ -z "${LIVE:-}" ] || [ ! -f "${LIVE}/fullchain.pem" ]; then
    echo "ERROR: no certificate found under ${LE_ETC}/live/ for ${TARGET}." >&2
    echo "       Check: sudo ls -la ${LE_ETC}/live/" >&2
    exit 1
fi
echo "==> Using certificate lineage: ${LIVE}"

# Where does the RUNNING nginx expect its cert? The config is baked into the
# image and can differ between builds (e.g. nginx.crt vs a per-domain path), so
# ask the container instead of assuming. Fall back to nginx.crt if nginx is down.
CRTPATH=$(docker exec "$NGINX_CONTAINER" sh -c "grep -m1 'ssl_certificate ' /etc/nginx/conf.d/tpotweb.conf 2>/dev/null | grep -oE '/etc/nginx/cert/[^; ]+'" 2>/dev/null || true)
KEYPATH=$(docker exec "$NGINX_CONTAINER" sh -c "grep -m1 'ssl_certificate_key' /etc/nginx/conf.d/tpotweb.conf 2>/dev/null | grep -oE '/etc/nginx/cert/[^; ]+'" 2>/dev/null || true)
[ -n "$CRTPATH" ] || CRTPATH="/etc/nginx/cert/nginx.crt"
[ -n "$KEYPATH" ] || KEYPATH="/etc/nginx/cert/nginx.key"
DEST_CRT="${CERT_DIR}/${CRTPATH#/etc/nginx/cert/}"
DEST_KEY="${CERT_DIR}/${KEYPATH#/etc/nginx/cert/}"

echo "==> Deploying certificate to ${DEST_CRT} | ${DEST_KEY} ..."
mkdir -p "$(dirname "$DEST_CRT")" "$(dirname "$DEST_KEY")"
cp -L "${LIVE}/fullchain.pem" "$DEST_CRT"
cp -L "${LIVE}/privkey.pem"   "$DEST_KEY"
chmod 644 "$DEST_CRT"
chmod 600 "$DEST_KEY"

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
echo "# Done. https://${TARGET}:64297/map/ now uses the Let's Encrypt cert."
$IS_IP && echo "# NOTE: IP cert is valid ~6 days - ensure a DAILY renewal timer is set."
echo "###########################################"
