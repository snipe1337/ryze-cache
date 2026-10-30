# ryze cache cleaner

a minimal, safe cache cleaner for windows 10/11. nukes regenerable junk, shader caches, and leftover app bloat without touching your personal files, logins, browser cookies, or game saves.

easily reclaims anywhere from 10 gb to 40+ gb of dead space (cleared 38.5 gb on a regular setup).

---

### what it cleans

* **system & temp:** user temp, windows temp, crash minidumps, memory dumps, delivery optimization, and update cache.
* **gpu caches:** directx shader caches, nvidia dxcache/glcache/nv, and amd cache.
* **browsers:** chrome, edge, and opera disk caches, code caches, and gpu caches across profiles.
* **media & game launchers:** spotify stream caches (often 8-10+ gb alone), steam web cache, epic games launcher cache, battle.net.
* **discord:** discord, discord canary, and ptb electron cache files.
* **dev tools:** vs code bytecode caches, go build cache, pip, npm, yarn, cargo, and gradle caches.

---

### quick run

run directly via powershell (no download needed):

```powershell
irm https://raw.githubusercontent.com/snipe1337/ryze-cache/main/ryze-cache-cleaner.ps1 | iex
```

or clone and run locally:

```cmd
powershell -ep bypass -file .\ryze-cache-cleaner.ps1
```

*prompts for uac admin automatically on launch.*

---

### credits

ryze [snipe1337] on github
