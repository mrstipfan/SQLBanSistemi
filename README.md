<p align="center">
  <a href="https://csarea.org">
    <img
      src="https://csarea.org/storage/uploads/2026/06/650x-20260620-155413-3c6836ef06.png"
      alt="CSArea"
      width="650"
    >
  </a>
</p>

<h1 align="center">CSArea SQL Ban Sistemi</h1>

<p align="center">
  Counter-Strike 1.6 sunucuları için AMX Mod X, SQLX ve MySQL/MariaDB tabanlı gelişmiş ban yönetim sistemi.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Sürüm-3.1-red" alt="Sürüm 3.1">
  <img src="https://img.shields.io/badge/Dil-Pawn-orange" alt="Pawn">
  <img src="https://img.shields.io/badge/Veritabanı-MySQL%20%7C%20MariaDB-blue" alt="MySQL veya MariaDB">
  <img src="https://img.shields.io/badge/Platform-AMX%20Mod%20X-green" alt="AMX Mod X">
</p>

---

## İçindekiler

- [Proje Hakkında](#proje-hakkında)
- [Öne Çıkan Özellikler](#öne-çıkan-özellikler)
- [Çalışma Mantığı](#çalışma-mantığı)
- [Gereksinimler](#gereksinimler)
- [Dosya Yapısı](#dosya-yapısı)
- [Kurulum](#kurulum)
- [Veritabanı Kullanıcısı Oluşturma](#veritabanı-kullanıcısı-oluşturma)
- [Yapılandırma](#yapılandırma)
- [Komutlar](#komutlar)
- [Yetki Sistemi](#yetki-sistemi)
- [SQL Tablo Yapısı](#sql-tablo-yapısı)
- [Ban ve Unban Davranışı](#ban-ve-unban-davranışı)
- [Yerel Ban Önbelleği](#yerel-ban-önbelleği)
- [Güvenlik Önerileri](#güvenlik-önerileri)
- [Derleme](#derleme)
- [Sorun Giderme](#sorun-giderme)
- [Teknik Notlar](#teknik-notlar)
- [Geliştirici](#geliştirici)

---

## Proje Hakkında

**CSArea SQL Ban Sistemi**, Counter-Strike 1.6 sunucularındaki oyuncu yasaklamalarını merkezi bir MySQL veya MariaDB veritabanında saklamak için geliştirilmiş bir AMX Mod X eklentisidir.

Eklenti; oyuncuları SteamID, IP adresi ve isteğe bağlı olarak kullanıcı adı üzerinden kontrol eder. Süreli veya süresiz ban oluşturabilir, aktif banları oyun içinden yönetebilir, normal unban işlemi uygulayabilir ve gerekli yetkiye sahip yöneticilerin SQL kayıtlarını fiziksel olarak temizlemesine izin verebilir.

Bu dokümantasyon, eklentinin **3.1** sürümündeki mevcut davranışa göre hazırlanmıştır.

> [!IMPORTANT]
> Eklenti SQL bağlantı bilgilerini `panel_sqlbansistemi.ini` dosyasından okur. Gerçek veritabanı parolanızı herkese açık GitHub deposuna yüklemeyin.

---

## Öne Çıkan Özellikler

- MySQL/MariaDB tabanlı merkezi ban kaydı
- SQLX ile asenkron veritabanı sorguları
- SteamID, IP adresi ve isteğe bağlı nick kontrolü
- Süreli ve süresiz ban desteği
- Oyun içi ban, unban ve SQL temizleme menüleri
- Konsol ve sohbet komutları
- Yapılandırılabilir yönetici yetkileri
- Yapılandırılabilir hazır ban sebepleri
- Manuel ban sebebi girişi
- Banlı oyuncunun bağlantı sırasında otomatik kontrol edilmesi
- Oyuncu adı değiştiğinde yeniden ban kontrolü
- Banlanan oyuncunun anında yerel önbelleğe alınması
- Normal unban işleminde geçmiş kaydın korunması
- Yetkili kullanıcılar için fiziksel SQL kayıt silme seçenekleri
- Pasif ve süresi dolmuş kayıtları temizleme seçenekleri
- Banlı giriş denemelerinde maskelenmiş IP duyurusu
- SQL tablosunun ilk çalıştırmada otomatik oluşturulması
- Sunucu konsolu ve `ADMIN_RCON` yetkisi için yönetim erişimi
- Bot ve HLTV istemcilerinin kontrol dışında bırakılması

---

## Çalışma Mantığı

Eklentinin temel işlem akışı aşağıdaki gibidir:

1. Eklenti başlatıldığında `panel_sqlbansistemi.ini` dosyası okunur.
2. Yapılandırma dosyası bulunamazsa varsayılan dosya otomatik oluşturulur.
3. SQL bağlantı tanımı hazırlanır.
4. Belirlenen SQL tablosu mevcut değilse otomatik oluşturulur.
5. Oyuncu bağlandığında ban kontrolü üç farklı zamanda çalıştırılır:
   - Yaklaşık `0.2` saniye sonra
   - Yaklaşık `1.0` saniye sonra
   - Yaklaşık `2.0` saniye sonra
6. Oyuncu önce yerel ban önbelleğinde kontrol edilir.
7. Yerel eşleşme bulunamazsa SQL veritabanında kontrol edilir.
8. Aktif bir ban bulunduğunda oyuncu sunucudan atılır.
9. Ban süresi dolmuşsa kayıt engelleme amacıyla kullanılmaz.
10. Normal unban işlemi kaydı silmez; kaydı pasif duruma getirir.

Bağlantı sırasında birden fazla kontrol yapılması, SteamID bilgisinin geç gelmesi veya oyuncu bilgilerinin ilk saniyelerde güncellenmesi gibi durumlarda ban kontrolünün kaçırılma ihtimalini azaltır.

---

## Gereksinimler

- Counter-Strike 1.6 HLDS veya ReHLDS sunucusu
- AMX Mod X
- AMX Mod X `sqlx` include dosyası
- Çalışan MySQL veya MariaDB sunucusu
- AMX Mod X MySQL modülü
- Veritabanına ağ erişimi
- Tablo oluşturma ve kayıt yönetimi için yeterli SQL izinleri

`modules.ini` içinde MySQL modülünün etkin olduğundan emin olun:

```ini
mysql
```

Bazı AMX Mod X kurulumlarında modül adı aşağıdaki şekilde bulunabilir:

```ini
mysql_amxx_i386.so
```

Sunucunuzdaki gerçek modül dosya adı kurulumunuza göre değişebilir.

---

## Dosya Yapısı

Önerilen kurulum yapısı:

```text
cstrike/
└── addons/
    └── amxmodx/
        ├── configs/
        │   ├── panel_sqlbansistemi.ini
        │   ├── plugins.ini
        │   └── modules.ini
        ├── plugins/
        │   └── panel_sqlbansistemi.amxx
        └── scripting/
            └── panel_sqlbansistemi.sma
```

---

## Kurulum

### 1. Kaynak kodu derleyin

`panel_sqlbansistemi.sma` dosyasını AMX Mod X compiler ile derleyin.

Başarılı derleme sonunda oluşan dosya:

```text
panel_sqlbansistemi.amxx
```

### 2. Eklentiyi plugins klasörüne yükleyin

```text
addons/amxmodx/plugins/panel_sqlbansistemi.amxx
```

### 3. Eklentiyi plugins.ini dosyasına ekleyin

```ini
panel_sqlbansistemi.amxx
```

### 4. MySQL modülünü etkinleştirin

`addons/amxmodx/configs/modules.ini` dosyasında MySQL modülünün kapalı olmadığını kontrol edin.

### 5. Sunucuyu başlatın

İlk çalıştırmada eklenti aşağıdaki yapılandırma dosyasını otomatik oluşturur:

```text
addons/amxmodx/configs/panel_sqlbansistemi.ini
```

### 6. SQL bilgilerini düzenleyin

Oluşturulan INI dosyasındaki veritabanı bilgilerini kendi sisteminize göre değiştirin.

### 7. Yapılandırmayı yeniden yükleyin

Sunucuyu yeniden başlatabilir veya yetkili konsolundan şu komutu çalıştırabilirsiniz:

```text
csa_reloadbansql
```

---

## Veritabanı Kullanıcısı Oluşturma

Aşağıdaki örnek komutları kendi veritabanı adınıza, kullanıcı adınıza, parolanıza ve oyun sunucusu IP adresinize göre düzenleyin.

```sql
CREATE DATABASE csarea_bans
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE USER 'csarea_ban'@'OYUN_SUNUCUSU_IP'
  IDENTIFIED BY 'GUCLU_BIR_PAROLA';

GRANT SELECT, INSERT, UPDATE, DELETE, CREATE
  ON csarea_bans.*
  TO 'csarea_ban'@'OYUN_SUNUCUSU_IP';

FLUSH PRIVILEGES;
```

Birden fazla oyun sunucusu aynı veritabanını kullanacaksa her sunucu IP adresi için ayrı kullanıcı tanımlamak daha güvenlidir.

> [!WARNING]
> Veritabanı kullanıcısına gereksiz şekilde `GRANT ALL` veya global yetki vermeyin. Eklentinin mevcut işlevleri için veritabanı seviyesinde `SELECT`, `INSERT`, `UPDATE`, `DELETE` ve `CREATE` yetkileri yeterlidir.

---

## Yapılandırma

Varsayılan yapılandırma dosyası:

```ini
; Onur MASALCI - CSArea SQL Ban Config
; addons/amxmodx/configs/panel_sqlbansistemi.ini

sql_host "sql.csarea.net"
sql_user "srv212_100_185_"
sql_pass ""
sql_db "srv212_100_185_"
sql_table "csa_bans"

def_ban_minutes "0"
info_message "1"
check_nick "1"
drop_message "Iletisim: www.CSArea.net"
chat_tag "[CSA-SQL Ban]"

access_ban "d"
access_unban "d"
access_sql_menu "r"
access_sql_delete "r"

reason_1 "Hile"
reason_2 "Kufur"
reason_3 "Kural ihlali"
reason_4 "Reklam"
reason_5 "Spam"
reason_6 "Flood"
```

### SQL ayarları

| Ayar | Açıklama |
|---|---|
| `sql_host` | MySQL/MariaDB sunucusunun alan adı veya IP adresi |
| `sql_user` | Veritabanı kullanıcı adı |
| `sql_pass` | Veritabanı parolası |
| `sql_db` | Kullanılacak veritabanının adı |
| `sql_table` | Ban kayıtlarının saklanacağı tablo adı |

### Genel ayarlar

| Ayar | Varsayılan | Açıklama |
|---|---:|---|
| `def_ban_minutes` | `0` | Menüdeki “Varsayılan Süre” seçeneğinin dakika değeri. `0` süresiz ban anlamına gelir. |
| `info_message` | `1` | Banlı giriş denemesi bilgisinin oyunculara gösterilip gösterilmeyeceği |
| `check_nick` | `1` | SQL ve yerel önbellek kontrollerinde nick eşleşmesinin kullanılması |
| `drop_message` | `Iletisim: www.CSArea.net` | Banlı oyuncu sunucudan atılırken gösterilecek ek mesaj |
| `chat_tag` | `[CSA-SQL Ban]` | Sohbet mesajlarında kullanılacak eklenti etiketi |

### Yetki ayarları

| Ayar | Varsayılan | Açıklama |
|---|---|---|
| `access_ban` | `d` | Oyuncu banlama yetkisi |
| `access_unban` | `d` | Normal unban yetkisi |
| `access_sql_menu` | `r` | SQL yönetim menüsünü açma yetkisi |
| `access_sql_delete` | `r` | SQL kayıtlarını fiziksel olarak silme yetkisi |

### Ban sebepleri

`reason_` ile başlayan satırlar ban sebebi menüsüne eklenir:

```ini
reason_1 "Hile"
reason_2 "Kufur"
reason_3 "Kural ihlali"
reason_4 "Reklam"
```

Kod tarafındaki azami hazır sebep sayısı:

```text
24
```

Bir sebebin azami uzunluğu:

```text
191 karakter
```

---

## Komutlar

### Sunucu ve yönetici konsolu komutları

| Komut | Açıklama |
|---|---|
| `csa_ban <nick/#userid> <dakika> [sebep]` | Çevrim içi oyuncuyu banlar |
| `csa_unban <nick/authid/ip>` | Nick, SteamID veya IP üzerinden normal unban uygular |
| `csa_banmenu` | Oyuncu banlama menüsünü açar |
| `csa_unbanmenu` | Aktif banlar için normal unban menüsünü açar |
| `csa_sqlmenu` | SQL kayıt yönetimi ve temizleme menüsünü açar |
| `csa_reloadbansql` | INI dosyasını yeniden okur, SQL bağlantısını yeniler ve tablo kontrolü yapar |

### Sohbet komutları

#### Ban menüsü

```text
!bm
.bm
/bm

!banmenu
.banmenu
/banmenu
```

#### Unban menüsü

```text
!ubm
.ubm
/ubm

!unbanmenu
.unbanmenu
/unbanmenu
```

#### SQL yönetim menüsü

```text
!sqlban
.sqlban
/sqlban

!sqlmenu
.sqlmenu
/sqlmenu
```

#### Sohbetten oyuncu banlama

```text
.ban <nick> <dakika> [sebep]
!ban <nick> <dakika> [sebep]
/ban <nick> <dakika> [sebep]
```

Örnek:

```text
.ban Player 60 Kufur ve hakaret
```

Süresiz ban örneği:

```text
.ban Player 0 Hile
```

#### Sohbetten normal unban

```text
.unban <nick/SteamID/IP>
!unban <nick/SteamID/IP>
/unban <nick/SteamID/IP>

.ub <nick/SteamID/IP>
!ub <nick/SteamID/IP>
/ub <nick/SteamID/IP>
```

Örnek:

```text
.unban STEAM_0:1:123456
```

---

## Yetki Sistemi

Eklenti AMX Mod X yönetici bayraklarını kullanır.

Varsayılan yetkiler:

| İşlem | Bayrak |
|---|---|
| Banlama | `d` |
| Normal unban | `d` |
| SQL menüsünü açma | `r` |
| SQL kayıtlarını fiziksel silme | `r` |

Aşağıdaki kullanıcılar özel davranışa sahiptir:

- Sunucu konsolu bütün yönetim kontrollerini geçer.
- `ADMIN_RCON` bayrağına sahip kullanıcılar yapılandırılmış yetki kontrolünü geçer.
- Normal yöneticiler `ADMIN_IMMUNITY` sahibi bir oyuncuyu banlayamaz.
- `ADMIN_RCON` sahibi bir yönetici immunity kontrolünü aşabilir.
- Yönetici kendisini banlayamaz.

Örnek `users.ini` kaydı:

```ini
"STEAM_0:1:123456" "" "bcdefghijklmnopqrstu" "ce"
```

Gerçek yetkileri kendi yönetici politikanıza göre sınırlandırın.

---

## SQL Tablo Yapısı

Eklenti, belirtilen tabloyu otomatik olarak aşağıdaki mantıkla oluşturur:

| Alan | Tür | Açıklama |
|---|---|---|
| `id` | `INT` | Otomatik artan benzersiz kayıt numarası |
| `player_nick` | `VARCHAR(32)` | Banlanan oyuncunun adı |
| `player_steamid` | `VARCHAR(34)` | Banlanan oyuncunun SteamID/AuthID değeri |
| `player_ip` | `VARCHAR(32)` | Banlanan oyuncunun IP adresi |
| `admin_nick` | `VARCHAR(32)` | Banı uygulayan yöneticinin adı |
| `admin_steamid` | `VARCHAR(34)` | Banı uygulayan yöneticinin SteamID/AuthID değeri |
| `reason` | `VARCHAR(191)` | Ban sebebi |
| `ban_minutes` | `INT` | Ban süresi. `0` süresiz ban anlamına gelir. |
| `created_at` | `DATETIME` | Banın oluşturulma zamanı |
| `expires_at` | `DATETIME` | Süreli banın bitiş zamanı |
| `server_ip` | `VARCHAR(64)` | Banın uygulandığı sunucunun IP değeri |
| `server_port` | `INT` | Banın uygulandığı sunucunun portu |
| `active` | `TINYINT(1)` | Kaydın aktif veya pasif durumu |
| `removed_at` | `DATETIME` | Normal unban zamanı |
| `removed_by` | `VARCHAR(64)` | Unban uygulayan yöneticinin adı |
| `removed_by_steamid` | `VARCHAR(34)` | Unban uygulayan yöneticinin SteamID/AuthID değeri |

Otomatik oluşturulan indeksler:

```text
PRIMARY KEY (id)
idx_player_nick
idx_player_steamid
idx_player_ip
idx_active
```

---

## Ban ve Unban Davranışı

### Süreli ban

Dakika değeri `1` veya daha büyük olduğunda:

```sql
expires_at = NOW() + belirtilen dakika
```

Ban kontrolü sırasında bitiş zamanı geçmiş kayıtlar oyuncuyu engellemez.

### Süresiz ban

Dakika değeri `0` olduğunda:

```text
ban_minutes = 0
expires_at = NULL
```

Bu kayıt, aktif olduğu sürece oyuncuyu engeller.

### Normal unban

Normal unban SQL kaydını fiziksel olarak silmez.

Aşağıdaki alanlar güncellenir:

```text
active = 0
removed_at = NOW()
removed_by = işlemi yapan yönetici
removed_by_steamid = yöneticinin SteamID/AuthID değeri
```

Bu yöntem ban geçmişinin korunmasını sağlar.

### SQL kaydını fiziksel silme

SQL temizleme menüsündeki kayıt silme işlemi şu sorguyu uygular:

```sql
DELETE FROM tablo WHERE id = kayıt_id;
```

Bu işlem geri alınamaz.

### Toplu temizleme işlemleri

SQL menüsünde aşağıdaki seçenekler bulunur:

- Pasif kayıtları sil
- Süresi dolmuş kayıtları sil
- Bütün SQL kayıtlarını sil
- Bütün yerel ban önbelleğini temizle

> [!CAUTION]
> Mevcut sürümde toplu SQL silme seçenekleri için ikinci bir onay ekranı bulunmamaktadır. `access_sql_delete` yetkisini yalnızca güvenilir yöneticilere verin.

---

## Yerel Ban Önbelleği

Eklenti, yeni oluşturulan banı SQL sorgusunun tamamlanmasını beklemeden yerel belleğe ekler. Böylece oyuncu aynı sunucuya hızlı şekilde yeniden bağlanmaya çalışırsa ban anında uygulanabilir.

### Özellikler

- Azami `128` yerel ban kaydı tutulur.
- Süreli kayıtlar zamanı dolduğunda temizlenir.
- Süresiz kayıtlar manuel olarak kaldırılana kadar bellekte kalır.
- SteamID, IP ve etkinse nick üzerinden eşleşme yapılır.
- Normal unban veya fiziksel silme sırasında ilgili yerel kayıt da kaldırılır.
- Önbellek dolduğunda mevcut kod ilk slotu yeniden kullanır.
- Yerel önbellek kalıcı değildir; sunucu veya eklenti yeniden başladığında temizlenir.

> [!NOTE]
> Yerel önbellek bir veritabanı yedeği değildir. SQL sunucusu erişilemez durumdayken yalnızca mevcut eklenti oturumunda daha önce oluşturulmuş yerel kayıtlar kullanılabilir.

---

## Güvenlik Önerileri

### SQL parolasını GitHub'a yüklemeyin

Aşağıdaki dosyayı `.gitignore` içine ekleyin:

```gitignore
addons/amxmodx/configs/panel_sqlbansistemi.ini
```

Depoda örnek bir yapılandırma paylaşacaksanız parola alanını boş bırakın:

```ini
sql_pass ""
```

### Ayrı ve kısıtlı SQL kullanıcısı kullanın

- Oyun sunucusunda `root` veritabanı hesabı kullanmayın.
- Her sunucu veya sunucu grubu için ayrı kullanıcı oluşturun.
- Kullanıcıyı yalnızca gerekli veritabanıyla sınırlandırın.
- Kaynak IP kısıtlaması kullanın.
- Güvenlik duvarında MySQL portunu herkese açmayın.

### Nick kontrolünü dikkatli kullanın

```ini
check_nick "1"
```

Nick kontrolü açık olduğunda aynı kullanıcı adını kullanan farklı bir oyuncu banlı kabul edilebilir.

SteamID ve IP kontrolü yeterliyse:

```ini
check_nick "0"
```

### SQL silme yetkisini sınırlandırın

```ini
access_sql_delete "r"
```

Bu yetki aşağıdaki geri döndürülemez işlemlere erişebilir:

- Tek kayıt silme
- Pasif kayıtları toplu silme
- Süresi dolan kayıtları toplu silme
- Bütün SQL kayıtlarını silme

### Yapılandırma dosyasını koruyun

Tablo adı SQL sorgularında yapılandırma dosyasından alınır. Bu nedenle INI dosyasına yalnızca güvenilir sistem kullanıcıları yazabilmelidir.

Örnek Linux izinleri:

```bash
chown oyunuser:oyunuser addons/amxmodx/configs/panel_sqlbansistemi.ini
chmod 600 addons/amxmodx/configs/panel_sqlbansistemi.ini
```

Kullanıcı ve grup adını kendi sunucu yapınıza göre değiştirin.

---

## Derleme

### Yerel compiler ile

Kaynak dosyayı AMX Mod X scripting klasörüne yerleştirin:

```text
addons/amxmodx/scripting/panel_sqlbansistemi.sma
```

Linux örneği:

```bash
cd addons/amxmodx/scripting
./amxxpc panel_sqlbansistemi.sma
```

Derlenen dosya genellikle şu dizinde oluşur:

```text
addons/amxmodx/scripting/compiled/panel_sqlbansistemi.amxx
```

Ardından dosyayı plugins klasörüne kopyalayın:

```bash
cp compiled/panel_sqlbansistemi.amxx ../plugins/
```

### Gerekli include dosyaları

Kaynak kod aşağıdaki include dosyalarını kullanır:

```pawn
#include <amxmodx>
#include <amxmisc>
#include <sqlx>
```

Derleme sırasında `sqlx.inc` bulunamadı hatası alırsanız AMX Mod X include paketiniz eksiktir.

---

## Sorun Giderme

### Eklenti çalışmıyor

Sunucu konsolunda:

```text
amxx plugins
```

Eklenti durumunu kontrol edin.

`bad load` görünüyorsa:

```text
amxx modules
```

komutuyla SQLX/MySQL modülünü kontrol edin.

### SQL bağlantı hatası

AMX Mod X loglarında aşağıdakine benzer satırlar aranmalıdır:

```text
[CSA-SQL Ban] SQL HATA: ...
[CSA-SQL Ban] Ban kontrol SQL hatasi: ...
```

Kontrol edilmesi gerekenler:

- `sql_host` doğru mu?
- `sql_user` doğru mu?
- `sql_pass` doğru mu?
- `sql_db` mevcut mu?
- MySQL portuna oyun sunucusundan erişilebiliyor mu?
- Veritabanı kullanıcısının kaynak IP izni doğru mu?
- Kullanıcının tablo oluşturma yetkisi var mı?
- AMX Mod X MySQL modülü yüklü mü?

### Tablo oluşmuyor

Eklenti tabloyu otomatik oluşturur. Veritabanı kullanıcısında en az şu yetkiler bulunmalıdır:

```text
CREATE
SELECT
INSERT
UPDATE
DELETE
```

### Oyuncu banlı olduğu halde girebiliyor

Şunları kontrol edin:

- SQL kaydında `active = 1` mi?
- Süreli banın `expires_at` zamanı geçmiş mi?
- Oyuncunun SteamID değeri doğru kaydedilmiş mi?
- IP adresi değişmiş mi?
- `check_nick` kapalı mı?
- Eklenti doğru SQL tablosuna mı bağlanıyor?
- Sunucunun sistem saati ile SQL sunucusunun saati uyumlu mu?

### Yanlış oyuncu nick nedeniyle banlı görünüyor

Nick eşleşmesini kapatın:

```ini
check_nick "0"
```

### Yapılandırma değişikliği uygulanmıyor

Sunucuyu yeniden başlatın veya:

```text
csa_reloadbansql
```

komutunu çalıştırın.

### Türkçe karakterler bozuk görünüyor

SQL tablosu `utf8mb4` ile oluşturulur. Buna rağmen oyun içi metinlerde karakter sorunu yaşanıyorsa:

- SMA dosyasının kodlamasını kontrol edin.
- Sunucu konsolunun ve compiler'ın karakter kodlamasını kontrol edin.
- Counter-Strike 1.6 istemci metin sınırlamalarını dikkate alın.
- Gerekirse oyun içi metinlerde ASCII karşılıkları kullanın.

---

## Teknik Notlar

- Eklenti sürümü: `3.1`
- Ban sebebi azami uzunluğu: `191`
- Oyuncu adı azami uzunluğu: `32`
- SteamID/AuthID alanı: `35`
- IP alanı: `32`
- Yerel ban slotu: `128`
- Hazır sebep sayısı: en fazla `24`
- SQL sorguları `SQL_ThreadQuery` ile asenkron çalıştırılır.
- Aktif ban sorguları en yeni kaydı `ORDER BY id DESC LIMIT 1` ile seçer.
- Aktif süreli banlar `expires_at > NOW()` koşuluyla doğrulanır.
- Oyuncu adı değiştiğinde yeniden kontrol planlanır.
- Bot ve HLTV istemcileri ban kontrolüne dahil edilmez.
- Banlı giriş duyurusunda IP adresinin son iki bölümü maskelenir.
- Fiziksel SQL temizliği sırasında silinen kayıtların geri dönüş mekanizması yoktur.
- Normal unban geçmiş kaydını korur.
- Eklenti, SQL bağlantısı için standart `SQL_MakeDbTuple` yapısını kullanır.
- SQL hata mesajları AMX Mod X loglarına yazılır.

---

## Örnek Kullanım Senaryoları

### Bir oyuncuyu 30 dakika banlama

```text
csa_ban "Player Name" 30 Kufur
```

### Bir oyuncuyu süresiz banlama

```text
csa_ban "Player Name" 0 Hile
```

### UserID ile banlama

```text
csa_ban #15 120 Reklam
```

### SteamID üzerinden normal unban

```text
csa_unban STEAM_0:1:123456
```

### IP üzerinden normal unban

```text
csa_unban 192.0.2.10
```

### Ban menüsünü açma

```text
csa_banmenu
```

veya sohbetten:

```text
!bm
```

### SQL yönetim menüsünü açma

```text
csa_sqlmenu
```

veya sohbetten:

```text
!sqlmenu
```

---

## Önerilen `.gitignore`

```gitignore
# Gerçek SQL giriş bilgileri
addons/amxmodx/configs/panel_sqlbansistemi.ini

# Derlenmiş AMXX dosyaları
addons/amxmodx/scripting/compiled/
*.amxx

# Log ve geçici dosyalar
*.log
*.tmp
```

Derlenmiş `.amxx` dosyasını GitHub Releases üzerinden dağıtacaksanız `*.amxx` satırını kaldırabilirsiniz.

---

## Depo İçin Önerilen Yapı

```text
csarea-sql-ban/
├── README.md
├── LICENSE
├── .gitignore
├── configs/
│   └── panel_sqlbansistemi.example.ini
├── scripting/
│   └── panel_sqlbansistemi.sma
└── releases/
    └── panel_sqlbansistemi.amxx
```

Örnek yapılandırma dosyasında gerçek parola kullanılmamalıdır.

---

## Geliştirici

**Onur “MrStipFan” MASALCI**

- Proje: CSArea SQL Ban Sistemi
- Sürüm: 3.1
- Platform: AMX Mod X / Counter-Strike 1.6
- Web: [CSArea.org](https://csarea.org)

---

<p align="center">
  <strong>CSArea</strong><br>
  Counter-Strike topluluğu ve oyun sunucusu çözümleri
</p>
