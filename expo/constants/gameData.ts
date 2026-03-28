import { CharacterClass, Spell, MonsterType, Weapon } from '@/types/game';

export const WEAPONS: Record<string, Weapon> = {
  'Longsword': { name: 'Longsword', type: 'melee', damage: '1d8' },
  'Mace': { name: 'Mace', type: 'melee', damage: '1d6' },
  'Dagger': { name: 'Dagger', type: 'melee', damage: '1d4' },
  'Short Sword': { name: 'Short Sword', type: 'melee', damage: '1d6' },
  'Longbow': { name: 'Longbow', type: 'ranged', damage: '1d8' },
  'Crossbow': { name: 'Crossbow', type: 'ranged', damage: '1d10' },
};

export const CHARACTER_CLASSES: Record<CharacterClass, {
  hitDie: number;
  startingGold: number;
  equipment: { weapon: Weapon; armor: string; items: string[] };
  spells?: Spell[];
}> = {
  'Fighter': {
    hitDie: 10,
    startingGold: 100,
    equipment: {
      weapon: WEAPONS['Longsword'],
      armor: 'Chain Mail',
      items: ['Rations', 'Torch']
    }
  },
  'Cleric': {
    hitDie: 8,
    startingGold: 75,
    equipment: {
      weapon: WEAPONS['Mace'],
      armor: 'Scale Mail',
      items: ['Holy Symbol', 'Rations']
    },
    spells: [
      { name: 'Cure Light Wounds', type: 'cure-light-wounds', description: 'Heals 1d8 HP to one party member' }
    ]
  },
  'Magic-User': {
    hitDie: 4,
    startingGold: 50,
    equipment: {
      weapon: WEAPONS['Dagger'],
      armor: 'Robes',
      items: ['Spellbook', 'Rations']
    },
    spells: [
      { name: 'Magic Missile', type: 'magic-missile', description: 'Deals 1d4+1 damage to one enemy' }
    ]
  },
  'Thief': {
    hitDie: 6,
    startingGold: 80,
    equipment: {
      weapon: WEAPONS['Short Sword'],
      armor: 'Leather Armor',
      items: ['Lockpicks', 'Rations', 'Torch']
    }
  },
  'Ranger': {
    hitDie: 10,
    startingGold: 90,
    equipment: {
      weapon: WEAPONS['Longbow'],
      armor: 'Studded Leather',
      items: ['Arrows', 'Rations']
    }
  },
  'Paladin': {
    hitDie: 10,
    startingGold: 120,
    equipment: {
      weapon: WEAPONS['Longsword'],
      armor: 'Plate Mail',
      items: ['Holy Symbol', 'Rations']
    }
  }
};

export const MONSTER_DATA: Record<MonsterType, {
  maxHP: number;
  attack: number;
  defense: number;
  xpReward: number;
  goldReward: number;
  canFlee?: boolean;
  canCallAllies?: boolean;
}> = {
  'Giant Rat': {
    maxHP: 8,
    attack: 2,
    defense: 10,
    xpReward: 10,
    goldReward: 5
  },
  'Goblin': {
    maxHP: 15,
    attack: 4,
    defense: 12,
    xpReward: 25,
    goldReward: 15,
    canFlee: true,
    canCallAllies: true
  }
};

export const XP_PER_LEVEL = [
  0,      // Level 1
  1000,   // Level 2
  2500,   // Level 3
  5000,   // Level 4
  10000,  // Level 5
];
