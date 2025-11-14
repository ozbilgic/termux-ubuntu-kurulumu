#!/data/data/com.termux/files/usr/bin/bash

# Ubuntu Termux Manuel Kurulum Script'i (PRoot ile)
# Root gerektirmez, proot-distro kullanmaz

echo "================================================"
echo "  Ubuntu Termux Manuel Kurulum Script'i"
echo "================================================"
echo ""

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Hata kontrolü fonksiyonu
check_error() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}[HATA]${NC} $1"
        exit 1
    fi
}

# Bilgi mesajı fonksiyonu
info() {
    echo -e "${GREEN}[BİLGİ]${NC} $1"
}

# Uyarı mesajı fonksiyonu
warn() {
    echo -e "${YELLOW}[UYARI]${NC} $1"
}

# Kurulum dizini
UBUNTU_DIR="$HOME/ubuntu-fs"
SCRIPT_DIR="$HOME"

# 1. Termux paketlerini güncelle ve onar
info "Termux paketleri güncelleniyor ve onarılıyor..."
info "Bu işlem birkaç dakika sürebilir..."

# Paket veritabanını güncelle
pkg update -y 2>/dev/null || {
    warn "Normal güncelleme başarısız, repo değiştiriliyor..."
    termux-change-repo
    pkg update -y
}

# Kritik kütüphaneleri ve paketleri yükselt
info "Sistem paketleri yükseltiliyor..."
pkg upgrade -y libandroid-posix-semaphore 2>/dev/null || true
pkg upgrade -y 2>/dev/null || {
    warn "Bazı paketler yükseltilemedi, devam ediliyor..."
}

# 2. Gerekli paketleri kur/yeniden kur
info "Gerekli paketler kuruluyor..."
pkg install -y --reinstall proot wget tar -o Dpkg::Options::="--force-confnew"
check_error "Gerekli paketlerin kurulumu başarısız oldu"

# wget çalışıyor mu test et
info "wget testi yapılıyor..."
if ! wget --version >/dev/null 2>&1; then
    echo -e "${RED}[HATA]${NC} wget düzgün çalışmıyor."
    echo "Lütfen Termux'u kapatıp yeniden açın ve script'i tekrar çalıştırın."
    exit 1
fi
info "✓ wget çalışıyor"

# Pipe üzerinden çalışıp çalışmadığını kontrol et (erken tespit için)
PIPED_INPUT=false
if [ ! -t 0 ]; then
    PIPED_INPUT=true
    warn "Script pipe üzerinden çalıştırılıyor, varsayılan değerler kullanılacak"
fi

# 3. Mevcut kurulum kontrolü
if [ -d "$UBUNTU_DIR" ]; then
    warn "Ubuntu kurulumu zaten mevcut: $UBUNTU_DIR"

    # Eğer pipe üzerinden çalışıyorsa otomatik olarak sil
    if [ "$PIPED_INPUT" = true ]; then
        response="e"
        info "Varsayılan seçim: Mevcut kurulum silinecek ve yeniden kurulacak"
    else
        read -p "Mevcut kurulumu silip yeniden kurmak ister misiniz? (e/h): " response
    fi

    if [ "$response" = "e" ] || [ "$response" = "E" ]; then
        info "Mevcut kurulum siliniyor..."
        rm -rf "$UBUNTU_DIR"
        check_error "Silme işlemi başarısız oldu"
    else
        info "Kurulum iptal edildi."
        exit 0
    fi
fi

# 4. Kurulum dizinini oluştur
info "Kurulum dizini oluşturuluyor: $UBUNTU_DIR"
mkdir -p "$UBUNTU_DIR"
check_error "Dizin oluşturulamadı"

# 5. Ubuntu base rootfs'i indir
info "Ubuntu base rootfs indiriliyor..."
info "Bu işlem birkaç dakika sürebilir, lütfen bekleyin..."

# Mimari tespiti
case $(uname -m) in
    aarch64|arm64)
        ARCH="arm64"
        ;;
    armv7l|armv8l)
        ARCH="armhf"
        ;;
    *)
        echo -e "${RED}[HATA]${NC} Desteklenmeyen mimari: $(uname -m)"
        exit 1
        ;;
esac

info "Mimari: $ARCH"

# En son 4 LTS versiyonunu dinamik olarak tespit et
info "Mevcut Ubuntu LTS versiyonları kontrol ediliyor..."

# Ubuntu releases sayfasından en son 4 LTS versiyonu çek
# LTS versiyonları .04 ile biter ve SADECE çift yıllarda çıkar (20.04, 22.04, 24.04, 26.04...)
AVAILABLE_VERSIONS=$(wget -qO- https://cdimage.ubuntu.com/ubuntu-base/releases/ 2>/dev/null | \
    grep -oP 'href="\K[0-9]{2}\.04(?=/)' | \
    awk '{year=int(substr($1,1,2)); if(year%2==0) print $1}' | \
    sort -Vru | \
    head -n 4)

if [ -z "$AVAILABLE_VERSIONS" ]; then
    echo -e "${RED}[HATA]${NC} Ubuntu versiyonları tespit edilemedi. İnternet bağlantınızı kontrol edin."
    warn "Fallback olarak bilinen versiyonlar kullanılıyor..."
    AVAILABLE_VERSIONS="24.04
22.04
20.04
18.04"
fi

# 4 versiyonu diziye al
VERSION_ARRAY=($AVAILABLE_VERSIONS)

VERSION_1="${VERSION_ARRAY[0]}"
VERSION_2="${VERSION_ARRAY[1]}"
VERSION_3="${VERSION_ARRAY[2]}"
VERSION_4="${VERSION_ARRAY[3]}"

# Her versiyon için en son point release'i bul
info "En son güncellemeler kontrol ediliyor..."

# Başarı mesajı
if [ ${#VERSION_ARRAY[@]} -ge 4 ]; then
    info "✓ Son 4 Ubuntu LTS versiyonu başarıyla tespit edildi"
fi

get_latest_point_release() {
    local base_version=$1
    local latest_point=$(wget -qO- "https://cdimage.ubuntu.com/ubuntu-base/releases/${base_version}/release/" 2>/dev/null | \
        grep -oP "ubuntu-base-${base_version}\.\K[0-9]+" | \
        sort -n | \
        tail -n 1)

    if [ -z "$latest_point" ]; then
        # Point release yoksa base version'ı kullan (yeni versiyonlar için)
        echo "${base_version}"
    else
        # Point release varsa onu kullan
        echo "${base_version}.${latest_point}"
    fi
}

VERSION_1_FULL=$(get_latest_point_release "$VERSION_1")
VERSION_2_FULL=$(get_latest_point_release "$VERSION_2")
VERSION_3_FULL=$(get_latest_point_release "$VERSION_3")
VERSION_4_FULL=$(get_latest_point_release "$VERSION_4")

# Kullanıcıya seçim yaptır
echo ""
echo -e "${BLUE}Hangi Ubuntu LTS versiyonunu yüklemek istersiniz?${NC}"
echo -e "${YELLOW}(LTS versiyonları Termux ile tam uyumlu ve 5 yıl desteklenir)${NC}"
echo ""
echo "  1) Ubuntu ${VERSION_1_FULL} LTS"
echo "  2) Ubuntu ${VERSION_2_FULL} LTS"
echo "  3) Ubuntu ${VERSION_3_FULL} LTS"
echo "  4) Ubuntu ${VERSION_4_FULL} LTS"
echo ""

# Eğer pipe üzerinden çalışıyorsa varsayılan seçim yap
if [ "$PIPED_INPUT" = true ]; then
    version_choice=1
    info "Varsayılan seçim: Ubuntu ${VERSION_1_FULL} LTS"
else
    read -p "Seçiminiz (1, 2, 3 veya 4): " version_choice
fi

# Seçilen versiyon ve alternatifleri ayarla
case $version_choice in
    1)
        UBUNTU_VERSION="$VERSION_1_FULL"
        UBUNTU_BASE_VERSION="$VERSION_1"
        ALTERNATIVES=("$VERSION_2_FULL:$VERSION_2" "$VERSION_3_FULL:$VERSION_3" "$VERSION_4_FULL:$VERSION_4")
        info "Ubuntu ${VERSION_1_FULL} seçildi"
        ;;
    2)
        UBUNTU_VERSION="$VERSION_2_FULL"
        UBUNTU_BASE_VERSION="$VERSION_2"
        ALTERNATIVES=("$VERSION_1_FULL:$VERSION_1" "$VERSION_3_FULL:$VERSION_3" "$VERSION_4_FULL:$VERSION_4")
        info "Ubuntu ${VERSION_2_FULL} seçildi"
        ;;
    3)
        UBUNTU_VERSION="$VERSION_3_FULL"
        UBUNTU_BASE_VERSION="$VERSION_3"
        ALTERNATIVES=("$VERSION_1_FULL:$VERSION_1" "$VERSION_2_FULL:$VERSION_2" "$VERSION_4_FULL:$VERSION_4")
        info "Ubuntu ${VERSION_3_FULL} seçildi"
        ;;
    4)
        UBUNTU_VERSION="$VERSION_4_FULL"
        UBUNTU_BASE_VERSION="$VERSION_4"
        ALTERNATIVES=("$VERSION_1_FULL:$VERSION_1" "$VERSION_2_FULL:$VERSION_2" "$VERSION_3_FULL:$VERSION_3")
        info "Ubuntu ${VERSION_4_FULL} seçildi"
        ;;
    *)
        echo -e "${RED}[HATA]${NC} Geçersiz seçim. 1, 2, 3 veya 4 seçmelisiniz."
        exit 1
        ;;
esac

# İndirme URL'lerini dinamik olarak oluştur
UBUNTU_URL="https://cdimage.ubuntu.com/ubuntu-base/releases/${UBUNTU_BASE_VERSION}/release/ubuntu-base-${UBUNTU_VERSION}-base-${ARCH}.tar.gz"

echo ""

cd "$HOME"

# İndirmeyi dene
info "İndirme URL: $UBUNTU_URL"
wget --timeout=30 --tries=3 --continue "${UBUNTU_URL}" -O ubuntu.tar.gz

# İndirme kontrolü
if [ $? -ne 0 ] || [ ! -f ubuntu.tar.gz ] || [ ! -s ubuntu.tar.gz ]; then
    echo -e "${RED}[HATA]${NC} Ubuntu ${UBUNTU_VERSION} indirilemedi."
    rm -f ubuntu.tar.gz

    # Alternatif versiyonları sun
    echo ""
    warn "Ubuntu ${UBUNTU_VERSION} için indirme başarısız oldu."
    echo ""
    echo -e "${BLUE}Alternatif versiyonlardan birini denemek ister misiniz?${NC}"
    echo ""

    # Alternatifleri göster
    for i in "${!ALTERNATIVES[@]}"; do
        ALT_FULL=$(echo "${ALTERNATIVES[$i]}" | cut -d: -f1)
        echo "  $((i+1))) Ubuntu ${ALT_FULL}"
    done
    echo "  $((${#ALTERNATIVES[@]}+1))) Kurulumu iptal et"
    echo ""

    # Eğer pipe üzerinden çalışıyorsa otomatik ilk alternatifi dene
    if [ "$PIPED_INPUT" = true ]; then
        alt_choice=1
        info "Varsayılan seçim: İlk alternatif versiyon deneniyor"
    else
        read -p "Seçiminiz: " alt_choice
    fi

    # Seçimi kontrol et
    if [ "$alt_choice" -ge 1 ] && [ "$alt_choice" -le "${#ALTERNATIVES[@]}" ] 2>/dev/null; then
        selected_index=$((alt_choice-1))
        UBUNTU_VERSION=$(echo "${ALTERNATIVES[$selected_index]}" | cut -d: -f1)
        UBUNTU_BASE_VERSION=$(echo "${ALTERNATIVES[$selected_index]}" | cut -d: -f2)
        UBUNTU_URL="https://cdimage.ubuntu.com/ubuntu-base/releases/${UBUNTU_BASE_VERSION}/release/ubuntu-base-${UBUNTU_VERSION}-base-${ARCH}.tar.gz"

        info "Ubuntu ${UBUNTU_VERSION} deneniyor..."
        info "İndirme URL: $UBUNTU_URL"
        wget --timeout=30 --tries=3 --continue "${UBUNTU_URL}" -O ubuntu.tar.gz

        # Alternatif indirme kontrolü
        if [ $? -ne 0 ] || [ ! -f ubuntu.tar.gz ] || [ ! -s ubuntu.tar.gz ]; then
            echo -e "${RED}[HATA]${NC} Ubuntu ${UBUNTU_VERSION} de indirilemedi."
            echo "İnternet bağlantınızı kontrol edin ve tekrar deneyin."
            rm -f ubuntu.tar.gz
            exit 1
        fi
    else
        echo "Kurulum iptal edildi."
        exit 1
    fi
fi

info "Ubuntu rootfs başarıyla indirildi ($(du -h ubuntu.tar.gz | cut -f1))"

# 6. Rootfs'i extract et
info "Ubuntu rootfs açılıyor..."
info "Bu işlem birkaç dakika sürebilir..."

cd "$UBUNTU_DIR"

# Tar dosyasının geçerliliğini kontrol et
info "Tar dosyası kontrol ediliyor..."
tar -tzf "$HOME/ubuntu.tar.gz" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${RED}[HATA]${NC} Tar dosyası bozuk, yeniden indiriliyor..."
    rm -f "$HOME/ubuntu.tar.gz"
    cd "$HOME"
    wget --timeout=30 --tries=3 --continue "${UBUNTU_URL}" -O ubuntu.tar.gz
    check_error "Yeniden indirme başarısız"
fi

# Farklı tar parametreleri dene
info "Dosya açılıyor (yöntem 1)..."
proot --link2symlink tar -xf "$HOME/ubuntu.tar.gz" --exclude='dev'||true 2>/dev/null

# Eğer başarısız olursa alternatif yöntem
if [ ! -d "$UBUNTU_DIR/usr" ]; then
    info "Alternatif yöntem deneniyor..."
    tar --warning=no-unknown-keyword --delay-directory-restore --preserve-permissions -xpf "$HOME/ubuntu.tar.gz" 2>/dev/null || \
    tar -xpf "$HOME/ubuntu.tar.gz" 2>/dev/null || \
    tar -xf "$HOME/ubuntu.tar.gz" 2>/dev/null
fi

# Kontrol et
if [ ! -d "$UBUNTU_DIR/usr" ] || [ ! -d "$UBUNTU_DIR/etc" ]; then
    echo -e "${RED}[HATA]${NC} Rootfs düzgün çıkartılamadı."
    echo "Lütfen manuel olarak kontrol edin: ls -la $UBUNTU_DIR"
    exit 1
fi

info "Rootfs başarıyla çıkarıldı"

# İndirilen dosyayı temizle
rm "$HOME/ubuntu.tar.gz"
info "Geçici dosyalar temizlendi"

# 7. DNS ayarlarını yapılandır
info "DNS yapılandırması yapılıyor..."
echo "nameserver 8.8.8.8" > "$UBUNTU_DIR/etc/resolv.conf"
echo "nameserver 8.8.4.4" >> "$UBUNTU_DIR/etc/resolv.conf"

# 8. Başlatma script'i oluştur
info "Başlatma script'i oluşturuluyor..."
cat > "$SCRIPT_DIR/start-ubuntu.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash

# Termux-exec'i devre dışı bırak
unset LD_PRELOAD

UBUNTU_DIR="$HOME/ubuntu-fs"

# Gerekli dizinleri oluştur
mkdir -p "$UBUNTU_DIR/dev"
mkdir -p "$UBUNTU_DIR/proc"
mkdir -p "$UBUNTU_DIR/sys"
mkdir -p "$UBUNTU_DIR/tmp"
mkdir -p "$UBUNTU_DIR/root"

# Kullanıcı adını kontrol et
UBUNTU_USER=""
if [ -f "$UBUNTU_DIR/root/.ubuntu-user" ]; then
    UBUNTU_USER=$(cat "$UBUNTU_DIR/root/.ubuntu-user")
fi

# PRoot ile Ubuntu'yu başlat
if [ -n "$UBUNTU_USER" ]; then
    # Kullanıcı varsa, o kullanıcı ile başlat
    proot \
        --root-id \
        --link2symlink \
        --kill-on-exit \
        --rootfs="$UBUNTU_DIR" \
        --bind=/dev \
        --bind=/proc \
        --bind=/sys \
        --bind=/sdcard \
        --cwd=/home/$UBUNTU_USER \
        --mount=/proc \
        --mount=/sys \
        --mount=/dev \
        /usr/bin/env -i \
        HOME=/home/$UBUNTU_USER \
        USER=$UBUNTU_USER \
        TERM="$TERM" \
        LANG=C.UTF-8 \
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
        /bin/bash -c "/bin/su -l $UBUNTU_USER"
else
    # Kullanıcı yoksa, root ile başlat
    proot \
        --root-id \
        --link2symlink \
        --kill-on-exit \
        --rootfs="$UBUNTU_DIR" \
        --bind=/dev \
        --bind=/proc \
        --bind=/sys \
        --bind=/sdcard \
        --cwd=/root \
        --mount=/proc \
        --mount=/sys \
        --mount=/dev \
        /usr/bin/env -i \
        HOME=/root \
        TERM="$TERM" \
        LANG=C.UTF-8 \
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
        /bin/bash --login
fi
EOF

chmod +x "$SCRIPT_DIR/start-ubuntu.sh"

# 9. İlk kurulum script'i oluştur (Ubuntu içinde çalışacak)
info "İlk kurulum script'i hazırlanıyor..."
cat > "$UBUNTU_DIR/root/first-setup.sh" << 'EOF'
#!/bin/bash

echo "Ubuntu ilk kurulum başlıyor. Bu uzun sürebilir, lütfen bekleyin..."

echo "Paket listeleri güncelleniyor..."
apt update
apt upgrade -y

echo "Yerel ayarlar yapılandırılıyor..."
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

echo "Temel paketler kuruluyor..."
apt install -y nano vim wget curl git sudo locales tzdata

echo "Yerel ayarlar yapılandırılıyor..."
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8

# Host dosyasını düzelt
echo '127.0.0.1 localhost' > /etc/hosts
echo '127.0.1.1 localhost.localdomain' >> /etc/hosts

echo "Paketler yapılandırılıyor..."
sudo dpkg --configure -a

# Grup dosyalarını düzelt
sudo groupadd -g 3003 termux_gid3003 2>/dev/null || true
sudo groupadd -g 9997 termux_gid9997 2>/dev/null || true
sudo groupadd -g 20427 termux_gid20427 2>/dev/null || true
sudo groupadd -g 50427 termux_gid50427 2>/dev/null || true

echo ""
echo "================================================"
echo "  Ubuntu temel kurulum tamamlandı!"
echo "================================================"
echo ""

# Yeni kullanıcı oluşturma seçeneği
read -p "Root olmayan yeni bir kullanıcı eklemek ister misiniz? (e/h): " create_user

if [ "$create_user" = "e" ] || [ "$create_user" = "E" ]; then
    echo ""
    echo "Yeni kullanıcı oluşturuluyor..."
    echo ""

    # Kullanıcı adı al
    while true; do
        read -p "Kullanıcı adı: " username

        # Kullanıcı adı kontrolü
        if [ -z "$username" ]; then
            echo "Hata: Kullanıcı adı boş olamaz."
            continue
        fi

        if id "$username" &>/dev/null; then
            echo "Hata: '$username' kullanıcısı zaten var."
            continue
        fi

        if ! [[ "$username" =~ ^[a-z][-a-z0-9]*$ ]]; then
            echo "Hata: Geçersiz kullanıcı adı. Küçük harf ile başlamalı ve sadece harf, rakam, tire içermelidir."
            continue
        fi

        break
    done

    # Kullanıcıyı oluştur
    useradd -m -s /bin/bash "$username"

    if [ $? -eq 0 ]; then
        echo "✓ Kullanıcı '$username' oluşturuldu"

        # Şifre belirle
        echo ""
        echo "Şifre belirleyin:"
        passwd "$username"

        # Sudo yetkisi ver (otomatik)
        echo ""
        echo "Sudo yetkisi veriliyor..."

        # Kullanıcıyı sudo grubuna ekle
        usermod -aG sudo "$username"

        # /etc/sudoers.d/ altında kullanıcı için yapılandırma oluştur
        # NOPASSWD opsiyonel, sudo şifre sormadan çalışır
        echo "$username ALL=(ALL:ALL) NOPASSWD: ALL" > "/etc/sudoers.d/$username"
        chmod 0440 "/etc/sudoers.d/$username"

        echo "✓ '$username' kullanıcısına sudo yetkisi verildi"

        # Ek gruplar ekle
        usermod -aG termux_gid3003,termux_gid9997,termux_gid20427,termux_gid50427 "$username" 2>/dev/null || true

        # Kullanıcı adını kaydet (start-ubuntu.sh için)
        echo "$username" > /root/.ubuntu-user

        echo ""
        echo "✓ Kullanıcı başarıyla oluşturuldu!"
        echo ""
        echo "Termux her açılışta otomatik olarak '$username' kullanıcısı ile başlayacak."
        echo ""
        echo "Yeni kullanıcıya geçmek için:"
        echo "  su - $username"
        echo ""
    else
        echo "✗ Kullanıcı oluşturulamadı"
    fi
else
    echo "Yeni kullanıcı oluşturulmadı."
fi

echo ""
echo "================================================"
echo "  Kurulum tamamlandı!"
echo "================================================"
echo ""
echo "İlk kurulum script'i tamamlandı."
echo "Bu dosyayı silebilirsiniz: rm /root/first-setup.sh"
echo ""
EOF

chmod +x "$UBUNTU_DIR/root/first-setup.sh"

# 10. Kurulum tamamlandı
echo ""
echo "================================================"
info "Ubuntu başarıyla kuruldu!"
echo "================================================"
echo ""
echo -e "${BLUE}Kurulum Dizini:${NC} $UBUNTU_DIR"
echo ""
echo -e "${GREEN}Ubuntu'yu başlatmak için:${NC}"
echo "  ./start-ubuntu.sh"
echo ""
echo -e "${GREEN}İlk girişte şunu çalıştırın:${NC}"
echo "  bash /root/first-setup.sh"
echo ""
echo "Bu komut sistem güncellemesi yapacak ve temel paketleri kuracak."
echo ""
echo -e "${YELLOW}Not:${NC} Ubuntu'dan çıkmak için 'exit' yazın"
echo ""

# 12. Kullanıcıya otomatik başlatma seçeneği sun
echo ""
# Eğer pipe üzerinden çalışıyorsa varsayılan olarak otomatik başlatma yapma
if [ "$PIPED_INPUT" = true ]; then
    auto_start="e"
    info "Varsayılan seçim: Otomatik başlatma."
else
    read -p "Ubuntu'yu Termux'un her açılışında otomatik olarak başlatmak ister misiniz? (Bu seçenek aynı zamanda ubuntu logosu ekler) (e/h): " auto_start
fi

if [ "$auto_start" = "e" ] || [ "$auto_start" = "E" ]; then
    info "Otomatik başlatma ayarı yapılandırılıyor..."

    # .bashrc dosyasını kontrol et
    BASHRC_FILE="$HOME/.bashrc"

    # Eğer zaten eklenmediyse ekle
    if ! grep -q "start-ubuntu.sh" "$BASHRC_FILE" 2>/dev/null; then
        # Logoyu ve otomatik başlatmayı ekle
        cat >> "$BASHRC_FILE" << 'BASHRC_EOF'
# Ubuntu logo ve otomatik başlatma
if [ -f "$HOME/start-ubuntu.sh" ]; then
    ORANGE='\033[38;5;208m'
    RESET='\033[0m'
    clear
    echo ""
    echo -e "${ORANGE}"
    echo "  _   _  _                  _          "
    echo " | | | || |                | |         "
    echo " | | | || |__   _   _ _ __ | |_  _   _ "
    echo " | | | ||  _ \ | | | |  _ \|  _|| | | |"
    echo " | |_| || |_) || |_| | | | | |_ | |_| |"
    echo "  \___/ |____/  \____|_| |_|\__| \____|"
    echo ""
    echo -e "${RESET}"
    ./start-ubuntu.sh
fi
BASHRC_EOF
        info "Otomatik başlatma ayarı eklendi"
        info "Termux'u her açtığınızda Ubuntu otomatik olarak başlayacak"
        echo ""
        echo -e "${YELLOW}Not:${NC} Otomatik başlatmayı devre dışı bırakmak için:"
        echo "  nano ~/.bashrc"
        echo "  (Son satırlardaki Ubuntu otomatik başlatma bölümünü silin)"
    else
        warn "Otomatik başlatma zaten ayarlanmış"
    fi

    # Şimdi başlat
    echo ""
    # Eğer pipe üzerinden çalışıyorsa başlatma
    if [ "$PIPED_INPUT" = true ]; then
        start_now="h"
        info "Script tamamlandı. Termux'u kapatıp açtığınızda Ubuntu otomatik başlayacak."
    else
        read -p "Ubuntu'yu şimdi başlatmak ister misiniz? (e/h): " start_now
        if [ "$start_now" = "e" ] || [ "$start_now" = "E" ]; then
            info "Ubuntu başlatılıyor..."
            exec "$SCRIPT_DIR/start-ubuntu.sh"
        else
            info "Script tamamlandı. Termux'u kapatıp açtığınızda Ubuntu otomatik başlayacak."
        fi
    fi
else
    info "Otomatik başlatma ayarlanmadı"

    # 13. Kullanıcıya Ubuntu'yu başlatma seçeneği sun
    echo ""
    # Eğer pipe üzerinden çalışıyorsa başlatma
    if [ "$PIPED_INPUT" = true ]; then
        start_ubuntu="h"
        info "Script tamamlandı. İyi çalışmalar!"
        echo ""
        echo -e "${GREEN}Ubuntu'yu başlatmak için:${NC}"
        echo "  ./start-ubuntu.sh"
    else
        read -p "Ubuntu'yu şimdi başlatmak ister misiniz? (e/h): " start_ubuntu
        if [ "$start_ubuntu" = "e" ] || [ "$start_ubuntu" = "E" ]; then
            info "Ubuntu başlatılıyor..."
            exec "$SCRIPT_DIR/start-ubuntu.sh"
        else
            info "Script tamamlandı. İyi çalışmalar!"
            echo ""
            echo -e "${GREEN}Ubuntu'yu başlatmak için:${NC}"
            echo "  ./start-ubuntu.sh"
        fi
    fi
fi
