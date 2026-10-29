# Hlavný PC, spoločné úlohy a servisný tunel

Táto verzia riadi viac turtle pri **kopaní**, **stavaní rovnej podlahy** aj **stropu**.
Postup na podlahu a význam jej súradníc opisuje [PODLAHA_NAVOD.md](PODLAHA_NAVOD.md).
Strop spustíš voľbou **3**; postup opisuje [STROP_NAVOD.md](STROP_NAVOD.md).
Steny miestnosti spustíš voľbou **4**; postup opisuje [STENY_NAVOD.md](STENY_NAVOD.md).
Pri podlahe turtle kladie iba pod seba, pri strope iba nad seba. Pri druhom
rohu zadávaš len X a Z, výška sa preberie z prvého a vrstva má jeden blok.
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

PC odošle zadania všetkým vybraným turtle naraz. Začínajú v poradí výberu:
každá ešte v doku čaká na rezerváciu prvej kontrolovanej truhly (**fuel**).
Ďalšia vyrazí až keď predchádzajúca dokončí celú úvodnú kontrolu truhiel,
natankuje podľa potreby, naloží materiál a fyzicky opustí posledné obslužné miesto.
Pevnú päťsekundovú pauzu nepoužívajú. Po potvrdení dokončenia môže byť
odchod oneskorený najviac bežným dvojsekundovým opakovaním požiadavky.
Na vstup predchádzajúcej turtle do tunela sa nečaká. Toto pravidlo je spoločné
pre kopanie, podlahu, strop aj steny; samotná práca zostáva súbežná.
Pri štartovej príprave idú medzi potrebnými
truhlami priamo a od poslednej pokračujú k práci. Dopĺňanie počas práce sa naďalej
vracia na pracovné miesto.

Pri zadávaní úlohy PC vypíše názov vybraného poschodia a súradnice výstupu.
Ak zadanie odmietne ešte pred odoslaním, zobrazí `Nespustene: ...` a počká na
Enter, aby dôvod neprekrylo menu. Posledné odmietnutie, rohy a vybraný výstup
uloží do `data/fleet-last-start-error.txt`; na PC ho otvoríš cez
`edit data/fleet-last-start-error.txt`. Odmietnuté zadanie nemení stav turtle.

Rezervuje sa iba konkrétne obslužné miesto pri truhle. Pri rôznych truhlách môžu
pracovať súčasne; pri tej istej sa vystriedajú. Pred rezerváciou ďalšej truhly
turtle opustí predchádzajúce miesto, aby si navzájom neblokovali odchod.
Miesto čakania sa určuje automaticky podľa výberu truhly:

- **Preddefinovaná truhla**: Turtle sa počas práce najprv vráti do vlastného
  doku, uvoľní tunel a tam čaká na rezerváciu truhly. Až potom vyrazí k nej.
- **Dočasná truhla**: pracovná truhla na tom istom poschodí. Turtle čaká na rezerváciu
  na svojej aktuálnej pozícii a potom ide k truhle. Nevracia sa kvôli tomu do doku.

Stačí odpoveď na **Dočasná truhla iba pre túto úlohu?**; ďalšia otázka na
miesto čakania sa nepýta. Úvodná kontrola ide medzi truhlami priamo,
bez návratu do doku medzi jednotlivými návštevami. Staré uložené úlohy bez
tejto voľby zachovajú pôvodné správanie; nové čakanie platí pre nové zadania.

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

Turtle ide: dok → výstup na základni → pridelený pruh → výstup na pracovnom
poschodí → pridelený výkop. Návrat používa rovnaký systém prideľovania pruhov.
Poschodia majú jedinečné Y; pri zadaní práce zvolíš jej pracovné
poschodie. Pozície miestnych truhiel patria k tomuto poschodiu. Pri ostatných
pozíciách sa poschodie určuje podľa najbližšej uloženej výšky.

Nový režim zapneš v `fleet_setup` voľbou **5 – pruhy a vystupy 3x3** a uložíš
voľbou **0**. Pred zapnutím rozšír všetky priechody. Uložený bod výstupu je
v tomto režime **stred otvoru 3×3**, nie jeho spodný riadok. Nechaj voľné tri
výšky `Y−1`, `Y`, `Y+1` a šírku tri bloky po celej priamej chodbe od šachty.
Aj priestor jeden blok za vonkajšou stranou otvoru musí byť voľný v rozmere 3×3.
Pri strede výstupu Y=63 preto otvor zaberá výšky **62, 63, 64**. Stredy poschodí
musia byť vzdialené aspoň päť výškových blokov; Y=68, 63 a 37 vyhovujú.

PC prideľuje **všetkých deväť zvislých pruhov**, pre oba smery. Turtle požiada
pred vstupom, dostane voľný pruh a po fyzickom opustení výstupu ho uvoľní.
Ku každému pruhu patrí jedno z deviatich políčok otvoru. Spodný riadok patrí
trom pruhom najbližším k danému otvoru, stredný stredným a horný najvzdialenejším.
Pri výstupe v osi X určuje poloha v Z vodorovné políčko; pri výstupe v osi Z
je vodorovné políčko podľa X. Mapovanie sa prispôsobuje strane šachty.
Ak políčko blokuje iná turtle, počká na jej odchod.

Zvislý presun môže prebiehať súčasne vo všetkých pruhoch. Krátke vodorovné
prechody na jednom poschodí sa striedajú, pretože ich trasy križujú zvislé pruhy.
Čakanie v šachte prebieha mimo troch výšok otvoru, aby turtle neblokovala výstup
susedného pruhu. Žiadny pruh sa neuvoľní iba podľa časovača, ak v ňom mohla
zostať neodpovedajúca turtle; po chybe zostáva rezervovaný pre bezpečnú obnovu.

Opakovaný pokus používa tú istú rezerváciu vstupu aj pruhu; nenásobí jej
počítadlo. Po chybe a pred obnovou turtle overí GPS a uvoľní svoje rezervácie
priechodov, mimo ktorých už stojí. Ak zostala v šachte alebo vo výstupe, potrebné
rezervácie zachová. Pri nedostupnom GPS ich neuvoľňuje naslepo.

Bez zapnutia voľby 5 zostáva pôvodný režim **dva pruhy nahor a jeden nadol**
s jednoblokovým výstupom. Zmena nastavení platí pre nové úlohy.

Kopaná oblasť nesmie obsahovať žiadny dok, truhlu, obslužné miesto, uložený
výstup, jeho rovný priechod ku stredu ani vnútro servisnej šachty.
Zlé zadanie sa odmietne pred odoslaním úloh.

## Hlavný PC

### Pomenované pracovné zóny

V hlavnom menu `fleet` otvor **13 – pracovné zóny**. Môžeš pridať pôdorys,
zmeniť jeho rohy, premenovať ho alebo odstrániť. Zadávaš iba **X/Z dvoch
protiľahlých rohov**, vrátane krajných blokov. Po návrate do hlavného menu sa
zmeny automaticky uložia do `data/fleet-settings.txt`. Rovnaká správa je aj
v `fleet_setup` voľbou **6**; tam nastavenia uložíš voľbou **0**.

Pri novej úlohe vyberieš preddefinovanú zónu alebo zadáš nový pôdorys iba pre
túto úlohu. Nový pôdorys sa automaticky neukladá medzi pomenované zóny.
Výšku vyberáš vždy nanovo:

- **Výkop:** začiatok a koniec Y, vrátane oboch výšok; poradie môže byť opačné.
- **Podlaha / strop:** iba Y vrstvy ukladaných blokov.
- **Steny:** začiatok a koniec Y bočných stien. Pri voľbe **bez rohov** je zóna
  vnútorný priestor; steny budú o jeden blok za každou hranicou X/Z. Pri voľbe
  **s rohmi** pôdorys určuje priamo bloky stien a treba vonkajší prístup.

Príklad: vnútorná zóna X=7489–7550, Z=−2559 až −2498 dá pri stenách bez rohov
vonkajší kváder X=7488–7551, Z=−2560 až −2497. Výška Y sa nerozširuje.
Zóna sa tým nemení a môžeš ju použiť na výkop alebo podlahu na inom poschodí.
Odoslané úlohy obsahujú vlastnú kópiu súradníc; neskoršia úprava či odstránenie
zóny nemení rozbehnutú prácu. Existujúce uložené úlohy stien sa nerozširujú znova.

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
4. Voľbou **4 – poschodia** pridaj základňu aj pracovné poschodie.
5. Po príprave širokých otvorov voľbou **5** zapni deväť pruhov a výstupy 3×3.
6. Voľbou **0** ulož nastavenia.

Keď neskôr pridávaš alebo upravuješ poschodia, choď priamo do voľby **4**;
súradnice tunela sa nepýtajú znova. Menu poschodí umožňuje **1 pridať**, **2
premenovať**, **3 zmeniť výstup**, **4 odstrániť** a **0 späť**. Poschodie vyberáš
číslom alebo názvom. Pri zmene výstupu Enter zachová aktuálnu súradnicu X/Y/Z.
Výstupy stále musia byť v osi tunela a rôzne poschodia musia mať rôzne Y.
Posledné poschodie zostáva zachované; celý tunel môžeš vypnúť vo voľbe 3.
Po úpravách sa vráť do hlavného menu a ulož voľbou **0**. Zmeny platia pre
nasledujúce úlohy; prebiehajúce úlohy používajú svoje pôvodné zadanie.

Potom spusti:

```text
fleet
```

Monitor zobrazuje celkový priebeh aj tabuľku turtle; dialógy ostávajú v termináli PC.
Hlavné menu:

| Voľba | Význam |
|---|---|
| 1 | Nový výkop: počet/ID turtle, uložená alebo nová zóna, rozsah Y, truhly a poschodie |
| 2 | Nová podlaha: počet/ID turtle, zóna, Y vrstvy, materiál, truhly a poschodie |
| 3 | Nový strop: rovnaké zadanie ako podlaha, turtle kladie nad seba |
| 4 | Nové steny: zóna, rozsah Y, počet/ID turtle, materiál, truhly, poschodie a voliteľné rohy |
| 5 | Celkový priebeh a turtle zoskupené podľa druhu práce |
| 6 | Pozastavenie konkrétnej turtle alebo všetkých |
| 7 | Pokračovanie pauzy alebo obnovenie segmentu po chybe (`failed`/`recovery`) |
| 8 | Zastavenie úlohy a pokus o návrat do doku; aj zo stavu `recovery` |
| 9 | Reset zastavenej turtle v doku do `idle`; ID 0 = všetky |
| 10 | Nastavenia základne; zmeny platia pre nasledujúce úlohy |
| 11 | Ručné uvoľnenie rezervácií po fyzickej kontrole |
| 12 | Aktualizovať jednu turtle, pracovníkov jednej úlohy alebo všetky |
| 13 | Pridať, upraviť, premenovať alebo odstrániť pracovné zóny |
| 0 | Ukončenie hlavného programu |

### Aktualizácia turtle z hlavného PC

Túto funkciu najprv nainštaluj raz ručne: na PC `update controller`, na každej
turtle `update turtle` a reštartuj programy. Starý worker bez tejto funkcie hlási
`update_requires_manual_install`; nevie sám prijať nový príkaz.

Potom vo `fleet` vyber **12 – update turtle**. Rozsah je rovnaký ako pri ostatných
poveloch: **1** jedna turtle, **2** pracovníci vybranej úlohy, **3** všetky.
Pracujúce alebo pozastavené turtle ukončia aktuálnu činnosť a vrátia sa do svojich
dokov. Až po overení polohy spustia `update turtle` a reštartujú sa. Pri nedostatku
paliva, neprístupnom doku alebo neúspešnom sťahovaní sa zobrazí chyba aktualizácie.
PC ukazuje `Update: navrat`, `Aktualizuje`, `Restartuje` a po opätovnom pripojení
`Aktualizovane`. Potvrdenie prijatia príkazu ešte neznamená úspešné dokončenie.

Nastavenia a uložená úloha zostávajú zachované. Po návrate aktualizovaných
pracovníkov do siete môžeš použiť **7 – Pokračovať**. Idle turtle zostane idle.
Startup použije uložené ID hlavného PC; pri novej turtle zostáva predvolené ID 16.
Aktualizácia PC samotného zostáva ručná (`update controller`).

Pre nový režim tunela aktualizuj **hlavný PC aj všetky turtle**. Najprv ich
vráť do dokov, aktualizuj PC a cez voľbu 12 aktualizuj turtle. Po dokončení
priprav otvory 3×3, zapni voľbu 5 v nastaveniach a zadaj novú úlohu.
Nemaž uložené dáta ani párovanie.

Ak worker pri štarte alebo počas behu spadne, `startup.lua` počká **10 sekúnd**
a automaticky reštartuje turtle. Pri dočasne nedostupnom GPS sa pokus opakuje,
kým worker dokáže naštartovať. Uložená úloha a rezervácie zostávajú zachované;
rozpracovaná úloha môže po reštarte vyžadovať **7 – Pokračovať** alebo
**8 – Návrat**. Bežná chyba úlohy v stave `failed` sa rieši týmito povelmi,
nie opakovanými reštartmi.

Monitor aj terminál zoskupujú turtle pod **Stavanie**, **Kopanie** a
**Ostatné/pripravené**. Pri stavbe sa rozlišuje podlaha, strop a steny. Zaradenie
sa riadi pridelenou úlohou aj pri pauze alebo tankovaní. Každá skupina má vlastný
súčet hotových miest zo svojich zadaní; celkový ukazovateľ hore sčíta evidované úlohy.
Pri turtle sa zobrazuje aj číslo úlohy, napríklad `podlaha/2`. Voľba **5** vypíše
každú úlohu zvlášť s priebehom a stavom.
Pri dlhom zozname sa stránky striedajú každých päť sekúnd a opakujú názov skupiny.
Na tablete zostáva prepínanie na detail jednotlivej turtle šípkami.
Môže bežať **viac spoločných úloh súčasne**, každá s inými turtle, oblasťou,
materiálom, truhlami a pracovným poschodím. Po spustení výkopu môžeš hneď zvoliť
**2 – podlaha**, **3 – strop** alebo **4 – steny** a prideliť mu ďalšie voľné turtle.
Napríklad voľbou 1 pošli ID 41 a 42 kopať, potom voľbou 2 pošli ID 43 stavať.
Pri zadávaní sa ponúkajú iba dostupné turtle bez rozbehnutej úlohy, čakajúceho
povelu alebo držanej rezervácie. Rezervácia inej pracujúcej turtle nové zadanie
neblokuje; pracovníci sa pri spoločnej truhle či v rovnakom pruhu vystriedajú.

PC odošle celé zadanie. Každá turtle samostatne plánuje presuny, kope alebo
stavia, kontroluje palivo a zásoby a chodí k truhlám. Počas bežnej práce nečaká
na pokyn PC pre každý krok. PC eviduje úlohy, prijíma stav, posiela ovládacie
povely a prideľuje spoločné rezervácie. Pri výpadku PC môže turtle pokračovať
v rozrobenej práci, ale nové rezervácie truhiel a tunela vyžadujú spojenie s PC.
Rezervácie sa pri výpadku automaticky neuvoľňujú.

Pri stenách sa rozdelia stĺpce vonkajšieho obvodu; nevznikajú priečky medzi
segmentmi. Každá turtle spraví svoj úsek v celej zadanej výške. Spoločný priechod
zostáva otvorený počas práce aj zásobovania. Prechod cez neho sa krátko rezervuje,
stavanie na pracovisku pokračuje súčasne. Turtle určená na uzavretie čaká v doku,
kým ostatné úspešne dokončia úseky a vrátia sa; potom uzavrie posledný blok zvonka.
Pri chybe inej turtle sa čaká na jej obnovenie. Pri zrušení môže priechod zostať
otvorený. Pre viac turtle musí mať interiér aspoň 2×2 bloky na vyhýbanie, teda
zadaný kváder aspoň 4×4 v X/Z. Pred štartom sa vypíšu súradnice priechodu.
Ak výstup pracovného poschodia leží vo voľnom interiéri, použije sa uložený
tunel a ďalší priechod cez stenu nevzniká. Výstupy, koridory a šachta sa pri
stenách kontrolujú proti štyrom bočným plochám, nie proti celému objemu miestnosti;
stavba nesmie uzavrieť používanú servisnú trasu priamo v stene.

Nová oblasť nesmie kolidovať s iným rozpracovaným zadaním. Pri podlahe a strope
sa chráni aj susedná výška na pohyb turtle. Chránené sú doky, truhly, tunel a
jeho definované prístupy používané ostatnými úlohami. Chyba `job_area_conflict:N`
označuje kolíziu s úlohou N, `job_infrastructure_conflict:N` jej servisné miesta
alebo tunel. Pozastavená či neúspešná úloha si oblasť ponechá pre pokračovanie;
po návrate a resete sa jej rezervácia pracovnej oblasti uvoľní.

Každá úloha si uchová vlastný priebeh aj po reštarte PC. Oneskorené hlásenie zo
starého zadania neprepíše nové. Dokončené úlohy sa ponechajú, kým na ne niektorá
turtle ešte odkazuje; odložená história sa pri nových zadaniach priebežne čistí,
aby sa súbor stavu nezväčšoval bez obmedzenia.

Monitor sa aktualizuje najviac raz za sekundu a zapisuje iba zmenené riadky.
Stĺpec stavu rozlišuje `GPS`, `Caka truhla`, `Caka tunel`, `Caka vchod`,
`Ina turtle` a `Caka cesta`. Rezervácia sa získava pred príchodom k truhle alebo
do tunela, preto sa môže čakať aj na pohľad vo voľnom priestore. Pri uvoľnení
rezervácie ju čakajúca turtle opätovne skúša najneskôr v bežnom dvojsekundovom
intervale, ak funguje spojenie s PC.
Jednoblokový odchod od truhly a krátke kroky v tunelovej križovatke používajú
priebežné sledovanie polohy s intervalovým GPS. Dlhšie presuny a neúspešné
pohyby si zachovávajú vynútené GPS overenie.
Pracovníci posielajú bežný stav najviac raz za sekundu; zmeny stavu a reakcie na
povely sa odosielajú hneď. Nezmenený stav nečinného riadiča sa opakovane neukladá;
pracovný priebeh sa naďalej priebežne ukladá a rezervácie sa ukladajú okamžite.

Pri pauze, pokračovaní, návrate a resete najprv vyber rozsah: **1 – turtle**,
**2 – celá úloha**, **3 – všetky**. Pri celej úlohe vyber zadanie zo zoznamu;
ovládanie sa týka iba turtle, ktoré k nemu stále patria. Pri výbere jednej
turtle zostáva `ID=0` skratkou pre všetky. Pozastavenie sa vykoná pri najbližšej
kontrole pohybu/kopania/stavania; rozbehnutá obsluha truhly sa môže najprv dokončiť.
Pri priebežnom tankovaní každá turtle počíta zásobu na celý zostávajúci vlastný
segment, servisné presuny vrátane tunela a rezervy, s dvojnásobným odhadom.
Cieľ obmedzuje kapacita nádrže a dostupné palivo v truhle. Ak má stále dosť
paliva na pokračovanie a bezpečný návrat, nezačne tankovať iba kvôli tomuto odhadu.
Ak sa palivová truhla automaticky dopĺňa a po odbere je znovu plná, nemožnosť
vrátiť prebytočné uhlie nezastaví úlohu. Turtle si ho ponechá v inventári;
nespaľuje ho navyše iba preto, aby uvoľnila slot. Chybné predmety v palivovej
truhle alebo skutočný nedostatok paliva sa naďalej hlásia ako chyba.

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
spojenia použi voľbu 7. Žiadna rezervácia offline turtle sa neodoberá automaticky.
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

### Obnova po ručnom premiestnení alebo poprehadzovaní dokov

`setup` nemení dok uložený workerom. Po rozbití turtle a položení na nové miesto
použi **worker_reset**, nie opakovaný setup ani obyčajný reset do idle.
Príkaz zruší starú úlohu tejto turtle a z aktuálnej GPS polohy vytvorí nový dok.
Je určený na ručnú obnovu v základni, nie na pokračovanie práce zo šachty.

1. Nahraj nový kód na GitHub. Na hlavnom PC ukonči `fleet`, vykonaj
   `update controller` a znova spusti `fleet`.
2. Polož každú turtle do jej požadovaného doku a otoč ju do voľnej chodby.
   Doky musia byť odlišné, mimo šachty, výstupov a obslužných miest truhiel.
3. Zastav worker cez Ctrl+T. Ak startup vypíše reštart o 10 sekúnd, stlač
   Ctrl+T znova počas tejto pauzy, aby si zostal v termináli.
4. Na každej turtle vykonaj `update turtle`, potom `worker_reset 16`.
   Číslo 16 nahraď ID svojho hlavného PC. Program sa spýta na skutočný smer:
   `0 sever −Z`, `1 východ +X`, `2 juh +Z`, `3 západ −X`.
   Môžeš ho uviesť priamo, napríklad `worker_reset 16 1`.
5. Spusti `reboot` alebo `worker 16`. Worker opakuje požiadavku na nové
   priradenie, kým ju PC nepotvrdí. PC zruší jeho starý segment, odstráni čakajúce
   povely a uvoľní iba rezervácie patriace tejto turtle. Ostatné nemení.

PC aj turtle musia byť aktualizované. Staré a oneskorené správy po novom
priradení nesmú znovu obnoviť pôvodný dok alebo úlohu. Opakované potvrdenie
toho istého priradenia nezruší novú úlohu. Pred novým spoločným zadaním dokonči
obnovu všetkých presunutých turtle a over ich stav `idle` na PC.
Pomenované truhly, poschodia a zóny na hlavnom PC zostávajú zachované.
Predchádzajúci lokálny stav je zálohovaný v `data/worker-before-reset.txt`.

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
3. V menu PC cez voľbu 5 over, že obe sú `idle` a pravidelne odpovedajú.
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
Na PC voľbou 8 pošli tejto turtle návrat do doku. Ak návrat zlyhá, najprv
skontroluj GPS, palivo a priechodnosť; problém sa zobrazí pri danej turtle.
Po odstránení prekážky môžeš namiesto návratu zvoliť **7** a ID konkrétnej turtle.
Pôvodná úloha aj pridelený segment sa zachovajú, ostatné turtle môžu ďalej pracovať.
Pri výkope sa prejde už vykopaná časť od vstupu a potom dokončí zvyšok.
Hotové bunky sa nezapočítajú druhýkrát. Bez uloženého kontrolného bodu sa segment
overí celý. Pri inej turtle v kopanej bunke sa čaká (`waiting_turtle`), bez kopania
do nej; pauza aj stop zostávajú funkčné. Voda a láva úlohu zastavia, po odstránení
môžeš použiť voľbu 7. Dáta pracovníka ani hlavného PC pri obnovení nemaž.

Neodpovedajúcej turtle sa segment ani rezervácia automaticky neodoberú. Mohla
zostať v tuneli alebo pred truhlou. Rezerváciu ručne uvoľni voľbou 11 až po
kontrole, že priechod je voľný a pôvodná turtle už nepokračuje v presune.
Na uvoľnenie program vyžaduje text `VOLNE`.
Po návrate všetkých turtle môžeš použiť **9 → 3**, aby boli `idle` a zabudli
pridelenú úlohu. Reset zachová dok, párovanie, truhly, poschodia a tunel.
Rozbehnutá turtle alebo turtle mimo doku reset odmietne; najprv použi návrat 8.
Ak si ju do nového doku položil ručne, použi vyššie uvedený `worker_reset`.
Reset nie je potrebný na nové zadanie: stavy `complete` a `failed` tiež prijímajú
novú úlohu, keď daná turtle nedrží rezerváciu ani nečaká na povel.
Ostatné skupiny môžu ďalej pracovať. Nové zadanie neúspešnej turtle nahradí jej
pôvodný segment; na pokračovanie pôvodného zadania použi radšej voľbu 7.

Po reštarte sa práca neobnoví sama; pokračovanie vyžiadaj voľbou 7. Nejde o
presné pokračovanie posledného fyzického kroku: uložený stav môže byť mierne starší
a prejdená časť výkopu sa overí znova. Pri podlahe sa znova skontroluje segment,
už položené správne bloky sa preskočia.
Po neúspešnej úlohe neoznačujeme zvyšok za vykopaný. Menšie ďalšie zadanie môžeš
zamerať na zostávajúcu časť. Pri vzdialenej práci musia byť potrebné chunky načítané.

## Rozdelenie kódu a overenie

`fleet.lua` je hlavný program, `fleet_setup.lua` nastavuje základňu a `worker.lua`
beží na turtle. Knižnice `fleet_controller`, `fleet_jobs`, `fleet_client`, `fleet_model`,
`fleet_settings`, `fleet_task`, `fleet_motion`, `transit`, `fleet_store`,
`fleet_dialog`, `fleet_display` rozdeľujú plánovanie, komunikáciu, dopravu,
nastavenia a zobrazenie. Programy `quarry` a `floor` zostávajú samostatne použiteľné.
Stavanie používa knižnice `building` a `floor_plan`; truhla `materials` je povinná.

Automatické testy kontrolujú pôvodné kopanie, delenie segmentov, duplicitné
zadania, návrat cez tunel, ochranu infraštruktúry, rezervácie po reštarte a
prepínanie tabletu, dopĺňanie materiálu a overenie položených blokov. Rádiová
simulácia overuje súbežnú prácu dvoch skutočných programov `worker` proti jednému
riadiacemu programu pri výkope aj podlahe. Minecraft server treba overiť v hre.

Pri aktualizácii sa starý záznam jednej úlohy automaticky načíta do novej evidencie
viacerých úloh; `data/fleet-state.txt` nemaž. Aktualizuj PC cez `update controller`,
turtle cez `update turtle` a tablet cez `update receiver`, potom programy reštartuj.
