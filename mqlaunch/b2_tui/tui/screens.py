from __future__ import annotations

import subprocess
from datetime import datetime, timezone

from textual.app import ComposeResult
from textual.binding import Binding
from textual.containers import Vertical
from textual.screen import ModalScreen
from textual.widgets import Input, Label, ListItem, ListView, Static

from mqlaunch.b2_tui.models import Prompt

_DIALOG_CSS = """
{cls} {{
    align: center middle;
}}
#{id} {{
    width: 72;
    height: auto;
    max-height: 85%;
    border: thick $primary;
    background: $surface;
    padding: 1 2;
}}
"""


class RouteScreen(ModalScreen[None]):
    CSS = _DIALOG_CSS.format(cls="RouteScreen", id="route-dialog")
    BINDINGS = [Binding("escape", "dismiss_screen", "Back")]

    def __init__(self, prompts: list[Prompt]) -> None:
        super().__init__()
        self.prompts = prompts

    def compose(self) -> ComposeResult:
        with Vertical(id="route-dialog"):
            yield Label("[bold]Route Task[/bold]  [dim]— describe your task and press Enter[/dim]")
            yield Input(placeholder="e.g. bygga en blueprint för TUI", id="task-input")
            yield Static("", id="route-result")

    def on_mount(self) -> None:
        self.query_one("#task-input", Input).focus()

    def on_input_submitted(self, event: Input.Submitted) -> None:
        task = event.value.strip()
        if not task:
            return
        from mqlaunch.b2_tui.core.project_loader import find_prompt
        from mqlaunch.b2_tui.core.router import ROUTE_PRIMARY, ROUTE_SUPPORT, route
        from mqlaunch.b2_tui.core.history import save_history

        best_route, support_routes, matched_kws = route(task)
        primary_id = ROUTE_PRIMARY[best_route]
        primary = find_prompt(self.prompts, primary_id)

        lines = ["[bold]Primary:[/bold]"]
        lines.append(f"  {primary.id if primary else primary_id}  {primary.name if primary else ''}")

        if support_routes:
            lines.append("\n[bold]Support:[/bold]")
            for r in support_routes:
                sid = ROUTE_PRIMARY[r]
                sp = find_prompt(self.prompts, sid)
                lines.append(f"  {sp.id if sp else sid}  {sp.name if sp else ''}")

        if matched_kws:
            kw_str = " + ".join(dict.fromkeys(matched_kws))
            lines.append(f"\n[dim]Signals: {kw_str}[/dim]")

        lines.append("\n[dim]Press Esc to go back[/dim]")
        self.query_one("#route-result", Static).update("\n".join(lines))

        save_history({
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "command": "route",
            "prompt_id": primary_id,
            "prompt_name": primary.name if primary else primary_id,
            "context": task,
        })

    def action_dismiss_screen(self) -> None:
        self.dismiss(None)


class ComposeScreen(ModalScreen[None]):
    CSS = _DIALOG_CSS.format(cls="ComposeScreen", id="compose-dialog")
    BINDINGS = [Binding("escape", "dismiss_screen", "Back")]

    def __init__(self, prompt: Prompt) -> None:
        super().__init__()
        self.prompt = prompt

    def compose(self) -> ComposeResult:
        with Vertical(id="compose-dialog"):
            yield Label(f"[bold]{self.prompt.id} — {self.prompt.name}[/bold]")
            yield Label("[dim]Enter context/task and press Enter[/dim]")
            yield Input(placeholder="What are you working on?", id="task-input")
            yield Static("", id="compose-result")

    def on_mount(self) -> None:
        self.query_one("#task-input", Input).focus()

    def on_input_submitted(self, event: Input.Submitted) -> None:
        task = event.value.strip()
        result_widget = self.query_one("#compose-result", Static)
        if not task:
            result_widget.update("[red]Task cannot be empty[/red]")
            return

        content = self.prompt.path.read_text() if self.prompt.path.exists() else ""
        composed = f"{content}\n\n---\n\nContext:\n{task}"

        try:
            subprocess.run(["pbcopy"], input=composed.encode(), check=True)
            copy_status = "[green]✓ Copied to clipboard[/green]"
        except Exception:
            copy_status = "[yellow]pbcopy not available[/yellow]"

        from mqlaunch.b2_tui.adapters.obsidian_writer import write_run
        from mqlaunch.b2_tui.core.history import save_history

        out_path = write_run(self.prompt, task, composed)
        save_history({
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "command": "compose",
            "prompt_id": self.prompt.id,
            "prompt_name": self.prompt.name,
            "category": self.prompt.category,
            "context": task,
            "output_file": str(out_path),
        })

        result_widget.update(
            f"{copy_status}\n[green]✓ Saved: {out_path.name}[/green]\n\n[dim]Press Esc to go back[/dim]"
        )

    def action_dismiss_screen(self) -> None:
        self.dismiss(None)


class HistoryScreen(ModalScreen[None]):
    CSS = _DIALOG_CSS.format(cls="HistoryScreen", id="history-dialog")
    BINDINGS = [Binding("escape", "dismiss_screen", "Back")]

    def compose(self) -> ComposeResult:
        from mqlaunch.b2_tui.core.history import _read_entries
        entries = _read_entries(limit=20)
        with Vertical(id="history-dialog"):
            yield Label("[bold]Recent History[/bold]  [dim](20 latest)[/dim]")
            if not entries:
                yield Static("[dim]No history yet — run some commands first.[/dim]")
            else:
                for e in reversed(entries):
                    ts = e.get("timestamp", "")[:16].replace("T", " ")
                    cmd = e.get("command", "?")
                    pid = e.get("prompt_id", "")
                    ctx = (e.get("context", "") or "")[:50]
                    yield Label(f"[dim]{ts}[/dim]  [bold]{cmd}[/bold]  {pid}  [dim]{ctx}[/dim]")
            yield Label("\n[dim]Press Esc to go back[/dim]")

    def action_dismiss_screen(self) -> None:
        self.dismiss(None)


class SearchScreen(ModalScreen[Prompt | None]):
    CSS = _DIALOG_CSS.format(cls="SearchScreen", id="search-dialog")
    BINDINGS = [Binding("escape", "dismiss_screen", "Back")]

    def __init__(self, prompts: list[Prompt]) -> None:
        super().__init__()
        self.prompts = prompts

    def compose(self) -> ComposeResult:
        with Vertical(id="search-dialog"):
            yield Label("[bold]Search Prompts[/bold]  [dim]— type to filter, Enter to select[/dim]")
            yield Input(placeholder="Search by ID, name or category…", id="search-input")
            yield ListView(id="search-results")

    def on_mount(self) -> None:
        self.query_one("#search-input", Input).focus()
        self._populate("")

    def _populate(self, query: str) -> None:
        lv = self.query_one("#search-results", ListView)
        lv.clear()
        q = query.lower()
        matches = [
            p for p in self.prompts
            if not q or q in p.id.lower() or q in p.name.lower() or q in p.category.lower()
        ]
        for p in matches[:30]:
            star = " ★" if p.mq_stack else ""
            lv.append(ListItem(Label(f" {p.id}  {p.name}{star}  [dim]{p.category}[/dim]"), name=p.id))

    def on_input_changed(self, event: Input.Changed) -> None:
        self._populate(event.value)

    def on_list_view_selected(self, event: ListView.Selected) -> None:
        pid = event.item.name
        self.dismiss(next((p for p in self.prompts if p.id == pid), None))

    def action_dismiss_screen(self) -> None:
        self.dismiss(None)
