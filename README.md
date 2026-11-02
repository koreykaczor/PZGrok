This is 100% vibe coded but worked well. Due to Elon Musk stealing $4 from me for a month of x premium + an immediate month-long suspension by overseas activist groups, I will no longer advocate for any of the big frontier models and I have moved onto local AI. 

# Across the River

A Project Zomboid B42 mod. Three broadcasts, rolled fresh every save and written
live while you play — by **Grok**:

- **A radio station** on the FM dial — new call letters, new host, new
  programming every save.
- **A television station** on its own channel, same again.
- **One to fifteen groups of survivors**, each on their own frequency and
  their own radio band, who you can actually talk to and who remember you.
  Most are across the Ohio River in southern Indiana; the ones on the
  long-range amateur bands can be much further off.

The third is the point. The first two are the world it lives in.

This is the Grok port of the original Claude-backed *Across the River*. Same
rules, same file bridge, same knowledge boundaries. The sidecar calls
`grok-4.5` instead of the `claude` CLI.

## What it needs

- Project Zomboid **B42**
- Python 3 (stdlib only — nothing to install)
- An [xAI API key](https://console.x.ai) in `XAI_API_KEY`, or as a single line
  in `~/.config/pzgrok/api_key`

The mod alone works without any of that. Both stations fall back to a scripted
library covering every hour and every stage of the collapse, so nothing is
ever dead air. Only the survivor frequencies need the helper process.

## Install

The zip is two pieces. **Keep the extracted folder.** Only the Lua half goes
into Zomboid.

```bash
# 1. Lua mod — this is what the game loads
cp -r Contents/mods/PZGrok ~/Zomboid/mods/

# 2. Sidecar stays where you unzipped it
#    PZGrok-main/sidecar/pzgrok.sh
#    PZGrok-main/sidecar/pzgrok.py
#    PZGrok-main/sidecar/prompts/
```

Enable **Across the River** in the game's **Mods** screen *for the save you
want to play*. Mods are per-save in B42, so enabling it on the main menu is
not enough.

Then make pressing Play start the helper too — Steam → Project Zomboid →
Properties → Launch Options (use the real path on your machine):

```
/home/YOU/PZGrok-main/sidecar/pzgrok.sh %command%
```

That starts the sidecar, runs the game, and stops the sidecar on exit.

To run the sidecar by hand instead:

```bash
mkdir -p ~/.config/pzgrok
echo 'xai-YOUR-KEY' > ~/.config/pzgrok/api_key
chmod 600 ~/.config/pzgrok/api_key
./sidecar/pzgrok.sh
```

If the sidecar is not running, stations still play from the scripted library.
Survivor frequencies wait ~100s and then go `<no reply>`.

## The rest of it

Finding the survivors, the bands, who they are, the Exclusion Zone, the Knox
Event timeline, permadeath, shared channels, the OOC channel, sandbox
options, transmitting, the file protocol, and transcripts — all of that is
the same design as the original. See the comments in
`42/media/lua/shared/PZGR_Core.lua` and `sidecar/prompts/`.

Bridge files live at `~/Zomboid/Lua/PZGrok/`. Sidecar log:
`~/.local/state/pzgrok.log`. Game log lines are prefixed `PZGrok:`.

## Layout

```
Contents/mods/PZGrok/42/     <- mod.info lives INSIDE 42/, not at the root
  media/
    sandbox-options.txt
    lua/
      shared/  PZGR_Core, PZGR_Json, PZGR_Bridge
      server/  PZGR_Roll, PZGR_Stations, PZGR_Fallback,
               PZGR_Presets, PZGR_Conversation
      client/  PZGR_TalkPanel, PZGR_TestKit, PZGR_InventoryRadio
sidecar/
  pzgrok.py                  <- the daemon
  pzgrok.sh                  <- Steam launch-options wrapper
  prompts/                   <- station.md, survivors.md, ooc.md
```
