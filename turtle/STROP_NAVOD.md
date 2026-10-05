# Jednoduchý strop

Spusti **`build` → 3 – Strop**, alebo priamo `ceiling`. V hlavnom PC je
spoločná stavba stropu dostupná cez **`fleet` → 3**.

Strop tvorí jednu vrstvu blokov. Pri prvom rohu zadaj **X, Y a Z**, pri
protiľahlom iba **X a Z**. Y druhého rohu sa preberie z prvého.
Súradnice patria blokom stropu. Napríklad `(100,70,200)` a `(104,204)`
vytvoria plochu 5×5 na Y=70; turtle chodí na Y=69 a kladie **iba nad seba**.
Pri prekážke neprepne na prácu zhora.

V `setup` nastav `fuel` a `materials`, prípadne `output` na uvoľňovanie
inventára. Pri flotile sú povinné všetky tri stanice. Materiál môžeš určiť
ID bloku, vzorkou vo vybranom slote alebo vzorkou z materiálovej truhly.
Nechaj voľnú cestu **pod stropom** a prístup k truhlám; tento program nekopá.
Pri tuneli má pracovný výstup byť v priestore pod stropom, teda Y-1.

Existujúce správne bloky preskočí, iné bloky na mieste stropu oznámi ako
prekážku. Keď samostatnej turtle dôjde materiál, vráti sa domov a čaká:
**1** po doplnení truhly pokračuje, **0** stavbu zruší. Po dokončení vráti
zvyšný materiál a ide na nastavený origin. Vo flotile používa rovnaké
ovládanie pokračovania, návratu a resetu ako podlaha.

Po nahratí zmien na GitHub aktualizuj turtle cez `update turtle`, hlavný
PC cez `update controller` a tablet cez `update receiver`. Potom zariadenia
reštartuj mimo rozbehnutej práce. Nastavenia a dáta sa nemažú.
