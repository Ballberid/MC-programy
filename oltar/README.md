# Oltár

Programy pre CC: Tweaked a Mekanism. Základ tvorí päť PC: jeden hlavný
a štyri pomocné. Všetky potrebujú modem a spojenie cez Rednet.

## Hlavný PC

Skopíruj `main.lua` do hlavného PC a spusti `main.lua`.
Program vypíše ID tohto PC, ktoré zadáš na pomocných PC.

| Strana hlavného PC | Zapojenie |
| --- | --- |
| `front` (predná) | Vstup: True povoľuje dopĺňanie mobov |
| `right` | Výstup na spawner (vľavo pri pohľade na obrazovku PC) |
| `back` (zadná) | Mekanism Teleporter |

V Mekanisme vytvor verejné frekvencie `oltar_1`, `oltar_2`, `oltar_3`,
`oltar_4`. Cieľové teleportery nastav na príslušné frekvencie.
Teleporter za hlavným PC musí mať bezpečnosť **Public** a byť prístupný ako
periféria s metódou `setFrequency(name)`.
Požiadavky vychádzajú z [oficiálnej dokumentácie Mekanismu](https://mekanism.github.io/computer_data/10.7.0.html).

Pri štarte hlavný PC vypne spawner, nastaví frekvenciu `oltar_1` (aj keď je
predný vstup False) a počká na počty mobov zo všetkých štyroch pomocných PC.
Potom vyberá vežu s najnižším počtom mobov. Pri rovnakých počtoch dodrží
poradie 1, 2, 3, 4. Najprv teda doplní jedného moba do každej veže,
až potom druhého do každej, potom tretieho atď. Počty sa riadia skutočnými
hláseniami senzorov, nie počítadlom odoslaných mobov.

Predvolený cieľ je **15 mobov na každú vežu**. Po dosiahnutí cieľa vo
všetkých vežiach spawner vypne. Ak niekde mob ubudne, túto vežu opäť
doplní. Limit môžeš zmeniť cez `main.lua setup`; uloží sa do
`main-config.txt`. Ak senzor umožňuje merať menej mobov než zadaný limit,
program použije kapacitu najmenšieho senzora. Už vytvorení alebo letiaci
mobovia môžu doraziť aj po vypnutí spawneru; program ich spätne neodstraňuje.

Predný vstup False okamžite vypne spawner; stavové správy sa stále prijímajú.
Po opätovnom zapnutí sa pokračuje podľa aktuálnych stavov.
Pri chybe teleportera sa spawner vypne, program vypíše dôvod a po oprave
automaticky zopakuje nastavenie. Ukončenie cez Ctrl+T tiež vypne spawner.
Program vypisuje zmeny vstupu `front` a výstupu `right`. Okrem redstone
udalostí kontroluje vstup každých 0,25 sekundy.
Ak teleporter poskytuje `getFrequency`, program overuje skutočnú zvolenú
frekvenciu pred potvrdením prepnutia. Pri nezhode vypne spawner a skúša znova.
Stavy sa uchovávajú v pamäti a po reštarte sa načítajú z pomocných PC.
Posledná frekvencia ostáva zvolená pri plnom oltári aj vypnutom vstupe.

## Štyri pomocné PC

Na každý skopíruj rovnaký `client.lua` a spusti ho.
Pri prvom spustení zadaj číslo oltára **1–4** a **ID hlavného PC**.
Každé číslo použi len raz. Nastavenie sa uloží do `client-config.txt`
vedľa programu. Zmenu nastavenia spusti cez `client.lua setup`.

| Strana pomocného PC | Zapojenie |
| --- | --- |
| `back` (zadná) | Analógový vstup z počítacieho senzora |
| `right` | Sila 15 pri zadnom signále aspoň 1, inak 0 |
| `bottom` (spodná) | True, keď je počet mobov väčší než 0 |

PC číta `redstone.getAnalogInput("back")`, rozsah **0–15** podľa
[dokumentácie CC: Tweaked](https://tweaked.cc/module/redstone.html#v:getAnalogInput).
Predvolené mapovanie je **0 = 0 mobov, 1 = 1 mob, …, 15 = 15 mobov**.
Prázdny signál môžeš upraviť cez `client.lua setup` (Enter nastaví 0);
každý ďalší mob musí zvýšiť silu o 1. Nastavenie klienta bez prázdneho
signálu sa automaticky doplní o hodnotu 0, číslo oltára a ID hlavného PC
sa zachovajú. Už uložená hodnota 1 sa pri aktualizácii nemení: po zmene
zapojenia na priame počty spusti na každom klientovi `client.lua setup`,
zadaj jeho pôvodné číslo a ID hlavného PC a prázdny signál **0**.
Uložený cieľ hlavného PC sa tiež nemení; pre 15 mobov spusti `main.lua setup`.

Senzor musí na vstup PC privádzať presnú silu. Nepoužívaj medzi ním a PC
repeater, ktorý z nenulového signálu spraví 15, a vyhni sa zoslabovaniu
signálu dlhým redstone vedením. Over silu **priamo na PC** pri 0 a 1 mobovi.
Ak si chceš hodnotu overiť ručne, ukonči program, spusti `lua` a zadaj
`redstone.getAnalogInput("back")`.

PC posiela názov oltára, počet mobov, silu signálu a kapacitu senzora.
Pravý výstup zapne na plnú silu 15 hneď pri zadnom signále aspoň 1;
pri signále 0 ho vypne. Tento výstup sa riadi priamo silou vstupu,
nezávisle od nastavenia prázdneho signálu. Ctrl+T alebo chyba ho tiež vypne.
Pri počte väčšom než 0 najprv odošle hlásenie a potom zapne spodný výstup;
pri poklese na 0 najprv spodný výstup vypne. Hlási každú zmenu analógovej
hodnoty, aj keď sa obyčajná hodnota True/False nezmení. Vstup kontroluje
aj každých 0,25 sekundy. Odošle tiež počiatočný stav a každé dve sekundy
zopakuje aktuálne hlásenie, aby sa napravila stratená správa a obnovili sa
počty po reštarte hlavného PC.
Ctrl+T alebo chyba programu vypne spodný výstup.
Hlásenie stavu znamená odoslanie do siete, nečaká na potvrdenie doručenia.
Pri výpadku spojenia hlavný PC drží posledný prijatý stav až do ďalšej správy.

## Router

Ak používaš samostatný PC ako router/opakovač, skopíruj a spusti
`router.lua`. Používa štandardný Rednet program `repeat`.
Takýto router je ďalší PC navyše k piatim riadiacim PC.
Pri spoločnej káblovej modemovej sieti ďalší PC na opakovanie netreba.
Existujúci router musí prenášať štandardné Rednet správy.

Strany sú vždy relatívne voči prednej strane konkrétneho počítača.

## Inštalácia, update a automatický štart

Keď budú súbory z priečinka `oltar` zverejnené na vetve `main` v GitHube,
na každom PC prejdi do koreňového priečinka a stiahni updater:

```text
cd /
wget https://raw.githubusercontent.com/Ballberid/MC-programy/main/oltar/oltar_update.lua update.lua
```

Na hlavnom PC spusti `update main`, na každom zo štyroch pomocných PC
`update client`. Na prípadnom samostatnom routeri spusti `update router`.
Updater stiahne príslušný program, `startup.lua` aj novú verziu seba samého
a uloží úlohu PC do `oltar-role.txt`. Potom spusti `startup` alebo `reboot`.
Klient pri prvom spustení ešte potrebuje číslo oltára a ID hlavného PC.

Pri ďalšej aktualizácii stačí ukončiť program cez Ctrl+T a spustiť `update`.
Úloha PC sa načíta z uloženého nastavenia; `client-config.txt` a
`main-config.txt` ostávajú zachované.
Zmenu úlohy pri aktualizácii vykonáš cez `update main`, `update client`
alebo `update router`. Zmenu čísla oltára alebo ID hlavného PC cez
`client.lua setup`.

**Prechod na analógový senzor:** aktualizuj hlavný PC aj všetky štyri pomocné
PC a spusti ich znova. Nová komunikácia používa `oltar.v2`; staré True/False
hlásenia sa ignorujú. Kým sa neozvú všetky štyri nové klienty, spawner ostane
vypnutý. Router môže zostať rovnaký. Limit zmeníš cez `main.lua setup`.

Updater používa rovnaký postup ako turtle: všetky súbory stiahne z jedného
commitu, overí syntax a až potom ich nahradí. Pri zlyhaní inštalácie obnoví
pôvodné súbory zo zálohy. Po prerušení aktualizácie opätovne spusti `update`,
aby obnovil pôvodnú verziu pred ďalšou inštaláciou.

Pri každom štarte PC, aj po reštarte servera, `startup.lua` spustí uloženú
úlohu. Pri štarte sa nič nesťahuje, takže automatický štart nepotrebuje HTTP.
PC musí byť načítaný v hernom svete, aby jeho program bežal.

Pri ručnom kopírovaní ulož `startup.lua` a program danej úlohy do koreňa PC.
Pri prvom spustení `startup` vyber `main`, `client` alebo `router`;
voľba sa uloží pre ďalšie štarty. `startup setup` umožní výber zmeniť.
