# 📚 Public Resources & Useful Notes

A collection of useful scripts, commands, and resources I use regularly.

---

# ⚡ NotNahid Utility

### Main

```powershell
irm https://dub.sh/nahid | iex
```

### Mirror 1

```powershell
irm https://bit.ly/notnahid | iex
```

### Mirror 2

```powershell
irm https://bit.ly/nonahid | iex
```

### Mirror 3

```powershell
irm https://bit.ly/nahd | iex
```

### PowerShell Gallery

https://www.powershellgallery.com/packages/notnahid

---

# 🪟 Chris Titus Windows Utility

Website

https://christitus.com/windows-utility-improved/

Run in PowerShell

```powershell
irm https://christitus.com/win | iex
```

---

# 📚 Python Books

https://drive.google.com/drive/folders/1h0lDBNndEClqhmZuei0oTZkYoCkFgXY7

---

# 🌐 Useful Links

https://docs.google.com/spreadsheets/d/1tyXMiOC7uva652ibgUSiyT6jmHwRAcc59dBfC_1GhHc/edit?usp=sharing

---

# 🎬 FFmpeg

## Remove audio from all MP4 files (PowerShell)

```powershell
Get-ChildItem *.mp4 | % {
    ffmpeg -i $_ -c:v copy -an "$($_.BaseName)_muted.mp4"
}
```

## Remove audio from all MP4 files (Command Prompt)

```cmd
for %f in (*.mp4) do ffmpeg -i "%f" -c:v copy -an "%~nf_muted.mp4"
```

---

# 🧠 Bengali Wikipedia

## January 16, 2026

- Rank: **1447**
- Username: **NotNahid**
- Total Edits: **153**

## March 30, 2026

- Rank: **572**
- Username: **NotNahid**
- Total Edits: **702**

Statistics

https://meta.wikimedia.org/wiki/Global_statistics/Rank_data/bnwiki

https://xtools.wmcloud.org/ec/en.wikipedia.org/NotNahid

---

# 🖥️ Python HTTP Server

## Serve D:\

```bat
@echo off
cd /d D:\
python -m http.server --bind 0.0.0.0 8080
```

## Serve a specific folder

```bat
@echo off
cd /d "D:\The Subtitle Meham"
python -m http.server --bind 0.0.0.0 8080
```
