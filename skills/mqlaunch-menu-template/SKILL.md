---
name: mqlaunch-menu-template
description: >
  Mall för att bygga mqlaunch-menyer med korrekt box-rendering, separator-prompt
  och konsekvent UI-mönster. Använd när Codex, Claude Code eller Claude ska skapa
  en ny mqlaunch-meny (t.ex. mq-workflows-menu.sh, mq-system-menu.sh). Triggas av
  fraser som "bygg en ny mqlaunch-meny", "lägg till ett menyval", "skapa submeny
  för X i mqlaunch", eller "ny menu-modul i macos-scripts".
---

# mqlaunch-menu-template

## Syfte

Denna skill definierar hur alla mqlaunch-menyer ska vara byggda —
box-layout, UI-funktioner, prompt-format och loopstruktur — så att
Codex och Claude Code kan generera konsekventa, fungerande menyfiler
utan att gissa sig till mönstret.

---

## 1. Kärnkoncept

### BOX_INNER = 88

Alla rader i boxen är exakt 88 tecken breda innanför ramarna.
`row()` fyller ut till exakt den bredden automatiskt.
Ändra **aldrig** BOX_INNER per meny — det är ett globalt konstant i `mqlaunch.sh`.

### UI-bibliotek

Varje menyfil **sourcear inte** UI-biblioteket själv. Menyfilen är en modul
som sourceas av `mqlaunch.sh` (som redan har laddat `mq-ui.sh`). Alla
UI-funktioner är alltså tillgängliga utan extra source-anrop.

Tillgängliga UI-funktioner (definierade i `mq-ui.sh`):

| Funktion | Effekt |
|---|---|
| `print_header` | Renderar dashboard-banner + tom rad |
| `print_footer` | Renderar underkant på boxen |
| `row "text"` | En rad innanför boxen, vänsterjusterad, paddar till BOX_INNER |
| `row_bold "text"` | Som `row` men med bold/neon-färg |
| `empty_row` | Tom rad innanför boxen (mellanrum) |
| `pause_enter` | Väntar på Enter — "Tryck Enter för att fortsätta" |

---

## 2. Prompt-format — Separator-prompt

**Detta är det enda godkända prompt-formatet för mqlaunch-menyer.**

Prompten består av tre delar i sekvens — utanför boxen, efter `print_footer`:

```
────────────────────────────────────────────────────────────────────────────────
<menynamn> >
────────────────────────────────────────────────────────────────────────────────
>> option, mqlaunch command, shell command, or x to exit
```

* Rad 1: horisontell separator (80 `─`-tecken, U+2500)
* Rad 2: `<menynamn> >` — menyns titel i lowercase följt av ` > `
* Rad 3: horisontell separator (80 `─`-tecken)
* Rad 4: `>> option, mqlaunch command, shell command, or x to exit`

Sedan `read -r choice` på samma rad som `>>`-prompten, eller direkt efter.

### Implementering i zsh

```bash
# Separator-konstant (definiera en gång i toppen av menyfilen eller i UI-lib)
SEP="────────────────────────────────────────────────────────────────────────────────"

# I menyloopen, efter print_footer:
printf '\n%s\n%s >\n%s\n>> ' "$SEP" "system" "$SEP"
read -r choice
```

Byt ut `"system"` mot menyns faktiska namn (lowercase, t.ex. `"workflows"`, `"dev"`, `"net"`).

---

## 3. Komplett menytemplate

```bash
#!/bin/zsh
# mq-NAMN-menu.sh — Kort beskrivning av menyn
# Sourceas av mqlaunch.sh — kräver inte eget source av mq-ui.sh

# Separator — 80 st U+2500
MQ_NAMN_SEP="────────────────────────────────────────────────────────────────────────────────"

# Öppnar NAMN-menyn.
open_NAMN_menu() {
  while true; do
    print_header
    row_bold "NAMN"
    empty_row
    row "  1. Första alternativet"
    row "  2. Andra alternativet"
    row "  3. Tredje alternativet"
    empty_row
    row "  b. Tillbaka"
    row "  x. Avsluta"
    print_footer

    printf '\n%s\nnamn >\n%s\n>> ' "$MQ_NAMN_SEP" "$MQ_NAMN_SEP"
    read -r choice

    case "$choice" in
      1) action_ett ;;
      2) action_tva ;;
      3) action_tre ;;
      b|B) return 0 ;;
      x|X) exit 0 ;;
      "")  continue ;;
      *)
        print_header
        row "Ogiltigt val: $choice"
        print_footer
        pause_enter
        ;;
    esac
  done
}

# Kör första alternativet.
action_ett() {
  print_header
  row_bold "FÖRSTA ALTERNATIVET"
  empty_row
  row "Beskrivning av vad som händer här."
  print_footer
  pause_enter
}

# Kör andra alternativet.
action_tva() {
  print_header
  row_bold "ANDRA ALTERNATIVET"
  empty_row
  row "Beskrivning av vad som händer här."
  print_footer
  pause_enter
}

# Kör tredje alternativet.
action_tre() {
  print_header
  row_bold "TREDJE ALTERNATIVET"
  empty_row
  row "Beskrivning av vad som händer här."
  print_footer
  pause_enter
}

# Entry point — stöder direktanrop: bash mq-NAMN-menu.sh menu
if [[ "${1:-}" == "menu" ]]; then
  open_NAMN_menu
fi
```

---

## 4. Tvåkolumns-layout (valfritt, för många val)

Använd tvåkolumner när du har 6+ val. Placera valen med fast kolumnbredd
så att kolumn 2 alltid börjar på teckenposition ~27.

```bash
row "  1. Workflows             2. System"
row "  3. Dev                   4. AI"
row "  5. Net                   6. Apps"
row "  7. Git                   8. Release"
empty_row
row "  b. Tillbaka              x. Avsluta"
```

Regel: Kolumn 1 börjar på position 2, kolumn 2 börjar på position 27.
Justera med blanksteg — aldrig med tab.

---

## 5. Separator-prompten — fullständig visuell representation

Så här ser det ut i terminalen efter `print_footer`:

```
────────────────────────────────────────────────────────────────────────────────
system >
────────────────────────────────────────────────────────────────────────────────
>> option, mqlaunch command, shell command, or x to exit
```

Användaren kan skriva:

* Ett nummer (`1`, `2`, `3` …) → menyval
* Ett mqlaunch-kommando direkt (`git`, `dev`, `perf` …) → dispatchar till `run_arg_command`
* Ett shell-kommando → exekveras i subshell
* `x` → avslutar

### Dispatcha fritt inmatade kommandon

Om menyn ska stödja fri mqlaunch-dispatch (som huvudmenyn), lägg till
detta i case-satsen:

```bash
*)
  # Försök dispatcha som mqlaunch-kommando
  if declare -f run_arg_command >/dev/null 2>&1; then
    run_arg_command "$choice"
  else
    print_header
    row "Ogiltigt val: $choice"
    print_footer
    pause_enter
  fi
  ;;
```

---

## 6. Namnkonventioner

| Vad | Konvention |
|---|---|
| Filnamn | `mq-<namn>-menu.sh` |
| Entry-funktion | `open_<namn>_menu()` |
| Action-funktioner | `action_<verb>()` eller `<verb>_<noun>()` |
| Rubrik i `row_bold` | VERSALER, max 40 tecken |
| Promptnamn | lowercase, matchar filnamn utan `mq-` och `-menu.sh` |
| Kommentar per funktion | `# Beskriver vad funktionen gör.` (punkt i slutet) |
| Exit-tangent | alltid `x` (inte `q`) — matchar separator-promptens text |

---

## 7. Registrering i mqlaunch.sh

När en ny meny är skapad, lägg till i `mqlaunch.sh`:

**Source-block** (bland övriga menyer, i rätt ordning):

```bash
if [[ -f "$BASE_DIR/terminal/menus/mq-NAMN-menu.sh" ]]; then
  source "$BASE_DIR/terminal/menus/mq-NAMN-menu.sh"
fi
```

**Argument-dispatch** (i `run_arg_command` case-satsen):

```bash
namn|namn-menu) open_NAMN_menu ;;
```

**Menyval i mq-main-menu.sh** (om det ska synas i huvudmenyn):

```bash
row "  N. NAMN"
```

Och i case-satsen för huvudmenyns `read`:

```bash
N|n) open_NAMN_menu ;;
```

---

## 8. Vanliga misstag att undvika

* **Aldrig** `read -p "Välj: "` — använd `printf + read` med separator-formatet
* **Aldrig** `q` som exit-tangent — det är `x` i separator-prompten
* **Aldrig** hårdkoda `BOX_INNER` i menyfilen
* **Aldrig** source `mq-ui.sh` i menyfilen (görs av mqlaunch.sh)
* **Alltid** avsluta aktioner med `pause_enter` om de visar output
* **Alltid** ha `b. Tillbaka` och `x. Avsluta` i varje meny
* **Alltid** ha ett `*)` wildcard-fall i case-satsen
* **Alltid** definiera `SEP` lokalt i filen (inte global — den kan skilja sig)

---

## 9. Exempelmenyer att studera

Dessa filer i `$BASE_DIR/terminal/menus/` är referensimplementationer:

* `mq-main-menu.sh` — Huvudmenystruktur, tvåkolumner, separator-prompt
* `mq-system-menu.sh` — Enkla aktioner med pause_enter
* `mq-dev-menu.sh` — Git-integration och submenyer
* `mq-workflows-menu.sh` — Workflow-loop med statusvisning

---

## 10. Snabbreferens — generera en meny

När Codex eller Claude Code ska bygga en ny meny, följ dessa steg:

1. Kopiera template från avsnitt 3
2. Ersätt `NAMN`/`namn` med menyns namn (snake_case / lowercase)
3. Definiera action-funktioner för varje val
4. Spara som `$BASE_DIR/terminal/menus/mq-<namn>-menu.sh`
5. Gör filen körbar: `chmod +x mq-<namn>-menu.sh`
6. Lägg till source-block i `mqlaunch.sh`
7. Registrera argument i `run_arg_command`
8. Lägg till menyval i `mq-main-menu.sh` om relevant

---

## Evals

### Should trigger

* "bygg en ny mqlaunch-meny för X"
* "lägg till en submeny i mqlaunch"
* "skapa en ny menu-modul i macos-scripts"
* "den nya menyn renderar boxen fel — följ template-mönstret"

### Should not trigger

* "lägg till ett nytt kommando i en befintlig meny" → use `mqlaunch-command-surface`
* "gör doctor-outputen lättare att läsa" → use `terminal-ui-polisher`
* "synka docs/COMMANDS.md efter ändringen" → use `docs-maintainer`
* "är repot redo att släppas?" → use `release-readiness`
