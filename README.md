# Traefik Docker Projesi

## Amaç

Bu proje, Docker üzerinde Traefik v3 ile hem local hem de production ortamlarında çalışacak şekilde yapılandırılmış bir ters proxy çözümü sunar. Local ortamda self-signed sertifikalarla çalışabilirken, production ortamında Let's Encrypt üzerinden otomatik SSL sertifikası oluşturulmasını sağlar.

Docker konteynerleri için merkezi bir giriş noktası (Edge Router) oluşturarak, servislerin otomatik olarak keşfedilmesini, SSL/TLS sertifikalarının yönetimini ve güvenli bir yönlendirme katmanı (IP Allowlist, Dashboard güvenliği vb.) sağlanmasını amaçlar.

## Gereksinimler

* Docker ve Docker Compose yüklü olması.
* Domain bazlı erişim için ağ erişimi (Local için hosts dosyası düzenleme yetkisi).
* Canlı ortam için 80 ve 443 portlarının açık olması.

## Ortak Hazırlık

### 1. Traefik Network Oluşturulması

Kuruluma başlamadan önce ortak olan ağ yapılandırmasını yapmalısınız.

```bash
docker network create traefik-network
```

### 2. Ortam Dosyasının Oluşturulması

```bash
cp .env.example .env
```

* Local ortam için `.env` dosyasında değişiklik yapmanıza gerek yok.
* Production ortam için gerekli değerler (örneğin: `LE_EMAIL`, `TRUSTED_IPS`, `TRAEFIK_DASHBOARD_ALLOWLIST`) projeye göre düzenlenmelidir.

## Yerel (Local) Ortam Kurulumu

### 1. Hosts Dosyasına Traefik Paneli İçin Kayıt Ekleyin:

* **Linux:** `/etc/hosts`
* **Windows:** `C:\Windows\System32\drivers\etc\hosts`

```text
127.0.0.1   traefik.localhost
```

### 2. Local Ortam İçin docker-compose.yml Dosyasını Oluşturun:

```bash
cp docker-compose.local.yml docker-compose.yml
```

### 3. TLS Yapılandırma Dosyasını Oluşturun:

Local ortamda self-signed sertifikalar için `tls.yml` dosyasını oluşturun:

```bash
cp tls.yml.example tls.yml
```

### 4. Opsiyonel Olarak Self-Signed Sertifika Oluşturabilirsiniz:

Sertifika ve key dosyalarını storage/certs/mydomain.com dizinine koyun

```bash
mkdir -p storage/certs/mydomain.com
```

Self-signed sertifika oluşturmak için mkcert aracını kullanabilirsiniz. Bakınız: [mkcert GitHub Sayfası](https://github.com/FiloSottile/mkcert)
```bash
# Yerel CA'yı sisteme yükler (Sadece bir kez yapılır)
mkcert -install
```

Self-signed sertifika oluşturma komutu:
```bash
mkcert -key-file storage/certs/mydomain.com/local.mydomain.com.key \
       -cert-file storage/certs/mydomain.com/local.mydomain.com.crt \
       mydomain.com "*.mydomain.com"
```

`tls.yml` dosyasını düzenleyerek self-signed sertifikaları ekleyebilirsiniz.

### 5. Traefik Konteynerini Başlatın:

```bash
docker compose up -d
```

## Production Ortam Kurulumu

### 1. Production Ortam İçin `docker-compose.yml` Dosyasını Oluşturun:

```bash
cp docker-compose.production.yml docker-compose.yml
```

### 2. `.env` Dosyasını Güncelleme
.env dosyasını açın ve canlı ortam için kritik olan değişkenleri düzenleyin:

* **LE_EMAIL**: Let's Encrypt bildirimleri için e-posta adresiniz.
* **TRUSTED_IPS**: Cloudflare veya Load Balancer kullanıyorsanız ilgili IP aralıkları.
* **TRAEFIK_DASHBOARD_HOST**: Panelin hangi domainde çalışacağı (örn: traefik.domain.com).
* **TRAEFIK_DASHBOARD_ALLOWLIST**: Panele erişebilecek IP adresleri (Güvenlik için şarttır).

### 3. Dosya İzinleri
Production ortamında SSL sertifikalarının saklanacağı dosya oluşturun ve izinlerini ayarlayın:

```bash
touch storage/acme.json
chmod 600 storage/acme.json
```

### 4. Traefik Konteynerini Başlatın:

```bash
docker compose up -d
```

> Not: Production ortamında SSL sertifikaları `storage/acme.json` dosyasında saklanacaktır.

## Notlar

* `tls.yml` dosyası ile default ve özel domain sertifikalarını yapılandırabilirsiniz.
* Local ortamda self-signed sertifika oluşturmak şart değildir, sadece gerekli durumlarda yapılmalıdır.
* `.gitignore` ile `.env`, `tls.yml`, ve proje özel dosyalar versiyon kontrolüne dahil edilmez.
* **Güvenlik**: Production ortamında Traefik Dashboard'u ipallowlist ile korunmaktadır. Kendi IP adresinizi .env dosyasına eklemeyi unutmayın.
* **Kalıcılık**: storage/ dizini altındaki acme.json ve sertifikalar .gitignore ile korunmaktadır ancak bu dosyaların yedeğini almanız SSL limitlerine takılmamanız için önerilir.
* **Otomatik Yönlendirme**: Bu yapılandırma tüm HTTP isteklerini otomatik olarak HTTPS'e yönlendirir.

## Kaynaklar

* [Traefik Resmi Dokümantasyon](https://doc.traefik.io/traefik/)
* [Docker Resmi Dokümantasyon](https://docs.docker.com/)
* [Docker Compose Resmi Dokümantasyon](https://docs.docker.com/compose/)
