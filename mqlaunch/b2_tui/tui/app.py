from __future__ import annotations

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal
from textual.events import Key
from textual.widgets import Footer, Header, Label, ListItem, ListView, Static

from mqlaunch.b2_tui.models import Prompt

_CSS = """
#main-grid {
    layout: horizontal;
    height: 1fr;
}
#categories {
    width: 30;
    border: solid $primary-darken-2;
}
#projects {
    width: 1fr;
    border: solid $primary-darken-2;
}
#preview {
    height: 11;
    border: solid $secondary-darken-2;
    padding: 0 2;
    overflow-y: auto;
}
"""


class B2App(App[None]):
    TITLE = "B2 Atlas Prompt OS"
    CSS = _CSS
    BINDINGS = [
        Binding("q", "quit", "Quit", priority=True),
        Binding("r", "route_task", "Route"),
        Binding("c", "compose_prompt", "Compose"),
        Binding("h", "show_history", "History"),
        Binding("v", "run_validate", "Validate"),
        Binding("slash", "open_search", "Search"),
        Binding("tab", "focus_next", "Next", show=False),
        Binding("shift+tab", "focus_previous", "Prev", show=False),
    ]

    def __init__(self, prompts: list[Prompt]) -> None:
        super().__init__()
        self.prompts = prompts
        self._categories: list[str] = []
        self._selected_category: str | None = None
        self._selected_prompt: Prompt | None = None

    def _get_categories(self) -> list[str]:
        seen: list[str] = []
        for p in self.prompts:
            if p.category not in seen:
                seen.append(p.category)
        return seen

    def _prompts_for(self, category: str | None) -> list[Prompt]:
        if category is None:
            return self.prompts
        return [p for p in self.prompts if p.category == category]

    def compose(self) -> ComposeResult:
        yield Header()
        with Horizontal(id="main-grid"):
            yield ListView(id="categories")
            yield ListView(id="projects")
        yield Static("", id="preview")
        yield Footer()

    def on_mount(self) -> None:
        self._categories = self._get_categories()
        cat_lv = self.query_one("#categories", ListView)
        for cat in self._categories:
            cat_lv.append(ListItem(Label(f" {cat}"), name=cat))
        if self._categories:
            self._selected_category = self._categories[0]
            self._refresh_projects()
        cat_lv.focus()

    def _refresh_projects(self) -> None:
        proj_lv = self.query_one("#projects", ListView)
        proj_lv.clear()
        for p in self._prompts_for(self._selected_category):
            star = " ★" if p.mq_stack else ""
            proj_lv.append(ListItem(Label(f" {p.id}  {p.name}{star}"), name=p.id))
        filtered = self._prompts_for(self._selected_category)
        self._selected_prompt = filtered[0] if filtered else None
        self._refresh_preview()

    def _refresh_preview(self) -> None:
        preview = self.query_one("#preview", Static)
        p = self._selected_prompt
        if p is None:
            preview.update("[dim]No prompt selected[/dim]")
            return
        lines: list[str] = [f"[bold]{p.id} — {p.name}[/bold]"]
        if p.mq_stack:
            lines.append(f"[dim]mq-stack: {p.mq_stack}[/dim]")
        lines.append("─" * 44)
        if p.path.exists():
            content = p.path.read_text().splitlines()
            lines.extend(content[:7])
            if len(content) > 7:
                lines.append(f"[dim]… ({len(content)} lines)[/dim]")
        else:
            lines.append("[red]File not found on disk[/red]")
        preview.update("\n".join(lines))

    def on_list_view_highlighted(self, event: ListView.Highlighted) -> None:
        if event.item is None:
            return
        if event.list_view.id == "categories":
            cat = event.item.name
            if cat != self._selected_category:
                self._selected_category = cat
                self._refresh_projects()
        elif event.list_view.id == "projects":
            pid = event.item.name
            self._selected_prompt = next(
                (p for p in self._prompts_for(self._selected_category) if p.id == pid), None
            )
            self._refresh_preview()

    def on_list_view_selected(self, event: ListView.Selected) -> None:
        if event.list_view.id == "categories":
            self.query_one("#projects", ListView).focus()
        elif event.list_view.id == "projects" and self._selected_prompt is not None:
            self.action_compose_prompt()

    def on_key(self, event: Key) -> None:
        focused = self.focused
        if isinstance(focused, ListView):
            if event.key == "j":
                focused.action_cursor_down()
                event.prevent_default()
            elif event.key == "k":
                focused.action_cursor_up()
                event.prevent_default()

    def action_route_task(self) -> None:
        from mqlaunch.b2_tui.tui.screens import RouteScreen
        self.push_screen(RouteScreen(self.prompts))

    def action_compose_prompt(self) -> None:
        if self._selected_prompt is None:
            self.notify("Select a prompt first", severity="warning")
            return
        from mqlaunch.b2_tui.tui.screens import ComposeScreen
        self.push_screen(ComposeScreen(self._selected_prompt))

    def action_show_history(self) -> None:
        from mqlaunch.b2_tui.tui.screens import HistoryScreen
        self.push_screen(HistoryScreen())

    def action_run_validate(self) -> None:
        import argparse
        import io
        import sys
        from mqlaunch.b2_tui.core.validator import cmd_validate
        buf = io.StringIO()
        old_stdout, sys.stdout = sys.stdout, buf
        code = cmd_validate(self.prompts, argparse.Namespace())
        sys.stdout = old_stdout
        out = buf.getvalue().strip()
        lines = out.splitlines()[:5]
        msg = "\n".join(lines) if lines else ("All OK" if code == 0 else "Validate failed")
        self.notify(msg, severity="information" if code == 0 else "warning", timeout=8)

    def action_open_search(self) -> None:
        from mqlaunch.b2_tui.tui.screens import SearchScreen

        def on_result(prompt: Prompt | None) -> None:
            if prompt is None:
                return
            self._selected_category = prompt.category
            self._refresh_projects()
            proj_lv = self.query_one("#projects", ListView)
            for i, p in enumerate(self._prompts_for(self._selected_category)):
                if p.id == prompt.id:
                    proj_lv.index = i
                    break
            proj_lv.focus()

        self.push_screen(SearchScreen(self.prompts), on_result)
