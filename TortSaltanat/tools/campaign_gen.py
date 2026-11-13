# 9-bosqich: kampaniya generatori. Missiya va kino-sahna JSON fayllarini yaratadi.
# Ishga tushirish: python3 campaign.py <loyiha_papkasi>
import json, sys, copy, os

ROOT = sys.argv[1]
QUICK = json.load(open(os.path.join(ROOT, "data/missions/quick.json")))

P_BASE = [-36, 0, 34]
E_BASE = [36, 0, -34]

TR = {}  # tarjimalar: uz -> (ru, en)


def tr(uz, ru, en):
    TR[uz] = (ru, en)
    return uz


# ---------------- Missiya qoliplari ----------------

def base_mission(mid, title, objective, pf, ef, env="day", diff="orta", first_wave=300, res=(600, 350)):
    m = copy.deepcopy(QUICK)
    m.update({
        "id": mid, "title": title, "objective": objective,
        "player_faction": pf, "enemy_faction": ef, "env": env, "difficulty": diff,
        "intro": "", "outro": "", "next": "",
        "resources": {"oltin": res[0], "yogoch": res[1]},
        "enemy_resources": {"oltin": res[0], "yogoch": res[1]},
        "auto_start": True, "player_base": P_BASE, "enemy_base": E_BASE,
        "camera_start": [-33, 0, 30],
    })
    m["ai"] = {"economy": True, "first_wave": first_wave, "wave_size": 5, "wave_growth": 2, "workers": 6, "heroes": True}
    return m


def field_mission(mid, title, objective, pf, ef, env="day"):
    """Bazasiz otryad missiyasi: o'yinchi kichik guruh bilan xaritada yuradi."""
    return {
        "id": mid, "title": title, "objective": objective,
        "player_faction": pf, "enemy_faction": ef, "env": env, "difficulty": "orta",
        "intro": "", "outro": "", "next": "",
        "camera_start": [-38, 0, 38], "resources": {"oltin": 0, "yogoch": 0},
        "auto_waves": False, "fog": True,
        "clear_spots": [[-38, 0, 38, 10], [0, 0, 0, 12], [36, 0, -36, 12], [-30, 0, -20, 9], [28, 0, 22, 9]],
        "player_units": [], "enemy_units": [], "player_buildings": [], "enemy_buildings": [],
        "resource_nodes": [],
        "forests": [{"at": [-46, 0, 10], "radius": 5, "count": 16}, {"at": [12, 0, 44], "radius": 6, "count": 18},
                    {"at": [44, 0, 6], "radius": 5, "count": 16}, {"at": [-8, 0, -44], "radius": 6, "count": 18}],
        "triggers": [],
    }


def defend_mission(mid, title, objective, pf, ef, seconds, env="night", res=(700, 400)):
    """Omon qolish: o'yinchi bazasi bor, dushman to'lqinlari chetdan keladi."""
    m = base_mission(mid, title, objective, pf, ef, env=env, res=res)
    m["auto_start_teams"] = [0]
    m["auto_waves"] = False
    m.pop("ai")
    m["victory"] = {"type": "survive", "seconds": seconds}
    m["triggers"] = []
    return m


def g(uid, count, at, **kw):
    d = {"id": uid, "count": count, "at": at}
    d.update(kw)
    return d


def say(speaker, text, t=None, team=0, after=None, delay=0):
    when = {}
    if t is not None:
        when["time"] = t
    if after:
        when["after"] = after
        when["delay"] = delay
    return {"when": when, "do": [{"say": [speaker, text], "team": team}]}


def wave(every, start, until, groups, msg=None):
    do = [{"spawn": [dict(gr, team=1, attack=True) for gr in groups]}]
    if msg:
        do.append({"say": msg, "team": 1})
    return {"every": every, "from": start, "until": until, "do": do}


EDGES = {"ne": [44, 0, -44], "e": [48, 0, 0], "n": [0, 0, -48], "nw": [-44, 0, -40], "se": [44, 0, 40]}

M = {}
CS = {}


# ---------------- Kino-sahna yordamchilari ----------------

def unit(id_, uid, pos, face, count=1, cols=4, team=0):
    d = {"kind": "unit", "id": id_, "unit": uid, "pos": pos, "face": face, "team": team}
    if count > 1:
        d.update({"count": count, "cols": cols, "spacing": 1.4})
    return d


def shot(dur, cam_from, cam_to, look, lines=(), spawn=(), env=None, title=None, actions=(), fade_in=False, fade_out=False, clear=True):
    s = {"duration": dur, "cam": {"from": cam_from, "to": cam_to, "look": look}}
    if env:
        s["env"] = env
    if not clear:
        s["clear"] = False
    if fade_in:
        s["fade_in"] = True
    if fade_out:
        s["fade_out"] = True
    if spawn:
        s["spawn"] = list(spawn)
    if title:
        s["title"] = title
    if lines:
        s["lines"] = [{"t": t, "speaker": sp, "text": tx} for (t, sp, tx) in lines]
    if actions:
        s["actions"] = list(actions)
    return s


def title_card(text, sub, env="dark"):
    return shot(4.5, [0, 9, 12], [0, 8, 10], [0, 0, 0], env=env, fade_in=True,
                title={"t": 0.3, "text": text, "sub": sub, "hold": 2.8})


def dialog_scene(cs_id, env, left, right, lines, extra_spawn=(), title=None, end_card=None, actions=()):
    """Ikki tomon yuzma-yuz turadi; kamera sekin suriladi."""
    spawn = []
    for i, (uid, team) in enumerate(left):
        spawn.append(unit("l%d" % i, uid, [-2.2 - i * 1.6, 0, 1.2 - i * 0.9], [4, 0, 0.5], team=team))
    for i, (uid, team) in enumerate(right):
        spawn.append(unit("r%d" % i, uid, [2.2 + i * 1.6, 0, 1.2 - i * 0.9], [-4, 0, 0.5], team=team))
    spawn.extend(extra_spawn)
    n = len(lines)
    per = 3.6
    lns = [(0.6 + i * per, sp, tx) for i, (sp, tx) in enumerate(lines)]
    shots = [shot(1.4 + n * per, [0, 2.8, 8.5], [0.8, 2.4, 7.0], [0, 1.3, 0], lines=lns, spawn=spawn, env=env,
                  fade_in=True, title=title, actions=actions, fade_out=end_card is None)]
    if end_card:
        shots.append(title_card(end_card[0], end_card[1]))
    CS[cs_id] = {"id": cs_id, "shots": shots}
    return cs_id


# =====================================================================
# 1-BOB: ODAMLAR — «Vodiy Uyg'onadi» (mission1, mission2 mavjud)
# =====================================================================
CH1 = tr("Vodiy Uyg'onadi", "Пробуждение долины", "The Valley Awakens")

# 3: Barchinoyni qutqarish (otryad, nishonlarni yo'q qilish)
m = field_mission("odam3", tr("3-missiya: Tumandagi asir", "Миссия 3: Пленница в тумане", "Mission 3: Captive in the Mist"),
                  tr("Qarg'a jodugarlarni yo'q qilib, Barchinoyni ozod qiling", "Уничтожьте вороньих ведьм и освободите Барчиной", "Destroy the raven witches and free Barchinoy"),
                  "odamlar", "yalmogiz", env="dusk")
m["player_units"] = [g("alpomish", 1, [-38, 0, 36], level=3), g("navkar", 4, [-40, 0, 40]), g("mergan", 3, [-36, 0, 42]), g("tabib", 1, [-42, 0, 42])]
m["enemy_units"] = [g("suyak_askar", 4, [-12, 0, 12]), g("ajina", 3, [10, 0, -8]), g("suyak_askar", 3, [22, 0, 18]),
                    g("qarga_jodugar", 3, [36, 0, -34], tag="nishon"), g("alvasti", 2, [32, 0, -30]), g("temir_tishli_ayiq", 1, [38, 0, -28])]
m["creep_camps"] = [{"at": [-30, 0, -20], "units": [{"id": "qaroqchi", "count": 2}, {"id": "qaroqchi_kamonchi", "count": 1}], "drop": "noyob"}]
m["victory"] = {"type": "kill_targets", "tag": "nishon"}
m["defeat"] = {"protect_unit": "alpomish"}
m["triggers"] = [
    say("Alpomish", "Barchinoy shu tumanning ichida. Qarg'a jodugarlar uni sehr bilan bog'lab qo'yibdi.", t=2),
    say("Tabib", "Ehtiyot bo'ling, botir! Agar siz yiqilsangiz, butun vodiy umidsiz qoladi.", t=8),
    {"id": "yarim", "when": {"area": [0, 0, 14]}, "do": [{"say": ["Alpomish", "Qarg'alar qichqirig'i yaqin... Sharqi-shimolga!"]}, {"reveal": [36, -34, 12], "reveal_time": 12}]},
    {"when": {"area": [30, -28, 14]}, "do": [{"say": ["Qarg'a Jodugar", "Odam bolasi! Kashshey seni kutmoqda!"], "team": 1}, {"wave": True}]},
]
m["outro"] = "odam3_end"
M["odam3"] = m
dialog_scene("odam3_end", "dusk", [("alpomish", 0)], [("barchinoy", 0)], [
    ("Barchinoy", "Alpomish! Bilardim, kelasan..."),
    ("Alpomish", "Seni Qora Tumanda qoldirarmidim? Kim seni bu yerga olib keldi?"),
    ("Barchinoy", "Kashsheyning odamlari. Ular Yer Yuragi bo'laklarini izlashyapti. Biri — bizning vodiyda!"),
])

# 4: Tungi hujum (omon qolish)
m = defend_mission("odam4", tr("4-missiya: Uzun tun", "Миссия 4: Долгая ночь", "Mission 4: The Long Night"),
                   tr("Tong otguncha (7 daqiqa) qishloqni himoya qiling", "Защищайте деревню до рассвета (7 минут)", "Defend the village until dawn (7 minutes)"),
                   "odamlar", "yalmogiz", 420)
m["player_units"] = [g("alpomish", 1, [-30, 0, 30], level=4), g("barchinoy", 1, [-32, 0, 32], level=3)]
m["defeat"] = {"protect_building": "qishloq_markazi"}
m["triggers"] = [
    say("Barchinoy", "Kashshey bo'lakni olish uchun bu kecha hujum qiladi. Minoralar quring, tez!", t=2),
    say("Alpomish", "Tong otguncha chidasak bas. Quyosh chiqqanda o'liklar chekinadi!", t=9),
    {"when": {"time": 1}, "do": [{"night": 430}]},
    wave(55, 70, 400, [g("suyak_askar", 4, EDGES["ne"]), g("ajina", 2, EDGES["e"])], ["Kashshey", "Bo'lakni bering, tiriklar!"]),
    wave(80, 160, 400, [g("alvasti", 2, EDGES["n"]), g("qarga_jodugar", 1, EDGES["n"])]),
    wave(120, 260, 400, [g("temir_tishli_ayiq", 2, EDGES["ne"]), g("ilon_otli", 2, EDGES["e"])]),
    say("Alpomish", "Yarmini o'tkazdik! Turing, botirlar!", t=210),
    say("Barchinoy", "Sharqda tong yorishyapti... Oz qoldi!", t=360),
]
M["odam4"] = m

# 5: Jon Tuxumlarini yo'q qilish
m = base_mission("odam5", tr("5-missiya: Jon Tuxumlari", "Миссия 5: Яйца души", "Mission 5: Soul Eggs"),
                 tr("Dushmanning barcha Jon Tuxumlarini yo'q qiling", "Уничтожьте все Яйца души врага", "Destroy all of the enemy's Soul Eggs"),
                 "odamlar", "yalmogiz", env="dusk", diff="orta", first_wave=330)
m["player_units"] = [g("alpomish", 1, [-30, 0, 30], level=5), g("barchinoy", 1, [-32, 0, 31], level=4)]
m["enemy_buildings"] = [{"id": "jon_tuxumi", "at": [28, 0, -42]}, {"id": "jon_tuxumi", "at": [44, 0, -26]}, {"id": "jon_tuxumi", "at": [30, 0, -24]}]
m["victory"] = {"type": "destroy_buildings", "buildings": ["jon_tuxumi"]}
m["triggers"] = [
    say("Mavlono Nurali", "Kashsheyning kuchi Jon Tuxumlarida. Ular butun tursa, uning askarlari qayta-qayta tiriladi.", t=2),
    say("Alpomish", "Unda avval qo'shin, keyin tuxumlar. Mavlono, siz biz bilan bo'ling!", t=9),
    {"when": {"time": 5}, "do": [{"spawn": {"id": "mavlono_nurali", "count": 1, "at": [-34, 0, 26], "team": 0, "level": 3}}]},
    {"when": {"time": 240}, "do": [{"say": ["Barchinoy", "Karvonsaroyda yaxshi buyumlar bor. Qahramonlarni kuchaytiring!"]}]},
]
M["odam5"] = m

# 6: Qora Tuman qal'asi
m = base_mission("odam6", tr("6-missiya: Qora Tuman qal'asi", "Миссия 6: Крепость Чёрного тумана", "Mission 6: The Black Mist Fortress"),
                 tr("Qora Tuman qo'shinini butunlay yo'q qiling", "Полностью уничтожьте войско Чёрного тумана", "Completely destroy the Black Mist army"),
                 "odamlar", "yalmogiz", env="night", diff="qiyin", first_wave=270, res=(800, 500))
m["player_units"] = [g("alpomish", 1, [-30, 0, 30], level=6), g("barchinoy", 1, [-32, 0, 31], level=5), g("husan", 1, [-28, 0, 32], level=4)]
m["enemy_units"] = [g("kashshey", 1, [32, 0, -30], level=6, tag="kashshey")]
m["triggers"] = [
    say("Husan", "Alpomish aka! Toshkentdan yordamga keldim. Bu gal Kashsheyni qochirmaymiz!", t=3),
    say("Alpomish", "Xush kelibsan, Husan. Bo'lak ularning qal'asida — oxirgi jang!", t=10),
    {"when": {"dead": "kashshey"}, "do": [{"say": ["Barchinoy", "Kashshey yiqildi... lekin u o'lmas. Jon Tuxumlarini ham buzing!"]}]},
]
m["outro"] = "odam6_end"
M["odam6"] = m
dialog_scene("odam6_end", "dusk", [("alpomish", 0), ("barchinoy", 0)], [("husan", 0), ("mavlono_nurali", 0)], [
    ("Alpomish", "Bo'lak endi bizda. Vodiy omon qoldi."),
    ("Mavlono Nurali", "Lekin Yer Yuragining yana uch bo'lagi bor: tog'larda, o'rmonda va tuman ichida."),
    ("Husan", "Unda boshqa saltanatlar ham bu jangga tortiladi..."),
    ("Barchinoy", "Kim birinchi bo'lib to'rt bo'lakni yig'sa, butun Ko'hna Zaminga hukmron bo'ladi."),
], extra_spawn=[{"kind": "crystal", "id": "shard", "pos": [0, 0.6, 0.6], "size": 0.4, "color": "#ffd470", "spin": 1.0}],
   end_card=(tr("1-bob tugadi", "Глава 1 завершена", "Chapter 1 complete"), tr("Keyingi: Tog'lar Gumburlaydi", "Далее: Горы грохочут", "Next: The Mountains Rumble")))

# =====================================================================
# 2-BOB: TROLLAR — «Tog'lar Gumburlaydi»
# =====================================================================
CH2 = tr("Tog'lar Gumburlaydi", "Горы грохочут", "The Mountains Rumble")

m = field_mission("troll1", tr("1-missiya: Vulqon uyg'ondi", "Миссия 1: Вулкан проснулся", "Mission 1: The Volcano Wakes"),
                  tr("Qoyaqulni janubi-sharqdagi dovonga olib boring", "Доведите Каякула до перевала на юго-востоке", "Lead Qoyaqul to the south-eastern pass"),
                  "trollar", "yalmogiz", env="dusk")
m["camera_start"] = [-38, 0, -36]
m["player_units"] = [g("qoyaqul", 1, [-38, 0, -38], level=2), g("toshtish_troll", 4, [-40, 0, -34]), g("nayza_otar", 3, [-36, 0, -32]), g("qulbon", 3, [-42, 0, -38])]
m["enemy_units"] = [g("lanatli_jangchi", 3, [-10, 0, -14]), g("tosh_golem", 2, [6, 0, 4]), g("suyak_askar", 4, [24, 0, 20])]
m["victory"] = {"type": "reach", "area": [40, 0, 40][::2] + [7], "unit": "qoyaqul"}
m["defeat"] = {"protect_unit": "qoyaqul"}
m["triggers"] = [
    {"when": {"time": 1}, "do": [{"say": ["Qoyaqul", "Tog' yonmoqda! Lava g'orlarimizni yutdi. Janubga, birodarlar!"]}, {"reveal": [40, 40, 8], "reveal_time": 15}]},
    say("Saidxon", "Qoyaqul! Yo'lda la'natlangan jangchilar bor. Ular tabiiy emas — kimdir ularni uyg'otgan.", t=10),
    wave(45, 30, 200, [g("lanatli_jangchi", 2, [-46, 0, -46])], ["Qoyaqul", "Orqadan ham kelishyapti! To'xtamang!"]),
    {"when": {"time": 6}, "do": [{"spawn": {"id": "saidxon", "count": 1, "at": [-34, 0, -40], "team": 0, "level": 2}}]},
    {"when": {"area": [24, 20, 12]}, "do": [{"say": ["Saidxon", "Suyaklar! Bu Kashsheyning askarlari-ku. Ular bu yerda nima qilyapti?"]}]},
]
m["intro"] = "troll_intro"
M["troll1"] = m
CS["troll_intro"] = {"id": "troll_intro", "shots": [
    title_card(tr("2-bob", "Глава 2", "Chapter 2"), CH2),
    shot(9, [0, 4, 12], [2, 3.4, 9], [0, 2, 0], env="dusk", fade_in=True, spawn=[
        {"kind": "light", "id": "lava", "pos": [0, 3, -6], "color": "#ff5010", "energy": 4.0, "range": 18},
        {"kind": "mist", "id": "smoke", "pos": [0, 0, -6], "radius": 5, "color": "#402020"},
        unit("qoyaqul", "qoyaqul", [0, 0, 1], [0, 0, 8]),
        unit("trollar", "toshtish_troll", [0, 0, -1.5], [0, 0, 8], count=6, cols=3),
    ], lines=[(0.5, "Hikoyachi", "Shimoliy tog'larda ming yil uxlagan vulqonlar birdaniga uyg'ondi."),
              (4.2, "Qoyaqul", "Ota-bobolarimiz g'orlari lava ostida qoldi. Bizga yangi makon kerak!")],
         actions=[{"t": 1.0, "do": "shake", "amount": 0.6}, {"t": 5.0, "actor": "trollar", "do": "attack", "times": 1}]),
    shot(6, [3, 2.2, 5], [2, 2.0, 4], [0, 1.6, 1], clear=False, fade_out=True,
         lines=[(0.4, "Qoyaqul", "Janubga yuramiz. Kim yo'limizni to'ssa — tosh bilan uchrashadi!")]),
]}

m = base_mission("troll2", tr("2-missiya: Yangi makon", "Миссия 2: Новый дом", "Mission 2: A New Home"),
                 tr("Qoyatosh qarorgohini quring va odamlar posbonlarini haydang", "Постройте лагерь и прогоните дозоры людей", "Build a stronghold and drive off the human outposts"),
                 "trollar", "odamlar", env="day", diff="oson", first_wave=360)
m["player_units"] = [g("qoyaqul", 1, [-30, 0, 30], level=3), g("saidxon", 1, [-32, 0, 31], level=2)]
m["triggers"] = [
    say("Qoyaqul", "Bu vodiy bo'sh emas ekan. Odamlar bizni bosqinchi deb o'ylaydi.", t=2),
    say("Saidxon", "Avval g'or, uylar va arena quramiz. Qulbonlar — oltinga!", t=8),
    say("Saidxon", "Esingizda bo'lsin: g'azablangan troll kuchliroq urادi, lekin olovdan qo'rqadi.".replace("urادi", "uradi"), t=20),
]
M["troll2"] = m

m = field_mission("troll3", tr("3-missiya: Boronbek sinovi", "Миссия 3: Испытание Буранбека", "Mission 3: Boronbek's Trial"),
                  tr("Arena chempionlarini yengib, Boronbekni qo'shiling", "Победите чемпионов арены и привлеките Буранбека", "Defeat the arena champions and win Boronbek over"),
                  "trollar", "elflar", env="day")
m["player_units"] = [g("qoyaqul", 1, [-38, 0, 36], level=4), g("saidxon", 1, [-36, 0, 38], level=3), g("toshtish_troll", 4, [-40, 0, 40]), g("botqoq_jodugari", 2, [-42, 0, 38])]
m["enemy_units"] = [g("barg_qilichli", 4, [0, 0, 0]), g("kumush_kamonchi", 3, [4, 0, -4]), g("shamshod", 1, [2, 0, 2], level=4, tag="nishon"),
                    g("oq_bugu_chavandoz", 2, [28, 0, 22]), g("daraxt_qoriqchi", 1, [30, 0, 18], tag="nishon")]
m["victory"] = {"type": "kill_targets", "tag": "nishon"}
m["defeat"] = {"protect_unit": "qoyaqul"}
m["triggers"] = [
    say("Boronbek", "Qoyaqul! Elflar mening arenam yonida qarorgoh qurishdi. Ularning sardorlarini yengsang — boltalarim seniki!", t=2, team=1),
    say("Qoyaqul", "Kelishdik, Boronbek. Shamol qilichbozi va o'rmon qo'riqchisi — ikkalasi!", t=9),
    {"when": {"time": 4}, "do": [{"reveal": [2, 2, 10], "reveal_time": 10}, {"reveal": [30, 18, 10], "reveal_time": 10}]},
]
m["outro"] = "troll3_end"
M["troll3"] = m
dialog_scene("troll3_end", "day", [("qoyaqul", 0), ("saidxon", 0)], [("boronbek", 0)], [
    ("Boronbek", "Ha-ha! Yaxshi urishdingiz. Ikki boltam endi sizning xizmatingizda!"),
    ("Saidxon", "Elflar bizni dushman deb o'ylashyapti. Lekin ular ham Qora Tumandan qochib kelgan..."),
    ("Qoyaqul", "Kim bilan urishishni o'zimiz tanlaymiz. Hozircha — makonimizni himoya qilamiz."),
])

m = defend_mission("troll4", tr("4-missiya: Tog' dovoni", "Миссия 4: Горный перевал", "Mission 4: The Mountain Pass"),
                   tr("Odamlar hujumidan 6 daqiqa davomida qarorgohni himoya qiling", "Удерживайте лагерь 6 минут против атаки людей", "Hold the stronghold against the humans for 6 minutes"),
                   "trollar", "odamlar", 360, env="day")
m["player_units"] = [g("qoyaqul", 1, [-30, 0, 30], level=5), g("boronbek", 1, [-32, 0, 31], level=4), g("saidxon", 1, [-28, 0, 32], level=3)]
m["defeat"] = {"protect_building": "tosh_gor"}
m["triggers"] = [
    say("Saidxon", "Odamlar katta qo'shin yuborishdi. Ular bizni Kashsheyning ittifoqchisi deb o'ylashyapti!", t=2),
    say("Qoyaqul", "Tushuntirishga vaqt yo'q. Minora va devorlar — dovonni ushlaymiz!", t=9),
    wave(50, 60, 340, [g("navkar", 4, EDGES["ne"]), g("mergan", 2, EDGES["ne"])], ["Odamlar sardori", "Trollarni tog'ga qaytaring!"]),
    wave(75, 130, 340, [g("otliq_botir", 3, EDGES["e"])]),
    wave(100, 200, 340, [g("manjaniq", 2, EDGES["n"]), g("oltin_gvardiya", 3, EDGES["n"])]),
    {"when": {"time": 280}, "do": [{"spawn": {"id": "barchinoy", "count": 1, "at": EDGES["n"], "team": 1, "level": 4, "attack": True}}, {"say": ["Barchinoy", "Trollar! Bo'lakni qayerga yashirdingiz?!"], "team": 1}]},
]
M["troll4"] = m

m = base_mission("troll5", tr("5-missiya: Devlar kengashi", "Миссия 5: Совет дэвов", "Mission 5: Council of Devs"),
                 tr("Elflarning Hayot Daraxtini yiqiting", "Срубите Древо жизни эльфов", "Bring down the elves' Tree of Life"),
                 "trollar", "elflar", env="dusk", diff="orta", first_wave=320)
m["player_units"] = [g("qoyaqul", 1, [-30, 0, 30], level=6), g("boronbek", 1, [-32, 0, 31], level=5), g("zahrinoz", 1, [-28, 0, 32], level=3)]
m["victory"] = {"type": "destroy_buildings", "buildings": ["hayot_daraxti"]}
m["triggers"] = [
    say("Zahrinoz", "Devlar kengashi qaror qildi: tog'dagi bo'lak elflar daraxti ildizlariga yashiringan!", t=2),
    say("Qoyaqul", "Unda daraxtni yiqitamiz. Olovdan ehtiyot bo'ling — o'zimizni ham kuydiradi.", t=9),
    say("Saidxon", "Kechasi elflar ko'rinmas bo'ladi. Kunduzi hujum qilish osonroq!", t=60),
]
M["troll5"] = m

m = base_mission("troll6", tr("6-missiya: Tog'lar qasosi", "Миссия 6: Месть гор", "Mission 6: Vengeance of the Mountains"),
                 tr("Haqiqiy dushman — Qora Tumanni yo'q qiling", "Уничтожьте настоящего врага — Чёрный туман", "Destroy the true enemy — the Black Mist"),
                 "trollar", "yalmogiz", env="night", diff="qiyin", first_wave=280, res=(800, 500))
m["player_units"] = [g("qoyaqul", 1, [-30, 0, 30], level=7), g("boronbek", 1, [-32, 0, 31], level=6), g("zahrinoz", 1, [-28, 0, 32], level=5), g("saidxon", 1, [-26, 0, 30], level=5)]
m["enemy_units"] = [g("alvasti_malika", 1, [32, 0, -30], level=6)]
m["triggers"] = [
    say("Saidxon", "Daraxt ostida bo'lak yo'q edi... Kashshey bizni elflar bilan urishtirib, o'zi tog'dagi bo'lakni o'g'irladi!", t=2),
    say("Qoyaqul", "Tog' hech qachon unutmaydi. Qora Tumanga — hammasi!", t=10),
]
m["outro"] = "troll6_end"
M["troll6"] = m
dialog_scene("troll6_end", "dusk", [("qoyaqul", 0), ("boronbek", 0)], [("saidxon", 0), ("zahrinoz", 0)], [
    ("Zahrinoz", "Tumandan bo'lakni qaytarib oldik. U hali ham issiq — xuddi tog' yuragi kabi."),
    ("Saidxon", "Odamlar va elflarga xabar yuborish kerak. Biz ular bilan urishmasligimiz kerak edi."),
    ("Qoyaqul", "Trollar uzr so'ramaydi... lekin kerak bo'lsa, yonma-yon turadi."),
], extra_spawn=[{"kind": "crystal", "id": "shard", "pos": [0, 0.6, 0.6], "size": 0.4, "color": "#ff7a30", "spin": 1.0}],
   end_card=(tr("2-bob tugadi", "Глава 2 завершена", "Chapter 2 complete"), tr("Keyingi: So'nayotgan O'rmon", "Далее: Угасающий лес", "Next: The Fading Forest")))

# =====================================================================
# 3-BOB: ELFLAR — «So'nayotgan O'rmon»
# =====================================================================
CH3 = tr("So'nayotgan O'rmon", "Угасающий лес", "The Fading Forest")

m = field_mission("elf1", tr("1-missiya: Tuman chekkasi", "Миссия 1: Край тумана", "Mission 1: Edge of the Mist"),
                  tr("O'rmonga kirgan barcha dushmanni yo'q qiling", "Уничтожьте всех врагов, вошедших в лес", "Destroy every enemy that entered the forest"),
                  "elflar", "yalmogiz", env="night")
m["player_units"] = [g("oydinoy", 1, [-38, 0, 36], level=2), g("kumush_kamonchi", 4, [-40, 0, 40]), g("barg_qilichli", 3, [-36, 0, 40]), g("shamol_raqqosasi", 2, [-42, 0, 36])]
m["enemy_units"] = [g("suyak_qul", 3, [-12, 0, 10]), g("suyak_askar", 3, [-6, 0, 16]), g("ajina", 3, [12, 0, -6]), g("suyak_askar", 4, [26, 0, 22]), g("qarga_jodugar", 2, [34, 0, -30]), g("temir_tishli_ayiq", 2, [30, 0, -34])]
m["victory"] = {"type": "destroy_all"}
m["triggers"] = [
    {"when": {"time": 1}, "do": [{"say": ["Oydinoy", "Daraxtlar qurib qolyapti... Tuman ular jonini so'ryapti."]}]},
    say("Oydinoy", "Kechasi biz ko'rinmasmiz. Jim turing — keyin birdan uring!", t=8),
    {"when": {"enemy_below": 8}, "do": [{"say": ["Shamshod", "Oydinoy! Shimolda qarg'a jodugarlar — tumanni ular yoyyapti!"]}, {"reveal": [32, -32, 12], "reveal_time": 15}, {"spawn": {"id": "shamshod", "count": 1, "at": [-34, 0, 34], "team": 0, "level": 2}}]},
]
m["intro"] = "elf_intro"
M["elf1"] = m
CS["elf_intro"] = {"id": "elf_intro", "shots": [
    title_card(tr("3-bob", "Глава 3", "Chapter 3"), CH3),
    shot(9, [0, 3, 11], [1.5, 2.6, 8.5], [0, 1.6, 0], env="night", fade_in=True, spawn=[
        {"kind": "forest", "id": "f", "pos": [0, 0, -5], "radius": 6, "count": 14, "seed": 3},
        {"kind": "mist", "id": "tuman", "pos": [4, 0, -4], "radius": 5, "color": "#3a1a50"},
        {"kind": "light", "id": "oy", "pos": [0, 6, 2], "color": "#9fc8ff", "energy": 2.0, "range": 16},
        unit("oydinoy", "oydinoy", [0, 0, 1.5], [0, 0, 8]),
        unit("elflar", "kumush_kamonchi", [0, 0, -0.5], [0, 0, 8], count=4, cols=4),
    ], lines=[(0.5, "Hikoyachi", "G'arbiy o'rmonlarda Qora Tuman har kecha bir qadam oldinga siljiydi."),
              (4.5, "Oydinoy", "Tuman o'rmonni yeyapti. Agar Hayot Daraxti qursa, elflar ham yo'q bo'ladi.")]),
    shot(6, [-2.5, 2, 5], [-2, 1.9, 4], [0, 1.5, 1], clear=False, fade_out=True,
         lines=[(0.4, "Oydinoy", "Kamonlaringizni tayyorlang. Bu tun — bizniki.")],
         actions=[{"t": 1.2, "actor": "elflar", "do": "attack", "times": 1}]),
]}

m = base_mission("elf2", tr("2-missiya: Ildizlarni tiklash", "Миссия 2: Восстановление корней", "Mission 2: Restoring the Roots"),
                 tr("Hayot Daraxtini saqlab, Qora Tuman qarorgohini yo'q qiling", "Сохраните Древо жизни и уничтожьте лагерь Чёрного тумана", "Keep the Tree of Life alive and destroy the Black Mist camp"),
                 "elflar", "yalmogiz", env="day", diff="oson", first_wave=340)
m["player_units"] = [g("oydinoy", 1, [-30, 0, 30], level=3), g("shamshod", 1, [-32, 0, 31], level=3)]
m["defeat"] = {"protect_building": "hayot_daraxti"}
m["triggers"] = [
    say("Oydinoy", "Hayot Daraxti — o'rmon yuragi. U yiqilsa, hammamiz yo'qolamiz.", t=2),
    say("Shamshod", "Gulchilar ildiz tarmog'ini kengaytirsin: unga ulangan binolar o'zini davolaydi.", t=9),
]
M["elf2"] = m

m = field_mission("elf3", tr("3-missiya: Yulduzlar kuzatuvchisi", "Миссия 3: Наблюдатель звёзд", "Mission 3: The Star Watcher"),
                  tr("Qamal qilingan rasadxonaga yetib, Ulug'bekni qutqaring", "Доберитесь до осаждённой обсерватории и спасите Улугбека", "Reach the besieged observatory and rescue Ulugh Beg"),
                  "elflar", "trollar", env="dusk")
m["player_units"] = [g("oydinoy", 1, [-38, 0, 36], level=4), g("shamshod", 1, [-36, 0, 38], level=4), g("kumush_kamonchi", 4, [-40, 0, 40]), g("oq_bugu_chavandoz", 2, [-42, 0, 36])]
m["enemy_units"] = [g("toshtish_troll", 3, [-8, 0, 8]), g("nayza_otar", 3, [8, 0, -4]), g("ikki_boshli_dev", 1, [26, 0, 6]), g("toshtish_troll", 4, [32, 0, -24]), g("nayza_otar", 2, [38, 0, -30])]
m["neutral_buildings"] = [{"id": "karvonsaroy", "at": [-30, 0, -20]}]
m["victory"] = {"type": "reach", "area": [36, -36, 7], "unit": "oydinoy"}
m["defeat"] = {"protect_unit": "oydinoy"}
m["triggers"] = [
    say("Oydinoy", "Ulug'bek yulduzlardan bo'laklarning joyini hisoblay oladi. Trollar uni rasadxonada qamal qilishgan.", t=2),
    say("Shamshod", "Trollar juda ko'p. Yo'lni aylanib o'tsak bo'ladi — o'rmon orqali.", t=9),
    {"when": {"time": 4}, "do": [{"reveal": [36, -36, 8], "reveal_time": 12}]},
    {"when": {"area": [30, -28, 14]}, "do": [{"say": ["Ulug'bek", "Elflar?! Kim bo'lsangiz ham — tezroq! Ular eshikni buzishyapti!"]}, {"wave": True}]},
]
m["outro"] = "elf3_end"
M["elf3"] = m
dialog_scene("elf3_end", "dusk", [("oydinoy", 0), ("shamshod", 0)], [("ulugbek", 0)], [
    ("Ulug'bek", "Rahmat, o'rmon farzandlari. Yulduzlar menga ko'p narsani aytdi."),
    ("Ulug'bek", "To'rt bo'lak to'rt saltanatda. Kashshey ikkitasini olgan, uchinchisi — sizning o'rmoningizda."),
    ("Oydinoy", "Unda trollar bizga dushman emas... Ular ham aldangan."),
])

m = field_mission("elf4", tr("4-missiya: Ittifoqmi?", "Миссия 4: Союз?", "Mission 4: Alliance?"),
                  tr("Qoyaqulni duelda yengib, ittifoqqa ko'ndiring", "Победите Каякула в поединке и склоните к союзу", "Defeat Qoyaqul in a duel and win the alliance"),
                  "elflar", "trollar", env="day")
m["player_units"] = [g("oydinoy", 1, [-38, 0, 36], level=5), g("shamshod", 1, [-36, 0, 38], level=5), g("ulugbek", 1, [-40, 0, 38], level=3), g("barg_qilichli", 4, [-40, 0, 40]), g("kumush_kamonchi", 4, [-36, 0, 42])]
m["enemy_units"] = [g("qoyaqul", 1, [4, 0, -4], level=6, tag="nishon"), g("toshtish_troll", 5, [8, 0, -8]), g("qoya_otar_gigant", 1, [12, 0, -12]), g("mamont_chavandoz", 2, [-4, 0, -14])]
m["victory"] = {"type": "kill_targets", "tag": "nishon"}
m["triggers"] = [
    say("Qoyaqul", "Elflar! Trollar faqat kuchliga quloq soladi. Meni yengsangiz — gaplashamiz.", t=2, team=1),
    say("Oydinoy", "Qabul qildik. Lekin o'ldirmaymiz — faqat yengamiz!", t=9),
    {"when": {"time": 20}, "do": [{"wave": True}]},
]
m["outro"] = "elf4_end"
M["elf4"] = m
dialog_scene("elf4_end", "day", [("oydinoy", 0), ("ulugbek", 0)], [("qoyaqul", 1), ("boronbek", 1)], [
    ("Qoyaqul", "Uf... Kuchli ekansiz, elflar. So'zim — so'z. Trollar sizning tomoningizda."),
    ("Oydinoy", "Bizning dushmanimiz bitta — Kashshey. Birga uramiz."),
    ("Boronbek", "Faqat daraxtlaringizni boltalamaymiz, deb va'da bermayman!"),
])

m = defend_mission("elf5", tr("5-missiya: To'lin oy kechasi", "Миссия 5: Ночь полнолуния", "Mission 5: Night of the Full Moon"),
                   tr("To'lin oy botguncha (7 daqiqa) Hayot Daraxtini himoya qiling", "Защищайте Древо жизни до заката луны (7 минут)", "Protect the Tree of Life until moonset (7 minutes)"),
                   "elflar", "yalmogiz", 420)
m["player_units"] = [g("oydinoy", 1, [-30, 0, 30], level=6), g("zumrad", 1, [-32, 0, 31], level=4), g("ulugbek", 1, [-28, 0, 32], level=4)]
m["defeat"] = {"protect_building": "hayot_daraxti"}
m["triggers"] = [
    {"when": {"time": 1}, "do": [{"night": 430}]},
    say("Zumrad", "O'rmon ruhlari uyg'ondi. Bu tun daraxtlar ham jang qiladi!", t=2),
    say("Ulug'bek", "Kashshey to'lin oyda bo'lakni olmoqchi. 7 daqiqa — keyin oy botadi!", t=9),
    wave(50, 60, 400, [g("suyak_askar", 5, EDGES["ne"]), g("ajina", 2, EDGES["e"])], ["Yalmog'iz Kampir", "Daraxtingizni qozonimga tashlayman!"]),
    wave(85, 150, 400, [g("ilon_otli", 3, EDGES["n"]), g("qarga_jodugar", 2, EDGES["n"])]),
    wave(120, 250, 400, [g("uch_boshli_ajdar", 1, EDGES["ne"]), g("temir_tishli_ayiq", 2, EDGES["e"])]),
    {"when": {"time": 200}, "do": [{"spawn": {"id": "qoyaqul", "count": 1, "at": [-44, 0, 20], "team": 0, "level": 6}}, {"spawn": {"id": "toshtish_troll", "count": 4, "at": [-44, 0, 22], "team": 0}}, {"say": ["Qoyaqul", "Va'da — va'da! Trollar yetib keldi!"]}]},
]
M["elf5"] = m

m = base_mission("elf6", tr("6-missiya: O'rmon uyg'onadi", "Миссия 6: Лес пробуждается", "Mission 6: The Forest Awakens"),
                 tr("Qora Tuman qarorgohini butunlay yo'q qiling", "Полностью уничтожьте лагерь Чёрного тумана", "Completely destroy the Black Mist camp"),
                 "elflar", "yalmogiz", env="dusk", diff="qiyin", first_wave=280, res=(800, 500))
m["player_units"] = [g("oydinoy", 1, [-30, 0, 30], level=7), g("zumrad", 1, [-32, 0, 31], level=5), g("shamshod", 1, [-28, 0, 32], level=6), g("ulugbek", 1, [-26, 0, 30], level=5)]
m["ally_units"] = [g("toshtish_troll", 4, [-24, 0, 38])]
m["enemy_units"] = [g("yalmogiz_kampir", 1, [32, 0, -30], level=6)]
m["triggers"] = [
    say("Oydinoy", "Bugun o'rmon qasos oladi. Ildizlardan tortib barglargacha — hammasi jangga!", t=2),
    say("Ulug'bek", "Bo'lak Yalmog'iz Kampirning qozonida. Qozonni buzing!", t=9),
]
m["outro"] = "elf6_end"
M["elf6"] = m
dialog_scene("elf6_end", "dusk", [("oydinoy", 0), ("zumrad", 0)], [("ulugbek", 0), ("qoyaqul", 0)], [
    ("Zumrad", "Tuman chekinmoqda... Daraxtlar yana nafas olyapti."),
    ("Ulug'bek", "Uch bo'lak tinch saltanatlar qo'lida. Lekin to'rtinchisi — Kashsheyning o'zida."),
    ("Oydinoy", "Unda oxirgi jang Yer Yuragi oldida bo'ladi."),
], extra_spawn=[{"kind": "crystal", "id": "shard", "pos": [0, 0.6, 0.6], "size": 0.4, "color": "#7fffd0", "spin": 1.0}],
   end_card=(tr("3-bob tugadi", "Глава 3 завершена", "Chapter 3 complete"), tr("Keyingi: O'lmas Shohning Qaytishi", "Далее: Возвращение Бессмертного царя", "Next: Return of the Undying King")))

# =====================================================================
# 4-BOB: YALMOG'IZ — «O'lmas Shohning Qaytishi»
# =====================================================================
CH4 = tr("O'lmas Shohning Qaytishi", "Возвращение Бессмертного царя", "Return of the Undying King")

m = field_mission("yal1", tr("1-missiya: Qabrdan uyg'onish", "Миссия 1: Пробуждение из могилы", "Mission 1: Rising from the Grave"),
                  tr("Chegara posbonlarini yo'q qiling", "Уничтожьте пограничные дозоры", "Wipe out the border patrols"),
                  "yalmogiz", "odamlar", env="night")
m["player_units"] = [g("kashshey", 1, [-38, 0, 36], level=2), g("suyak_askar", 5, [-40, 0, 40]), g("ajina", 3, [-36, 0, 40]), g("qarga_jodugar", 1, [-42, 0, 38])]
m["enemy_units"] = [g("navkar", 3, [-10, 0, 10]), g("mergan", 2, [-6, 0, 14]), g("navkar", 4, [14, 0, -4]), g("tabib", 1, [16, 0, -2]), g("otliq_botir", 3, [30, 0, 24]), g("navkar", 4, [34, 0, -30]), g("mergan", 3, [38, 0, -26])]
m["enemy_buildings"] = [{"id": "minora", "at": [30, 0, -34]}, {"id": "minora", "at": [-4, 0, 18]}]
m["victory"] = {"type": "destroy_all"}
m["triggers"] = [
    {"when": {"time": 1}, "do": [{"say": ["Kashshey", "Ming yillik uyqu tugadi. Mening jonim igna uchida — igna esa tuxumda. Hech kim meni o'ldira olmaydi."]}]},
    say("Kashshey", "Tiriklar chegarasini yorib o'tamiz. Har bir yiqilgan dushman — yangi askar!", t=9),
    {"when": {"enemy_below": 12}, "do": [{"spawn": {"id": "olimxon", "count": 1, "at": [-34, 0, 34], "team": 0, "level": 2}}, {"say": ["Olimxon", "Hukmdorim! Men tumandan chiqdim — sizga xizmat qilish uchun."]}]},
]
m["intro"] = "yal_intro"
M["yal1"] = m
CS["yal_intro"] = {"id": "yal_intro", "shots": [
    title_card(tr("4-bob", "Глава 4", "Chapter 4"), CH4),
    shot(9, [0, 3.4, 11], [1.2, 2.8, 8.5], [0, 1.6, 0], env="dark", fade_in=True, spawn=[
        {"kind": "mist", "id": "tuman", "pos": [0, 0, -2], "radius": 7, "color": "#2a1238"},
        {"kind": "light", "id": "yashil", "pos": [0, 2.5, 0], "color": "#7fff3f", "energy": 2.5, "range": 12},
        unit("kashshey", "kashshey", [0, 0, 1], [0, 0, 8]),
        unit("skeletlar", "suyak_askar", [0, 0, -1.5], [0, 0, 8], count=8, cols=4),
    ], lines=[(0.5, "Hikoyachi", "Sharqning la'natlangan yerlarida qadimiy qabr ochildi."),
              (4.2, "Kashshey", "To'rt bo'lak... to'rt saltanat... Hammasi menga bo'ysunadi.")],
         actions=[{"t": 0.6, "actor": "kashshey", "do": "rise"}, {"t": 2.0, "actor": "skeletlar", "do": "rise"}]),
    shot(6, [2.5, 2, 5], [2, 1.9, 4], [0, 1.5, 1], clear=False, fade_out=True,
         lines=[(0.4, "Kashshey", "Tuman, yoyil! Bugun tiriklar dunyosi bizni eslaydi.")]),
]}

m = base_mission("yal2", tr("2-missiya: Tuman yoyilmoqda", "Миссия 2: Туман расползается", "Mission 2: The Mist Spreads"),
                 tr("Qora Tumanni yoyib, elflar qarorgohini yo'q qiling", "Распространите туман и уничтожьте лагерь эльфов", "Spread the mist and destroy the elven camp"),
                 "yalmogiz", "elflar", env="dusk", diff="oson", first_wave=360)
m["player_units"] = [g("kashshey", 1, [-30, 0, 30], level=3), g("olimxon", 1, [-32, 0, 31], level=2)]
m["triggers"] = [
    say("Olimxon", "Hukmdorim, binolarimiz faqat tuman ichida turadi. Avval Jon Tuxumi va qabristonlar!", t=2),
    say("Kashshey", "Tuxum — mening abadiyligim. Unda qahramonlar o'lmaydi, qayta tug'iladi.", t=9),
]
M["yal2"] = m

m = field_mission("yal3", tr("3-missiya: Birinchi bo'lak", "Миссия 3: Первый осколок", "Mission 3: The First Shard"),
                  tr("Qadimgi qo'riqchini yengib, bo'lakni oling", "Победите древнего стража и заберите осколок", "Defeat the ancient guardian and take the shard"),
                  "yalmogiz", "trollar", env="night")
m["player_units"] = [g("kashshey", 1, [-38, 0, 36], level=4), g("olimxon", 1, [-36, 0, 38], level=3), g("suyak_askar", 5, [-40, 0, 40]), g("alvasti", 2, [-36, 0, 42]), g("qarga_jodugar", 2, [-42, 0, 38])]
m["enemy_units"] = [g("qadimgi_qoriqchi", 1, [36, 0, -36], tag="nishon", level=1), g("tosh_golem", 3, [30, 0, -30])]
m["creep_camps"] = [
    {"at": [-8, 0, 8], "units": [{"id": "tosh_golem", "count": 2}], "drop": "noyob"},
    {"at": [20, 0, 20], "units": [{"id": "lanatli_jangchi", "count": 3}], "drop": "noyob"},
    {"at": [-20, 0, -18], "units": [{"id": "qaroqchi", "count": 3}, {"id": "qaroqchi_kamonchi", "count": 2}], "drop": "epik"},
]
m["victory"] = {"type": "kill_targets", "tag": "nishon"}
m["defeat"] = {"protect_unit": "kashshey"}
m["triggers"] = [
    say("Olimxon", "Bo'lakni qadimgi qo'riqchi saqlaydi. Avval lagerlardan buyum yig'ing — u juda kuchli.", t=2),
    say("Kashshey", "Qo'riqchi... Men uni ming yil oldin ham ko'rganman.", t=9),
    {"when": {"area": [30, -30, 14]}, "do": [{"say": ["Qadimgi Qo'riqchi", "Yer Yuragi hech kimga tegishli emas. Ortga qayt, o'lmas!"], "team": 1}]},
]
M["yal3"] = m

m = base_mission("yal4", tr("4-missiya: Trollar tog'i", "Миссия 4: Гора троллей", "Mission 4: Troll Mountain"),
                 tr("Trollarning Tosh G'orini yo'q qiling va tog' bo'lagini oling", "Разрушьте Каменную пещеру троллей и заберите осколок", "Destroy the trolls' Stone Cave and take the mountain shard"),
                 "yalmogiz", "trollar", env="night", diff="orta", first_wave=300)
m["player_units"] = [g("kashshey", 1, [-30, 0, 30], level=5), g("olimxon", 1, [-32, 0, 31], level=4), g("alvasti_malika", 1, [-28, 0, 32], level=3)]
m["victory"] = {"type": "destroy_buildings", "buildings": ["tosh_gor", "qoya_qala", "vulqon_taxti"]}
m["triggers"] = [
    say("Alvasti Malika", "Trollar elflar bilan urishib charchagan. Ayni payt!", t=2),
    say("Kashshey", "Ularning bosh g'orini yiqitsangiz, bo'lak o'zi menga keladi.", t=9),
]
M["yal4"] = m

m = defend_mission("yal5", tr("5-missiya: Ittifoq hujumi", "Миссия 5: Удар союза", "Mission 5: The Alliance Strikes"),
                   tr("Odamlar va elflar hujumidan 8 daqiqa davomida Jon Tuxumini saqlang", "Удерживайте Яйцо души 8 минут против людей и эльфов", "Keep the Soul Egg alive for 8 minutes against humans and elves"),
                   "yalmogiz", "odamlar", 480, env="dusk")
m["player_units"] = [g("kashshey", 1, [-30, 0, 30], level=6), g("alvasti_malika", 1, [-32, 0, 31], level=5), g("yalmogiz_kampir", 1, [-28, 0, 32], level=4)]
m["player_buildings"] = [{"id": "jon_tuxumi", "at": [-42, 0, 24]}]
m["defeat"] = {"protect_building": "jon_tuxumi"}
m["triggers"] = [
    say("Yalmog'iz Kampir", "Odamlar va elflar birlashibdi! Qozonimga hammasi sig'adi.", t=2),
    say("Kashshey", "Tuxum yashasa — men yashayman. 8 daqiqa ushlab turing!", t=9),
    wave(55, 60, 460, [g("navkar", 4, EDGES["ne"]), g("mergan", 2, EDGES["ne"])], ["Alpomish", "Kashshey! Bu gal tuxumingni sindiramiz!"]),
    wave(70, 120, 460, [g("kumush_kamonchi", 3, EDGES["e"]), g("barg_qilichli", 3, EDGES["e"])]),
    wave(110, 220, 460, [g("otliq_botir", 3, EDGES["n"]), g("oq_bugu_chavandoz", 2, EDGES["n"])]),
    {"when": {"time": 300}, "do": [{"spawn": [{"id": "alpomish", "count": 1, "at": EDGES["ne"], "team": 1, "level": 7, "attack": True}, {"id": "oydinoy", "count": 1, "at": EDGES["e"], "team": 1, "level": 7, "attack": True}]}, {"say": ["Oydinoy", "Tuxumni sindiring! Shunda u o'lmas emas!"], "team": 1}]},
]
M["yal5"] = m

m = base_mission("yal6", tr("6-missiya: O'lmas Shoh", "Миссия 6: Бессмертный царь", "Mission 6: The Undying King"),
                 tr("Odamlar poytaxtini butunlay yo'q qiling", "Полностью уничтожьте столицу людей", "Completely destroy the human capital"),
                 "yalmogiz", "odamlar", env="night", diff="qiyin", first_wave=270, res=(800, 500))
m["player_units"] = [g("kashshey", 1, [-30, 0, 30], level=7), g("alvasti_malika", 1, [-32, 0, 31], level=6), g("yalmogiz_kampir", 1, [-28, 0, 32], level=5), g("olimxon", 1, [-26, 0, 30], level=5)]
m["enemy_units"] = [g("alpomish", 1, [32, 0, -30], level=7), g("barchinoy", 1, [34, 0, -28], level=6)]
m["triggers"] = [
    say("Kashshey", "Oxirgi bo'lak Oltin Vodiyda. Alpomish uni o'z poytaxtida saqlaydi.", t=2),
    say("Olimxon", "Hukmdorim... bo'laklarni yig'sangiz, nima bo'ladi? Dunyo omon qoladimi?", t=9),
    say("Kashshey", "Dunyo menga bo'ysunadi, Olimxon. Bu — omon qolishning yagona yo'li.", t=15),
]
m["outro"] = "yal6_end"
M["yal6"] = m
dialog_scene("yal6_end", "dark", [("kashshey", 0), ("yalmogiz_kampir", 0)], [("olimxon", 0), ("alvasti_malika", 0)], [
    ("Kashshey", "To'rt bo'lak... nihoyat. Yer Yuragi uyg'onmoqda!"),
    ("Olimxon", "Hukmdorim, qarang — yer titrayapti. Bo'laklar o'zi bir-biriga intilyapti!"),
    ("Yalmog'iz Kampir", "Yurak to'rt saltanatni bir joyga chaqiryapti. Hamma keladi..."),
    ("Kashshey", "Kelsin. Yer Yuragi oldida taqdir hal bo'ladi."),
], extra_spawn=[{"kind": "crystal", "id": "shard", "pos": [0, 0.8, 0.6], "size": 0.6, "color": "#b04fe0", "spin": 1.6}],
   end_card=(tr("4-bob tugadi", "Глава 4 завершена", "Chapter 4 complete"), tr("Oxirgi jang: Yer Yuragi", "Последняя битва: Сердце Земли", "Final battle: The Heart of the Earth")))

# =====================================================================
# FINAL — «Yer Yuragi» (saltanat va yakunni tanlash)
# =====================================================================
CH5 = tr("Yer Yuragi", "Сердце Земли", "The Heart of the Earth")
m = base_mission("final", tr("Final: Yer Yuragi", "Финал: Сердце Земли", "Finale: The Heart of the Earth"),
                 tr("Dushman qo'shinini butunlay yo'q qiling", "Полностью уничтожьте вражеское войско", "Completely destroy the enemy army"),
                 "odamlar", "yalmogiz", env="dusk", diff="qiyin", first_wave=260, res=(900, 600))
m["clear_spots"] = m["clear_spots"] + [[0, 0, 0, 12]]
m["choices"] = [
    {"question": tr("Qaysi saltanat bilan oxirgi jangga kirasiz?", "С каким царством вы вступите в последний бой?", "Which kingdom will you lead into the final battle?"),
     "options": [
         {"text": "Odamlar", "set": {"player_faction": "odamlar", "enemy_faction": "yalmogiz"}},
         {"text": "Trollar", "set": {"player_faction": "trollar", "enemy_faction": "yalmogiz"}},
         {"text": "Elflar", "set": {"player_faction": "elflar", "enemy_faction": "yalmogiz"}},
         {"text": "Yalmog'iz", "set": {"player_faction": "yalmogiz", "enemy_faction": "odamlar"}},
     ]},
    {"question": tr("G'alabadan keyin Yer Yuragini nima qilasiz?", "Что вы сделаете с Сердцем Земли после победы?", "What will you do with the Heart of the Earth after victory?"),
     "options": [
         {"text": tr("Bo'laklarni to'rt saltanatga qaytarish", "Вернуть осколки четырём царствам", "Return the shards to the four kingdoms"), "set": {"outro": "final_end_peace"}},
         {"text": tr("Yurakni o'zim uchun olish", "Забрать Сердце себе", "Take the Heart for myself"), "set": {"outro": "final_end_power"}},
     ]},
]
m["triggers"] = [
    say("Hikoyachi", "Yer Yuragi xaritaning markazida uyg'ondi. To'rt saltanat qo'shinlari unga qarab yo'l oldi.", t=2),
    say("Hikoyachi", "Markazdagi qadimgi qo'riqchilar Yurakni saqlaydi. Ularni yengganga Yurak kuch beradi.", t=10),
    {"when": {"time": 1}, "do": [{"reveal": [0, 0, 10], "reveal_time": 20}]},
]
m["creep_camps"] = m["creep_camps"] + [{"at": [0, 0, 0], "units": [{"id": "qadimgi_qoriqchi", "count": 2}, {"id": "tosh_golem", "count": 2}], "drop": "afsonaviy"}]
m["intro"] = "final_intro"
M["final"] = m
CS["final_intro"] = {"id": "final_intro", "shots": [
    title_card(tr("Final", "Финал", "Finale"), CH5),
    shot(10, [0, 4, 12], [0, 3, 8], [0, 2.2, 0], env="dusk", fade_in=True, spawn=[
        {"kind": "crystal", "id": "yurak", "pos": [0, 2.4, 0], "size": 1.0, "color": "#ffd470", "spin": 0.8},
        {"kind": "light", "id": "nur", "pos": [0, 2.6, 0], "color": "#ffd470", "energy": 3.0, "range": 14},
        unit("odam", "alpomish", [-5, 0, 2], [0, 0, 0]), unit("troll", "qoyaqul", [5, 0, 2], [0, 0, 0]),
        unit("elf", "oydinoy", [-3, 0, 5], [0, 0, 0]), unit("yal", "kashshey", [3, 0, -4], [0, 0, 0], team=1),
    ], lines=[(0.5, "Hikoyachi", "To'rt bo'lak birlashdi. Ko'hna Zaminning yuragi qayta urmoqda."),
              (4.0, "Kashshey", "Yurak meniki! Ming yil kutganman!"),
              (7.0, "Alpomish", "Yurak hech kimniki emas. Uni bugun himoya qilamiz!")],
         actions=[{"t": 3.0, "do": "shake", "amount": 0.5}, {"t": 4.0, "actor": "yal", "do": "attack", "times": 1}]),
]}
dialog_scene("final_end_peace", "day", [("alpomish", 0), ("oydinoy", 0)], [("qoyaqul", 0), ("olimxon", 0)], [
    ("Alpomish", "Jang tugadi. Yurakni hech kim yolg'iz o'ziga ololmaydi."),
    ("Oydinoy", "Bo'laklarni har bir saltanatga qaytaramiz — o'rmon, tog', vodiy va tuman."),
    ("Qoyaqul", "Trollar bo'lakni qo'riqlaydi. Endi — do'st sifatida."),
    ("Olimxon", "Tuman ham tinchlansin. Kashsheyning tuxumi esa abadiy muzda qolsin."),
], extra_spawn=[{"kind": "crystal", "id": "yurak", "pos": [0, 1.2, 0.4], "size": 0.6, "color": "#ffd470", "spin": 0.5}],
   end_card=(tr("Tinchlik yakuni", "Финал мира", "Ending: Peace"), tr("To'rt saltanat yangi davrni birga boshladi. Rahmat, Husan!", "Четыре царства вместе начали новую эпоху. Спасибо, Хусан!", "The four kingdoms began a new era together. Thank you, Husan!")))
dialog_scene("final_end_power", "dark", [("kashshey", 1)], [("alpomish", 0), ("barchinoy", 0)], [
    ("Hikoyachi", "G'olib Yer Yuragini qo'liga oldi. Yurak qizib, porlab ketdi..."),
    ("Barchinoy", "To'xta! Yurak bitta qo'lda bo'lsa, u dunyoni yondiradi!"),
    ("Alpomish", "Kuch — bu yuk. Kim uni olsa, butun Zamin uchun javob beradi."),
    ("Hikoyachi", "Yangi hukmdor taxtga o'tirdi. Ammo uzoq sharqda Kashsheyning tuxumi yana titray boshladi..."),
], extra_spawn=[{"kind": "crystal", "id": "yurak", "pos": [0, 1.2, 0.4], "size": 0.7, "color": "#ff4040", "spin": 2.0}],
   end_card=(tr("Hukmdor yakuni", "Финал власти", "Ending: Power"), tr("Davomi bormi? Buni faqat vaqt ko'rsatadi...", "Продолжение? Покажет только время...", "To be continued? Only time will tell...")))

# Odamlar bobini bog'lash
M_EXIST = {"mission1": {"next": "mission2"}, "mission2": {"next": "odam3"}}

CHAPTERS = [
    {"title": CH1, "faction": "odamlar", "missions": ["mission1", "mission2", "odam3", "odam4", "odam5", "odam6"]},
    {"title": CH2, "faction": "trollar", "missions": ["troll1", "troll2", "troll3", "troll4", "troll5", "troll6"]},
    {"title": CH3, "faction": "elflar", "missions": ["elf1", "elf2", "elf3", "elf4", "elf5", "elf6"]},
    {"title": CH4, "faction": "yalmogiz", "missions": ["yal1", "yal2", "yal3", "yal4", "yal5", "yal6"]},
    {"title": CH5, "faction": "", "missions": ["final"], "requires_all": True},
]

# next zanjiri
for ch in CHAPTERS:
    ids = ch["missions"]
    for i, mid in enumerate(ids):
        if mid in M:
            M[mid]["next"] = ids[i + 1] if i + 1 < len(ids) else ""

# Yozish
for mid, md in M.items():
    json.dump(md, open(os.path.join(ROOT, "data/missions/%s.json" % mid), "w"), ensure_ascii=False, indent=1)
for cid, cd in CS.items():
    json.dump(cd, open(os.path.join(ROOT, "data/cutscenes/%s.json" % cid), "w"), ensure_ascii=False, indent=1)
for mid, patch in M_EXIST.items():
    p = os.path.join(ROOT, "data/missions/%s.json" % mid)
    d = json.load(open(p))
    d.update(patch)
    json.dump(d, open(p, "w"), ensure_ascii=False, indent=1)
json.dump({"chapters": CHAPTERS}, open(os.path.join(ROOT, "data/campaign.json"), "w"), ensure_ascii=False, indent=1)

# Tarjimalar
lp = os.path.join(ROOT, "data/localization.json")
loc = json.load(open(lp))
for k, v in TR.items():
    loc["t"][k] = list(v)
json.dump(loc, open(lp, "w"), ensure_ascii=False, indent=0)
print("missiyalar:", len(M), "kino:", len(CS), "tarjima:", len(TR))
