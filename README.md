# Termux'a Ubuntu Nasıl Yüklenir?

Termux için otomatik Ubuntu kurulum scripti. Root gerektirmez.

## Özellikler

- **Dinamik LTS Seçimi**: En son yayınlanan 4 Ubuntu LTS versiyonunu otomatik tespit eder
- **Sadece Kararlı Sürümler**: Termux ile tam uyumlu LTS versiyonları sunulur
- **Akıllı Yedekleme**: İndirme başarısız olursa alternatif versiyonlar sunar
- **Otomatik Tamir**: Termux kütüphane sorunlarını otomatik çözer
- **Otomatik Başlatma**: Termux'u her açışta Ubuntu'yu otomatik başlatma seçeneği
- **Ubuntu Logosu**: Açılışta renkli Ubuntu logosu gösterimi
- **Kullanıcı Yönetimi**: İlk kurulumda (first-setup.sh ile) güvenli kullanıcı oluşturma seçeneği
  - Otomatik sudo yetkisi
  - Şifre korumalı giriş
  - Root yerine güvenli kullanıcı ile çalışma
- **Kolay Kurulum**: Tek komutla kurulum

## Tek Komutla Kurulum

```bash
pkg install -y wget && wget -O - https://raw.githubusercontent.com/ozbilgic/termux-ubuntu-kurulumu/main/ubuntu-installer.sh | bash
```

## Manuel Kurulum

```bash
# Script'i indir
wget https://raw.githubusercontent.com/ozbilgic/termux-ubuntu-kurulumu/main/ubuntu-installer.sh

# Çalıştırılabilir yap
chmod +x ubuntu-installer.sh

# Kurulumu başlat
./ubuntu-installer.sh
```

## Kurulum Adımları

1. Termux paketleri otomatik güncelleme ve onarım
2. Ubuntu LTS versiyonu seçimi (dinamik olarak tespit edilen 4 LTS versiyonu arasından)
3. Gerekli paketlerin kurulumu (proot, wget, tar)
4. Ubuntu rootfs indirme ve kurulum
5. İndirme başarısız olursa alternatif versiyon seçimi
6. Başlatma script'i oluşturma (start-ubuntu.sh)
7. İlk kurulum script'i hazırlama (first-setup.sh)
8. Otomatik başlatma seçeneği (Ubuntu logosu ile birlikte)
9. İlk kurulum: Sistem güncellemesi, temel paketler ve yeni kullanıcı oluşturma içerir

## Otomatik Başlatma Seçmeyenler İçin Ubuntu'yu Başlatma

```bash
./start-ubuntu.sh
```

## İlk Girişte Yapılması Gerekenler

Ubuntu'ya ilk girişte şu komutu çalıştırın:

```bash
bash /root/first-setup.sh
```

Bu komut:
- Sistem güncellemesi yapar
- Temel paketleri kurar (nano, vim, wget, curl, git, sudo)
- Yerel ayarları yapılandırır
- **Yeni kullanıcı oluşturma** seçeneği sunar (root yerine kullanmak için)
  - Kullanıcı adı ve şifre belirleme
  - Otomatik sudo yetkisi verme
  - Termux'un her açılışında bu kullanıcı ile başlama

### Yeni Kullanıcı Oluşturma (Önerilen)

İlk kurulum sırasında `first-setup.sh` scripti size yeni bir kullanıcı oluşturma seçeneği sunar. Bu özellik sayesinde:
- Root yerine güvenli bir kullanıcı ile çalışabilirsiniz
- Kullanıcı otomatik olarak sudo yetkisi alır
- Termux her açıldığında bu kullanıcı ile otomatik başlar
- Dilediğiniz zaman `su - kullanici_adi` ile kullanıcılar arası geçiş yapabilirsiniz

## Otomatik Başlatmayı Devre Dışı Bırakma

Eğer otomatik başlatmayı devre dışı bırakmak isterseniz:

```bash
nano ~/.bashrc
# Son kısımdaki "Ubuntu logo ve otomatik başlatma" bölümünü silin
```

## Desteklenen Mimariler

- ARM64 (aarch64)
- ARMHF (armv7l, armv8l)

## Gereksinimler

- Termux uygulaması
- İnternet bağlantısı
- En az 1GB boş alan

## Ubuntu'dan Çıkış

```bash
exit
```

## Sorun Giderme

### wget Kütüphane Hatası (libandroid-posix-semaphore.so)
Script bu sorunu otomatik çözmeye çalışır. Eğer hala devam ederse:

```bash
# Termux'u tamamen kapatıp yeniden açın
pkg update && pkg upgrade -y
pkg install --reinstall wget
```

### İndirme Hataları
- İnternet bağlantınızı kontrol edin
- Script otomatik olarak alternatif versiyonlar sunacaktır
- Farklı bir ağ deneyin
- Script'i tekrar çalıştırın

### Kurulum Hataları
Mevcut kurulumu silip yeniden kurmak için:

```bash
rm -rf ~/ubuntu-fs
./ubuntu-installer.sh
```

## Lisans

MIT License

## Katkıda Bulunma

Pull request'ler kabul edilir. Büyük değişiklikler için lütfen önce bir issue açın.
