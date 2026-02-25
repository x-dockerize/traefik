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
* Production ortam için gerekli değerler (örneğin: `LE_EMAIL`, `TRUSTED_IPS`, `DASHBOARD_ALLOWLIST`) projeye göre düzenlenmelidir.

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

Sertifika ve key dosyalarını .docker/traefik/certs/mydomain.com dizinine koyun

```bash
mkdir -p .docker/traefik/certs/mydomain.com
```

Self-signed sertifika oluşturmak için mkcert aracını kullanabilirsiniz. Bakınız: [mkcert GitHub Sayfası](https://github.com/FiloSottile/mkcert)
```bash
# Yerel CA'yı sisteme yükler (Sadece bir kez yapılır)
mkcert -install
```

Self-signed sertifika oluşturma komutu:
```bash
mkcert -key-file .docker/traefik/certs/mydomain.com/local.mydomain.com.key \
       -cert-file .docker/traefik/certs/mydomain.com/local.mydomain.com.crt \
       local.mydomain.com "*.local.mydomain.com"
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
* **DASHBOARD_ALLOWLIST**: Panele erişebilecek IP adresleri (Güvenlik için şarttır).

### 3. Dosya İzinleri
Production ortamında SSL sertifikalarının saklanacağı dosya oluşturun ve izinlerini ayarlayın:

```bash
# Http Challenge için
touch .docker/traefik/le-http-acme.json
chmod 600 .docker/traefik/le-http-acme.json

# Cloudflare DNS Challenge için (Eğer kullanıyorsanız)
touch .docker/traefik/le-cloudflare-acme.json
chmod 600 .docker/traefik/le-cloudflare-acme.json
```

### 4. Traefik Konteynerini Başlatın:

```bash
docker compose up -d
```

### 5. CrowdSec Kurulumu

CrowdSec, açık kaynaklı bir siber güvenlik çözümüdür ve sistemlerinizi kötü niyetli aktivitelerden korumak için 
tasarlanmıştır. CrowdSec, çeşitli kaynaklardan gelen verileri analiz ederek potansiyel tehditleri tespit eder ve bu 
tehditlere karşı önlemler alır. İşte CrowdSec'in temel işlevleri:

* **Tehdit Tespiti**: CrowdSec, sistem loglarını ve ağ trafiğini analiz ederek kötü niyetli aktiviteleri tespit eder.
* **Topluluk Tabanlı Güvenlik**: CrowdSec, kullanıcı topluluğundan gelen verileri kullanarak tehditleri daha hızlı ve etkili bir şekilde tanımlar.
* **Otomatik Yanıt**: Tespit edilen tehditlere karşı otomatik olarak yanıt verir, örneğin kötü niyetli IP adreslerini engeller.
* **Güncellenen Tehdit Veritabanı**: CrowdSec, sürekli olarak güncellenen bir tehdit veritabanına sahiptir, bu da yeni tehditlere karşı koruma sağlar.
* **Kullanıcı Dostu Arayüz**: CrowdSec, kullanıcıların tehditleri izlemesi ve yönetmesi için kullanıcı dostu bir arayüz sunar.
* **Açık Kaynak**: CrowdSec, açık kaynaklı bir proje olduğu için kullanıcılar tarafından incelenebilir ve katkıda bulunulabilir.
* **Performans**: CrowdSec, hafif yapısı sayesinde sistem kaynaklarını verimli kullanır ve yüksek performans sağlar.

Bu özellikler sayesinde CrowdSec, sistemlerinizi kötü niyetli aktivitelerden korumak için etkili bir çözüm sunar.

#### 5.1 Manager İçin API Anahtarı Oluşturma

CrowdSec Manager, CrowdSec'in resmi olmayan yönetim ve izleme bileşenidir. Web tabanlı bir arayüz sunarak kullanıcıların CrowdSec'in işleyişini kolayca yönetmelerine ve izlemelerine olanak tanır.
Kontrol paneli üzerinden tehditleri görüntüleyebilir, yapılandırmaları yönetebilir ve sistem performansını izleyebilirsiniz.
Bunun için 

.env dosyasında `CROWDSEC_DASHBOARD_HOST` değerini ayarlayın (örn: crowdsec.domain.com).

CrowdSec Manager'ı için aşağıdaki komutla API anahtarını alın:

```bash
docker exec -it crowdsec cscli bouncers add crowdsec-manager
```

Aldığınız  `.env` dosyasına `CROWDSEC_MANAGER_API_KEY` değerini ekleyin ve crowdsec-manager konteynerini yeniden başlatın:

```bash
docker compose up -d crowdsec-manager
```

#### 5.2 Traefik Bouncer İçin API Anahtarı Oluşturma

CrowdSec Traefik Bouncer'ı için aşağıdaki komutla API anahtarını alın:

```bash
docker exec crowdsec cscli bouncers add traefik-bouncer
```

Daha sonra `.env` dosyasına `CROWDSEC_TRAEFIK_BOUNCER_API_KEY` değerini ekleyin ve crowdsec-traefik-bouncer konteynerini yeniden başlatın:

```bash
docker compose up -d crowdsec-traefik-bouncer
```

#### 5.3 CrowdSec Console ile Entegrasyon (Opsiyonel)

CrowdSec Console, CrowdSec’in merkezi yönetim ve izleme panelidir. Kısaca: birden fazla sunucu ve CrowdSec kurulumunu tek bir yerden görmeni, yönetmeni ve analiz etmeni sağlar. 

[https://app.crowdsec.net](https://app.crowdsec.net) adresine gidin ve bir hesap oluşturun. Size yönlendirilen talimatları takip ederek CrowdSec Console ile entegrasyonu tamamlayın.

## Notlar

Hazır olarak iki adet middleware yapılandırması bulunmaktadır:

CrowdSec Koruması için:
```yaml
- "traefik.http.routers.%router%.middlewares=crowdsec@docker"
```

Grafana, Prometheus vb. servislere iç ağ erişimi sağlamak için:
```yaml
- "traefik.http.routers.%router%.middlewares=internal@docker"
```

* `tls.yml` dosyası ile default ve özel domain sertifikalarını yapılandırabilirsiniz.
* Local ortamda self-signed sertifika oluşturmak şart değildir, sadece gerekli durumlarda yapılmalıdır.
* **Güvenlik**: Production ortamında Traefik Dashboard'u ipallowlist ile korunmaktadır. Kendi IP adresinizi .env dosyasına eklemeyi unutmayın.
* **Otomasyon**: CrowdSec ile kötü niyetli IP’ler otomatik tespit edilir ve Traefik üzerinden engellenir.
* **Kalıcılık**: .docker/traefik/ dizini altındaki acme.json ve sertifikalar .gitignore ile korunmaktadır ancak bu dosyaların yedeğini almanız SSL limitlerine takılmamanız için önerilir.
* **Otomatik Yönlendirme**: Bu yapılandırma tüm HTTP isteklerini otomatik olarak HTTPS'e yönlendirir.

## Kaynaklar

* [Traefik Resmi Dokümantasyon](https://doc.traefik.io/traefik/)
* [Docker Resmi Dokümantasyon](https://docs.docker.com/)
* [Docker Compose Resmi Dokümantasyon](https://docs.docker.com/compose/)
