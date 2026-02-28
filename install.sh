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
read -rp "Base domain (örn: example.com, dashboard host'ları için kullanılır): " BASE_DOMAIN
read -rp "LETSENCRYPT_EMAIL: " LETSENCRYPT_EMAIL

echo
echo "--- Sertifika Çözümleyici ---"
echo "  1) letsencrypt — HTTP challenge (varsayılan, Cloudflare gerektirmez)"
echo "  2) cloudflare  — DNS challenge  (Cloudflare API token gerektirir)"
read -rp "Seçim (boş bırakılırsa: letsencrypt): " INPUT_CERT_RESOLVER
if [[ "$INPUT_CERT_RESOLVER" == "2" || "$INPUT_CERT_RESOLVER" == "cloudflare" ]]; then
  CERT_RESOLVER="cloudflare"
  read -rp "CLOUDFLARE_DNS_API_TOKEN: " CLOUDFLARE_DNS_API_TOKEN
else
  CERT_RESOLVER="letsencrypt"
  CLOUDFLARE_DNS_API_TOKEN=""
fi

echo
echo "--- Dashboard Hostları ---"
read -rp "TRAEFIK_DASHBOARD_HOST (boş bırakılırsa: traefik.${BASE_DOMAIN}): " INPUT_TRAEFIK_HOST
TRAEFIK_DASHBOARD_HOST="${INPUT_TRAEFIK_HOST:-traefik.${BASE_DOMAIN}}"

read -rp "CROWDSEC_MANAGER_DASHBOARD_HOST (boş bırakılırsa: crowdsec.${BASE_DOMAIN}): " INPUT_CROWDSEC_HOST
CROWDSEC_MANAGER_DASHBOARD_HOST="${INPUT_CROWDSEC_HOST:-crowdsec.${BASE_DOMAIN}}"

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
set_env LETSENCRYPT_EMAIL                "$LETSENCRYPT_EMAIL"
set_env CERT_RESOLVER                    "$CERT_RESOLVER"
set_env CLOUDFLARE_DNS_API_TOKEN         "$CLOUDFLARE_DNS_API_TOKEN"
set_env TRAEFIK_DASHBOARD_HOST           "$TRAEFIK_DASHBOARD_HOST"
set_env CROWDSEC_MANAGER_DASHBOARD_HOST  "$CROWDSEC_MANAGER_DASHBOARD_HOST"
set_env CROWDSEC_GID                     "$CROWDSEC_GID"

# --------------------------------------------------
# CrowdSec API Key Otomatik Üretme (Opsiyonel)
# --------------------------------------------------
echo
read -rp "CrowdSec API key'leri otomatik oluşturulsun mu? (e/h): " AUTO_CROWDSEC
if [[ "$AUTO_CROWDSEC" =~ ^[Ee]$ ]]; then
  echo "⏳ CrowdSec başlatılıyor..."
  docker compose -f docker-compose.production.yml up -d crowdsec

  echo "⏳ CrowdSec hazır olana kadar bekleniyor..."
  until docker exec crowdsec cscli lapi status > /dev/null 2>&1; do
    sleep 2
  done

  BOUNCER_KEY=$(docker exec crowdsec cscli bouncers add traefik-bouncer --output raw 2>/dev/null || true)
  MANAGER_KEY=$(docker exec crowdsec cscli bouncers add crowdsec-manager --output raw 2>/dev/null || true)

  if [ -n "$BOUNCER_KEY" ]; then
    set_env CROWDSEC_TRAEFIK_BOUNCER_API_KEY "$BOUNCER_KEY"
    echo "✅ CROWDSEC_TRAEFIK_BOUNCER_API_KEY oluşturuldu"
  else
    echo "ℹ️  traefik-bouncer zaten mevcut, CROWDSEC_TRAEFIK_BOUNCER_API_KEY güncellenmedi"
  fi

  if [ -n "$MANAGER_KEY" ]; then
    set_env CROWDSEC_MANAGER_API_KEY "$MANAGER_KEY"
    echo "✅ CROWDSEC_MANAGER_API_KEY oluşturuldu"
  else
    echo "ℹ️  crowdsec-manager zaten mevcut, CROWDSEC_MANAGER_API_KEY güncellenmedi"
  fi

  CROWDSEC_AUTO=true
else
  CROWDSEC_AUTO=false
fi

# --------------------------------------------------
# Sonuçları Göster
# --------------------------------------------------
echo
echo "==============================================="
echo "✅ Traefik .env başarıyla hazırlandı!"
echo "-----------------------------------------------"
echo "🌐 Traefik   : https://$TRAEFIK_DASHBOARD_HOST"
echo "🛡️ CrowdSec  : https://$CROWDSEC_MANAGER_DASHBOARD_HOST"
echo "-----------------------------------------------"
if [ "$CROWDSEC_AUTO" = true ]; then
  echo "▶️  Tüm servisleri başlatmak için:"
  echo "   docker compose up -d"
else
  echo "⚠️  Kurulum tamamlanmadan önce yapılması gerekenler:"
  echo ""
  echo "  1. Önce sadece CrowdSec'i başlatın:"
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
fi
echo "==============================================="
