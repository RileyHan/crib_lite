# Skunked

Skunked is a cribbage roguelite built with Godot 4.x and GDScript. Development is
incremental; this initial milestone creates the project shell and does not yet
implement gameplay.

## Keep the working copy on your local Desktop

The project files belong in a normal local Windows Desktop folder, not a
cloud-synced, virtual, or redirected folder. Before cloning, check the Desktop
folder's **Properties → Location** in File Explorer. Confirm that it is
`C:\Users\<YourWindowsUsername>\Desktop`, is not under OneDrive, and is not
redirected. If it is redirected, restore the local Desktop location before
cloning. Then, in PowerShell, clone the repository into:

```powershell
git clone https://github.com/RileyHan/crib_lite.git "$env:USERPROFILE\Desktop\Skunked"
```

The repository checkout used to prepare this project is an agent workspace; it
does not place files on your personal PC. GitHub synchronization transfers
source files, but does not choose or change the location of your local working
copy.

## Open and run

1. Install Godot 4.x for Windows.
2. In Godot's Project Manager, choose **Import** and select
   `C:\Users\<YourWindowsUsername>\Desktop\Skunked\project.godot`.
3. Open the project and press **F6** to run the current scene or **F5** to run
   the project. The current scene is a placeholder welcome screen.

No paid assets or third-party game dependencies are required.

## GitHub

For a fresh local project without a remote, add the GitHub repository as `origin`
from the project folder:

```powershell
git init
git add .
git commit -m "Initialize Skunked Godot project"
git branch -M main
git remote add origin https://github.com/RileyHan/crib_lite.git
git push -u origin main
```

If you cloned the repository using the command above, `origin` is already
configured. Use `git pull` and `git push` to synchronize changes.

## Project layout

- `scenes/` — reusable Godot scenes, grouped by game area.
- `scripts/` — future GDScript systems, separated by responsibility.
- `resources/` — data-driven cards, perks, opponents, bosses, and encounters.
- `assets/` — project-owned art, audio, and fonts; placeholder folders are kept
  for future work.
- `docs/` — game design, technical design, and the development roadmap.
- `tests/` — planned gameplay-rule tests.

See `docs/DEVELOPMENT_ROADMAP.md` for the staged development plan and
`.github/copilot-instructions.md` for contribution requirements.
