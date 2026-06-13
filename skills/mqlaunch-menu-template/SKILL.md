---
name: mqlaunch-menu-template
description: >
  Mall för att bygga mqlaunch-menyer med korrekt box-rendering, tvålinjig prompt
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

## 2. Menystruktur — Tvålinjig prompt

Alla mqlaunch-menyer använder **tvålinjig prompt**:

```
┌─────────── Rad 1: Menyval (numrerade) ───────────┐
│  1. Alternativ A    2. Alternativ B               │
│  3. Alternativ C    4. Alternativ D               │
│                                                   │
│  b. Tillbaka        q. Avsluta                   │
└───────────────────────────────────────────────────┘

Välj [1-4 / b / q]:
>
```

Prompten är alltid två rader:
* Rad 1: `"Välj [1-N / b / q]:"` (eller anpassad text)
* Rad 2: `"> "` (inmatningsrad)

Detta är det enda godkända prompt-formatet för mqlaunch-menyer.

---

## 3. Komplett menytemplate

```bash
#!/bin/zsh
# mq-NAMN-menu.sh — Kort beskrivning av menyn
# Sourceas av mqlaunch.sh — kräver inte eget source av mq-ui.sh

# Öppnar NAMN-menyn.
open_NAMN_menu() {
  while true; do
    print_header
    row_bold "NAMN"                        # Rubrik i versaler
    empty_row
    row "  1. Första alternativet"
    row "  2. Andra alternativet"
    row "  3. Tredje alternativet"
    empty_row
    row "  b. Tillbaka"
    row "  q. Avsluta"
    print_footer

    printf '\nVälj [1-3 / b / q]:\n> '
    read -r choice

    case "$choice" in
      1) action_ett ;;
      2) action_tva ;;
      3) action_tre ;;
      b|B) return 0 ;;
      q|Q) exit 0 ;;
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

Använd tvåkolumner när du har 6+ val. Placera valen i jämna kolumner
med fast padding så att kolumn 2 alltid börjar på teckenposition ~46.

```bash
row "  1. Workflows             2. System"
row "  3. Dev                   4. AI"
row "  5. Net                   6. Apps"
row "  7. Git                   8. Release"
empty_row
row "  b. Tillbaka              q. Avsluta"
```

Regel: Kolumn 1 börjar på position 2, kolumn 2 börjar på position 27
(justera med blanksteg, aldrig med tab).

---

## 5. Namnkonventioner

| Vad | Konvention |
|---|---|
| Filnamn | `mq-<namn>-menu.sh` |
| Entry-funktion | `open_<namn>_menu()` |
| Action-funktioner | `action_<verb>()` eller `<verb>_<noun>()` |
| Rubrik i `row_bold` | VERSALER, max 40 tecken |
| Kommentar per funktion | `# Beskriver vad funktionen gör.` (punkt i slutet) |

---

## 6. Registrering i mqlaunch.sh

När en ny meny är skapad, lägg till i `mqlaunch.sh`:

**Source-block** (i rätt ordning bland övriga menyer):

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

Och i case-satsen:

```bash
N|n) open_NAMN_menu ;;
```

---

## 7. Vanliga misstag att undvika

* **Aldrig** `echo` direkt för UI — använd alltid `row()` innanför boxen
* **Aldrig** `read -p "Välj: "` — använd tvålinjig `printf + read`
* **Aldrig** hårdkoda `BOX_INNER` i menyfilen
* **Aldrig** source `mq-ui.sh` i menyfilen (görs av mqlaunch.sh)
* **Alltid** avsluta aktions med `pause_enter` om de visar output
* **Alltid** ha `b. Tillbaka` och `q. Avsluta` i varje meny
* **Alltid** ha ett `*)` wildcard-fall i case-satsen

---

## 8. Exempelmenyer att studera

Dessa filer i `$BASE_DIR/terminal/menus/` är referensimplementationer:

* `mq-main-menu.sh` — Huvudmenystruktur, tvåkolumner
* `mq-system-menu.sh` — Enkla aktioner med pause_enter
* `mq-dev-menu.sh` — Git-integration och submenyer
* `mq-workflows-menu.sh` — Workflow-loop med statusvisning

---

## 9. Snabbreferens — generera en meny

När Codex eller Claude Code ska bygga en ny meny, följ dessa steg:

1. Kopiera template från avsnitt 3
2. Ersätt `NAMN` med menyns namn (snake_case)  
3. Definiera action-funktioner för varje val
4. Spara som `$BASE_DIR/terminal/menus/mq-<namn>-menu.sh`
5. Gör filen körbar: `chmod +x mq-<namn>-menu.sh`
6. Lägg till source-block i `mqlaunch.sh`
7. Registrera argument i `run_arg_command`
8. Lägg till menyval i `mq-main-menu.sh` om relevant
