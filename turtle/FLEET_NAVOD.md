# Hlavný PC, spoločné úlohy a servisný tunel

Táto verzia riadi viac turtle pri **kopaní** aj **stavaní rovnej podlahy**.
Postup na podlahu a význam jej súradníc opisuje [PODLAHA_NAVOD.md](PODLAHA_NAVOD.md).
Každá vybraná turtle dostane vlastný neprekrývajúci sa kváder a vracia sa do
vlastného doku. Rozdelenie prebieha pozdĺž dlhšej vodorovnej osi X alebo Z.

Najprv nahraj nové súbory do `main` na GitHube. `wget` a `update` sťahujú z GitHubu,
nie z lokálneho priečinka na tomto počítači. Updater rozlišuje roly `controller`,
`turtle`, `receiver`, `router` a pre každú stiahne aj potrebné knižnice.

## Čo postaviť

- Jeden CC:Tweaked PC s bezdrôtovým modemom na voľnej strane.
- Jeden veľký monitor z **12 blokov: 4 na šírku × 3 na výšku**. Použi rovnaký typ
  monitorov a otoč všetky obrazovkou rovnakým smerom, aby vytvorili jednu plochu.
  Môžeš použiť Advanced Monitor. Program nastavuje textovú mierku 0.5.
- PC musí priamo susediť aspoň s jedným blokom tejto plochy, napríklad zozadu
  alebo pri okraji. Na prvú skúšku pripoj iba tento jeden monitor. Väčší panel
  zobrazí viac riadkov; malý panel stále funguje, ale tabuľka sa môže nezmestiť.
- Dve alebo viac mining turtle s krompáčom a bezdrôtovým modemom.
- Pocket computer s bezdrôtovým modemom na sledovanie výsledkov.
- Fungujúce GPS v dosahu dokov, truhiel, celého tunela aj pracovnej oblasti.

Ender modemy odporúčam, ak ich máš dostupné. Pre spojenie na ľubovoľnú vzdialenosť
použi Ender Modem na oboch koncoch spojenia, vrátane GPS hostov. Pri bežných
modemoch musíš zabezpečiť pokrytie. `router` opakuje rednet správy; nenahrádza
GPS hosty ani GPS pokrytie. Všetky súradnice v tomto systéme patria do jednej dimenzie.

GPS vyžaduje aspoň štyri hosty rozmiestnené tak, aby neboli v jednej rovine.
Na každom hoste spusti `gps host X Y Z` s jeho vlastnými presnými súradnicami.
Ak existujúce GPS už funguje, použi ho. Oficiálny postup:
https://tweaked.cc/guide/gps_setup.html

## Doky a truhly

Dok je voľné miesto, na ktorom turtle stojí pri prvom spustení `worker`.
Každá má vlastný dok. Nedávaj dok priamo na miesto obsluhy spoločnej truhly,
do servisného tunela ani pred jeho otvor. Turtle sa tam po úlohe vráti a bude
čakať na ďalšie zadanie.

Praktické rozloženie: hlavná chodba od tunela k truhlám, doky ako bočné odbočky.
Turtle čakajúce v dokoch musia nechať chodbu voľnú. Zabezpeč priestor aj pred
truhlami a pred vstupmi do tunela.

Turtle v doku otoč smerom do voľnej chodby. Pri odchode najprv prejde **jeden blok
dopredu** v uloženom smere doku a až potom odbočí. Pred každým dokom preto nechaj
voľnú bunku; smer sa berie z pôvodného párovania pracovníka.

PC odošle zadania všetkým vybraným turtle naraz. Začínajú v poradí výberu
s rozostupom **5 sekúnd**, bez čakania na dokončenie kontroly truhiel alebo vstup
predchádzajúcej turtle do tunela. Pri štartovej príprave idú medzi potrebnými
truhlami priamo a od poslednej pokračujú k práci. Dopĺňanie počas práce sa naďalej
vracia na pracovné miesto.

Rezervuje sa iba konkrétne obslužné miesto pri truhle. Pri rôznych truhlách môžu
pracovať súčasne; pri tej istej sa vystriedajú. Pred rezerváciou ďalšej truhly
turtle opustí predchádzajúce miesto, aby si navzájom neblokovali odchod.

Truhly môžu byť pri hlavnom PC. Pre palivo, vykladanie a materiál vyberáš
samostatné stanice. Pri novej úlohe môžeš jednotlivé stanice nahradiť dočasnými
truhlami pri pracovisku. Ich súradnice zadáš iba na hlavnom PC.

**Stanica = miesto, kde stojí turtle**, nie blok truhly. Pridávaš aj smer turtle
a polohu truhly `front`, `up` alebo `down`. Smery:
`0 = sever (-Z), 1 = východ (+X), 2 = juh (+Z), 3 = západ (-X)`.

## Tunel 3×3

Postav súvislú prázdnu šachtu s vnútorným prierezom **3×3**. Zapíš X a Z jej
stredného bloku. V celej časti 3×3 nesmú byť podlahy, rebríky, káble ani iné prekážky.
Turtle lieta vlastným pohonom; na presun nepotrebuje schody ani rebrík.

Na každom používanom poschodí priprav vodorovný priechod od stredu šachty von.
Uložíš jeden bod výstupu mimo šachty. Bod musí mať rovnaké X **alebo** Z ako
stred a byť vzdialený aspoň dva bloky od stredu. Celý rovný priechod musí byť
voľný. Výška Y označuje bunku, v ktorej stojí turtle, teda priestor nad podlahou.

Príklad s vymyslenými súradnicami:

```text
stred tunela:      X=100, Z=200
výstup základňa:   X=102, Y=64, Z=200
výstup poschodie:  X=102, Y=70, Z=200
```

Turtle ide: dok → výstup na základni → pridelený pruh nahor → výstup na pracovnom
poschodí → pridelený výkop. Návrat používa samostatný pruh nadol a uložené výstupy.
Poschodia majú jedinečné Y; pri zadaní práce zvolíš jej pracovné
poschodie. Pozície miestnych truhiel patria k tomuto poschodiu. Pri ostatných
pozíciách sa poschodie určuje podľa najbližšej uloženej výšky.

Šachta používa **dva pruhy nahor a jeden nadol**. V rôznych pruhoch je možný
súbežný prejazd. Na konkrétnom poschodí sa strieda iba krátky priechod cez spoločný
výstup; každé obslužné miesto pri truhle má vlastnú rezerváciu. Žiadny pruh sa neuvoľní
iba podľa časovača, ak v ňom mohla zostať neodpovedajúca turtle.

Kopaná oblasť nesmie obsahovať žiadny dok, truhlu, obslužné miesto, uložený
výstup, jeho rovný priechod ku stredu ani vnútro servisnej šachty.
Zlé zadanie sa odmietne pred odoslaním úloh.

## Hlavný PC

Všetky príkazy píš do terminálu CC počítača v hre.

```text
wget https://raw.githubusercontent.com/Ballberid/MC-programy/refs/heads/main/turtle/turtle_update.lua update.lua
update controller
reboot
id
fleet_setup
```

Zapíš si ID počítača, napríklad **12**. V `fleet_setup`:

1. Voľbou **1** pridaj pomenované truhly, napríklad `Uhlie`, `Vystup`, `Material`.
2. Voľbou **2** priraď predvolené truhly: `fuel` = palivo, `output` = vykladanie,
   `materials` = stavebný materiál. Materiál môžeš vynechať pomocou `-`.
3. Voľbou **3** nastav stred tunela (X/Z).
4. Voľbou **5 – poschodia** pridaj základňu aj pracovné poschodie.
5. Voľbou **4** ulož nastavenia.

Keď neskôr pridávaš alebo upravuješ poschodia, choď priamo do voľby **5**;
súradnice tunela sa nepýtajú znova. Menu poschodí umožňuje **1 pridať**, **2
premenovať**, **3 zmeniť výstup**, **4 odstrániť** a **0 späť**. Poschodie vyberáš
číslom alebo názvom. Pri zmene výstupu Enter zachová aktuálnu súradnicu X/Y/Z.
Výstupy stále musia byť v osi tunela a rôzne poschodia musia mať rôzne Y.
Posledné poschodie zostáva zachované; celý tunel môžeš vypnúť vo voľbe 3.
Po úpravách sa vráť do hlavného menu a ulož voľbou **4**. Zmeny platia pre
nasledujúce úlohy; prebiehajúce úlohy používajú svoje pôvodné zadanie.

Potom spusti:

```text
fleet
```

Monitor zobrazuje celkový priebeh aj tabuľku turtle; dialógy ostávajú v termináli PC.
Hlavné menu:

| Voľba | Význam |
|---|---|
| 1 | Nový výkop: počet/ID turtle, rohy, truhly a poschodie |
| 2 | Celkový priebeh a stav všetkých turtle v termináli |
| 3 | Pozastavenie konkrétnej turtle alebo všetkých |
| 4 | Pokračovanie pauzy alebo obnovenie pôvodného segmentu po chybe (`failed`/`recovery`) |
| 5 | Zastavenie úlohy a pokus o návrat do doku; aj návrat zo stavu `recovery` |
| 6 | Nastavenia základne; zmeny platia pre nasledujúce úlohy |
| 7 | Ručné uvoľnenie servisnej aj tunelovej rezervácie po fyzickej kontrole |
| 8 | Ukončenie hlavného programu |
| 9 | Nová podlaha: počet/ID turtle, dva rohy s rovnakým Y, materiál, truhly a poschodie |
| 10 | Reset zastavenej turtle v doku do `idle`; ID 0 = všetky |

Pri ovládaní `ID=0` znamená všetky turtle. Pozastavenie sa vykoná pri najbližšej
kontrole pohybu/kopania/stavania; rozbehnutá obsluha truhly sa môže najprv dokončiť.
Pri priebežnom tankovaní každá turtle počíta zásobu na celý zostávajúci vlastný
segment, servisné presuny vrátane tunela a rezervy, s dvojnásobným odhadom.
Cieľ obmedzuje kapacita nádrže a dostupné palivo v truhle. Ak má stále dosť
paliva na pokračovanie a bezpečný návrat, nezačne tankovať iba kvôli tomuto odhadu.

Servis pri truhlách a prejazd tunelom majú samostatné rezervácie. Pri odchode
z poschodia s truhlami na pracovné poschodie turtle uvoľní servis po dosiahnutí
jej zvislého pruhu. Ďalšia tak môže overovať truhly či tankovať ešte predtým, ako prvá
začne pracovať. V 3×3 sú dva pruhy nahor (X stredu −1, Z stredu −1 alebo +1 podľa
poradia priradenia) a jeden nadol (X stredu +1, Z stredu). V rôznych pruhoch môžu ísť súčasne;
v rovnakom pruhu sa striedajú. Krátke vodorovné vstupy a výstupy na každom poschodí
majú vlastnú rezerváciu. Pred výstupom sa čaká o jednu úroveň vyššie/nižšie,
aby čakanie neblokovalo križovatku. Celá vyhradená časť 3×3 musí byť priechodná;
nové súradnice ani nastavenie pruhov netreba zadávať.
Doky umiestni mimo stredu tunela a priechodov k jeho výstupom, aby zaparkovaná
turtle nezablokovala návrat ostatných.
Na rovnakom poschodí a pri servisných návštevách sa spoločné cesty stále striedajú.
Prehľad na PC a tablete ukazuje osobitne držiteľa servisu a zoznam turtle v tuneli.
Obsadená rezervácia pri odpovedajúcom hlavnom PC už nevyprší po piatich minútach.
Bez odpovede PC približne päť minút sa ohlási `controller_unreachable`; po oprave
spojenia použi voľbu 4. Žiadna rezervácia offline turtle sa neodoberá automaticky.
Na bežnej ceste sa na inú turtle čaká päť sekúnd a potom sa hľadá obchádzka.
Na presnej parkovacej pozícii truhly aj v pruhu tunela sa čaká na uvoľnenie;
pozastavenie a stop zostávajú funkčné. Dočasná turtle sa neukladá ako pevná stena.

Pred použitím tejto verzie aktualizuj hlavný PC aj všetky turtle mimo bežiacej
úlohy. Staré a nové verzie pracovníkov nekombinuj: stará verzia nepoužíva tieto pruhy.
Pre nové zobrazenie tunela aktualizuj aj zobrazovací PC alebo tablet.

Pozastavená turtle môže držať servisnú alebo tunelovú rezerváciu. Počas práce nechaj `fleet`
bežať, lebo udeľuje povolenia na spoločné presuny. Ovládanie používa potvrdzované
správy; bez spojenia nemožno predpokladať, že príkaz už dorazil.

## Každá turtle

Najprv ju polož do jej vlastného doku a doplň palivo na počiatočné overenie ciest.
Pre prvú blízku skúšku daj niekoľko stoviek jednotiek paliva. Potom:

```text
wget https://raw.githubusercontent.com/Ballberid/MC-programy/refs/heads/main/turtle/turtle_update.lua update.lua
update turtle
reboot
worker 12
```

Číslo `12` nahraď ID hlavného PC. `worker` automaticky zisťuje smer krátkym
skúšobným pohybom. Ak chceš smer zadať ručne, napríklad sever:

```text
worker 12 0
```

Ručný smer musí zodpovedať skutočnej orientácii turtle. Zvlášť `setup` pre flotilu
nie je potrebný: stanice dostane od hlavného PC a dok uloží pri prvom spustení.
Existujúce lokálne nastavenia sa počas úlohy dočasne nahradia a potom obnovia.
Pripravená turtle bude čakať; spustenie výkopu zadávaš na hlavnom PC.

Dok a párovanie sa ukladajú do `data/worker-state.txt`. Po reštarte na inom mieste
sa dok automaticky nepresunie. `worker` bez argumentov použije uložené ID PC.
Neprenášaj súbory `data/worker-state.txt` medzi turtle.

## Tablet

```text
wget https://raw.githubusercontent.com/Ballberid/MC-programy/refs/heads/main/turtle/turtle_update.lua update.lua
update receiver
reboot
receiver fleet 12
```

Číslo nahraď ID hlavného PC. Zobrazuje súhrn z hlavného PC, preto musí byť hlavný
PC v dosahu spojenia. **Šípky doľava/doprava** alebo **Tab** prepínajú prehľad
a jednotlivé turtle. **0** vráti celkový prehľad. Detail ukazuje palivo, voľné
sloty, hotové/zostávajúce miesta, rozbité bloky, stav a súradnice.

Pôvodné `receiver` a `receiver ID_TURTLE` zostávajú dostupné pre samostatné turtle.

## Prvá skúška

1. Postav základňu a jeden pracovný výstup z tunela.
2. Spusti `fleet` na PC a `worker ID_PC` na **dvoch** turtle v oddelených dokoch.
3. V menu PC cez voľbu 2 over, že obe sú `idle` a pravidelne odpovedajú.
4. Vyber malý skúšobný výkop, napríklad **6×2×4** na pracovnom poschodí,
   s voľným prístupom k prvému rohu každého segmentu. Do oblasti nezahrň podlahu,
   ktorú chceš zachovať, ani časti servisnej infraštruktúry.
5. Voľbou 1 zadaj oba rohy, počet 2, palivovú a vykladaciu truhlu a poschodie.
6. Sleduj, či turtle prechádzajú uloženými výstupmi, vykladajú a vracajú sa do
   svojich dokov. Na tablete prepni detail oboch turtle.

Rohy sú **vrátane koncových blokov**. Očakávaný počet je
`(|X2-X1|+1) × (|Y2-Y1|+1) × (|Z2-Z1|+1)`.

## Výpadok alebo reštart

Úlohy majú jedinečné ID a opakované doručenie nespustí ten istý segment druhýkrát.
PC pravidelne opakuje nepotvrdené zadania a uchováva stav úloh aj rezervácií.
Priebežné počítadlá sa ukladajú približne každé dve sekundy; posledné okamihy
pred výpadkom nemusia byť zaznamenané. Nejde o záznam každého pohybu na obnovu výkopu.
Po prerušení worker prejde do `recovery`: výkop sa **automaticky neobnoví**.
Na PC voľbou 5 pošli tejto turtle návrat do doku. Ak návrat zlyhá, najprv
skontroluj GPS, palivo a priechodnosť; problém sa zobrazí pri danej turtle.
Po odstránení prekážky môžeš namiesto návratu zvoliť **4** a ID konkrétnej turtle.
Pôvodná úloha aj pridelený segment sa zachovajú, ostatné turtle môžu ďalej pracovať.
Pri výkope sa prejde už vykopaná časť od vstupu a potom dokončí zvyšok.
Hotové bunky sa nezapočítajú druhýkrát. Bez uloženého kontrolného bodu sa segment
overí celý. Pri inej turtle v kopanej bunke sa čaká (`waiting_turtle`), bez kopania
do nej; pauza aj stop zostávajú funkčné. Voda a láva úlohu zastavia, po odstránení
môžeš použiť voľbu 4. Dáta pracovníka ani hlavného PC pri obnovení nemaž.

Neodpovedajúcej turtle sa segment ani rezervácia automaticky neodoberú. Mohla
zostať v tuneli alebo pred truhlou. Rezerváciu ručne uvoľni voľbou 7 až po
kontrole, že priechod je voľný a pôvodná turtle už nepokračuje v presune.
Na uvoľnenie program vyžaduje text `VOLNE`.
Po návrate všetkých turtle môžeš použiť **10 → 0**, aby boli `idle` a zabudli
pridelenú úlohu. Reset zachová dok, párovanie, truhly, poschodia a tunel.
Rozbehnutá turtle alebo turtle mimo doku reset odmietne; najprv použi návrat 5.
Reset nie je potrebný na nové zadanie: stavy `complete` a `failed` tiež prijímajú
novú úlohu, keď sú predchádzajúce segmenty ukončené a rezervácie uvoľnené.

Po reštarte sa práca neobnoví sama; pokračovanie vyžiadaj voľbou 4. Nejde o
presné pokračovanie posledného fyzického kroku: uložený stav môže byť mierne starší
a prejdená časť výkopu sa overí znova. Pri podlahe sa znova skontroluje segment,
už položené správne bloky sa preskočia.
Po neúspešnej úlohe neoznačujeme zvyšok za vykopaný. Menšie ďalšie zadanie môžeš
zamerať na zostávajúcu časť. Pri vzdialenej práci musia byť potrebné chunky načítané.

## Rozdelenie kódu a overenie

`fleet.lua` je hlavný program, `fleet_setup.lua` nastavuje základňu a `worker.lua`
beží na turtle. Knižnice `fleet_controller`, `fleet_client`, `fleet_model`,
`fleet_settings`, `fleet_task`, `fleet_motion`, `transit`, `fleet_store`,
`fleet_dialog`, `fleet_display` rozdeľujú plánovanie, komunikáciu, dopravu,
nastavenia a zobrazenie. Programy `quarry` a `floor` zostávajú samostatne použiteľné.
Stavanie používa knižnice `building` a `floor_plan`; truhla `materials` je povinná.

Automatické testy kontrolujú pôvodné kopanie, delenie segmentov, duplicitné
zadania, návrat cez tunel, ochranu infraštruktúry, rezervácie po reštarte a
prepínanie tabletu, dopĺňanie materiálu a overenie položených blokov. Rádiová
simulácia overuje súbežnú prácu dvoch skutočných programov `worker` proti jednému
riadiacemu programu pri výkope aj podlahe. Minecraft server treba overiť v hre.
