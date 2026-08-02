---
name: audit-macos-scripts-menus
description: Kontrollera att macos-scripts menyer, launchers, bridges, routing, command registry och shellscript fungerar genom repots kanoniska syntax-, inventory-, smoke- och releasekontroller. Använd när Codex ska granska alla mqlaunch-menyer och script, felsöka en trasig meny, verifiera command-surface efter ändringar eller ge en evidensbaserad funktionsrapport för macos-scripts.
---

# Audit macOS Scripts Menus

Utför en säker, läsande funktionskontroll av `macos-scripts`. Återanvänd repots
testytor; skapa inte en parallell uppsättning egna kontroller.

## Grundregler

- Kör från repo-roten och respektera `AGENTS.md` samt relevant
  `.mq/context/task-pack.md`.
- Läs `git status --short --branch` först. Bevara samtidiga ändringar och
  rapportera dem separat från testresultatet.
- Kör aldrig varje menyåtgärd direkt. Menyer innehåller muterande, externa och
  interaktiva val. Använd isolerade smoke-test och stubbade delegates som
  bevisning.
- Tolka inte ett saknat externt verktyg som ett scriptfel utan att isolera
  beroendet.
- Ändra inget när användaren bara ber om kontroll eller rapport.

## Full kontroll

Kör lagren i ordning. Fortsätt efter ett fel när det kan göras säkert så att
rapporten visar hela felbilden, men behåll varje exitkod.

### 1. Inventering och kontrakt

Kör:

```bash
python3 tools/scripts/validate-command-registry.py
python3 tools/scripts/generate-help-list.py --check
python3 tools/scripts/inventory-command-surfaces.py --fail-on-unclassified --max-bypass 0 --max-loop 10
tests/test-inventory-smoke.sh
tests/command-discovery-inventory-smoke.sh
```

Kräv att alla testscript är klassificerade, alla aktiva test är kopplade till
`tools/scripts/test-all.sh`, alla menyval är klassificerade, ingen meny kringgår
dispatchern och ingen menyloop har fler än tio operatörsval.

### 2. Kanonisk smoke-svit

Kör:

```bash
MACOS_SCRIPTS_HOME="$PWD" MQ_NO_TUI=1 ./tools/scripts/test-all.sh
```

Detta är huvudbeviset för menyer, routing, EOF, outputkontrakt, delegering,
säkerhetsgränser, HAL-ytor och shell lint. Redovisa `tests/manifest.tsv`-test
som `manual`, `broken` eller `obsolete` separat; kalla dem inte passerade.

### 3. Release- och miljögate

Kör:

```bash
./release-check.sh --dry-run
mqlaunch doctor --json
```

`release-check.sh` ska vara läsande och bekräfta version, skills,
runtime-authority, shellsyntax och hela smoke-sviten. Validera doctor-JSON och
redovisa `summary.ok`, `summary.warn`, `summary.fail` samt exitkod.

### 4. Riktad verklig menyverifiering

Kör endast om fullsviten pekar på ett menyområde eller användaren uttryckligen
ber om extra TTY-kontroll:

- Kör motsvarande `tests/*menu*smoke.sh`.
- Använd `tests/menu-eof-smoke.sh` för headless avslut.
- Använd `tests/menu-shell-guard-smoke.sh` för okänd input och explicit
  `!`-shellväg.
- Använd `tests/terminal-width-smoke.sh` och relevanta golden/screenshot-test
  för layout.
- Kör riktig interaktiv meny endast i PTY, med ofarligt val som back/help.
  Kör aldrig release, push, delete, install, shellkommandon eller externa appar
  som prov.

## Diagnos

Vid fel:

1. Reproducera det minsta felande testet.
2. Klassificera felet som `syntax`, `registry`, `routing`, `menu behavior`,
   `dependency/environment` eller `test infrastructure`.
3. Ange första relevanta felrad, testnamn och exitkod.
4. Jämför mot aktuell kod och kontrakt; gissa inte.
5. Föreslå minsta säkra fix. Implementera endast om användaren har bett om fix.

Om ett test fallerar på sandbox, cache eller nekad skrivning utanför repot,
kör om samma test med korrekt behörighet innan det räknas som kodfel.

## Rapport

Svara kort på svenska:

```text
macos-scripts audit: OK | VARNING | FEL | OKÄND

Täckning
- menyer: <antal/källa>
- aktiva test: <antal från manifest>
- script/syntax: <resultat och verktyg>

Resultat
- <kontroll, exitkod, verifierat utfall>

Fel eller luckor
- <klass, test, evidens>

Bedömning
- <faktaavgränsad slutsats>

Nästa steg
1. <högst tre prioriterade åtgärder>
```

Använd `OK` endast när inventering, full smoke-svit och release-gate passerar.
Använd `VARNING` när valfria beroenden saknas eller manuella test återstår.
Använd `FEL` för brutet kontrakt eller reproducerbart testfel. Använd `OKÄND`
när verifieringen inte kunde slutföras.
