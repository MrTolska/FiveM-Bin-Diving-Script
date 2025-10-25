# VX Bins – Dumpster Scavenging Script
A FiveM script that allows players to search dumpsters, grab bin bags, rummage through them for loot, and track scavenging reputation.

**Features:**
- Grab bin bags from dumpsters.
- Rummage/search through bin bags for items.
- Configurable loot table with tiers and weighted chances.
- Scavenging reputation system stored in QBCore metadata.
- Optional Discord webhook and FiveMerr logging.
- Cooldowns per bin to prevent repeated searching.
- Progress UI and interactive text prompts.

**Installation:**  
Place the resource in your server’s resource folder. Add it to `server.cfg` using:


**Usage:**  
- Walk up to a dumpster and press the prompt key to grab a bin bag.  
- Use `[E]` to search the bag and `[G]` to discard it.  
- Cooldowns prevent searching the same dumpster repeatedly.  
- Track your scavenging reputation using `/binrep`.

**Loot System:**  
- Items are rolled based on configured chance and tier.  
- Reputation increases chance for higher tier loot.  
- Can be configured for single or multiple item rolls.

**Author:**  
Bamm / MrTolska – [GitHub Profile](https://github.com/MrTolska)

**Notes:**  
- Client-side only interactions for bag grabbing and searching.  
- Server-side handles rep, loot distribution, cooldowns, and logging.  
- Compatible with QBCore framework.  
- Optional integrations: Discord webhooks and FiveMerr logs.
