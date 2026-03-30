#!/usr/bin/env python3

import os, sys, subprocess, time, getpass, json

# ─── auto install dependencies ───────────────────────────────────────────────
def install(pkg):
    subprocess.check_call([sys.executable, "-m", "pip", "install", pkg, "-q"])

for pkg in ["rich", "colorama"]:
    try:
        __import__(pkg)
    except ImportError:
        print(f"📦 Installing {pkg}...")
        install(pkg)

from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.prompt import Prompt, Confirm
from rich.progress import Progress, SpinnerColumn, TextColumn
from rich.text import Text
from rich.align import Align
from rich import box
from rich.rule import Rule
import getpass as gp

console = Console()

CONFIG_FILE = os.path.expanduser("~/.git_gittool.json")

BANNER = """[bold cyan]
  ██████  ██ ████████     ████████  ██████   ██████  ██      
 ██       ██    ██           ██    ██    ██ ██    ██ ██      
 ██   ███ ██    ██           ██    ██    ██ ██    ██ ██      
 ██    ██ ██    ██           ██    ██    ██ ██    ██ ██      
  ██████  ██    ██           ██     ██████   ██████  ███████ 
[/bold cyan]"""

VERSION = "v10.0 — Production"

# ─── helpers ──────────────────────────────────────────────────────────────────

def clear():
    os.system("clear" if os.name == "posix" else "cls")

def run(cmd, capture=False):
    if capture:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return result.stdout.strip(), result.returncode
    return os.system(cmd)

def ask(msg, password=False):
    while True:
        try:
            if password:
                v = gp.getpass(f"  {msg}: ").strip()
            else:
                v = Prompt.ask(f"  [cyan]{msg}[/cyan]")
            if v:
                return v
            console.print("  [red]❌ Required[/red]")
        except KeyboardInterrupt:
            console.print("\n  [yellow]👋 Cancelled[/yellow]")
            sys.exit()

def success(msg):
    console.print(f"\n  [bold green]✅ {msg}[/bold green]")
    time.sleep(1)

def error(msg):
    console.print(f"\n  [bold red]❌ {msg}[/bold red]")
    time.sleep(1.5)

def info(msg):
    console.print(f"\n  [bold yellow]ℹ️  {msg}[/bold yellow]")

# ─── config ───────────────────────────────────────────────────────────────────

def load_config():
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, "r") as f:
            return json.load(f)
    return None

def save_config(cfg):
    with open(CONFIG_FILE, "w") as f:
        json.dump(cfg, f)
    os.chmod(CONFIG_FILE, 0o600)

def delete_config():
    if os.path.exists(CONFIG_FILE):
        os.remove(CONFIG_FILE)

# ─── git helpers ──────────────────────────────────────────────────────────────

def has_git(path):
    return os.path.exists(os.path.join(path, ".git"))

def ensure_git(path):
    if not has_git(path):
        info("No .git found — initializing repo...")
        os.system("git init -b main")
        success("Git repo initialized")

def get_branch():
    out, _ = run("git branch --show-current", capture=True)
    return out or "main"

def get_remote():
    out, _ = run("git remote get-url origin", capture=True)
    return out or None

def get_status():
    out, _ = run("git status --porcelain", capture=True)
    return out

def get_log():
    out, _ = run("git log --oneline -5", capture=True)
    return out

def inject_token(url, user, token):
    if "https://" in url:
        return url.replace("https://", f"https://{user}:{token}@")
    return url

# ─── gitignore ────────────────────────────────────────────────────────────────

def create_gitignore():
    content = """__pycache__/
*.pyc
*.pyo
.env
venv/
env/
*.db
*.sqlite3
*.log
.DS_Store
node_modules/
.idea/
.vscode/
*.zip
"""
    if not os.path.exists(".gitignore"):
        with open(".gitignore", "w") as f:
            f.write(content)
        success(".gitignore created")
    else:
        info(".gitignore already exists")

# ─── UI components ────────────────────────────────────────────────────────────

def print_banner():
    clear()
    console.print(BANNER)
    console.print(Align.center(f"[dim]{VERSION}[/dim]\n"))

def print_status_panel(path):
    branch = get_branch()
    remote = get_remote() or "[dim]not set[/dim]"
    status_raw = get_status()

    info_table = Table(box=None, show_header=False, padding=(0, 2))
    info_table.add_column(style="dim",       width=10)
    info_table.add_column(style="bold cyan")
    info_table.add_row("branch", branch)
    info_table.add_row("remote", remote)
    info_table.add_row("path",   path)
    console.print(Panel(info_table, title="[bold cyan]● REPO[/bold cyan]", border_style="cyan", box=box.ROUNDED))

    status_table = Table(box=box.SIMPLE, show_header=False, padding=(0, 1))
    status_table.add_column(width=4)
    status_table.add_column()

    if status_raw:
        for line in status_raw.splitlines():
            flag  = line[:2].strip()
            fname = line[3:]
            color = "yellow" if flag in ("M", "MM") else "green" if flag in ("A", "AM") else "red" if flag == "D" else "dim"
            flag  = "?" if flag == "??" else flag
            status_table.add_row(f"[{color}]{flag}[/{color}]", f"[{color}]{fname}[/{color}]")
    else:
        status_table.add_row("[green]✓[/green]", "[dim]clean — nothing to commit[/dim]")

    console.print(Panel(status_table, title="[bold yellow]● STATUS[/bold yellow]", border_style="yellow", box=box.ROUNDED))

def print_menu():
    menu = Table(box=box.SIMPLE, show_header=False, padding=(0, 3))
    menu.add_column(width=22)
    menu.add_column(width=22)
    menu.add_row("[bold cyan]\\[1][/bold cyan] Commit",         "[bold cyan]\\[2][/bold cyan] Push")
    menu.add_row("[bold cyan]\\[3][/bold cyan] Full Deploy",    "[bold cyan]\\[4][/bold cyan] Dashboard")
    menu.add_row("[bold cyan]\\[5][/bold cyan] .gitignore",     "[bold cyan]\\[6][/bold cyan] Undo commit")
    menu.add_row("[bold cyan]\\[7][/bold cyan] Switch account", "[bold cyan]\\[8][/bold cyan] Exit")
    console.print(Panel(menu, title="[bold green]● ACTIONS[/bold green]", border_style="green", box=box.ROUNDED))

# ─── auth ─────────────────────────────────────────────────────────────────────

def auth():
    cfg = load_config()
    console.print(Panel("[bold cyan]🔐 Authentication[/bold cyan]", border_style="cyan", box=box.ROUNDED))

    if cfg:
        console.print(f"\n  [dim]Saved account:[/dim] [bold cyan]{cfg['user']}[/bold cyan]")
        choice = ask("Use saved login? (yes / no / delete)")
        if choice.lower() == "yes":
            return cfg
        if choice.lower() == "delete":
            delete_config()
            success("Saved login deleted")
            return auth()

    user  = ask("GitHub Username")
    email = ask("Email")
    token = ask("GitHub Token (hidden)", password=True)

    cfg = {"user": user, "email": email, "token": token}
    save_config(cfg)
    success(f"Logged in as {user}")
    return cfg

# ─── actions ──────────────────────────────────────────────────────────────────

def do_commit():
    console.print(Rule("[yellow]Commit[/yellow]"))
    run("git add .")
    msg = ask("Commit message")
    msg = msg.replace('"', "'")

    _, code = run("git diff --cached --quiet", capture=True)
    if code == 0:
        error("Nothing to commit")
        return

    with Progress(SpinnerColumn(style="cyan"), TextColumn("[cyan]Committing...[/cyan]"), transient=True, console=console) as p:
        p.add_task("", total=None)
        _, code = run(f'git commit -m "{msg}"', capture=True)

    if code == 0:
        success("Committed successfully")
    else:
        error("Commit failed")

def do_push(cfg):
    console.print(Rule("[yellow]Push[/yellow]"))
    remote = get_remote()

    if not remote:
        error("No remote set — use Full Deploy (3) first")
        return

    if not Confirm.ask("  [cyan]Push to GitHub?[/cyan]"):
        return

    auth_remote = inject_token(remote, cfg["user"], cfg["token"])

    with Progress(SpinnerColumn(style="cyan"), TextColumn("[cyan]Pushing...[/cyan]"), transient=True, console=console) as p:
        p.add_task("", total=None)
        _, code = run(f'git push {auth_remote}', capture=True)

    if code == 0:
        success("Pushed successfully 🚀")
    else:
        console.print("  [yellow]Trying force push...[/yellow]")
        _, code = run(f'git push {auth_remote} --force', capture=True)
        if code == 0:
            success("Force pushed successfully 🚀")
        else:
            error("Push failed — check token and repo name")

def do_deploy(cfg):
    console.print(Rule("[yellow]Full Deploy[/yellow]"))
    repo_name = ask("GitHub repo name")
    create_gitignore()

    console.print("\n  [dim]Current status:[/dim]")
    run("git status -s")

    if not Confirm.ask("\n  [cyan]Continue with deploy?[/cyan]"):
        return

    run("git add .")
    msg = ask("Commit message")
    msg = msg.replace('"', "'")

    _, code = run("git diff --cached --quiet", capture=True)
    if code != 0:
        with Progress(SpinnerColumn(style="cyan"), TextColumn("[cyan]Committing...[/cyan]"), transient=True, console=console) as p:
            p.add_task("", total=None)
            run(f'git commit -m "{msg}"', capture=True)

    remote_url = f"https://{cfg['user']}:{cfg['token']}@github.com/{cfg['user']}/{repo_name}.git"
    os.system(f'git remote add origin {remote_url} 2>/dev/null || git remote set-url origin {remote_url}')

    if not Confirm.ask("  [cyan]Push to GitHub now?[/cyan]"):
        return

    with Progress(SpinnerColumn(style="cyan"), TextColumn("[cyan]Deploying...[/cyan]"), transient=True, console=console) as p:
        p.add_task("", total=None)
        _, code = run("git push -u origin main --force", capture=True)

    if code == 0:
        console.print(Panel(
            f"[bold green]🚀 Deployed![/bold green]\n\n  [dim]https://github.com/{cfg['user']}/{repo_name}[/dim]",
            border_style="green", box=box.ROUNDED
        ))
    else:
        error("Deploy failed — make sure the repo exists on github.com/new")

    time.sleep(2)

def do_dashboard():
    console.print(Rule("[cyan]Dashboard[/cyan]"))
    branch = get_branch()
    log    = get_log()
    remote = get_remote() or "none"

    log_table = Table(box=box.SIMPLE, show_header=False, padding=(0, 1))
    log_table.add_column(style="cyan",  width=10)
    log_table.add_column(style="white")

    if log:
        for line in log.splitlines():
            parts = line.split(" ", 1)
            if len(parts) == 2:
                log_table.add_row(parts[0], parts[1])
    else:
        log_table.add_row("—", "[dim]no commits yet[/dim]")

    console.print(Panel(log_table, title=f"[cyan]● Last 5 commits — {branch}[/cyan]", border_style="cyan", box=box.ROUNDED))
    console.print(f"  [dim]remote:[/dim] [cyan]{remote}[/cyan]\n")
    input("  Press Enter to go back...")

def do_undo():
    console.print(Rule("[red]Undo Last Commit[/red]"))
    if Confirm.ask("  [red]Undo last commit? (your files are kept)[/red]"):
        run("git reset --soft HEAD~1")
        success("Last commit undone — files kept")

# ─── boot ─────────────────────────────────────────────────────────────────────

print_banner()
time.sleep(0.3)

cfg = auth()

os.system(f'git config --global user.name "{cfg["user"]}"')
os.system(f'git config --global user.email "{cfg["email"]}"')

console.print("\n")
console.print(Panel(
    "[cyan]\\[1][/cyan] Current folder\n[cyan]\\[2][/cyan] Custom folder",
    title="[bold cyan]📁 Project Setup[/bold cyan]",
    border_style="cyan", box=box.ROUNDED
))

choice = ask("Choose")
path = os.getcwd() if choice == "1" else ask("Enter full project path")
path = os.path.abspath(path)

if not os.path.isdir(path):
    error(f"Folder does not exist: {path}")
    sys.exit()

os.chdir(path)
ensure_git(path)

# ─── main loop ────────────────────────────────────────────────────────────────

while True:
    print_banner()
    print_status_panel(path)
    print_menu()

    try:
        opt = Prompt.ask("\n  [bold cyan]Choose action[/bold cyan]")
    except KeyboardInterrupt:
        console.print(Panel("[bold cyan]👋 Goodbye![/bold cyan]", border_style="cyan", box=box.ROUNDED))
        break

    if   opt == "1": do_commit()
    elif opt == "2": do_push(cfg)
    elif opt == "3": do_deploy(cfg)
    elif opt == "4": do_dashboard()
    elif opt == "5": create_gitignore(); time.sleep(1)
    elif opt == "6": do_undo()
    elif opt == "7":
        delete_config()
        cfg = auth()
        os.system(f'git config --global user.name "{cfg["user"]}"')
        os.system(f'git config --global user.email "{cfg["email"]}"')
        success(f"Switched to {cfg['user']}")
    elif opt == "8":
        console.print(Panel("[bold cyan]👋 Goodbye![/bold cyan]", border_style="cyan", box=box.ROUNDED))
        break
    else:
        error("Invalid option — choose 1 to 8")
