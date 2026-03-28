export type CharacterClass = 'Fighter' | 'Cleric' | 'Magic-User' | 'Thief' | 'Ranger' | 'Paladin';

export type Attributes = {
  STR: number;
  DEX: number;
  CON: number;
  INT: number;
  WIS: number;
  CHA: number;
};

export type WeaponType = 'melee' | 'ranged';

export type Weapon = {
  name: string;
  type: WeaponType;
  damage: string;
};

export type Equipment = {
  weapon: Weapon;
  armor: string;
  items: string[];
};

export type Character = {
  id: string;
  name: string;
  class: CharacterClass;
  level: number;
  xp: number;
  attributes: Attributes;
  maxHP: number;
  currentHP: number;
  gold: number;
  equipment: Equipment;
};

export type Party = Character[];

export type MonsterType = 'Giant Rat' | 'Goblin';

export type Monster = {
  id: string;
  type: MonsterType;
  name: string;
  hp: number;
  maxHP: number;
  attack: number;
  defense: number;
  xpReward: number;
  goldReward: number;
  imageAsset?: string;
};

export type Direction = 'north' | 'south' | 'east' | 'west';

export type Position = {
  x: number;
  y: number;
  facing: Direction;
};

export type Tile = {
  walls: {
    north: boolean;
    south: boolean;
    east: boolean;
    west: boolean;
  };
  visited: boolean;
};

export type DungeonLevel = {
  level: number;
  grid: Tile[][];
  width: number;
  height: number;
};

export type CombatAction = 'attack' | 'spell' | 'item' | 'flee';

export type SpellType = 'cure-light-wounds' | 'magic-missile';

export type Spell = {
  name: string;
  type: SpellType;
  description: string;
};

export type CombatLog = {
  id: string;
  message: string;
  timestamp: number;
};

export type CombatState = {
  active: boolean;
  monsters: Monster[];
  turn: 'player' | 'enemy';
  logs: CombatLog[];
  playerActionQueue: number[];
};

export type GameState = {
  party: Party;
  position: Position;
  dungeonLevel: DungeonLevel;
  inCombat: boolean;
  combatState: CombatState | null;
};
