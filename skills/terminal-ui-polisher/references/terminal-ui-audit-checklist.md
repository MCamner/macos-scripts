# Terminal UI Audit Checklist

## 1. First screen

- Is the current mode obvious?
- Is the app name clear?
- Is there a readable hierarchy?
- Is the next action obvious?
- Does the screen fit normal terminal sizes?

## 2. Header

A strong header can include:

- App name
- Mode
- Host
- User
- Path or repo
- Time
- Status

Avoid making the header taller than the content.

## 3. Menus

Check:

- Are actions grouped logically?
- Are destructive actions separated?
- Are shortcut keys memorable?
- Is there a clear Back/Quit behavior?
- Are numbers reused consistently?
- Is there a help command?

## 4. Status feedback

Every command should clearly return one of:

- ready
- running
- success
- warning
- failed
- partial
- skipped

Avoid silent failure.

## 5. Error states

Good terminal errors should include:

- What failed
- Why it probably failed
- What the user can do next
- The exact command to retry, when useful

## 6. Width and layout

Check:

- Does the UI degrade gracefully in narrow terminals?
- Are long paths truncated safely?
- Are tables aligned?
- Are columns worth the complexity?
- Are separators dynamic?

## 7. Color

Use colors sparingly:

- Title / accent
- Success
- Warning
- Error
- Muted text

Never rely on color alone.

## 8. Product feel

A polished terminal tool feels like:

- A system, not a script
- A cockpit, not a dump
- A calm command surface, not a toy
