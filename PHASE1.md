# Faze 1 — overeni prostredi (2026-11-07)

## Vysledek

Splneno: vlastni UnrealScript balik lze sestavit proti nainstalovane hre,
dynamicky nacist a pouzit jako GameInfo serveru na kampanove mape.

- Build: 0 chyb kompilace; 2 varovani `ReadToken: Bad quoted string`
  behem inicializace zavislosti. Puvod varovani zatim neni urcen.
- Kontrola baliku: `LANCOOP_CHECK_OK`, MaxPlayers=2.
- Server: `LANCOOP_PHASE1_INIT` a `LANCOOP_PHASE1_READY` v suburbs-3.
- Sit: `PHASE1_SERVER_OK PID=28216 UDP=7787 Map=suburbs-3`.
  Vlastnictvi UDP portu overeno podle PID vytvoreneho procesu.
- Server po testu ukoncen. Zadna graficka instance hry nebyla spoustena.

Omezeni prostredi nejprve skrylo systemovy seznam socketu. Opakovani testu
mimo omezene prostredi uspelo. Pri podobne chybe nejprve zkontrolovat
opravneni testu; samotna prazdna tabulka neprokazuje chybu serveru.

## Co tento test neznamena

Zatim nebylo overeno pripojeni klienta, hrani ve dvou, synchronizace NPC,
inventare, prechody map ani ukladani. Docasny probe dedi z xDeathMatch.
Na kampanove mape zpusobuje chyby NPC, ktera ocekavaji singleplayerovy
GameInfo. Tento probe tedy neni zaklad hotove kampane, ale test nastroju.

## Instalace a zdroje

UCC hlasi 5100, sestaveni 17. dubna 2023. README dodanych zdrojaku uvadi
22. dubna 2023. Nas kod se kompiluje proti lokalnim .u balikum, coz overuje
pouzite rozhrani; uplna shoda vsech zdrojaku se vsemi binarkami neni dolozena.
ZIPy s oznacenim 2022 / NC compile nebyly rozbalovany pres instalaci.
REA zatim nebylo potreba pouzit.

Build vytvari vlastni LanCoop.ini, LanCoopUser.ini, LanCoop.u a staging
zdrojaku. Savy smeruji do LanCoopSaves, cache do LanCoopCache.
Postal2.ini, User.ini, Nickovy konfigurace a existujici savy se neupravuji.
Jde o oddeleni konfigurace, nikoliv zaruku izolace vsech zapisu enginu.

## Dalsi krok

Vybrat a implementovat kampanove kompatibilni GameInfo a zivotni cyklus
hracu. Overit dva klienty na jedne mape, spravny spawn a viditelnost postav.
Az pote boj a NPC. Pri navrhu oddelit stav sveta od stavu kazdeho hrace,
aby prechod A -> B -> A neobnovoval inventar z nespravneho okamziku.
