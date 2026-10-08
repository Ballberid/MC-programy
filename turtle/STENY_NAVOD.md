# Štyri steny miestnosti

Na turtle spusti `build` a vyber **2 – Steny miestnosti**. Priamy príkaz `walls`
funguje tiež. Pre **viac turtle** spusti na hlavnom PC `fleet` a vyber
**4 – Steny**; na turtle nechaj bežať `worker ID_PC`.

Vo fleet vyber počet alebo konkrétne ID, oba rohy kvádra, rohy áno/nie, materiál,
truhly **fuel / materials / output** a pracovné poschodie. Obvod sa rozdelí na
samostatné úseky v celej výške; podlaha, strop a vnútro sa nemenia.
Pre viac turtle potrebuje miestnosť interiér aspoň 2×2 bloky (kváder aspoň 4×4 v X/Z).
Stačí prístup k jednému spoločnému priechodu, ktorého súradnice PC vypíše.
Pri jeho prechode sa turtle vystriedajú, na stenách pracujú súčasne. Posledná
turtle počká v doku na úspešný návrat ostatných, potom priechod uzavrie zvonka.
Pri chybe zostáva priechod otvorený; po odstránení problému použi vo fleet
**7 – Pokračovať** pre danú turtle. **8** znamená návrat/stop, **9** reset v doku.
Pri zastavení celej úlohy sa uzavretie priechodu nevynucuje.

Ak uložený výstup pracovného poschodia vedie do voľného interiéru miestnosti,
fleet použije tento tunel na vstup aj zásobovanie. Dočasný priechod cez stenu
vtedy nevytvára a všetky bloky stien kladie ako bežnú stavbu. Samotný výstup,
koridor a používaná šachta smú byť v interiéri, ale nesmú zasahovať do bočných
stien, ktoré by im stavba zablokovala. Výstup vo vnútri kvádra teda pri stenách
nie je automaticky chyba. Pri kopaní, podlahe a strope zostávajú ich kontroly.

Výstup môže byť aj nad hornou alebo pod spodnou hranicou stien. Turtle použije
voľnú cestu do interiéru a pokračuje po vnútornom obvode; pomocný priechod zvonka
nevyžaduje. Napríklad steny Y=40–49 môžu mať výstup na Y=63, ak je od neho
voľný prístup nadol do miestnosti. Podlahu, strop ani prekážky na tejto ceste
nevykope. Aj presuny po materiál používajú rovnaké hranice navigácie ako ostatné úlohy.

Odchod z dokov je spoločný pre kopanie, podlahu, strop aj steny. Každá turtle
ešte v doku rezervuje prvú truhlu (`fuel`); ďalšia odíde až keď predchádzajúca
dokončí celú kontrolu truhiel vrátane naloženia materiálu a fyzicky opustí
posledné obslužné miesto. Na pracovisku už pracujú súbežne.

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

Bez priameho vstupu z pracovného poschodia nechá jeden dočasný priechod na strane prvého rohu. Jeho súradnice vypíše pred
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
`output`, materiál berie z `materials`. Pri samostatnom programe, keď materiál dôjde, vráti sa domov a čaká:
**1** po doplnení truhly pokračuje, **0** stavbu zruší. Po dokončení vyloží odpad,
vráti zvyšný stavebný materiál a ide domov. Tablet ukazuje priebeh aj položené bloky.

Vo fleet po doplnení prázdnej materiálovej truhly použi **7 – Pokračovať** pre
zastavenú turtle; ostatné môžu ďalej stavať. Správne dokončené bloky preskočí.

Po nahratí nových súborov na GitHub spusti na PC `update controller`, na turtle
`update turtle` a reštartuj programy. Dáta nemaž. Na tablete
aktualizuj aj `update receiver`. Updater stiahne nové knižnice automaticky.
