# To'rt Saltanat: Afsonalar Urushi — v1.0

Android uchun real-time strategiya (Godot 4.3, GL Compatibility).

## v1.0 — 10-bosqich: sayqal va Google Play
- **Ovoz va musiqa** (assets/audio, noldan sintez — tools/synth.py): 18 ta effekt (qilich, o'q, sehr, portlash,
  o'lim, qurilish, daraja, karnay signali, g'alaba/mag'lubiyat...) va 5 ta kuy — menyu va har saltanatga o'zi
  (doira usuli, dutor-tanbur tori, nay, karnay; maqomlarga yaqin tovushqatorlar). Ovoz faqat kamera yaqinida
  va ko'rinib turgan joyda eshitiladi, bir xil ovoz takrorlanib quloqni charchatmaydi
- **Effektlar**: o'lim, portlash va qurilish uchqunlari (past sifatda o'chadi)
- **Statistika** g'alaba/mag'lubiyat oynasida: vaqt, tayyorlangan, qurilgan, yo'q qilingan, yo'qotish, oltin
- **Do'stlar yuzlari**: assets/faces/<qahramon>.png (yoki telefonda files/faces/) — qahramon ustida dumaloq medalyon
- **Balans**: Barg Qilichli va Ajina zarari kamaytirildi, Qora Shamol sog'lig'i va Uch Boshli Ajdar zarari oshirildi
- **Google Play**: original ikonka (adaptive), feature graphic, AAB eksport (play.yml), maxfiylik siyosati,
  do'kon matnlari (uz/ru/en) — docs/GOOGLE_PLAY.md

## v0.10 — 9-bosqich: kampaniya
- **4 bob, 24 missiya + final** (data/campaign.json):
  1. Odamlar — «Vodiy Uyg'onadi»: Chegaradagi jang, Vodiyni tiklash, Tumandagi asir, Uzun tun, Jon Tuxumlari, Qora Tuman qal'asi
  2. Trollar — «Tog'lar Gumburlaydi»: Vulqon uyg'ondi, Yangi makon, Boronbek sinovi, Tog' dovoni, Devlar kengashi, Tog'lar qasosi
  3. Elflar — «So'nayotgan O'rmon»: Tuman chekkasi, Ildizlarni tiklash, Yulduzlar kuzatuvchisi, Ittifoqmi?, To'lin oy kechasi, O'rmon uyg'onadi
  4. Yalmog'iz — «O'lmas Shohning Qaytishi»: Qabrdan uyg'onish, Tuman yoyilmoqda, Birinchi bo'lak, Trollar tog'i, Ittifoq hujumi, O'lmas Shoh
  5. Final — «Yer Yuragi»: saltanatni tanlaysiz, g'alabadan keyin ikki xil yakun (Tinchlik yoki Hukmdor)
- **Missiya turlari**: hammasini yo'q qilish, omon qolish (taymer), nishonlarni yo'q qilish, binolarni buzish,
  qahramonni manzilga olib borish; mag'lubiyat: bosh binoni yoki qahramonni yo'qotish
- **Skript triggerlar** (scripts/game/mission_script.gd): vaqt, hududga kirish, teg bo'yicha o'lim, dushman soni,
  qahramon darajasi → dialog, qo'shimcha qo'shin (ittifoqchi yoki dushman), yangi vazifa, xaritani ochish, oltin, tun, to'lqin
- Har bob boshida va oxirida kino-sahna, missiyalar ichida dialoglar; do'st qahramonlari hikoyaga qo'shildi
  (Husan — 1-bob, Saidxon — 2-bob, Ulug'bek — 3-bob, Olimxon — 4-bob)
- Har bobning birinchi missiyasi ochiq; final 4 bob tugagach ochiladi

## v0.9 — 8-bosqich: menyular, saqlash, sozlamalar, tillar
- **Yangi bosh menyu**: Davom ettirish (saqlangan o'yin bo'lsa), Kampaniya, Tezkor jang, Qahramonlar Zali,
  Sozlamalar, Mualliflar, Muqaddima filmi, Chiqish
- **Kampaniya ekrani**: boblar va missiyalar; keyingi missiya oldingisini yutgandan keyin ochiladi (user://progress.json)
- **Qahramonlar Zali**: 4 saltanatning 17 qahramoni — aylanib turuvchi 3D ko'rinish, ko'rsatkichlar, qobiliyatlar
- **Sozlamalar** (user://settings.cfg): til, musiqa va effektlar ovozi, soyalar, grafika sifati (past/o'rta/yuqori), 30/60 FPS
- **Tillar**: o'zbekcha, ruscha, inglizcha (data/localization.json). Birinchi ishga tushishda telefon tili tanlanadi.
  Interfeys, nomlar, xabarlar va missiya vazifalari tarjima qilingan; hikoya dialoglari va qobiliyat tavsiflari hozircha o'zbekcha
- **Saqlash**: jangda «Menyu» → Saqlash / Saqlab menyuga chiqish; bosh menyuda «Davom ettirish».
  Saqlanadi: birliklar (qahramon darajasi, qobiliyatlari, buyumlari), binolar, navbatlar, resurslar, tadqiqotlar,
  oltin-yog'och, kun vaqti, ochilgan xarita, kamera
- **Yuklanish ekrani** maslahatlar bilan; **jang menyusi** (pauza): Davom, Saqlash, Jangni tark etish

## v0.8 — 7-bosqich: raqib AI
- **Qiyinlik**: Oson (sekin qaror, kam ishchi, kech hujum, 2-davrdan oshmaydi, tadqiqot qilmaydi),
  O'rta, Qiyin (tez qaror, 9 ishchi, erta hujum, barcha tadqiqotlar, 3 qahramon, ikkita kazarma)
- **Qiyin darajada mikro**: yarador askarlarni bazaga olib ketadi, eng zaif dushmanga (va qahramonlarga) fokus,
  boshida razvedka
- **Saltanat uslublari**: Trollar — erta bosim; Elflar — kamonchilar, tungi hujum, ishchilarga zarba;
  Yalmog'iz — tuman yoyish, Jon Tuxumini birinchi quradi, tungi hujum; Odamlar — ikkinchi baza va karvonlar, ko'proq minora
- AI davrni ko'taradi, ishlab chiqarish va tadqiqot binolarini quradi, saltanatiga xos birliklarni afzal ko'radi
- AI aldamaydi: faqat o'zi ko'rgan yoki eslab qolgan narsaga hujum qiladi
- Tezkor jang ekranida qiyinlikni tanlash; yuqori panelda raqib va qiyinlik ko'rinadi

## v0.7 — 6-bosqich: to'rt saltanat
- **Saltanat tanlash**: Menyu → «Tezkor jang: saltanat tanlash» — Odamlar, Trollar, Elflar yoki Yalmog'iz; raqib va vaqt
- **Trollar** (9 birlik): Qulbon, Toshtish Troll, Nayza Otar, Botqoq Jodugari, Ikki Boshli Dev, Mamont Chavandoz,
  Qoya Otar Gigant, Vulqon Ilon (uchuvchi), Qadimgi Tog' Ruhi (super). Mexanika: **G'azab Olovi**
- **Elflar** (9): Gulchi, Barg Qilichli, Kumush Kamonchi, Shamol Raqqosasi, Daraxt Qo'riqchisi, Oq Bug'u Chavandoz,
  Tikanli Ildiz, Humo Qushi (davolovchi uchuvchi), Simurg' (kuldan qayta tug'iladi). Mexanika: **Ildiz Tarmog'i**, **Oy va Quyosh**
- **Yalmog'iz va Kashsheylar** (9): Suyak Qul, Ajina, Alvasti, Qarg'a Jodugar (skelet chaqiradi), Temir Tishli Ayiq,
  Ilon Otli, Tovuq Oyoqli Kulba, Uch Boshli Ajdar, Qora Shamol. Mexanika: **Qora Tuman**, **Jon Tuxumi**
- Har saltanatda 3 davr, o'z binolari va texnologiyalari; 16 qahramon (har saltanatda 4, bittadan do'st qahramoni:
  Husan, Saidxon, Olimxon, Ulug'bek)
- Odamlar: **Karvon Yo'li** (ikkinchi bosh bino — karvon oltin olib keladi)
- **Kun va tun** (5 daqiqa kun, 3 daqiqa tun): kechasi ko'rish masofasi qisqaradi
- Jonzotlar: ot, mamont, bug'u, ayiq, ilon, tovuq oyoqlari, qush, uch boshli ajdar, bo'ron
- Yalmog'iz binolari: KayKit Halloween to'plami (CC0)

## v0.6 — 5-bosqich: qahramonlar, narsalar, neytral dunyo
- **Qahramonlar** (bosh bino → «Qahramonlar»; ko'pi bilan 3 ta): Alpomish, Barchinoy, Mavlono Nurali,
  Husan — Adolat Sardori (do'st qahramoni). Trollarda: Qoyaqul, Bo'ronbek. Choyxonada: Nasriddin Afandi.
- 10 daraja, tajriba (yaqindagi dushman o'limidan), har darajada ko'nikma ochkosi, 4 qobiliyat (ULTI 6-darajada)
- Qobiliyatlar: zarba+karaxtlik, meteor, o'qlar yomg'iri, aura, qalqon, otilib borish, Ko'pkari (tortib kelish),
  qurolsizlantirish, tumanni ochish (Dalil), aylanib urish, gigantga aylanish va boshqalar
- Halok bo'lgan qahramon bosh binoda tiriltiriladi (darajasi va narsalari saqlanadi)
- **40 ta narsa** (oddiy, noyob, epik, afsonaviy), 6 katakli inventar; **Karvonsaroy** — do'kon
- **Neytral lagerlar**: qaroqchilar, la'natli jangchilar, tosh golemlar, Qadimgi Qo'riqchi (boss);
  oltin mukofot, lager tozalanganda sandiq tushadi
- Dushman AI qahramon yollaydi, tiriltiradi va qobiliyatlarini ishlatadi

## v0.5 — 4-bosqich: Odamlar saltanati to'liq
- **Davrlar**: Qishloq Markazi (1) → Qal'a (2) → Poytaxt Saroyi (3) — bosh binoni tanlab «→ Qal'a» tugmasi
- **Yangi birliklar**: Yulduz Olimi (sehrli zarba + sekinlashtirish), Tabib (yaradorlarni davolaydi),
  Otliq Botir (tez og'ir jangchi), Manjaniq (qamal, sachratma, binolarga katta zarar),
  Uchar Gilam Sehrgari (uchuvchi — yaqin jangchilar ura olmaydi), Oltin Gvardiya (eng kuchli, ko'pi bilan 5 ta)
- **Yangi binolar**: Temirchi, Rasadxona, Shifoxona, Otxona, Ustaxona, Qal'a Devori
- **Texnologiyalar**: Qilich va nayza I–III, O'q-yoy I–III, Sovut I–III, Qal'a muhandisligi, Munajjimlik, Uzoq o'q, Shifo kuchi
- Talablar: qulflangan tugmalar xira; bosilsa nima kerakligini aytadi
- Effektlar: shifo nuri, portlash, sekinlashgan dushman ustida ko'k halqa

## v0.4 — haqiqiy 3D modellar
- Personajlar, binolar, daraxtlar, tog'lar, oltin koni — **KayKit** modellari (Kay Lousberg, www.kaylousberg.com, **CC0**)
- Personajlar animatsiyali: turish, yurish, hujum, o'q otish, o'lim (75+ animatsiya)
- Navkar — ritsar, Mergan — kapyushonli arbaletchi, Dehqon — boltali ishchi, Trollar — yashil terili devlar
- Binolar: qal'a, uylar, kazarma, kamon maydoni, minora; trollar — g'or-kon, chodir, arena, katapultali minora
- Qurilayotgan bino atrofida iskala, buzilgan bino o'rnida vayrona
- Kashshey va kampir-jodugarlar filmchalarda skelet-sehrgar va sehrgar modellarida
- Modellar GitHub Actions'da `tools/fetch_models.sh` orqali avtomatik yuklanadi (repo'ga yuklash shart emas)
- Model topilmasa, o'yin avvalgi oddiy shakllarga qaytadi

## v0.3 — 3-bosqich: tuman urushi, minoralar, yo'l topish
- **Tuman urushi**: ko'rilmagan joy — qora, ilgari ko'rilgan — xira, askarlar ko'rib turgan joy — ochiq.
  Dushman askarlari faqat ko'rinadigan joyda ko'rinadi; ko'rilgan dushman binolari esda qoladi. Mini-xaritada ham tuman.
- Har bir birlik va binoning ko'rish radiusi bor (`sight`), Mergan va minoralar uzoqroq ko'radi
- **Minoralar**: Minora (Odamlar, o'q otadi) va Qo'riqchi Tosh (Trollar, xarsang otadi)
- **Yo'l topish**: askarlar binolar, oltin konlari va daraxtlarni aylanib o'tadi (AStarGrid2D + yo'lni silliqlash)
- Dushman AI endi aldamaydi: faqat o'zi ko'rgan narsaga qarab ish ko'radi, minora quradi

## v0.2 — 2-bosqich: iqtisod
- Ishchilar: **Dehqon** (Odamlar) va **Qulbon** (Trollar) — oltin konidan oltin, daraxtdan yog'och tashiydi, bino quradi
- Binolar: Qishloq Markazi, Uy, Navkarxona, Kamonchilar Maydoni · Tosh G'or, Totem Ustuni, Jangchilar Arenasi
- Qurish: «Qurish» → bino tanlash → xaritaga bosib joy tanlash (yashil/qizil arvoh) → «Joylash»
- O'rgatish navbati (5 tagacha), navbatdan chiqarish (pul qaytadi), to'plash nuqtasi (bino tanlab yerga bosish)
- Oziq limiti (Uy +6, Markaz +10), oltin/yog'och xazinasi, narxlar
- Dushman iqtisodiy AI: ishchi o'rgatadi, resurs yig'adi, totem quradi, troll o'rgatadi, to'lqin bo'lib hujum qiladi, bazasini himoya qiladi
- 2-missiya «Vodiyni tiklash» + 2 ta yangi filmcha; kampaniya zanjiri: 1-missiya → 2-missiya
- Tezkor jang endi bazali (skirmish)

## v0.1 — 1-bosqich
- Bosh menyu (orqada aylanayotgan 3D sahna, Yer Yuragi va to'rt saltanat vakillari)
- **Kino-sahnalar tizimi** (`data/cutscenes/*.json`): kamera harakati, subtitrli dialoglar, sarlavhalar,
  qora kino chiziqlari, chaqnash, silkinish, kristall parchalanishi, qora tuman, «O'tkazib yuborish»
  - `intro.json` — Muqaddima: Yer Yuragining bo'linishi, to'rt saltanat, chegaradagi trollar hujumi
  - `mission1_end.json` — G'alabadan keyin: Kashshey sirli rejasi
- 1-missiya «Chegaradagi jang»: Navkar + Mergan Kamonchi (Odamlar) vs Toshtish Troll + Nayza Otar (Trollar)
- 20 Hz simulyatsiya + silliq grafika, buyruqlar navbati (GameCommand), formatsiya, to'qnashuvdan qochish
- Hujum/sovut turlari jadvali (`data/damage_table.json`), trollar regeneratsiyasi, o'qlar va nayzalar
- Telefon boshqaruvi: bosish, ikki marta bosish, surish, chimchilab zoom, ramka bilan tanlash
- HUD: resurslar, vazifa, mini-xarita, birlik ma'lumoti, buyruq tugmalari, o'zbekcha javoblar, 1x/1.5x/2x, pauza
- Tezkor jang rejimi

## Boshqaruv
| Harakat | Natija |
|---|---|
| Askarga bosish | Tanlash |
| Askarga ikki marta bosish | Ekrandagi shu turdagilarning hammasi |
| Yerga bosish | Tanlanganlar o'sha joyga yuradi |
| Dushmanga bosish | Hujum |
| «Hujum» + yerga bosish | Yo'lda uchraganga hujum qilib boradi |
| Bir barmoq bilan surish | Kamera |
| «Ramka» yoqilgan + surish | Ramka ichidagilarni tanlash |
| Ikki barmoq | Siljitish + zoom |

## Tuzilma
`scripts/core` — main, GameData, GameCommand, Simulation · `scripts/units` — Unit, UnitVisual, Projectile ·
`scripts/game` — Battle, WorldBuilder · `scripts/input` — RtsCamera, TouchController ·
`scripts/ui` — HUD, overlay, minimap, menyu, uslub · `scripts/cutscene` — CutscenePlayer ·
`data/` — barcha balans va matnlar JSON'da · `docs/MASTER_PROMPT.md` — to'liq reja

## Yangi kino-sahna qo'shish
`data/cutscenes/` ga JSON qo'shing: har bir `shot` da `duration`, `env` (day/dusk/night/dark),
`cam` (`from`, `to`, `look`, `look_to`), `spawn` (unit / crystal / mist / light), `actions`
(walk_to, fly_to, face, attack, die, spin, rise, laugh, shatter, flash, shake, hide, show),
`lines` (`speaker`, `text`, `t`), `title` (`text`, `sub`, `hold`), `fade_in`, `fade_out`, `clear`.
Keyin missiya faylida `"intro"` yoki `"outro"` ga shu nomni yozing.
