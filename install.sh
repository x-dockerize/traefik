#!/usr/bin/env bash
set -e

ENV_EXAMPLE=".env.example"
ENV_FILE=".env"
MIDDLEWARES_EXAMPLE=".docker/traefik/conf/middlewares.yml.example"
MIDDLEWARES_FILE=".docker/traefik/conf/middlewares.yml"

# --------------------------------------------------
# Kontroller
# --------------------------------------------------
if [ ! -f "$ENV_EXAMPLE" ]; then
  echo "❌ $ENV_EXAMPLE bulunamadı."
  exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
  cp "$ENV_EXAMPLE" "$ENV_FILE"
  echo "✅ $ENV_EXAMPLE → $ENV_FILE kopyalandı"
else
  echo "ℹ️  $ENV_FILE mevcut, güncellenecek"
fi

if [ ! -f "$MIDDLEWARES_FILE" ]; then
  cp "$MIDDLEWARES_EXAMPLE" "$MIDDLEWARES_FILE"
  echo "✅ $MIDDLEWARES_EXAMPLE → $MIDDLEWARES_FILE kopyalandı"
else
  echo "ℹ️  $MIDDLEWARES_FILE mevcut, dokunulmadı"
fi

# --------------------------------------------------
# Yardımcı Fonksiyonlar
# --------------------------------------------------
set_env() {
  local key="$1"
  local value="$2"

  if grep -q "^${key}=" "$ENV_FILE"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
  else
    echo "${key}=${value}" >> "$ENV_FILE"
  fi
}

# --------------------------------------------------
# Kullanıcıdan Gerekli Bilgiler
# --------------------------------------------------
read -rp "WILDCARD_DOMAIN (örn: example.com): " WILDCARD_DOMAIN
read -rp "LETSENCRYPT_EMAIL: " LETSENCRYPT_EMAIL
read -rp "CLOUDFLARE_DNS_API_TOKEN: " CLOUDFLARE_DNS_API_TOKEN

echo
echo "--- Dashboard Hostları ---"
read -rp "TRAEFIK_DASHBOARD_HOST (boş bırakılırsa: traefik.${WILDCARD_DOMAIN}): " INPUT_TRAEFIK_HOST
TRAEFIK_DASHBOARD_HOST="${INPUT_TRAEFIK_HOST:-traefik.${WILDCARD_DOMAIN}}"

read -rp "CROWDSEC_DASHBOARD_HOST (boş bırakılırsa: crowdsec.${WILDCARD_DOMAIN}): " INPUT_CROWDSEC_HOST
CROWDSEC_DASHBOARD_HOST="${INPUT_CROWDSEC_HOST:-crowdsec.${WILDCARD_DOMAIN}}"

# --------------------------------------------------
# Docker GID — otomatik tespit
# --------------------------------------------------
CROWDSEC_GID=$(getent group docker | cut -d: -f3)
if [ -z "$CROWDSEC_GID" ]; then
  echo "⚠️  docker grubu bulunamadı, CROWDSEC_GID manuel giriniz:"
  read -rp "CROWDSEC_GID: " CROWDSEC_GID
else
  echo "ℹ️  CROWDSEC_GID otomatik tespit edildi: $CROWDSEC_GID"
fi

# --------------------------------------------------
# Docker Network
# --------------------------------------------------
NETWORK_NAME="traefik-network"
if docker network inspect "$NETWORK_NAME" > /dev/null 2>&1; then
  echo "ℹ️  Docker network '$NETWORK_NAME' zaten mevcut"
else
  docker network create "$NETWORK_NAME"
  echo "✅ Docker network '$NETWORK_NAME' oluşturuldu"
fi

# --------------------------------------------------
# .env Güncelle
# --------------------------------------------------
set_env WILDCARD_DOMAIN              "$WILDCARD_DOMAIN"
set_env LETSENCRYPT_EMAIL            "$LETSENCRYPT_EMAIL"
set_env CLOUDFLARE_DNS_API_TOKEN     "$CLOUDFLARE_DNS_API_TOKEN"
set_env TRAEFIK_DASHBOARD_HOST       "$TRAEFIK_DASHBOARD_HOST"
set_env CROWDSEC_DASHBOARD_HOST      "$CROWDSEC_DASHBOARD_HOST"
set_env CROWDSEC_GID                 "$CROWDSEC_GID"

# --------------------------------------------------
# Sonuçları Göster
# --------------------------------------------------
echo
echo "==============================================="
echo "✅ Traefik .env başarıyla hazırlandı!"
echo "-----------------------------------------------"
echo "🌐 Traefik   : https://$TRAEFIK_DASHBOARD_HOST"
echo "🛡️ CrowdSec  : https://$CROWDSEC_DASHBOARD_HOST"
echo "-----------------------------------------------"
echo "⚠️ Kurulum tamamlanmadan önce yapılması gerekenler:"
echo ""
echo " 1. Önce sadece CrowdSec'i başlatın:"
echo "     docker compose up -d crowdsec"
echo ""
echo "  2. Traefik bouncer API key üretin ve .env'e ekleyin:"
echo "     docker exec crowdsec cscli bouncers add traefik-bouncer"
echo "     → CROWDSEC_TRAEFIK_BOUNCER_API_KEY=<üretilen_key>"
echo ""
echo "  3. CrowdSec Manager API key üretin ve .env'e ekleyin:"
echo "     docker exec crowdsec cscli bouncers add crowdsec-manager"
echo "     → CROWDSEC_MANAGER_API_KEY=<üretilen_key>"
echo ""
echo "  4. Tüm servisleri başlatın:"
echo "     docker compose up -d"
echo "==============================================="
