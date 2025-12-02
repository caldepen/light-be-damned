import { Character, Monster, CombatLog, SpellType, WeaponType } from '@/types/game';

export function rollDice(sides: number, count: number = 1): number {
  let total = 0;
  for (let i = 0; i < count; i++) {
    total += Math.floor(Math.random() * sides) + 1;
  }
  return total;
}

export function rollD20(): number {
  return rollDice(20);
}

export function getAttributeBonus(attributeValue: number): number {
  return Math.floor((attributeValue - 10) / 2);
}

export function calculateAttackRoll(attacker: Character | Monster, defender: Character | Monster, weaponType?: WeaponType): {
  hit: boolean;
  damage: number;
} {
  const attackRoll = rollD20();
  const attack = 'class' in attacker ? attacker.attributes.STR : attacker.attack;
  const defense = 'class' in defender ? 10 + Math.floor(defender.attributes.DEX / 2) : defender.defense;
  
  const hit = attackRoll + attack >= defense;
  let baseDamage = hit ? Math.max(1, rollDice(6) + Math.floor(attack / 2)) : 0;
  
  if (hit && 'class' in attacker) {
    let statBonus = 0;
    if (weaponType === 'melee') {
      statBonus = getAttributeBonus(attacker.attributes.STR);
    } else if (weaponType === 'ranged') {
      statBonus = getAttributeBonus(attacker.attributes.DEX);
    }
    baseDamage += statBonus;
  }
  
  const damage = Math.max(1, baseDamage);
  
  return { hit, damage };
}

export function castSpell(caster: Character, spell: SpellType, target: Character | Monster): {
  success: boolean;
  damage?: number;
  healing?: number;
  message: string;
} {
  switch (spell) {
    case 'cure-light-wounds':
      if (!('class' in target)) {
        return { success: false, message: 'Cannot heal monsters!' };
      }
      const wisBonus = getAttributeBonus(caster.attributes.WIS);
      const healing = rollDice(8) + wisBonus;
      return {
        success: true,
        healing,
        message: `${caster.name} casts Cure Light Wounds on ${target.name} for ${healing} HP!`
      };
    
    case 'magic-missile':
      const intBonus = getAttributeBonus(caster.attributes.INT);
      const damage = rollDice(4) + 1 + intBonus;
      return {
        success: true,
        damage,
        message: `${caster.name} casts Magic Missile at ${target.name} for ${damage} damage!`
      };
    
    default:
      return { success: false, message: 'Unknown spell!' };
  }
}

export function calculateXPGain(character: Character, xp: number): {
  newXP: number;
  leveledUp: boolean;
  newLevel?: number;
} {
  const newXP = character.xp + xp;
  const currentLevel = character.level;
  
  const XP_PER_LEVEL = [0, 1000, 2500, 5000, 10000];
  let newLevel = currentLevel;
  
  for (let i = currentLevel; i < XP_PER_LEVEL.length; i++) {
    if (newXP >= XP_PER_LEVEL[i]) {
      newLevel = i + 1;
    }
  }
  
  return {
    newXP,
    leveledUp: newLevel > currentLevel,
    newLevel: newLevel > currentLevel ? newLevel : undefined
  };
}

export function createCombatLog(message: string): CombatLog {
  return {
    id: `${Date.now()}_${Math.random()}`,
    message,
    timestamp: Date.now()
  };
}

export function isPartyDead(party: Character[]): boolean {
  return party.every(char => char.currentHP <= 0);
}

export function areMonstersDead(monsters: Monster[]): boolean {
  return monsters.every(monster => monster.hp <= 0);
}

export function canCharacterAttack(character: Character, characterIndex: number): {
  canAttack: boolean;
  reason?: string;
} {
  const isInFrontRow = characterIndex < 3;
  const weaponType = character.equipment.weapon.type;
  
  if (weaponType === 'melee' && !isInFrontRow) {
    return { canAttack: false, reason: 'Melee weapons can only attack from the front row' };
  }
  
  if (weaponType === 'ranged' && isInFrontRow) {
    return { canAttack: false, reason: 'Ranged weapons can only attack from the back row' };
  }
  
  return { canAttack: true };
}
