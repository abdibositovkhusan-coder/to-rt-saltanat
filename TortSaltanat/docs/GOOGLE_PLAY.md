# To'rt Saltanat — Google Play'ga chiqarish yo'riqnomasi

## 1. Google Play Console akkaunti
- https://play.google.com/console — bir martalik to'lov 25 $.
- Yangi shaxsiy akkauntlar uchun: ilovani ishlab chiqarishga (production) chiqarishdan oldin
  **yopiq test** talab qilinadi — kamida 12 ta testchi 14 kun davomida. (Tashkilot akkauntida bu talab yo'q.)

## 2. Release kalitini yaratish (BIR MARTA, YO'QOTMANG!)
Kompyuterda (Java o'rnatilgan bo'lsa):

    keytool -genkeypair -v -keystore release.keystore -alias tortsaltanat -keyalg RSA -keysize 2048 -validity 10000

Parol so'raydi — eslab qoling. Keyin faylni base64 qiling:
- Windows (PowerShell): `[Convert]::ToBase64String([IO.File]::ReadAllBytes("release.keystore")) | Set-Clipboard`
- Linux/Mac: `base64 -w0 release.keystore`

GitHub → repo → Settings → Secrets and variables → Actions → **New repository secret**:
| Nomi | Qiymati |
|---|---|
| RELEASE_KEYSTORE_BASE64 | base64 matn |
| RELEASE_KEYSTORE_PASSWORD | parol |
| RELEASE_KEY_ALIAS | tortsaltanat |

`release.keystore` faylini xavfsiz joyda saqlang (Google Drive + fleshka). Yo'qolsa, ilovani yangilab bo'lmaydi
(Play App Signing yoqilsa, Google tiklashga yordam beradi — yoqib qo'ying).

## 3. AAB yasash
`.github/workflows/play.yml` repoda bo'lsin. GitHub → Actions → **Google Play (AAB + imzolangan APK)** → Run workflow.
Tugagach Artifacts'dan `TortSaltanat.aab` ni yuklab oling.

## 4. Play Console'da ilova yaratish
- Ilova nomi: **To'rt Saltanat: Afsonalar Urushi**
- Til: o'zbek (asosiy), qo'shimcha: rus, ingliz
- Turi: O'yin · Kategoriya: **Strategiya** · Bepul
- Paket nomi: `uz.husan.tortsaltanat` (o'zgartirib bo'lmaydi)

## 5. Do'kon sahifasi (Store listing)
**Qisqa tavsif (80 belgigacha)**
- uz: To'rt afsonaviy saltanat, qahramonlar va 25 missiyali real-time strategiya
- ru: Стратегия в реальном времени: четыре царства, герои легенд и 25 миссий
- en: Real-time strategy: four legendary kingdoms, heroes and 25 missions

**To'liq tavsif (uz)**
> Ko'hna Zaminda Yer Yuragi to'rt bo'lakka bo'lindi. Endi to'rt saltanat — Odamlar, Trollar va Devlar,
> Elflar hamda Yalmog'iz va Kashsheylar — uning taqdiri uchun kurashadi.
> • 4 saltanat, har birining o'z binolari, askarlari va mexanikasi
> • 17 afsonaviy qahramon: Alpomish, Barchinoy, Kashshey, Oydinoy, Qoyaqul va boshqalar
> • 4 bobli kampaniya, 25 missiya, kino-sahnalar va ikki xil yakun
> • Tezkor jang: istalgan saltanat, 3 xil qiyinlik
> • Kun va tun, tuman urushi, neytral lagerlar, buyumlar, karvonsaroy va choyxona
> • Telefon uchun qulay boshqaruv; o'zbek, rus va ingliz tillari
> • Internet talab qilinmaydi, reklama yo'q

**Grafika**
- Ikonka 512×512: `assets/icon/icon_512.png`
- Feature graphic 1024×500: `docs/feature_graphic_1024x500.png`
- Skrinshotlar: kamida 2 ta (telefonda o'yindan screenshot oling, gorizontal 16:9)

## 6. Majburiy bo'limlar (App content)
- **Maxfiylik siyosati**: `docs/PRIVACY_POLICY.md` matnini ochiq sahifaga joylang
  (masalan, GitHub repo ochiq bo'lsa — fayl havolasi, yoki Google Sites) va havolani kiriting.
- **Data safety**: "Ilova hech qanday foydalanuvchi ma'lumotini yig'maydi va uzatmaydi" — hammasiga "Yo'q".
- **Reklama**: Yo'q.
- **Kontent reytingi (IARC so'rovnoma)**: fantastik zo'ravonlik (multfilmsimon, qonsiz) — odatda 12+ / PEGI 12.
- **Maqsadli auditoriya**: 13+ (bolalar uchun maxsus emas — Families siyosati talablarini oldini oladi).
- **Huquqlar**: 3D modellar — KayKit (Kay Lousberg), CC0 litsenziya (tijoratda ham erkin);
  musiqa va ovozlar — loyiha ichida noldan sintez qilingan; afsonaviy nomlar — xalq og'zaki ijodi.

## 7. Chiqarish
1. Testing → **Internal testing** → yangi release → `TortSaltanat.aab` ni yuklang → o'zingizni testchi qiling.
2. Hammasi ishlasa: Closed testing (12 testchi, 14 kun) → Production.
3. Har yangi versiyada `export_presets.cfg` dagi `version/code` ni bittaga oshiring (Claude oshirib beradi).
