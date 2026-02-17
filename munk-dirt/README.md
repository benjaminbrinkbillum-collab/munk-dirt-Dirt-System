# munk-dirt

Standalone, server-synced dirt system for FiveM.

## Installation
1. Place the entire `munk-dirt` folder in your `resources` directory.
2. **IMPORTANT:** The folder must be named exactly `munk-dirt` for the script to work correctly.
3. Add to your `server.cfg`:
   ```
   ensure munk-dirt
   ```
4. Run the `sql.sql` file in your database if you want to save dirt levels.

## Features
- Vehicles get dirty over time, faster in rain and offroad.
- Extra dirt if you drive through water or in harbor/factory areas (oil effect).
- Dirt level is synced for all players.
- Fully configurable in `config.lua`.

## Configuration
See and adjust values in `config.lua` for dirt speed, zones, and effects.

## Requirements
- FiveM server 
- oxmysql or mysql-async (optional, only if you want to save dirt in a database)

## Support
Contact Munk for help or suggestions.
