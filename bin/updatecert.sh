#!/bin/bash


# Function to display progress over a given duration
display_progress() {
  local duration=$1
  local elapsed=0
  local progress=0
  local step=1  # How often to update the progress, in seconds

  echo -n "Waiting for services to stabilize: "

  while [ $elapsed -lt $duration ]; do
    sleep $step
    elapsed=$((elapsed + step))
    progress=$((elapsed * 100 / duration))
    echo -ne "$progress%"'\r'
  done

  echo "Done"
}



# Check if certbot is installed by checking its version
if ! certbot --version > /dev/null 2>&1; then
  echo "Certbot is not installed. Please install Certbot and try again."
  exit 1
fi

# Initialize an array to hold the domains
DOMAINS=()

# Parse command line options
while getopts "d:" opt; do
  case $opt in
    d)
      DOMAINS+=("${OPTARG}")  # Add the domain to the DOMAINS array
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# Check if at least one domain name was provided
if [ ${#DOMAINS[@]} -eq 0 ]; then
  echo "No domain names specified. Use the -d option to specify domains."
  exit 1
fi

# Validate each domain by checking its DNS record
for DOMAIN in "${DOMAINS[@]}"; do
  echo "Checking DNS for $DOMAIN..."
  if ! nslookup "$DOMAIN" > /dev/null; then
    echo "DNS lookup failed for $DOMAIN. Please check the domain name and try again."
    exit 1
  fi
done

echo "All domains have valid DNS records."

# Prepare the -d options for certbot
CERTBOT_DOMAINS=""
for DOMAIN in "${DOMAINS[@]}"; do
  CERTBOT_DOMAINS+=" -d $DOMAIN"
done

# Stop the T-Pot service
service tpot stop

# Obtain SSL certificates for the specified domains
eval "certbot certonly --standalone $CERTBOT_DOMAINS"

# Since the script supports multiple domains, choose one for the nginx certificate.
# This example uses the first domain in the list.
cp "/etc/letsencrypt/live/${DOMAINS[0]}/fullchain.pem" /data/nginx/cert/nginx.crt
cp "/etc/letsencrypt/live/${DOMAINS[0]}/privkey.pem" /data/nginx/cert/nginx.key

# Start the T-Pot service
service tpot start

# Wait for services to stabilize
display_progress 45

# Execute T-Pot's diagnostic script
/opt/tpot/bin/dps.sh
