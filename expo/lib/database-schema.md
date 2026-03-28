# SQLite Database Schema

## Overview
The game uses SQLite for persistent storage of characters, party state, and game progress.

## Tables

### characters
Stores all character data including stats, equipment, and progression.

```sql
CREATE TABLE characters (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  class TEXT NOT NULL,
  level INTEGER DEFAULT 1,
  xp INTEGER DEFAULT 0,
  str INTEGER NOT NULL,
  dex INTEGER NOT NULL,
  con INTEGER NOT NULL,
  int INTEGER NOT NULL,
  wis INTEGER NOT NULL,
  cha INTEGER NOT NULL,
  maxHP INTEGER NOT NULL,
  currentHP INTEGER NOT NULL,
  gold INTEGER DEFAULT 0,
  weapon TEXT,
  armor TEXT,
  items TEXT,
  created_at INTEGER DEFAULT (unixepoch()),
  updated_at INTEGER DEFAULT (unixepoch())
);
```

### party
Tracks which characters are in the active party and their order.

```sql
CREATE TABLE party (
  character_id TEXT PRIMARY KEY,
  position INTEGER NOT NULL,
  FOREIGN KEY (character_id) REFERENCES characters(id) ON DELETE CASCADE
);
```

### game_state
Stores current game state including position, dungeon level, and combat.

```sql
CREATE TABLE game_state (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  position_x INTEGER DEFAULT 0,
  position_y INTEGER DEFAULT 0,
  facing TEXT DEFAULT 'north',
  dungeon_level INTEGER DEFAULT 1,
  dungeon_data TEXT,
  combat_state TEXT,
  updated_at INTEGER DEFAULT (unixepoch())
);
```

## Indexes
- `idx_party_position` - For efficient party ordering
- `idx_characters_class` - For filtering by character class
- `idx_characters_level` - For filtering by level

## API Functions

### Character Management
- `saveCharacter(character)` - Save or update a character
- `getCharacter(id)` - Retrieve a single character
- `getAllCharacters()` - Get all characters
- `deleteCharacter(id)` - Delete a character

### Party Management
- `saveParty(party)` - Save the current party (replaces existing)
- `getParty()` - Get the current party in order

### Game State
- `saveGameState(position, dungeonLevel, combatState)` - Save game progress
- `getGameState()` - Load game progress

### Utilities
- `initDatabase()` - Initialize database and create tables
- `resetDatabase()` - Clear all data and reset to defaults

### monsters
Stores monster definitions with image references.

```sql
CREATE TABLE monsters (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  maxHP INTEGER NOT NULL,
  attack INTEGER NOT NULL,
  defense INTEGER NOT NULL,
  xpReward INTEGER NOT NULL,
  goldReward INTEGER NOT NULL,
  canFlee INTEGER DEFAULT 0,
  canCallAllies INTEGER DEFAULT 0,
  imageAsset TEXT,
  created_at INTEGER DEFAULT (unixepoch())
);
```

### dungeon_walls
Stores wall art image references for dungeon rendering.

```sql
CREATE TABLE dungeon_walls (
  id TEXT PRIMARY KEY,
  position TEXT NOT NULL,
  imageAsset TEXT NOT NULL,
  created_at INTEGER DEFAULT (unixepoch())
);
```

## Future Expansion Ideas
- Items/Inventory table with foreign keys to characters
- Quest/Achievement tables
- Dungeon persistence (save discovered rooms)
- Monster bestiary (track encountered monsters)
- Spell/Ability tables
- Equipment stats and modifiers
- Death/resurrection history
