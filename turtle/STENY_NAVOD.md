# Štyri steny miestnosti

Na turtle spusti `build` a vyber **2 – Steny miestnosti**. Priamy príkaz `walls`
funguje tiež. Tento program beží samostatne na jednej turtle.

V `setup` priprav truhly **fuel**, **materials** a **output**. Materiálová truhla
má obsahovať jeden druh stavebného bloku. Blok vyber jeho ID alebo vzorkou vo
vybranom slote; s prázdnym slotom a prázdnym ID sa použije vzorka z truhly.
Turtle potrebuje dva prázdne sloty navyše na vykopané predmety.

Zadaj dva protiľahlé rohy kvádra ako **súradnice blokov**, napríklad dolný roh
`100,64,200` a protiľahlý horný roh `106,67,208`. Rozmery sú vrátane oboch rohov:
v tomto príklade 7×4×9. Potom odpovedz na **Spraviť aj rohy? [a/N]**:
Enter alebo `n` znamená **bez rohov** (predvolené); `a` alebo `y` znamená s rohmi.
Bez rohov vytvorí **96 blokov stien**, s rohmi **112**. Vynechávajú sa celé štyri
rohové stĺpce v zadanej výške: nekopú sa, nemenia sa a nepočítajú sa do materiálu,
priebehu ani plánovanej práce pre palivo.
Oba vodorovné rozmery musia mať aspoň tri bloky, aby zostalo miesto pre turtle.

Program mení iba bunky na štyroch bočných stenách v zadanej výške. Nevytvára
podlahu ani strop a nemení vnútorné bloky kvádra. Aj spodný a horný okraj bočných
stien patria do stavby. Dvere a okná sa zatiaľ nerobia: otvory v stenách sa vyplnia.

Turtle začína a končí **mimo kvádra**; mimo neho musia byť aj servisné stanice.
Pri voľbe **s rohmi** rohové stĺpce najprv dokončí zvonka, pretože z interiéru sa
rohový blok nedá položiť priamo pred seba. Pri voľbe **bez rohov** ich ponechá
pôvodné; prístup k nim zvonka nepotrebuje. Ostatné steny stavia **pred seba z vnútorného obvodu**.
Na pracovnom mieste nikdy nestojí v budovanej stene.

Nechá jeden dočasný priechod na strane prvého rohu. Jeho súradnice vypíše pred
štartom. Priechod otvorí, používa ho na vstup a zásobovanie, potom vyjde von
a **uzavrie ho ako posledný blok**. Pri chybe alebo zrušení môže zostať otvorený.

Nechaj voľný vnútorný obvod a prístup k jednému servisnému priechodu aj k truhlám.
Priechod leží na X strane prvého rohu, jeden blok smerom do steny po Z a približne
v polovici zadanej výšky. Jeho vonkajšie susedné miesto musí byť dostupné aj pri
voľbe **bez rohov**; ostatný vonkajší obvod môže zostať v zemi. V tomto režime pri
zablokovanom vnútornom prístupe neskúša vonkajšiu stranu.
Pri voľbe **s rohmi** navyše priprav miesto pri rohoch zvonka; pri prekážke vo
vnútornom obvode môže skúsiť vonkajší prístup k stene.
Interiér ani prekážky mimo stien nevykope.

Správne bloky preskočí. Iné bloky na stenách vykope a nahradí, až keď má materiál
a miesto na vykopané predmety. Truhly a iné inventáre nevykope. Voda, láva alebo
nezničiteľný blok stavbu zastavia s chybou. Na inú turtle počká.

Palivo a miesto v inventári kontroluje priebežne. Vykopané predmety vykladá do
`output`, materiál berie z `materials`. Keď materiál dôjde, vráti sa domov a čaká:
**1** po doplnení truhly pokračuje, **0** stavbu zruší. Po dokončení vyloží odpad,
vráti zvyšný stavebný materiál a ide domov. Tablet ukazuje priebeh aj položené bloky.

Po nahratí nových súborov na GitHub spusti `update turtle` a `reboot`. Na tablete
aktualizuj aj `update receiver`. Updater stiahne nové knižnice automaticky.
