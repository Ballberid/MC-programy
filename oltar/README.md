# Oltár

Programy pre CC: Tweaked a Mekanism. Základ tvorí päť PC: jeden hlavný
a štyri pomocné. Všetky potrebujú modem a spojenie cez Rednet.

## Hlavný PC

Skopíruj `main.lua` do hlavného PC a spusti `main.lua`.
Program vypíše ID tohto PC, ktoré zadáš na pomocných PC.

| Strana hlavného PC | Zapojenie |
| --- | --- |
| `front` (predná) | Vstup: True povoľuje dopĺňanie mobov |
| `left` (ľavá) | Výstup na spawner |
| `back` (zadná) | Mekanism Teleporter |

V Mekanisme vytvor verejné frekvencie `oltar_1`, `oltar_2`, `oltar_3`,
`oltar_4`. Cieľové teleportery nastav na príslušné frekvencie.
Teleporter za hlavným PC musí mať bezpečnosť **Public** a byť prístupný ako
periféria s metódou `setFrequency(name)`.
Požiadavky vychádzajú z [oficiálnej dokumentácie Mekanismu](https://mekanism.github.io/computer_data/10.7.0.html).

Pri štarte hlavný PC nastaví ľavý výstup podľa predného vstupu a následne
frekvenciu `oltar_1`, aj keď je predný vstup False. Potom vyberá prvý oltár,
ktorý nemá True, v poradí 1, 2, 3, 4. Zatiaľ neohlásený stav považuje za
neobsadený. Pri štyroch True spawner vypne. Keď niektorý stav klesne na
False, prepne na prvý chýbajúci oltár a opäť zapne spawner, ak je predný
vstup True. Ak vypadne iba tretí, vyberie priamo `oltar_3`.

Predný vstup False okamžite vypne spawner; stavové správy sa stále prijímajú.
Po opätovnom zapnutí sa pokračuje podľa aktuálnych stavov.
Pri chybe teleportera sa spawner vypne, program vypíše dôvod a po oprave
automaticky zopakuje nastavenie. Ukončenie cez Ctrl+T tiež vypne spawner.
Program vypisuje zmeny vstupu `front` a výstupu `left`. Okrem redstone
udalostí kontroluje vstup každých 0,25 sekundy.
Stavy sa uchovávajú v pamäti a po reštarte sa načítajú z pomocných PC.
Posledná frekvencia ostáva zvolená pri plnom oltári aj vypnutom vstupe.

## Štyri pomocné PC

Na každý skopíruj rovnaký `client.lua` a spusti ho.
Pri prvom spustení zadaj číslo oltára **1–4** a **ID hlavného PC**.
Každé číslo použi len raz. Nastavenie sa uloží do `client-config.txt`
vedľa programu. Zmenu nastavenia spusti cez `client.lua setup`.

| Strana pomocného PC | Zapojenie |
| --- | --- |
| `back` (zadná) | Vstup z dosky: True = mob je prítomný |
| `bottom` (spodná) | Výstup kopírujúci stav vstupu |

Pri True PC najprv odošle hlásenie s názvom oltára a potom zapne spodný
výstup. Pri False vypne spodný výstup a oznámi False hlavnému PC.
Odošle tiež počiatočný stav a každé dve sekundy zopakuje aktuálny stav,
aby sa napravila stratená správa a hlavný PC mohol reštartovať.
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
Úloha PC sa načíta z uloženého nastavenia; `client-config.txt` ostáva zachovaný.
Zmenu úlohy pri aktualizácii vykonáš cez `update main`, `update client`
alebo `update router`. Zmenu čísla oltára alebo ID hlavného PC cez
`client.lua setup`.

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
