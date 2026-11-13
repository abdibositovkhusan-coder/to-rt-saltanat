# MASTER PROMPT — «TO'RT SALTANAT: AFSONALAR URUSHI»
### Android uchun real-time strategiya (RTS) o'yini — Godot 4, GitHub Actions orqali APK

---

## 0. SENING ROLING VA ASOSIY QOIDALAR

Sen — tajribali o'yin dasturchisi, game-designer va texnik rahbarsan. Vazifang: telefon (Android) uchun **katta, to'liq, Warcraft III darajasidagi** real-time strategiya o'yinini yaratish. O'yin janri: baza qurish, resurs yig'ish, armiya tayyorlash, darajasi oshadigan qahramonlar, sehrli qobiliyatlar, kampaniya va skirmish rejimi.

**Majburiy qoidalar:**
1. O'yin **100% original** bo'ladi. Warcraft, Blizzard yoki boshqa kompaniyalarning nomlari, qahramonlari, irqlari, rasmlari, ovozlari, xaritalari, UI dizayni va matnlarini **ishlatma**. Faqat janr mexanikalari (resurs, baza, qahramon, tuman urushi) umumiy — ular hammaniki.
2. Barcha o'yin ichidagi matnlar **o'zbek tilida (lotin)**, keyinchalik rus va ingliz tili qo'shilishi uchun lokalizatsiya tizimi bo'ladi.
3. Kodni **bosqichma-bosqich** yoz (13-bo'lim). Har bosqich oxirida o'yin ishga tushadigan, APK quriladigan holatda bo'lsin. Bir martada hammasini yozishga urinma.
4. Barcha birlik, bino, qahramon, qobiliyat va texnologiya ma'lumotlari **kod ichida emas, ma'lumot fayllarida** (Godot `Resource` `.tres` yoki JSON) saqlansin — balansni kodga tegmasdan o'zgartirish mumkin bo'lsin.
5. Har bir yangi faylning boshida qisqa izoh: nima qiladi, nimaga bog'liq.

---

## 1. O'YIN HAQIDA UMUMIY

- **Nomi:** «To'rt Saltanat: Afsonalar Urushi»
- **Platforma:** Android (minimal Android 8.0, API 26), landshaft (gorizontal) ekran. Keyinchalik PC (Windows) eksporti ham ishlasin.
- **Dvigatel:** Godot 4.3+ (GDScript), 3D low-poly grafika, izometrik kamera (45° burchak, yaqinlashtirish/uzoqlashtirish mumkin).
- **Dunyo:** «Ko'hna Zamin» — afsonaviy o'lka. Tog'lar, botqoqlar, sehrli o'rmonlar, oltin vodiylar va la'natlangan cho'llar. Qadimda «Yer Yuragi» degan sehrli tosh to'rt bo'lakka bo'lingan va har bir saltanat bitta bo'lagini qo'riqlaydi. Kim to'rtalasini birlashtirsa — butun dunyoga hukmron bo'ladi.
- **Rejimlar:**
  - **Kampaniya** — har bir saltanat uchun 6 tadan missiya (jami 24), hikoya bilan bog'langan.
  - **Skirmish** — kompyuter (AI) ga qarshi, 2–4 o'yinchi, 3 xil qiyinlik.
  - **Tezkor jang** — 10 daqiqalik qisqa o'yin, telefon uchun.
  - **Ko'p o'yinchi (keyingi versiya)** — LAN/Wi-Fi orqali; arxitektura buni hisobga olgan holda yozilsin (deterministik simulyatsiya, buyruqlar navbati).

---

## 2. RESURSLAR VA IQTISODIYOT

Hamma saltanatda umumiy 3 ta resurs bor:

| Resurs | Qayerdan | Nima uchun |
|---|---|---|
| **Oltin** | Oltin konlaridan ishchilar tashiydi | Birliklar, binolar, texnologiyalar |
| **Yog'och** | Daraxtlarni kesish | Binolar, qurollar, mudofaa |
| **Oziq (aholi limiti)** | Oziq binolari beradi | Armiya hajmi chegarasi (maks. 120) |

**Xizmat haqi (soliq) tizimi:** armiya 50 dan oshsa oltin daromadi 30% kamayadi, 80 dan oshsa 60% kamayadi. Bu o'yinchini kichik, kuchli armiya bilan o'ynashga undaydi.

Har bir saltanatda **o'ziga xos 4-resurs/mexanika** bor (3-bo'limda).

---

## 3. TO'RT SALTANAT

### 3.1. TROLLAR VA DEVLAR SALTANATI — «Qoyatosh Davlati»

**Tasvir:** Shimoliy tog'larda yashovchi ulkan, kuchli, lekin sekin xalq. Toshdan o'yilgan qal'alar, vulqon olovi, ibtidoiy totemlar. Rang: to'q yashil, kul rang, lava qizili.

**O'ziga xos mexanika — «G'azab Olovi»:** har bir birlik jangda zarba berganda va olganda G'azab to'playdi (0–100). G'azab 100 ga yetganda birlik 8 soniya **kattalashadi**: +40% zarar, +25% hajm, lekin boshqarib bo'lmay yaqin dushmanga o'zi tashlanadi. Trollar o'z-o'zidan sog'ayadi (regeneratsiya), lekin olovdan 2 barobar zarar oladi.

**Birliklar:**
| Birlik | Turi | Tavsif |
|---|---|---|
| **Qulbon** | Ishchi | Kichik tosh-troll, yelkasida savat. Bir martada boshqalardan 1.5x ko'p yog'och tashiydi, lekin sekin. |
| **Toshtish Troll** | Piyoda jangchi | Tosh boltali, arzon, tez tiklanadi. |
| **Nayza Otar Troll** | Uzoqdan hujum | Zaharli nayzalar otadi, zahar 5 soniya zarar beradi. |
| **Botqoq Jodugari** | Sehrgar | Dushmanni sekinlashtiruvchi botqoq yaratadi, o'z birliklarini sog'aytiradi. |
| **Ikki Boshli Dev** | Og'ir jangchi | Ikki bosh — ikki xil hujum: biri yaqinni uradi, biri uzoqqa tosh otadi. |
| **Mamont Chavandoz** | Otliq (og'ir) | Junli mamontga mingan dev. Yugurib kelib urganda dushmanni uloqtiradi. |
| **Qoya Otar Gigant** | Qamal mashinasi | Ulkan dev, binolarga qoya otadi. Juda sekin. |
| **Vulqon Ilon** | Uchuvchi | Lava qanotli ilon, yerga olovli iz qoldiradi. |
| **Qadimgi Tog' Ruhi** | Super birlik (1 ta) | Tog'ning o'zi tirilgandek ulkan mavjudot. Yerga urib zilzila chiqaradi. |

**Binolar:** Tosh G'or (bosh bino) → Qoya Qal'a → Vulqon Taxti (3 daraja), Totem Ustuni (oziq), Jangchilar Arenasi, Shamon Kulbasi, Devlar Chuquri, Lava O'chog'i (qurol-yarog' yaxshilash), Ilonlar Uyasi, Qo'riqchi Tosh (minora).

---

### 3.2. YALMOG'IZ VA KASHSHEYLAR SALTANATI — «Qora Tuman Saltanati»

**Tasvir:** La'natlangan sharqiy o'rmonlar va jonsiz cho'llar. Yalmog'iz kampirlar sehri va O'lmas Kashshey shohlari boshqaradi. Tovuq oyoqli kulbalar, suyak minoralar, qora qarg'alar. Rang: binafsha, qora, zahar yashili.

**O'ziga xos mexanika — «Jon Tuxumi»:** Kashshey qahramonlari va elita birliklarning joni **Jon Tuxumi** binosida saqlanadi (afsonadagidek: igna tuxum ichida, tuxum sandiqda). Tuxum tik turar ekan, bu birliklar o'lganda 20 soniyadan keyin tuxum yonida **qayta tiriladi**. Dushman tuxumni topib buzsa — bu imtiyoz yo'qoladi. Tuxumni boshqa joyga yashirincha ko'chirish mumkin (60 soniya, sekin).

**Ikkinchi mexanika — «Qora Tuman»:** binolar atrofga qora tuman yoyadi. Tumanda o'z birliklari sog'ayadi, dushman sekinlashadi va ko'rishi qisqaradi. Binolarni faqat tuman ustiga qurish mumkin.

**Birliklar:**
| Birlik | Turi | Tavsif |
|---|---|---|
| **Suyak Qul** | Ishchi | Tirilgan skelet, charchamaydi, kechasi ham ishlaydi, lekin oltinni sekin tashiydi. |
| **Ajina** | Piyoda | Tez, kichik jin; ko'rinmas bo'lib yaqinlashadi. |
| **Alvasti** | Uzoqdan hujum | Sochlarini qamchidek ishlatib uzoqdan uradi, dushman qurolini zaiflashtiradi. |
| **Qarg'a Jodugar** | Sehrgar | O'lgan dushmanlardan Suyak Askar tiriltiradi, qarg'alar galasini yuboradi. |
| **Temir Tishli Ayiq** | Og'ir jangchi | Yalmog'iz sehrlagan ayiq, tishlaganda qon ketishi (bleed). |
| **Ilon Otli Chavandoz** | Otliq | Ulkan ilonga mingan Kashshey ritsari. |
| **Tovuq Oyoqli Kulba** | Qamal + transport | Yuruvchi kulba! Ichiga 4 birlik sig'adi, binolarga tepib zarar beradi. |
| **Uch Boshli Ajdar** | Uchuvchi | Har bir boshi alohida: olov, muz, zahar. |
| **Qora Shamol** | Super birlik (1 ta) | Ruhlardan iborat bo'ron, o'tgan joyidagi hamma narsani zaiflashtiradi. |

**Binolar:** Yalmog'iz Kulbasi (bosh) → Suyak Qasr → O'lmaslar Taxti, Jon Tuxumi (maxsus, faqat 1 ta), Qabriston (oziq), Jinlar Qudug'i, Jodugarlar Qozoni, Ayiq Uyasi, Ajdar Qoyasi, Qarg'a Minorasi.

---

### 3.3. ELFLAR SALTANATI — «Oydin O'rmon Saltanati»

**Tasvir:** G'arbdagi ming yillik o'rmonlar. Daraxtlar ichiga qurilgan nurli shaharlar, kumush daryolar, sehrli gullar. Elflar uzoq yashaydi, chaqqon, kamon va tabiat sehrining ustalari. Rang: zumrad yashil, kumush, oy nuri ko'ki.

**O'ziga xos mexanika — «Ildiz Tarmog'i»:** elf binolari yer ostidan ildizlar bilan bog'lanadi. Bog'langan binolar bir-biriga **resurs va sog'liq** uzatadi, bir binoda o'rgatilayotgan birlik tarmoqdagi istalgan binodan chiqishi mumkin. Dushman ildizni (ko'rinadigan yo'lak) kesib tarmoqni uzishi mumkin.

**Ikkinchi mexanika — «Oy va Quyosh»:** kechasi elflar ko'rinmas bo'lib qoladi (harakatsiz turganda), kunduzi esa hujumi +15%.

**Birliklar:**
| Birlik | Turi | Tavsif |
|---|---|---|
| **Gulchi** | Ishchi | Daraxtni kesmaydi — undan "nektar" yig'adi, daraxt yo'qolmaydi (cheksiz yog'och, lekin sekin). |
| **Barg Qilichli Qo'riqchi** | Piyoda | Yengil, tez, ikkita egri qilich. |
| **Kumush Kamonchi** | Uzoqdan hujum | Eng uzoq masofa, kechasi o'qlari ko'rinmaydi. |
| **Shamol Raqqosasi** | Sehrgar | Bo'ron chaqiradi, o'z birliklarini tezlashtiradi. |
| **Qadimgi Daraxt Qo'riqchisi** | Og'ir jangchi | Yuruvchi qari daraxt, ildizlari bilan dushmanni ushlab qoladi. |
| **Oq Bug'u Chavandoz** | Otliq | Sehrli bug'uga mingan nayzachi, o'rmonda ko'rinmas harakatlanadi. |
| **Tikanli Ildiz** | Qamal | Yer ostidan binolarga ildiz yuborib, ularni ichidan buzadi. |
| **Humo Qushi** | Uchuvchi | Afsonaviy baxt qushi. Soyasi tushgan o'z birliklari sog'ayadi. |
| **Simurg'** | Super birlik (1 ta) | Ulkan olov-nur qushi, o'lganda kuldan qayta tug'iladi (bir marta). |

**Binolar:** Hayot Daraxti (bosh) → Oy Ibodatxonasi → Abadiy Bog', Gul Bog'i (oziq), Qo'riqchilar Daraxtzori, Kamon Ustaxonasi, Shamol Minorasi, Bug'ular Yaylovi, Osmon Uyasi, Tikan Qo'rg'oni (mudofaa).

---

### 3.4. ODAMLAR SALTANATI — «Oltin Vodiy Saltanati»

**Tasvir:** Markazdagi unumdor vodiylar. Moviy gumbazli shaharlar, karvonsaroylar, qal'a devorlari, dehqonchilik va hunarmandchilik. Odamlar alohida kuchli emas, lekin eng **moslashuvchan** va eng yaxshi muhandislar. Rang: oltin, moviy (koshin), oq.

**O'ziga xos mexanika — «Karvon Yo'li»:** ikki yoki undan ko'p shahar markazi qurilsa, ular o'rtasida avtomatik **savdo karvonlari** yuradi va qo'shimcha oltin olib keladi. Karvonni dushman talashi mumkin — uni qo'riqlash kerak.

**Ikkinchi mexanika — «Bayroq va Ruh»:** Bayroqdor birlik atrofidagi askarlar +20% himoya oladi. Odamlar jangda yutgan sari «Shon-shuhrat» to'playdi va undan maxsus buyruqlar ochiladi (masalan, «Umumiy Hujum!» — 10 soniya barcha armiya tezlashadi).

**Birliklar:**
| Birlik | Turi | Tavsif |
|---|---|---|
| **Dehqon** | Ishchi | Tez quradi; xavf paytida «Qurollan!» tugmasi bilan vaqtincha jangchiga aylanadi. |
| **Navkar** | Piyoda | Qalqon va qilichli, muvozanatli askar; qalqon devori hosil qila oladi. |
| **Mergan Kamonchi** | Uzoqdan hujum | Yaxshilanganda olovli o'q. |
| **Yulduz Olimi** | Sehrgar | Rasadxonada o'qigan munajjim-sehrgar: meteor yog'diradi, dushmanni sekinlashtiradi. |
| **Tabib** | Yordamchi | Davolaydi, zaharni olib tashlaydi. |
| **Otliq Botir** | Otliq | Qorabayir otdagi og'ir sovutli chavandoz. |
| **Manjaniq** | Qamal | Uzoqdan katta toshlar otadi, binolarga 3x zarar. |
| **Uchar Gilam Sehrgari** | Uchuvchi | Gilamda uchib, yuqoridan olovli shishalar tashlaydi. |
| **Oltin Gvardiya** | Super birlik (5 kishilik guruh) | Saltanatning eng zo'r qo'riqchilari, bir-birini himoya qiladi. |

**Binolar:** Qishloq Markazi (bosh) → Qal'a → Poytaxt Saroyi, Uy (oziq), Navkarxona, Kamonchilar Maydoni, Rasadxona (sehrgarlar), Shifoxona, Otxona, Temirchi (yaxshilash), Ustaxona (qamal), Minora, Qal'a Devori (qurib, darvoza qo'yiladigan).

---

## 4. QAHRAMONLAR

Har bir saltanatda **4 ta qahramon**: 3 ta oddiy + 1 ta maxfiy «Do'stlar» qahramoni (o'yinchi va do'stlari, yuzi suratlaridan olingan). Qahramon maksimal 10-darajagacha o'sadi, har darajada 1 ochko, 3 ta oddiy qobiliyat (har biri 3 daraja) va 6-darajada ochiladigan **ulti** qobiliyat. O'lgan qahramonni bosh binoda oltin evaziga qayta tiriltirish mumkin. Bir vaqtda maksimum 3 ta qahramon.

Qahramonlarning 6 ta inventar katagi bor (narsalar, 6-bo'lim).

### 4.1. Trollar va Devlar qahramonlari
1. **Qoyaqul — Tog' Devi** (tank)
   - *Qoya Qalqon:* 6 soniya hamma zarbaning 60% ini yutadi.
   - *Yer Yorig'i:* oldiga yoriq ochib, dushmanlarni 2 soniya qotiradi.
   - *Tosh Teri:* passiv — himoya +3/+6/+9.
   - **ULTI — Tog'ning Uyg'onishi:** 20 soniya ulkan tosh gigantga aylanadi, zarar 2x, hajm 3x.
2. **Zahrinoz — Botqoq Jodugari** (sehr)
   - *Zaharli Bulut*, *Qurbaqaga Aylantirish* (dushmanni 4 soniya qurbaqa qiladi), *Botqoq Shifosi*.
   - **ULTI — Botqoq Yutadi:** katta hududni botqoqqa aylantiradi, ichidagi dushmanlar sekin cho'kib zarar oladi.
3. **Bo'ronbek — Ikki Boltali Troll** (hujumchi)
   - *Bolta Bo'roni* (aylanib uradi), *Qon Hidi* (yarador dushmanga tezlik), *Bolta Otish*.
   - **ULTI — Cheksiz G'azab:** G'azab 100 da qotib qoladi, lekin boshqaruv yo'qolmaydi.
4. **[Do'st qahramoni] Saidxon — Vulqon Bahodiri** — qobiliyatlari: *Lava Mushti*, *Olovli Sakrash*, *Vulqon Qalbi*; ULTI — *Otashfishon*.

### 4.2. Yalmog'iz va Kashsheylar qahramonlari
1. **Kashshey — O'lmas Shoh** (sehrli jangchi)
   - *Muz Zanjir*, *Jon So'rish* (dushman sog'lig'ini o'ziga oladi), *Suyak Qo'shini* (3 skelet chaqiradi).
   - **ULTI — Igna Sirri:** 15 soniya umuman o'lmaydi (sog'liq 1 dan pastga tushmaydi).
2. **Yalmog'iz Kampir** (sehr)
   - *Qozon Qaynashi* (zaharli suyuqlik sachratadi), *Supurgi Parvozi* (uchib boshqa joyga o'tish), *La'nat* (dushman qobiliyatlari qayta ishlash vaqti 2x).
   - **ULTI — Tovuq Oyoqli Qal'a:** maydonga vaqtinchalik yuruvchi jang kulbasini chaqiradi.
3. **Alvasti Malika** (makr)
   - *Ko'zgu Aksi* (2 ta soxta nusxa), *Ko'rinmaslik*, *Qo'rquv Qichqirig'i* (dushmanlar qochib ketadi).
   - **ULTI — Tush Qamog'i:** dushman qahramonini 6 soniya uxlatib, uni tushida azoblaydi.
4. **[Do'st qahramoni] Olimxon — Qora Qarg'alar Hukmdori** — *Qarg'a Galasi*, *Soya Qadami*, *Kechki Ko'z*; ULTI — *Abadiy Tun* (xaritada 30 soniya tun bo'ladi).

### 4.3. Elflar qahramonlari
1. **Oydinoy — Oy Kamonchisi** (uzoqdan)
   - *Oy O'qi* (zarba + qotirish), *Kumush Yomg'ir* (o'qlar yomg'iri), *Yulduz Ko'zi* (passiv, kritik zarba).
   - **ULTI — To'lin Oy:** xaritaning bir qismi oy nuri bilan yoritiladi, ichidagi dushmanlar ko'r bo'ladi.
2. **Shamshod — O'rmon Ruhi** (yordamchi)
   - *Ildiz Tuzog'i*, *Hayot Nafasi* (guruhni davolaydi), *Daraxt Tiriltirish* (daraxtlarni jangchiga aylantiradi).
   - **ULTI — O'rmon Uyg'onishi:** atrofdagi barcha daraxtlar 30 soniya qo'riqchiga aylanadi.
3. **Zumrad — Shamol Qilichbozi** (tez hujumchi)
   - *Shamol Qadami* (dash), *Barg Bo'roni*, *Raqs Zarbasi* (ketma-ket zarbalar).
   - **ULTI — Ming Tig':** 5 ta yaqin dushmanga birdaniga uchib borib uradi.
4. **[Do'st qahramoni] Ulug'bek — Yulduzlar Kuzatuvchisi** — *Yulduz Xaritasi* (xaritani ochadi), *Meteor O'qi*, *Osmon Qalqoni*; ULTI — *Yulduzlar Yomg'iri*.

### 4.4. Odamlar qahramonlari
1. **Alpomish — Qo'ng'irot Botiri** (afsonaviy jangchi; xalq dostoni qahramoni)
   - *Botir Zarbasi*, *Jangovar Hayqiriq* (atrofdagilarga +hujum), *Temir Iroda* (sekinlashtirish va qotirishga chidamli).
   - **ULTI — Yetti Yillik Zindon Kuchi:** sog'lig'i qancha kam bo'lsa, shuncha kuchli uradi.
2. **Barchinoy — Ot Ustasi** (otliq qahramon)
   - *Chopqir Hujum*, *Kamon Otishma* (otda yurib otadi), *Otlar Hamdardligi* (otliqlarga +tezlik).
   - **ULTI — Ko'pkari:** dushman qahramonini ushlab, o'z qo'shini ichiga sudrab olib keladi.
3. **Mavlono Nurali — Rasadxona Allomasi** (sehrgar)
   - *Meteor*, *Vaqt Sekinlashuvi*, *Bilim Nuri* (passiv, guruh manasi tiklanadi).
   - **ULTI — Quyosh Tutilishi:** 8 soniya barcha dushman sehrlari ishlamaydi.
4. **[Do'st qahramoni] Husan — Adolat Sardori** (qo'mondon)
   - *Hukm* (eng kuchli dushmanni belgilaydi, unga hamma +30% zarar beradi), *Qonun Qalqoni* (guruhga himoya), *Dalil* (dushmanning ko'rinmas birliklarini fosh qiladi).
   - **ULTI — Oliy Hukm:** hududdagi barcha dushmanlar 5 soniya qurolsizlanadi.

> Do'st qahramonlari kampaniyada maxfiy missiyalarni bajargandan keyin yoki «Choyxona»da ochiladi. Ularning 3D yuzi uchun suratdan teksturani yuzga qoplash tizimi bo'lsin (`assets/faces/` papkasiga rasm qo'yilsa, avtomatik ishlatilsin). Qaysi do'st qaysi saltanatda — sozlash faylida o'zgartirish mumkin.

---

## 5. TEXNOLOGIYALAR DARAXTI (TEXNIKALAR)

Har saltanatda **3 davr**: 1-davr (boshlanish) → 2-davr (bosh binoni yaxshilash) → 3-davr (oxirgi yaxshilash). Har davr yangi birlik, bino va qobiliyatlarni ochadi.

**Umumiy yaxshilashlar (har saltanatda o'z nomi bilan, 3 darajadan):**
- Yaqin jang quroli, uzoq jang quroli, sovut, sehr kuchi, ishchi samaradorligi, minora kuchi.

**Har saltanatning maxsus texnikalari (har biri 4–6 ta):**
- **Trollar:** *Qon Regeneratsiyasi* (tiklanish 2x), *Vulqon Qurollari* (zarbaga olov), *Devlar Kuchi* (devlarga +sog'liq), *Qadimgi Totem* (G'azab tezroq to'planadi), *Muzga Chidamlilik*.
- **Yalmog'iz va Kashshey:** *Qoraygan Yer* (tuman 2x kengayadi), *Jon Ignasi* (Jon Tuxumi 2 marta tiriltiradi), *Murda Tiriltirish*, *Qarg'a Josuslari* (xaritada josus qarg'alar), *Suyak Sovut*.
- **Elflar:** *Chuqur Ildizlar* (tarmoq masofasi +50%), *Oy Barakasi* (kechasi sog'ayish), *Sehrli O'qlar* (o'q dushman sovutini teshadi), *Bug'u Chaqqonligi*, *Abadiy Bahor* (Gulchilar tezroq).
- **Odamlar:** *Karvon Qo'riqchilari* (karvonlar jang qiladi), *Damashq Po'lati* (qurollar +zarar), *Qal'a Muhandisligi* (devorlar 2x mustahkam), *Munajjimlik* (sehrgarlar ko'proq mana), *Bayroq Ruhi* (bayroq aurasi kengayadi), *Porox* (3-davrda zambarak ochiladi).

Texnologiyalar daraxti o'yin ichida **vizual ekran** sifatida ko'rinsin (tugunlar va chiziqlar).

---

## 6. NEYTRAL DUNYO, NARSALAR VA JOYLAR

- **Neytral yirtqich lagerlari** (xaritada): bo'rilar, cho'l chayonlari, tosh golemlar, qaroqchilar to'dasi, qadimgi ajdar (eng kuchli). O'ldirilsa — tajriba (XP), oltin va narsalar tushadi.
- **Choyxona** (neytral bino): har qanday saltanatdan bo'lmagan yollanma qahramonlarni yollash (masalan, *Nasriddin Afandi — Hiylakor Donishmand* eshagi bilan).
- **Karvonsaroy** (neytral do'kon): narsalar sotib olish — sog'liq ichimligi, mana ichimligi, teleport o'rami, ko'rinmaslik choponi, kuch uzugi, Sulaymon muhri (qobiliyat himoyasi) va h.k. Jami kamida 40 ta narsa, 4 daraja noyoblik (oddiy, noyob, epik, afsonaviy).
- **Sehrli manba** — tun bo'yi manani tiklaydi.
- **Ko'priklar, darvozalar, buziladigan daraxtlar, baland joylar** (balandlikdagi birlik +25% masofa va pastdan ko'rinmaydi).
- **Kun va tun aylanishi:** 1 kun = 8 daqiqa. Kechasi ko'rish masofasi qisqaradi, ba'zi yirtqichlar uxlaydi.
- **Ob-havo:** yomg'ir (otashli hujumlar zaiflashadi), qor (sekinlashish), qum bo'roni (ko'rish yo'q).

---

## 7. JANG MEXANIKASI

- **Hujum va himoya turlari** (tosh-qaychi-qog'oz kabi): Hujum turlari — *Oddiy, Teshuvchi, Sehrli, Qamal, Qahramon*. Sovut turlari — *Yengil, O'rta, Og'ir, Mustahkam (binolar), Qahramon*. Har juftlik uchun zarar koeffitsienti jadvali (`data/damage_table.tres`).
- **Tuman urushi (fog of war):** qora (ko'rilmagan), kulrang (ko'rilgan, lekin hozir yo'q), ochiq.
- **Birliklar holati:** hujum, harakat, ushlab turish (hold), patrul, ergashish, «hujum-harakat» (yo'lda duch kelganga hujum).
- **Buff/debuff tizimi:** sekinlashtirish, qotirish, zahar, yonish, qon ketishi, ko'rinmaslik, qobiliyat taqiqi — umumiy `StatusEffect` resursi orqali.
- **Tajriba:** qahramon yaqinida o'lgan dushmanlar XP beradi.

---

## 8. SUN'IY INTELLEKT (AI)

- **Raqib AI** 3 qiyinlikda (Oson, O'rta, Qiyin) + har saltanat uchun o'z uslubi (Trollar — erta bosim, Yalmog'iz — tuman yoyish va kechki hujum, Elflar — kamonchilar va ko'rinmas hujumlar, Odamlar — kengayish va karvonlar).
- AI qurilishi: *iqtisod moduli* (ishchilar, resurs), *qurilish tartibi* (data faylidan), *armiya moduli* (tarkib, hujum vaqti), *qahramon moduli* (lagerlar, daraja), *taktik modul* (yarador birlikni orqaga olish, fokus).
- **Birlik AI:** yaqin dushmanga avtomatik javob, guruh bo'lib harakatlanish (formatsiya), to'siqlarni aylanib o'tish.
- Qiyin darajada AI **aldamasin** (xaritani ko'rmasin) — faqat aqlliroq o'ynasin.

---

## 9. TELEFON UCHUN BOSHQARUV (JUDA MUHIM)

RTS telefonda qulay bo'lishi uchun:
- **Bir marta bosish** — birlikni tanlash; **bo'sh joyga bosish** — tanlangan birliklarni yuborish.
- **Bir barmoqni ushlab sudrash** — ramka bilan ko'p birlik tanlash (tanlash rejimi tugmasi yoqilganda).
- **Ikki barmoq bilan surish** — kamerani siljitish; **chimchilash** — zoom; ekran chetiga yaqin sudrash ham kamerani siljitadi.
- **Ikki marta bosish** — ekrandagi shu turdagi barcha birliklarni tanlash.
- **Uzoq bosish** birlikda — ma'lumot oynasi.
- **Pastki panel:** tanlangan birlik(lar) portreti, qobiliyat tugmalari (katta, barmoqqa mos), buyruqlar (hujum, ushlab tur, patrul).
- **Chap tomonda** 1–5 guruh tugmalari (armiya guruhlari), «barcha armiya», «bo'sh ishchi» tugmalari.
- **O'ng yuqorida** mini-xarita (bosganda kamera o'sha joyga), resurslar, pauza.
- Qobiliyatni nishonga olish: tugmani bosib, keyin xaritaga bosish (hudud doirasi ko'rinadi).
- Avtomatik qobiliyat (autocast) — tugmani uzoq bosish bilan yoqiladi.
- O'yinni **tezlashtirish** (1x / 1.5x / 2x) va **pauzada buyruq berish** imkoniyati (bir o'yinchi rejimida).

---

## 10. GRAFIKA, OVOZ VA INTERFEYS

- **Uslub:** yorqin, biroz multfilmga o'xshash low-poly 3D (telefonda tez ishlashi uchun). Har saltanatning o'z rang palitrasi (3-bo'limda).
- Hozircha tayyor modellar yo'q — **boshlang'ich bosqichda grafikani kod orqali** (oddiy shakllar, CSG/MeshInstance, rangli materiallar) yarat; har bir birlik turi siluet va rangi bo'yicha aniq ajralib tursin. Keyinchalik `.glb` modellarni almashtirish oson bo'lsin (har birlik ma'lumot faylida `model_path` maydoni).
- **Effektlar:** GPUParticles bilan olov, sehr, qon emas — rangli uchqunlar (yosh chegarasi 12+), portlashlar, sog'ayish nuri.
- **Animatsiyalar:** yurish, hujum, o'lish, qobiliyat — AnimationTree orqali.
- **Ovoz:** birlik tanlanganda va buyruq olganda qisqa o'zbekcha javoblar («Tayyorman!», «Buyuring, sardor!», «Bajaraman!»). Hozircha matn ko'rinishida (sub-title), ovoz fayllari qo'shiladigan tizim tayyor bo'lsin.
- **Musiqa:** har saltanatga o'z mavzusi (karnay-surnay, doira, dutor uslubidagi motivlar — keyin qo'shiladi), audio-bus tizimi.
- **Menyular:** bosh menyu (Kampaniya, Skirmish, Tezkor jang, Qahramonlar Zali, Sozlamalar), saltanat tanlash ekrani, yuklanish ekrani (maslahatlar bilan), g'alaba/mag'lubiyat ekrani statistikasi bilan.

---

## 11. KAMPANIYA HIKOYASI (QISQA)

1. **Odamlar — «Vodiy Uyg'onadi»:** Oltin Vodiyga noma'lum hujumlar boshlanadi. Alpomish va Barchinoy sabab izlaydi. (6 missiya)
2. **Trollar — «Tog'lar Gumburlaydi»:** vulqonlar uyg'onib, devlar janubga ko'chishga majbur. (6 missiya)
3. **Elflar — «So'nayotgan O'rmon»:** Qora Tuman o'rmonni yeyapti; Oydinoy dushmanlar bilan ittifoq tuzishi kerakmi? (6 missiya)
4. **Yalmog'iz va Kashshey — «O'lmas Shohning Qaytishi»:** Kashshey Yer Yuragi bo'laklarini yig'ish rejasini amalga oshiradi. (6 missiya)
5. **Final missiya — «Yer Yuragi»:** to'rt saltanatdan biri bilan yakuniy jang (o'yinchi tanlovi bilan ikki xil yakun).

Missiyalar orasida qisqa dialog sahnalari (portret + matn). Missiya turlari xilma-xil: bazani himoya qilish, qahramon bilan sarguzasht (bazasiz), vaqtga qarshi, karvonni kuzatish, boss jangi.

---

## 12. TEXNIK ARXITEKTURA

```
tort-saltanat/
├── project.godot
├── export_presets.cfg
├── .github/workflows/android.yml   # APK avtomatik qurish
├── data/
│   ├── factions/      # trollar.tres, yalmogiz.tres, elflar.tres, odamlar.tres
│   ├── units/         # har birlik — alohida .tres
│   ├── buildings/
│   ├── heroes/
│   ├── abilities/
│   ├── upgrades/
│   ├── items/
│   ├── damage_table.tres
│   └── ai_build_orders/
├── scenes/
│   ├── main_menu/  game/  ui/  units/  buildings/  effects/  maps/
├── scripts/
│   ├── core/          # GameManager, CommandQueue, Simulation (tick), SaveLoad
│   ├── units/         # Unit, Hero, Worker, Projectile
│   ├── buildings/
│   ├── abilities/     # Ability bazaviy klassi + har bir qobiliyat
│   ├── combat/        # Damage, StatusEffect, Aura
│   ├── economy/       # Resource, Upkeep, Caravan
│   ├── faction_mechanics/  # Rage, SoulEgg, DarkMist, RootNetwork, Banner
│   ├── ai/
│   ├── fog/
│   ├── input/         # TouchInput, Selection, Camera
│   └── localization/
├── assets/  (models, textures, faces, audio, fonts)
└── localization/ (uz.csv, ru.csv, en.csv)
```

**Texnik talablar:**
- **Simulyatsiya** belgilangan tick (20 Hz) da ishlasin, grafika esa interpolyatsiya bilan; barcha o'yinchi harakatlari `Command` obyektlari orqali — kelajakda multiplayer va replay uchun.
- **Yo'l topish:** NavigationServer3D + avoidance; ko'p birliklar uchun guruh harakati (flow field yoki formatsiya ofsetlari).
- **Ishlash darajasi:** o'rta darajali telefonda 200 ta birlik bilan kamida 30 FPS. Buning uchun: MultiMeshInstance3D, LOD, object pooling (o'qlar, effektlar), tuman uchun past ruxsatli tekstura.
- **Saqlash:** kampaniya progressi va sozlamalar `user://` ga; o'yin o'rtasida saqlash (save game).
- **Xarita muharriri (keyinroq):** xaritalar oddiy ma'lumot formatida (relyef, resurslar, start nuqtalari), shuning uchun yangi xarita qo'shish oson.
- **Kamida 6 ta skirmish xaritasi:** «Ikki Daryo Oralig'i» (2 o'yinchi), «Vulqon Darasi», «Oydin Ko'l», «La'natlangan Cho'l», «Ipak Yo'li» (4 o'yinchi), «Yer Yuragi» (4 o'yinchi, markazda kuchli neytral boss).

**GitHub Actions:** `.github/workflows/android.yml` — Godot 4.3 headless (masalan, `barichello/godot-ci` image), Android export templates, debug keystore avtomatik yaratish, `push` da APK qurib, **Artifacts** ga yuklash. Keyinchalik release keystore secrets orqali (Google Play uchun AAB).

---

## 13. ISHLAB CHIQISH BOSQICHLARI (SHU TARTIBDA ISHLA)

**1-bosqich — Poydevor:** loyiha tuzilmasi, GitHub Actions APK, izometrik kamera, telefon boshqaruvi (tanlash, yuborish, zoom, siljitish), oddiy xarita, bitta birlik turi yurib, hujum qiladi.
**2-bosqich — Iqtisod:** oltin koni, daraxtlar, ishchilar, resurs paneli, bino qurish (joylashtirish va qurilish jarayoni), birlik o'rgatish navbati, oziq limiti.
**3-bosqich — Jang:** hujum/sovut turlari, o'qlar, sog'liq chiziqlari, o'lim, tuman urushi, mini-xarita, minoralar.
**4-bosqich — Odamlar saltanati to'liq:** barcha birlik, bino, texnologiya va 3 davr (bitta saltanatni to'liq tayyorlab, tizimni sinab ko'rish uchun).
**5-bosqich — Qahramonlar va qobiliyatlar:** XP, daraja, qobiliyat tizimi, inventar, narsalar, Karvonsaroy, neytral lagerlar.
**6-bosqich — Qolgan 3 saltanat:** Trollar, Yalmog'iz/Kashshey, Elflar — maxsus mexanikalari bilan (G'azab, Jon Tuxumi, Qora Tuman, Ildiz Tarmog'i, Oy va Quyosh).
**7-bosqich — AI:** raqib AI 3 qiyinlik, saltanat uslublari.
**8-bosqich — Menyular, skirmish, sozlamalar, saqlash, lokalizatsiya.**
**9-bosqich — Kampaniya:** missiya tizimi (skript triggerlar), dialoglar, 24 missiya.
**10-bosqich — Sayqal:** effektlar, ovoz tizimi, balans, optimallashtirish, do'st qahramonlari (yuz teksturasi), Google Play uchun tayyorgarlik.

Har bosqich oxirida:
1. Nima qilinganini qisqa yoz.
2. APK qurilishini tekshir (workflow muvaffaqiyatli).
3. Keyingi bosqichga o'tishdan oldin menga sinab ko'rish uchun nimalarni tekshirish kerakligini ayt.

---

## 14. BIRINCHI VAZIFA

Hozir **1-bosqichni** boshla: Godot 4 loyihasini yarat, papkalar tuzilmasini 12-bo'limdagidek qur, `.github/workflows/android.yml` ni yoz, izometrik kamera va telefon boshqaruvini qil, xaritaga 5 ta Navkar (Odamlar) va 5 ta Toshtish Troll qo'y — ular tanlanib, yurib, bir-biriga hujum qila olsin. Keyin GitHub'ga push qilib APK qurilishini tekshir.
