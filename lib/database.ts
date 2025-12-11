import { Platform } from 'react-native';
import { Character, Party, Position, DungeonLevel } from '@/types/game';
import { WEAPONS } from '@/constants/gameData';

let SQLite: any = null;
if (Platform.OS !== 'web') {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  SQLite = require('expo-sqlite');
}

let db: any = null;

export async function initDatabase(): Promise<any> {
  if (Platform.OS === 'web') {
    console.log('Database not supported on web, using mock');
    return null;
  }
  
  if (db) return db;
  
  console.log('Initializing SQLite database...');
  db = await SQLite.openDatabaseAsync('wizardry.db');
  
  await db.execAsync(`
    PRAGMA journal_mode = WAL;
    PRAGMA foreign_keys = ON;
    
    CREATE TABLE IF NOT EXISTS characters (
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
    
    CREATE TABLE IF NOT EXISTS party (
      character_id TEXT PRIMARY KEY,
      position INTEGER NOT NULL,
      FOREIGN KEY (character_id) REFERENCES characters(id) ON DELETE CASCADE
    );
    
    CREATE TABLE IF NOT EXISTS cemetery (
      character_id TEXT PRIMARY KEY,
      died_at INTEGER DEFAULT (unixepoch()),
      FOREIGN KEY (character_id) REFERENCES characters(id) ON DELETE CASCADE
    );
    
    CREATE TABLE IF NOT EXISTS game_state (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      position_x INTEGER DEFAULT 0,
      position_y INTEGER DEFAULT 0,
      facing TEXT DEFAULT 'north',
      dungeon_level INTEGER DEFAULT 1,
      dungeon_data TEXT,
      combat_state TEXT,
      updated_at INTEGER DEFAULT (unixepoch())
    );
    
    CREATE TABLE IF NOT EXISTS monsters (
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
    
    CREATE TABLE IF NOT EXISTS dungeon_walls (
      id TEXT PRIMARY KEY,
      position TEXT NOT NULL,
      imageAsset TEXT NOT NULL,
      created_at INTEGER DEFAULT (unixepoch())
    );
    
    CREATE INDEX IF NOT EXISTS idx_party_position ON party(position);
    CREATE INDEX IF NOT EXISTS idx_characters_class ON characters(class);
    CREATE INDEX IF NOT EXISTS idx_characters_level ON characters(level);
    CREATE INDEX IF NOT EXISTS idx_cemetery_died_at ON cemetery(died_at);
    CREATE INDEX IF NOT EXISTS idx_monsters_name ON monsters(name);
    CREATE INDEX IF NOT EXISTS idx_dungeon_walls_position ON dungeon_walls(position);
    
    INSERT OR IGNORE INTO game_state (id) VALUES (1);
  `);
  
  console.log('Database initialized successfully');
  return db;
}

export async function getDatabase(): Promise<any> {
  if (!db) {
    return await initDatabase();
  }
  return db;
}

export async function saveCharacter(character: Character): Promise<void> {
  if (Platform.OS === 'web') return;
  const database = await getDatabase();
  
  await database.runAsync(
    `INSERT OR REPLACE INTO characters 
    (id, name, class, level, xp, str, dex, con, int, wis, cha, maxHP, currentHP, gold, weapon, armor, items, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, unixepoch())`,
    [
      character.id,
      character.name,
      character.class,
      character.level,
      character.xp,
      character.attributes.STR,
      character.attributes.DEX,
      character.attributes.CON,
      character.attributes.INT,
      character.attributes.WIS,
      character.attributes.CHA,
      character.maxHP,
      character.currentHP,
      character.gold,
      character.equipment.weapon.name,
      character.equipment.armor,
      JSON.stringify(character.equipment.items)
    ]
  );
  
  console.log(`Character ${character.name} saved to database`);
}

export async function getCharacter(id: string): Promise<Character | null> {
  if (Platform.OS === 'web') return null;
  const database = await getDatabase();
  
  const row: any = await database.getFirstAsync(
    'SELECT * FROM characters WHERE id = ?',
    [id]
  );
  
  if (!row) return null;
  
  return {
    id: row.id,
    name: row.name,
    class: row.class,
    level: row.level,
    xp: row.xp,
    attributes: {
      STR: row.str,
      DEX: row.dex,
      CON: row.con,
      INT: row.int,
      WIS: row.wis,
      CHA: row.cha
    },
    maxHP: row.maxHP,
    currentHP: row.currentHP,
    gold: row.gold,
    equipment: {
      weapon: WEAPONS[row.weapon] || { name: row.weapon, type: 'melee', damage: '1d6' },
      armor: row.armor,
      items: JSON.parse(row.items || '[]')
    }
  };
}

export async function getAllCharacters(): Promise<Character[]> {
  if (Platform.OS === 'web') return [];
  const database = await getDatabase();
  
  const rows: any[] = await database.getAllAsync(
    'SELECT * FROM characters ORDER BY created_at DESC'
  );
  
  return rows.map((row: any) => ({
    id: row.id,
    name: row.name,
    class: row.class,
    level: row.level,
    xp: row.xp,
    attributes: {
      STR: row.str,
      DEX: row.dex,
      CON: row.con,
      INT: row.int,
      WIS: row.wis,
      CHA: row.cha
    },
    maxHP: row.maxHP,
    currentHP: row.currentHP,
    gold: row.gold,
    equipment: {
      weapon: WEAPONS[row.weapon] || { name: row.weapon, type: 'melee', damage: '1d6' },
      armor: row.armor,
      items: JSON.parse(row.items || '[]')
    }
  }));
}

export async function deleteCharacter(id: string): Promise<void> {
  if (Platform.OS === 'web') return;
  const database = await getDatabase();
  
  await database.runAsync('DELETE FROM characters WHERE id = ?', [id]);
  console.log(`Character ${id} deleted from database`);
}

export async function saveParty(party: Party): Promise<void> {
  if (Platform.OS === 'web') return;
  const database = await getDatabase();
  
  await database.runAsync('DELETE FROM party');
  
  for (let i = 0; i < party.length; i++) {
    await saveCharacter(party[i]);
    await database.runAsync(
      'INSERT INTO party (character_id, position) VALUES (?, ?)',
      [party[i].id, i]
    );
  }
  
  console.log(`Party with ${party.length} members saved to database`);
}

export async function getParty(): Promise<Party> {
  if (Platform.OS === 'web') return [];
  const database = await getDatabase();
  
  const rows: any[] = await database.getAllAsync(
    `SELECT c.* FROM characters c
     JOIN party p ON c.id = p.character_id
     ORDER BY p.position ASC`
  );
  
  return rows.map((row: any) => ({
    id: row.id,
    name: row.name,
    class: row.class,
    level: row.level,
    xp: row.xp,
    attributes: {
      STR: row.str,
      DEX: row.dex,
      CON: row.con,
      INT: row.int,
      WIS: row.wis,
      CHA: row.cha
    },
    maxHP: row.maxHP,
    currentHP: row.currentHP,
    gold: row.gold,
    equipment: {
      weapon: WEAPONS[row.weapon] || { name: row.weapon, type: 'melee', damage: '1d6' },
      armor: row.armor,
      items: JSON.parse(row.items || '[]')
    }
  }));
}

export async function saveGameState(
  position: Position,
  dungeonLevel: DungeonLevel,
  combatState: any
): Promise<void> {
  if (Platform.OS === 'web') return;
  const database = await getDatabase();
  
  await database.runAsync(
    `UPDATE game_state SET 
     position_x = ?,
     position_y = ?,
     facing = ?,
     dungeon_level = ?,
     dungeon_data = ?,
     combat_state = ?,
     updated_at = unixepoch()
     WHERE id = 1`,
    [
      position.x,
      position.y,
      position.facing,
      dungeonLevel.level,
      JSON.stringify(dungeonLevel),
      combatState ? JSON.stringify(combatState) : null
    ]
  );
  
  console.log('Game state saved to database');
}

export async function getGameState(): Promise<{
  position: Position;
  dungeonLevel: DungeonLevel | null;
  combatState: any;
} | null> {
  if (Platform.OS === 'web') return null;
  const database = await getDatabase();
  
  const row: any = await database.getFirstAsync(
    'SELECT * FROM game_state WHERE id = 1'
  );
  
  if (!row) return null;
  
  return {
    position: {
      x: row.position_x,
      y: row.position_y,
      facing: row.facing
    },
    dungeonLevel: row.dungeon_data ? JSON.parse(row.dungeon_data) : null,
    combatState: row.combat_state ? JSON.parse(row.combat_state) : null
  };
}

export async function resetDatabase(): Promise<void> {
  if (Platform.OS === 'web') return;
  const database = await getDatabase();
  
  await database.execAsync(`
    DELETE FROM party;
    DELETE FROM cemetery;
    DELETE FROM characters;
    UPDATE game_state SET 
      position_x = 0,
      position_y = 0,
      facing = 'north',
      dungeon_level = 1,
      dungeon_data = NULL,
      combat_state = NULL,
      updated_at = unixepoch()
    WHERE id = 1;
  `);
  
  console.log('Database reset successfully');
}

export async function addToCemetery(characterId: string): Promise<void> {
  if (Platform.OS === 'web') return;
  const database = await getDatabase();
  
  await database.runAsync(
    'INSERT OR REPLACE INTO cemetery (character_id) VALUES (?)',
    [characterId]
  );
  
  console.log(`Character ${characterId} added to cemetery`);
}

export async function getCemetery(): Promise<Character[]> {
  if (Platform.OS === 'web') return [];
  const database = await getDatabase();
  
  const rows: any[] = await database.getAllAsync(
    `SELECT c.* FROM characters c
     JOIN cemetery cem ON c.id = cem.character_id
     ORDER BY cem.died_at DESC`
  );
  
  return rows.map((row: any) => ({
    id: row.id,
    name: row.name,
    class: row.class,
    level: row.level,
    xp: row.xp,
    attributes: {
      STR: row.str,
      DEX: row.dex,
      CON: row.con,
      INT: row.int,
      WIS: row.wis,
      CHA: row.cha
    },
    maxHP: row.maxHP,
    currentHP: row.currentHP,
    gold: row.gold,
    equipment: {
      weapon: WEAPONS[row.weapon] || { name: row.weapon, type: 'melee', damage: '1d6' },
      armor: row.armor,
      items: JSON.parse(row.items || '[]')
    }
  }));
}

export async function saveCemetery(cemetery: Party): Promise<void> {
  if (Platform.OS === 'web') return;
  const database = await getDatabase();
  
  const existingRows: any[] = await database.getAllAsync(
    'SELECT character_id FROM cemetery'
  );
  const existingIds = new Set(existingRows.map((row: any) => row.character_id));
  
  for (const character of cemetery) {
    if (!existingIds.has(character.id)) {
      await saveCharacter(character);
      await database.runAsync(
        'INSERT INTO cemetery (character_id) VALUES (?)',
        [character.id]
      );
    }
  }
  
  console.log(`Cemetery with ${cemetery.length} members saved to database`);
}

export async function saveMonsterType(
  name: string,
  maxHP: number,
  attack: number,
  defense: number,
  xpReward: number,
  goldReward: number,
  canFlee: boolean,
  canCallAllies: boolean,
  imageAsset?: string
): Promise<void> {
  if (Platform.OS === 'web') return;
  const database = await getDatabase();
  
  await database.runAsync(
    `INSERT OR REPLACE INTO monsters 
    (id, name, maxHP, attack, defense, xpReward, goldReward, canFlee, canCallAllies, imageAsset)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      name.toLowerCase().replace(/\s+/g, '_'),
      name,
      maxHP,
      attack,
      defense,
      xpReward,
      goldReward,
      canFlee ? 1 : 0,
      canCallAllies ? 1 : 0,
      imageAsset || null
    ]
  );
  
  console.log(`Monster type ${name} saved to database`);
}

export async function getMonsterImage(monsterType: string): Promise<string | null> {
  if (Platform.OS === 'web') return null;
  const database = await getDatabase();
  
  const row: any = await database.getFirstAsync(
    'SELECT imageAsset FROM monsters WHERE name = ?',
    [monsterType]
  );
  
  return row?.imageAsset || null;
}

export async function saveWallImage(
  position: 'left' | 'right' | 'back',
  imageAsset: string
): Promise<void> {
  if (Platform.OS === 'web') return;
  const database = await getDatabase();
  
  await database.runAsync(
    `INSERT OR REPLACE INTO dungeon_walls (id, position, imageAsset)
    VALUES (?, ?, ?)`,
    [position, position, imageAsset]
  );
  
  console.log(`Wall image for ${position} saved to database`);
}

export async function getWallImage(position: 'left' | 'right' | 'back'): Promise<string | null> {
  if (Platform.OS === 'web') return null;
  const database = await getDatabase();
  
  const row: any = await database.getFirstAsync(
    'SELECT imageAsset FROM dungeon_walls WHERE position = ?',
    [position]
  );
  
  return row?.imageAsset || null;
}

export async function getAllMonsterTypes(): Promise<{
  name: string;
  maxHP: number;
  attack: number;
  defense: number;
  xpReward: number;
  goldReward: number;
  canFlee: boolean;
  canCallAllies: boolean;
  imageAsset: string | null;
}[]> {
  if (Platform.OS === 'web') return [];
  const database = await getDatabase();
  
  const rows: any[] = await database.getAllAsync(
    'SELECT * FROM monsters ORDER BY name ASC'
  );
  
  return rows.map((row: any) => ({
    name: row.name,
    maxHP: row.maxHP,
    attack: row.attack,
    defense: row.defense,
    xpReward: row.xpReward,
    goldReward: row.goldReward,
    canFlee: row.canFlee === 1,
    canCallAllies: row.canCallAllies === 1,
    imageAsset: row.imageAsset
  }));
}
