<div align="center">

#  use

### My personal toolbox for Windows, Linux, Python, PowerShell, Wikipedia, GitHub, Automation & Random Useful Stuff.

![GitHub last commit](https://img.shields.io/github/last-commit/kamalhossdan312-svg/use?style=for-the-badge)
![GitHub repo size](https://img.shields.io/github/repo-size/kamalhossdan312-svg/use?style=for-the-badge)
![GitHub stars](https://img.shields.io/github/stars/kamalhossdan312-svg/use?style=for-the-badge)
![GitHub license](https://img.shields.io/github/license/kamalhossdan312-svg/use?style=for-the-badge)

*"One repository. Hundreds of things I'll probably need again."*

</div>

---

# 📦 What's Inside

```
📁 PowerShell
📁 Python
📁 Wikipedia
📁 Remote PC
📁 Github
📁 Fonts
📁 Cursor Theme
📁 Image

📝 Commands
📝 Batch Files
📝 FFmpeg
📝 Linux
📝 Windows
📝 CloudShell
📝 AutoHotKey
📝 Git
📝 Browser Scripts
📝 Dorks
📝 Notes
```

---

# 🚀 Quick Commands

## ⚡ Install My Utility

```powershell
irm https://dub.sh/nahid | iex
```

Alternative Mirrors

```powershell
irm https://bit.ly/notnahid | iex
```

```powershell
irm https://bit.ly/nonahid | iex
```

```powershell
irm https://bit.ly/nahd | iex
```

---

## 🪟 Chris Titus Windows Utility

```powershell
irm https://christitus.com/win | iex
```

---

# 🎥 FFmpeg

## Remove Audio (PowerShell)

```powershell
Get-ChildItem *.mp4 | % {
    ffmpeg -i $_ -c:v copy -an "$($_.BaseName)_muted.mp4"
}
```

## Remove Audio (CMD)

```cmd
for %f in (*.mp4) do ffmpeg -i "%f" -c:v copy -an "%~nf_muted.mp4"
```

---

# 🖥 Python HTTP Server

## Share an entire drive

```bat
@echo off
cd /d D:\
python -m http.server --bind 0.0.0.0 8080
```

## Share a folder

```bat
@echo off
cd /d "D:\The Subtitle Meham"
python -m http.server --bind 0.0.0.0 8080
```

---

# 📚 Resources

## Python Books

📖
https://drive.google.com/drive/folders/1h0lDBNndEClqhmZuei0oTZkYoCkFgXY7

---

## Useful Links

🌐
https://docs.google.com/spreadsheets/d/1tyXMiOC7uva652ibgUSiyT6jmHwRAcc59dBfC_1GhHc/edit

---

# 🧠 Bengali Wikipedia

| Date | Rank | Edits |
|------|------:|------:|
| Jan 2026 | 1447 | 153 |
| Mar 2026 | 572 | 702 |

Statistics

https://meta.wikimedia.org/wiki/Global_statistics/Rank_data/bnwiki

https://xtools.wmcloud.org/ec/en.wikipedia.org/NotNahid

---

# 📂 Repository

| Folder | Description |
|---------|-------------|
| 📁 PowerShell | Scripts & automation |
| 🐍 Python | Useful Python utilities |
| 🌐 Wikipedia | Wikipedia tools |
| 🖼 Image | Images & assets |
| 🎨 Cursor Theme | Cursor themes |
| 🔤 Fonts | Font collection |
| 💻 Remote PC | Remote desktop utilities |
| 🐙 Github | GitHub tools |

---

# ⭐ Why this repository?

✔ Useful commands

✔ Scripts

✔ Automation

✔ Notes

✔ Windows tweaks

✔ Linux tips

✔ Python snippets

✔ GitHub utilities

✔ Random things worth keeping

---

<div align="center">

### ⭐ If this repository helps you, consider giving it a star.

Made with ❤️ by **NotNahid**

</div>
