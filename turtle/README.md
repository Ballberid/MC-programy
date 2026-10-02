# Craftoria turtle knižnice

Modulárny základ pre CC:Tweaked s programom `quarry` na kopanie kvádra
a menu `build` na výber stavebného programu (zatiaľ podlaha `floor`).
Postup opisuje [PODLAHA_NAVOD.md](PODLAHA_NAVOD.md).
Viac turtle môže riadiť hlavný PC programom `fleet`; stavbu a inštaláciu opisuje
[FLEET_NAVOD.md](FLEET_NAVOD.md).
Knižnice sa načítavajú cez `require("navigation")` atď. Súbory nainštaluj do rovnakého
pracovného priečinka a programy spúšťaj z neho. Dáta sa ukladajú do `data/`.

## Inštalácia a prvé overenie

Nové súbory musia byť najprv nahrané do vetvy `main` repozitára
`Ballberid/MC-programy`. Lokálne úpravy samy osebe nemenia GitHub ani turtle v hre.

`dw_update.lua` sťahuje `turtle/turtle_update.lua` a uloží ho v hre ako `update.lua`.
Ak má existujúci herný `dw_update` ešte starú URL smerujúcu do koreňa repozitára,
jednorazovo oprav jeho URL alebo po nahratí súborov použi:

```text
wget https://raw.githubusercontent.com/Ballberid/MC-programy/refs/heads/main/turtle/turtle_update.lua update.lua
```

Na turtle postupne spusti:

```text
update turtle
reboot
setup
test check
test
```

`setup` potrebuje dostupné GPS. Automatické zistenie smeru urobí skúšobný pohyb,
prípadne obmedzený výstup nahor, a pokúsi sa vrátiť na pôvodné miesto aj smer.
Ak to priestor nedovolí, zvoľ v setup ručné zadanie smeru. Ručný smer je tvoja
informácia o skutočnej orientácii turtle, nie príkaz na jej otočenie.

Otázky áno/nie zobrazujú `A/n` alebo `a/N`. Veľké písmeno označuje predvolenú
odpoveď po prázdnom Enteri: `A/n` znamená áno, `a/N` znamená nie.
Pre áno stačí `a` alebo `y`, pre nie `n`, bez ohľadu na veľkosť písmen.
Prijímajú sa aj celé slová `ano`, `Áno`, `yes`, `nie`, `no`. Neplatná odpoveď
zopakuje otázku. Odpoveď sa píše na samostatnom riadku za krátkym `> `.

Orientácia: `0 = North (-Z)`, `1 = East (+X)`, `2 = South (+Z)`, `3 = West (-X)`.
Y je výška, nezávislá od orientácie.

Start a konečné miesto sú oddelené. `left/right/front/back` sa pri setup prepočítajú
podľa pôvodného smeru na štartovacej polohe. Pri vzdialenej truhle zadávaj súradnice
**miesta, kde bude stáť turtle**, jej smer a stranu truhly (`front/up/down`).
Rôzne služby môžu používať tú istú truhlu.

Najprv vlož dostatok paliva na overenie cesty k palivovej stanici aj návrat.
Setup ukladá nastavenia, nenavštevuje truhly. V diagnostike potom vyber overenie
truhiel. `test check` sa nepohybuje a nespotrebúva predmety. Interaktívne menu
vyžaduje `ANO` pred pohybom alebo zásobovaním. Diagnostika nekopá ani nestavia.

## Kopanie kvádra

Po aktualizácii spusti v termináli mining turtle:

```text
quarry
```

Program si vypýta X/Y/Z dvoch protiľahlých rohov. Sú to súradnice blokov, ktoré
majú patriť do vykopanej oblasti; oba rohy aj hranice sú zahrnuté. Rohy môžu byť
zadané v ľubovoľnom poradí; prvý určuje roh, od ktorého začne prechádzanie.
Pre kopanie zhora nadol zadaj horný roh ako prvý.
Napríklad `(100,50,100)` a `(102,52,104)` znamenajú
oblasť 3 × 3 × 5, teda 45 miest. Pred štartom zobrazí normalizované hranice,
rozmery a počet miest. Potvrdenie používa `a/N`, takže prázdny Enter kopanie zruší.
Ďalšia otázka umožní automatické zistenie smeru cez GPS alebo jeho ručné zadanie.

Používa palivovú a vykladaciu stanicu zo setupu; obe musia byť nastavené.
Knižnice a program automaticky stiahne `update turtle` podľa manifestu.
Potrebuje mining turtle s nástrojom na kopanie, funkčné GPS a počiatočné palivo
na overenie truhiel. Do setupu netreba zadávať rozmery výkopu.
Pred vstupom do výkopu doplní palivo podľa odhadu uvedeného nižšie.
Ak zásoba v truhle nestačí na celý cieľ, môže pokračovať s čiastočnou zásobou,
ak má palivo na návrat a rezervu. Počet blokov celého výkopu nie je požiadavkou,
aby mala všetko palivo naraz; počas práce sa môže opakovane zásobovať.
Na cestu za palivom pri nízkej zásobe používa už overenú trasu.
Plnenie nádrže používa `refuel(64)` po stackoch. Pri menšom cieľovom doplnení
zistí výdatnosť jedného kusu a zvyšný potrebný počet spotrebuje naraz.
Pri štarte vypisuje `Rezim: stacky paliva + lokalny vstup/prvy roh.`, aby bolo zrejmé,
že sa spustila táto verzia programu.

Najprv overí prístup k palivu a vykladacej truhle. Úvodné tankovanie preskočí,
ak palivo pokryje `2 × (objem výkopu + presuny + cesta k palivu a späť + rezervy)`.
Presuny zahŕňajú vstup, konečné vyloženie a návrat domov; pre neoverené cesty
sa pridá aj rezerva na obchádzanie. Inak doplní iba na tento cieľ, obmedzený
kapacitou nádrže a dostupným palivom. Pri cieli nad kapacitou naplní nádrž;
zásoba po návrate z tankovania je znížená o palivo spotrebované na túto cestu.
Kontroly zásob pri každom kroku zostávajú aktívne; dvojnásobný odhad
nie záruka pri opakovanom vykladaní alebo prekážkach. Pri štarte sa vypíše
vypočítaná potrebná zásoba, ak tankovanie preskočí.
Overenie prístupu k palivovej truhle môže prebehnúť aj bez tankovania.
Potom sa vráti na miesto,
kde bola turtle pri štarte úlohy. Ak je priamo pod ňou blok patriaci do výkopu,
vykope ho, vstúpi do oblasti a prekope sa k prvému zadanému rohu iba cez bloky
vo vnútri oblasti. Tak môže vstúpiť aj uprostred plochy s neprístupnými okrajmi.
Ak už stojí vo vnútri kvádra, tiež použije vnútornú cestu k prvému rohu.

Ak pod turtle ani v jej polohe nie je výkop, ide bežnou navigáciou k **prvému
zadanému rohu**. Skúša len vonkajšie miesta susediace s týmto rohom a nevyberie
iný bližší roh. Pri dolnom prvom rohu môže vstúpiť zboku alebo zdola. Pri každom
pokuse vypíše súradnice miesta pre turtle a rohového bloku.
**Nikdy nevykopáva prístupový tunel mimo zadanej oblasti.**

Oblasť prechádza cikcakom po vrstvách od prvého rohu: zhora nadol pri hornom
prvom rohu, zdola nahor pri dolnom. Každé ďalšie pracovné miesto
je susedný blok. Pri kopaní počíta úspešné presuny, nie počet pokusov. Pred každým
kopaním kontroluje palivo a aspoň dva prázdne sloty. Podľa potreby navštívi palivo
alebo vykladaciu truhlu a vráti sa na presnú pracovnú polohu aj smer. Telemetria
obsahuje priebeh; každých 64 miest vypíše počet dokončených miest. Limit oblasti
je 1 000 000 miest, ale dostupnosť paliva a navigačné limity môžu zastaviť aj menšiu oblasť.

Vykladá aj vykopaný uhlík a ďalšie palivové predmety, aby nezaplnili inventár.
Chránené predmety z `protectedItems` a nastavené palivové sloty zostávajú zachované.
Nepoužité novo vyzdvihnuté palivo vracia do palivovej truhly. Predmety, ktoré už
boli v inventári pred spustením, sa tiež môžu vyložiť, ak nie sú chránené.

Padajúci piesok/štrk opakovane odstraňuje, najviac 32 pokusov na jedno miesto.
Pri nerozbitnom bloku, inom turtle, inventári, vode/láve, nedostatku zásob alebo
nedoriešenej ceste úlohu označí ako nedokončenú, vypíše dôvod a pokúsi sa vrátiť
domov bez kopania. Nastavené truhly nesmú byť vo výkope. Program neodčerpáva
kvapaliny ani nemá automatické pokračovanie po reštarte. Po odstránení príčiny
možno znova zadať rovnaké rohy; už vyprázdnené miesta prejde bez kopania.

Po dokončení vyloží zvyšný materiál a vráti sa na konečné miesto aj smer zo setupu.
Zobrazený počet miest zahŕňa aj miesta, kde už bol vzduch; počet skutočných
kopaní je oddelený v údajoch `dug`. Modové bloky môžu zhadzovať viac rôznych predmetov
naraz; dva rezervné sloty nemusia stačiť na ľubovoľné množstvo lootov z jedného bloku.

## Súbory a API

| Súbor | Hlavné príkazy |
| --- | --- |
| `config.lua` | `defaults()`, `load()`, `save(settings)` |
| `position.lua` | Vnútorné sledovanie polohy, GPS, zisťovanie smeru |
| `navigation.lua` | `init([heading])`, `getPosition()`, `sync()`, `turnToDirection(d)`, `moveToCoord(x,y,z,[options])`, `step(side,[options])`, `knownDistance(point,[from])`, `setOrigin()`, `getOrigin()`, `goHome([options])` |
| `pathfinding.lua` | Ohraničené A*, mapa priechodných miest; `setAvoid(box)` rezervuje stavebnú oblasť a vracia predchádzajúcu rezerváciu |
| `fuel.lua` | `level()`, `has(amount)`, `refuel([target],[slots])`, `ensure(amount,[slots])`, `required(workMoves,returnMoves,reserve)`, `slots(settings)` |
| `inventory.lua` | `freeSlots()`, `freeSlotList()`, `count(name)`, `find(name)`, `select(name)`, `space(name)`, `snapshot()`, `hasMaterials(materials)` |
| `stations.lua` | `get(name)`, `visit(name,[options])`, `verify(name,[options])`, `refuel(target,[options])`, `unload([keep],[options])`, `takeMaterials(materials,[options])` |
| | `fillFuel([options])` naplní nádrž v stanici, potom sa vráti; palivo po návrate je znížené o túto cestu |
| `supplies.lua` | `prepare([heading])`, `check(request)`, `ensure(request)`, `navigationOptions()` |
| `cuboid.lua` | Normalizácia rohov, rozmery a postupné susedné bunky kvádra |
| `mining.lua` | `validateArea(cornerA,cornerB)`, `run(cornerA,cornerB,[heading])`, `stepTo(point,box,[progress])` |
| `quarry_entry.lua` | Výber a overovanie alternatívnych vstupov do kvádra |
| `quarry.lua` | Herný dialóg na vykopanie oblasti |
| `floor_plan.lua` | `new(a,b)`, `cell(box,index,first)`, `protected(box)`; bloky podlahy a priestor pre turtle nad aj pod nimi |
| `floor_access.lua` | Ohraničený prístup k bloku podlahy zhora alebo zdola, kladenie pod seba alebo nad seba |
| `building.lua` | `validateArea(a,b)`, `run(a,b,[blockName],[heading],[wholeArea],[onMaterialsMissing])`; vráti úspech, chybu a priebeh stavby |
| `floor.lua` | Herný dialóg na položenie obdĺžnikovej podlahy |
| `build.lua`, `build_programs.lua` | Menu stavebných programov a zoznam jeho možností; spúšťa sa cez `build` |
| `telemetry.lua` | `configure(settings,[positionProvider])`, `setActivity(text)`, `emit(level,message,[details],[force])`, `log(message,[level],[details])`, `capture(function,...)` |
| `network.lua` | Otvorenie dostupných modemov pre rednet |
| `setup.lua`, `test.lua` | Herné programy na nastavenie a diagnostiku |
| `receiver.lua`, `router.lua` | Programy na inom počítači/tablete/opakovači |

Väčšina akčných funkcií vracia `true` pri úspechu alebo `false, dôvod` pri neúspechu.
Čítanie konfigurácie a hľadanie objektu vracia `hodnota` alebo `nil, dôvod`.
`fuel.refuel()` naďalej vracia úroveň paliva vrátane hodnoty `"unlimited"`.
`nav.getOrigin()` naďalej vracia `x,y,z,smer`; číta aj pôvodný `data/origin.txt`,
ak ešte nie je nový setup. `nav.setOrigin()` nastaví štart aj konečné miesto na aktuálnu polohu.
`nav.direction()` zabezpečí inicializáciu/overenie a vracia úspech; smer získaš z `getPosition().direction`.

`stations.visit()` zostáva pri truhle. Ostatné servisné funkcie sa pokúsia vrátiť
na pracovnú polohu aj smer, vrátane prípadov, keď je truhla prázdna alebo plná.
Pri čiastočnom vyložení sa prenesené predmety neberú späť: výsledok oznámi chybu
a inventár obsahuje skutočný zostatok. Vykladanie chráni palivové predmety,
`protectedItems` a požadované počty materiálu v tabuľke `keep`.

Materiál sa berie cez `suck`, ktoré nemá argument na výber zdrojového slotu.
Knižnica preto postupne vezme najviac 16 dávok, overí obsah a novo získané
nepožadované predmety vráti. Veľká zmiešaná truhla môže hlásiť `materials_missing`,
aj keď má hľadané predmety v neskorších slotoch. Pre spoľahlivé zásobovanie používaj
truhly s príslušným materiálom a palivovú truhlu s palivom. Inventár truhly musí
byť rozpoznateľný ako CC periféria typu `inventory`; inak knižnica prenos odmietne.
`space(name)` odhaduje kapacitu podľa názvu; rozdielne NBT môžu brániť stohovaniu.

## Použitie z budúceho programu

```lua
local nav = require("navigation")
local supplies = require("supplies")
local telemetry = require("telemetry")

local ok, err = supplies.prepare() -- GPS/smer a návšteva palivovej stanice s návratom
if not ok then error(err, 0) end

telemetry.capture(function()
    local ready, reason = supplies.ensure({
        moves = 20, -- horný limit počtu presunov v nasledujúcej časti práce
        freeSlots = 2,
        materials = { ["minecraft:stone"] = 10 },
        -- endpoint = { x = 100, y = 64, z = 20 }, -- voliteľný koniec tejto časti
    })
    if not ready then error(reason, 0) end

    local options, optionsErr = supplies.navigationOptions()
    if not options then error(optionsErr, 0) end
    local moved, moveErr = nav.step("front", options)
    if not moved then error(moveErr, 0) end
    print("Pracovna cast dokoncena")

    local home, homeErr = nav.goHome(options)
    if not home then error(homeErr, 0) end
end)
```

Kontroluj zásoby pred každou obmedzenou časťou práce. `moves` musí zahŕňať všetky
plánované presuny danej časti. Bez známej trasy z jej konca sa návrat konzervatívne
odhaduje ako aktuálny návrat plus počet pracovných presunov. `ensure` berie do úvahy
aj servisnú cestu; pri neznámej trase je jej dĺžka odhad, pričom pohybová kontrola
paliva zostáva aktívna na každom kroku.

**Pohyb a otáčanie rob cez navigáciu.** Priame `turtle.forward/up/turnRight` mimo
knižnice obíde sledovanie stavu; GPS navyše nevie zistiť otočenie na mieste.
`position.lua` je vnútorná vrstva, jej priame pohyby obídu rezervu paliva.

## Navigácia a obmedzenia

Mapa sa tvorí v pamäti počas jednej relácie. Po reštarte sa musí znova overiť
palivová stanica cez `supplies.prepare()`. Nie je považovaná za dostupnú len preto,
že jej súradnice boli uložené v setup. Pri nedostatku počiatočného paliva môže
overenie skončiť pred dosiahnutím truhly; treba doplniť palivo ručne v inventári.

Poloha sa mení iba po úspešnom pohybe. GPS sa overí pred cestou, periodicky počas
nej a na konci. Strata GPS zastaví pohyb. Rozdiel medzi GPS a počítanou polohou
zruší inicializáciu aj mapu a vyžaduje opätovné zistenie polohy/smeru.

A* plánuje v troch osiach. Neznáme bunky sú potenciálne priechodné; po objavení
prekážky sa plán prepočíta. Povolená je aj dočasná cesta od cieľa a návrat zo slepej
vetvy. Hranice okolo začiatku a cieľa sa počas cesty nerozširujú. Predvolené limity:
12 blokov obchádzky v každej osi, 6000 rozvinutých uzlov na hľadanie,
512 úspešných presunov na cestu, 128 preplánovaní a 2 opakovania pri dočasnom zablokovaní.
Tieto hodnoty upravíš v `data/settings.txt`, v časti `navigation`.

Navigácia nekopá ani neútočí. Nezaručuje najkratšiu cestu v neznámom svete;
hľadá najkratšiu podľa dostupnej mapy. Aj pri existujúcej ceste môže nastavený
limit viesť k bezpečnému zastaveniu. Pri novej bežnej ceste sa staré informácie
o prekážkach zabudnú, aby sa dali nájsť medzitým odstránené bloky.

Pred každým krokom musí zostať palivo na krok, známu cestu k bezpečnému bodu
a rezervu. Predvoleným bezpečným bodom je nastavená palivová stanica; keď nie je
nastavená, je ním začiatok danej cesty. Ak cesta k nastavenej palivovej stanici
nie je známa, bežný pohyb ju neodhadne ako bezpečnú a skončí `return_route_unknown`.
Explicitná voľba `anchor` slúži na overovacie/diagnostické výpravy zo známeho miesta.
`knownOnly=true` vynúti pohyb len po známych priechodných miestach.

`moveToCoord` pri limite alebo nedostatku paliva **zastane na aktuálnej polohe**,
vráti dôvod a tretí výsledok `{position=..., moved=...}`. Hlavný program rozhodne
o návrate či zásobovaní. Známa cesta môže byť medzitým zablokovaná hráčom alebo
inou turtle; v meniacej sa mape sa fyzická dostupnosť návratu nedá zaručiť.

V `data/settings.txt` môžeš nastaviť `fuelSlots = {16}` na obmedzenie automatického
spaľovania na vybrané sloty; prázdna tabuľka povoľuje všetky. Napríklad
`protectedItems = {["minecraft:coal"] = true}` chráni materiál v inventári pred
automatickým spaľovaním pri navigácii a vykladaním. Explicitné `fuel.refuel()` bez
filtra spotrebúva všetko dostupné palivo; na rešpektovanie nastavení použi
`fuel.refuel(target, fuel.slots(config.load()))`.

## Telemetria, monitor a tablet

Počítač s monitorom alebo CC pocket computer/tablet s modemom:

```text
update receiver
reboot
receiver
```

`receiver 12` zobrazí iba turtle s ID 12. Bez ID zobrazuje viac zariadení,
podľa miesta na obrazovke. Podporuje najviac 32 záznamov. Použije prvý dostupný
monitor alebo vlastný terminál. Tablet iného modu musí podporovať CC programy
a modem/rednet; univerzálne zobrazenie na ľubovoľnom tablete nie je súčasťou.

Palivo a voľné sloty sú na samostatných riadkoch, pred stavom a súradnicami.
Dlhší stav, súradnice a správy sa zalamujú podľa šírky obrazovky.
Externý monitor používa mierku písma 0.5; pocket computer mierku písma meniť nevie.
Pri kopaní navyše zobrazuje `Hotove: dokončené/celkom`, `Zostava` a `Rozbite bloky`.
Pri podlahe zobrazuje hotové/zostávajúce miesta, `Polozene` a `Existujuce` bloky.
Hotové miesta zahŕňajú aj prázdne bunky a vstupný tunel v oblasti; každá bunka sa
počíta iba raz. Rozbité bloky počítajú skutočné kopanie vrátane padajúceho piesku
a štrku, preto sa môžu líšiť od počtu hotových miest. Údaje zostávajú v každej
správe aj počas presunu k truhlám. Pre tieto počítadlá aktualizuj turtle aj prijímač.

Router/opakovač s pripojeným modemom:

```text
update router
reboot
router
```

`router` používa vstavaný CC program `repeat`. Počítače musia byť v dosahu siete
a načítané v hre. Existujúci router musí opakovať správy rednet, aby tento
protokol prenášal. Vlastný modemový protokol iného routera si vyžiada adaptér.

Predvolený protokol je `craftoria.turtle.v1`. V setup zvoľ broadcast pre súčasné
sledovanie na monitore aj tablete. Voľba konkrétneho ID pošle dáta iba tomuto
prijímaču. Iný protokol použiješ na prijímači ako `receiver 12 vlastny.protokol`.

Odosiela sa poloha/smer, palivo, inventár, činnosť a hlásenie. Bežné kroky sú
obmedzené intervalom 2 sekundy; dôležité zmeny a chyby sa odosielajú okamžite.
`telemetry.capture(fn)` navyše odosiela `print` počas behu danej funkcie.
Po skončení alebo chybe obnoví pôvodný `print`. Samostatný idle heartbeat nie je
spustený; prijímač ukazuje vek poslednej správy, nie potvrdenie aktuálnej dostupnosti.
Výpadok odosielania neblokuje činnosť turtle. Odoslanie nepotvrdzuje doručenie.

## Aktualizácia a vývojové testy

`manifest.json` je zoznam súborov a rolí. Novú knižnicu pridaj sem; updater ju
automaticky zaradí. Sťahuje jednu konkrétnu verziu podľa SHA získaného z GitHub API,
skontroluje syntax všetkých Lua súborov a až potom nahradí aktuálne súbory.
API aj raw GitHub musia byť dostupné cez herné HTTP; API má limity požiadaviek.

Záloha ostáva v `data/update-backup/`. Journal umožňuje obnovu po prerušení počas
inštalácie pri ďalšom spustení updatera. Chyba sťahovania nemení existujúci kód.
Konfigurácia a origin nie sú súčasťou aktualizácie. Aktualizáciu rob pri zastavených
pracovných programoch a potom reštartuj počítač, aby sa nepoužili staré moduly v pamäti.

Lokálne regresné testy v `tests/turtle_spec.lua` simulujú GPS, pohyb, inventár,
truhly, sieť a súborový systém. Potrebujú Python a balík `lupa`:

```text
python -m pip install lupa
python tests/run_turtle.py
```

Testy dopĺňajú hernú diagnostiku. Skutočný modem, modové truhly, GPS sieť a fyzické
prekážky treba overiť v Craftorii. Referencie API:
[turtle](https://tweaked.cc/module/turtle.html),
[GPS](https://tweaked.cc/module/gps.html),
[rednet](https://tweaked.cc/module/rednet.html),
[monitor](https://tweaked.cc/peripheral/monitor.html).
