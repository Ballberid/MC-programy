# Jednoduchá podlaha

Spusti `build` a vyber **1 – Podlaha**. Program `floor` položí obdĺžnik z jedného druhu bloku. Používa existujúce
nastavenia originu a truhiel; rozmery zadáš pri spustení programu.
Na hlavnom PC je rovnaká úloha dostupná cez `fleet`, voľbu **9 – podlaha**.

## Príprava samostatnej turtle

Po nahratí nových súborov na GitHub spusti v termináli turtle:

```text
update turtle
reboot
```

Ak ešte nemáš nastavené truhly, spusti `setup`. Pre stavanie potrebuješ:

- `fuel`: truhlu s palivom;
- `materials`: truhlu s jedným druhom stavebného bloku;
- `output`: voliteľnú vykladaciu truhlu, ak bude treba uvoľniť inventár.

Pri truhle zadávaj **miesto, kde stojí turtle**, jej smer a stranu truhly.
Origin určuje miesto návratu po práci. Nechaj voľné prístupové cesty a priestor
nad plánovanou podlahou; turtle pri tejto úlohe nekopá. Potrebuje dostupné GPS,
modem a počiatočné palivo na overenie cesty k palivovej truhle aj späť.
Vyhradené palivové sloty sa pri naberaní stavebného materiálu preskočia.

Táto prvá verzia je určená pre bežné plné bloky, napríklad stone, cobblestone,
bricks alebo oak_planks. Použi bloky, ktoré zostanú na svojom mieste bez podpory;
piesok a štrk môžu padať. Schody, orientácie a kombinovanie slabov táto verzia
nenastavuje. Názov predmetu a položeného bloku musí byť rovnaký.

## Spustenie a rohy

```text
build
```

V menu vyber **1 – Podlaha**; **0 – Koniec** zatvorí menu. Po skončení alebo
zrušení podlahy sa vrátiš do výberu programov. Priamy príkaz `floor` tiež funguje.

Zadaj dva protiľahlé rohy obdĺžnika. Sú to súradnice **blokov podlahy**,
oba rohy majú **rovnaké Y** a hranice sú zahrnuté.

Príklad: `(100,63,100)` a `(104,63,104)` vytvoria podlahu **5×5 = 25 blokov**.
Turtle sa pri kladení pohybuje na **Y=64**, teda o blok vyššie. Začne nad prvým
zadaným rohom a prejde celú plochu cikcakom. Pri samostatnom programe môže mať
origin aj nad podlahou; jeho samotné miesto nesmie byť vyplnené blokom.

Pri otázke na blok nechaj prázdny Enter. Turtle navštívi `materials`, vezme jeden
kus ako vzorku a vráti ho do truhly. Alternatívne zadaj celé ID, napríklad
`minecraft:stone`. S konkrétnym ID vie využiť aj materiál, ktorý už má v inventári,
a skontrolovať hotovú podlahu pri prázdnej materiálovej truhle.

Potvrď štart pomocou `a` alebo `y`; prázdny Enter pri `a/N` štart zruší.
Potom zvoľ automatické určenie smeru alebo zadaj skutočný smer ručne.

## Správanie počas práce

Turtle priebežne kontroluje palivo aj cestu k palivovej truhle. Úvodný cieľ paliva
je dvojnásobok odhadu práce, presunov, zásobovania a rezervy, obmedzený nádržou.
Ak už má dosť, netankuje. Pri nedostatku materiálu berie najviac stack naraz,
pri menšom zvyšku len potrebný počet. Po zásobovaní sa vráti presne nad
rozpracované miesto. Keď zostane v truhle menej než stack, využije aj túto zásobu.
Stavebné drevo v inventári chráni pred automatickým spálením.

Celú budúcu rovinu podlahy vylúči z navigácie, aby si položenými blokmi
nezablokovala cestu používanú na návrat alebo zásobovanie. Overí polohu a výsledok
každého položenia; až potom miesto započíta medzi hotové.

- Rovnaký existujúci blok preskočí a započíta ako hotové miesto.
- Pri inom bloku, prekážke v trase, chýbajúcom materiáli alebo chybe položenia
  sa zastaví, oznámi dôvod a pokúsi sa vrátiť na origin bez kopania.
- Po úspechu vráti zvyšný stavebný materiál do zdrojovej truhly a ide domov.

Po chybe môžeš opraviť príčinu a zadať **rovnakú podlahu znova**. Hotové bloky
preskočí. Priebeh sa počíta pre nové spustenie, automatické pokračovanie po
reštarte sa nespúšťa.

## Viac turtle cez hlavný PC

Aktualizuj hlavný PC pomocou `update controller`, turtle pomocou `update turtle`
a tablet pomocou `update receiver`; potom zariadenia reštartuj.
Truhly a tunel nastav cez `fleet_setup`, rovnako ako pri kopaní.

Na turtle nechaj bežať `worker ID_PC`, na hlavnom PC spusti `fleet` a zvoľ **9**.
Vyber počet turtle, rohy podlahy, blok alebo automatickú vzorku a truhly.
Tu sú povinné palivová, materiálová aj vykladacia stanica. Všetky vybrané turtle
používajú rovnaký materiál a dostanú vlastné neprekrývajúce sa segmenty.

Pri tuneli vyber pracovné poschodie, ktorého výstup je v priestore pre turtle:
pri podlahe na Y=63 teda výstup na Y=64. Doky, truhly, šachtu aj prístupové
koridory umiestni mimo plochy podlahy a priestoru nad ňou. Prístup k spoločným
staniciam a tunelu riadi servisná rezervácia; samotné stavanie prebieha súbežne.

Monitor a `receiver fleet ID_PC` ukazujú hotové/zostávajúce miesta a položené
bloky. Na tablete šípkami prepínaš detail turtle, **0** zobrazí celkový prehľad.
Detail rozlišuje `Polozene` a `Existujuce`. Pre samostatnú turtle stačí doterajší
`receiver ID_TURTLE`.

## Knižnice a overenie

`build.lua` zobrazuje menu stavebných programov zo zoznamu `build_programs.lua`.
Nový stavebný program do menu pridáš položkou s názvom, popisom a príkazom v tomto
zozname a jeho súborom v update manifeste. `floor.lua` obsahuje dialóg,
`floor_plan.lua` plán plochy a `building.lua` prácu:

```lua
local ok, err, progress = require("building").run(
    { x = 100, y = 63, z = 100 },
    { x = 104, y = 63, z = 104 },
    nil -- automatická vzorka; alebo napríklad "minecraft:stone"
)
```

Výsledok obsahuje `total`, `completed`, `remaining`, `placed`, `skipped`,
`phase` a `returnedHome`. `test check` ukazuje pripravenosť knižníc a nastavené
stanice bez pohybu; voľba **6** v `test` overuje prístup k truhlám.
Pred veľkou podlahou skús v hre plochu **3×3**.

Automatické testy bežia v simulovanom CC prostredí. Overujú dopĺňanie, existujúce
bloky, prekážky, chyby položenia, ochranu dreva, návrat aj dve súbežné turtle.
Zatiaľ nejde o overenie na skutočnom Minecraft serveri.
