import { useState, useEffect, useCallback } from 'react';
import createContextHook from '@nkzw/create-context-hook';
import { Character, Party, Position, DungeonLevel, CharacterClass, Attributes, Monster, MonsterType, CombatState } from '@/types/game';
import { CHARACTER_CLASSES, MONSTER_DATA } from '@/constants/gameData';
import { rollDice, calculateAttackRoll, castSpell, createCombatLog, isPartyDead, areMonstersDead, calculateXPGain, canCharacterAttack } from '@/utils/combat';
import { generateDungeon, canMove, moveForward, turnLeft, turnRight, checkForEncounter } from '@/utils/dungeon';
import * as db from '@/lib/database';

function generateAttributes(): Attributes {
  return {
    STR: rollDice(6, 3),
    DEX: rollDice(6, 3),
    CON: rollDice(6, 3),
    INT: rollDice(6, 3),
    WIS: rollDice(6, 3),
    CHA: rollDice(6, 3)
  };
}

export const [GameProvider, useGame] = createContextHook(() => {
  const [party, setParty] = useState<Party>([]);
  const [cemetery, setCemetery] = useState<Party>([]);
  const [position, setPosition] = useState<Position>({ x: 0, y: 0, facing: 'north' });
  const [dungeonLevel, setDungeonLevel] = useState<DungeonLevel>(generateDungeon(1));
  const [combatState, setCombatState] = useState<CombatState | null>(null);
  const [isLoaded, setIsLoaded] = useState<boolean>(false);

  useEffect(() => {
    const loadGameState = async () => {
      try {
        await db.initDatabase();
        const loadedParty = await db.getParty();
        const loadedCemetery = await db.getCemetery();
        const gameState = await db.getGameState();
        
        if (loadedParty.length > 0) {
          setParty(loadedParty);
        }
        
        if (loadedCemetery.length > 0) {
          setCemetery(loadedCemetery);
        }
        
        if (gameState) {
          setPosition(gameState.position);
          if (gameState.dungeonLevel) {
            setDungeonLevel(gameState.dungeonLevel);
          }
          if (gameState.combatState) {
            setCombatState(gameState.combatState);
          }
        }
      } catch (error) {
        console.log('Error loading game state:', error);
      } finally {
        setIsLoaded(true);
      }
    };
    
    loadGameState();
  }, []);

  useEffect(() => {
    if (!isLoaded) return;
    
    const saveData = async () => {
      try {
        await db.saveParty(party);
        await db.saveCemetery(cemetery);
        await db.saveGameState(position, dungeonLevel, combatState);
      } catch (error) {
        console.log('Error saving game state:', error);
      }
    };
    
    const timeoutId = setTimeout(() => {
      saveData();
    }, 500);
    
    return () => clearTimeout(timeoutId);
  }, [isLoaded, party, cemetery, position, dungeonLevel, combatState]);

  const createCharacter = useCallback((name: string, characterClass: CharacterClass): Character => {
    const classData = CHARACTER_CLASSES[characterClass];
    const attributes = generateAttributes();
    const maxHP = rollDice(classData.hitDie) + Math.floor(attributes.CON / 2);

    return {
      id: `${Date.now()}_${Math.random()}`,
      name,
      class: characterClass,
      level: 1,
      xp: 0,
      attributes,
      maxHP,
      currentHP: maxHP,
      gold: classData.startingGold,
      equipment: classData.equipment
    };
  }, []);

  const addCharacterToParty = useCallback((character: Character) => {
    if (party.length < 6) {
      setParty(prev => [...prev, character]);
    }
  }, [party]);

  const removeCharacterFromParty = useCallback((characterId: string) => {
    setParty(prev => prev.filter(c => c.id !== characterId));
  }, []);

  const reorderParty = useCallback((newOrder: Character[]) => {
    setParty(newOrder);
  }, []);

  const resetDungeon = useCallback(() => {
    setPosition({ x: 0, y: 0, facing: 'north' });
    setDungeonLevel(generateDungeon(1));
    setCombatState(null);
  }, []);

  const createMonster = useCallback((type: MonsterType): Monster => {
    const data = MONSTER_DATA[type];
    return {
      id: `${Date.now()}_${Math.random()}`,
      type,
      name: type,
      hp: data.maxHP,
      maxHP: data.maxHP,
      attack: data.attack,
      defense: data.defense,
      xpReward: data.xpReward,
      goldReward: data.goldReward
    };
  }, []);

  const startEncounter = useCallback(() => {
    const monsterTypes: MonsterType[] = ['Giant Rat', 'Goblin'];
    const numMonsters = Math.floor(Math.random() * 3) + 1;
    const monsters: Monster[] = [];
    
    for (let i = 0; i < numMonsters; i++) {
      const type = monsterTypes[Math.floor(Math.random() * monsterTypes.length)];
      monsters.push(createMonster(type));
    }
    
    setCombatState({
      active: true,
      monsters,
      turn: 'player',
      logs: [createCombatLog(`Encountered ${monsters.map(m => m.name).join(', ')}!`)],
      playerActionQueue: []
    });
  }, [createMonster]);

  const move = useCallback((direction: 'forward' | 'left' | 'right') => {
    if (combatState) return;

    let shouldStartEncounter = false;

    setPosition(prev => {
      let newPos = prev;
      
      if (direction === 'left') {
        newPos = { ...prev, facing: turnLeft(prev.facing) };
      } else if (direction === 'right') {
        newPos = { ...prev, facing: turnRight(prev.facing) };
      } else if (direction === 'forward') {
        if (canMove(dungeonLevel, prev)) {
          newPos = moveForward(prev);
          
          if (checkForEncounter()) {
            shouldStartEncounter = true;
          }
        }
      }
      
      return newPos;
    });

    if (shouldStartEncounter) {
      startEncounter();
    }
  }, [dungeonLevel, combatState, startEncounter]);

  const playerAttack = useCallback((characterIndex: number, monsterIndex: number) => {
    if (!combatState || combatState.turn !== 'player') return;
    
    const character = party[characterIndex];
    const monster = combatState.monsters[monsterIndex];
    
    if (!character || !monster || character.currentHP <= 0 || monster.hp <= 0) return;
    
    const attackCheck = canCharacterAttack(character, characterIndex);
    if (!attackCheck.canAttack) {
      const newLogs = [...combatState.logs, createCombatLog(`${character.name}: ${attackCheck.reason}`)];
      setCombatState(prev => prev ? { ...prev, logs: newLogs } : null);
      return;
    }
    
    const weaponType = character.equipment.weapon.type;
    const result = calculateAttackRoll(character, monster, weaponType);
    const newLogs = [...combatState.logs];
    
    if (result.hit) {
      newLogs.push(createCombatLog(`${character.name} hits ${monster.name} for ${result.damage} damage!`));
      
      const newMonsters = [...combatState.monsters];
      newMonsters[monsterIndex] = { ...monster, hp: Math.max(0, monster.hp - result.damage) };
      
      if (newMonsters[monsterIndex].hp <= 0) {
        newLogs.push(createCombatLog(`${monster.name} is defeated!`));
      }
      
      setCombatState(prev => prev ? {
        ...prev,
        monsters: newMonsters,
        logs: newLogs
      } : null);
      
      if (areMonstersDead(newMonsters)) {
        endCombat(true);
      } else {
        setTimeout(() => enemyTurn(), 1000);
      }
    } else {
      newLogs.push(createCombatLog(`${character.name} misses ${monster.name}!`));
      setCombatState(prev => prev ? { ...prev, logs: newLogs } : null);
      setTimeout(() => enemyTurn(), 1000);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [combatState, party]);

  const playerCastSpell = useCallback((characterIndex: number, spellType: 'cure-light-wounds' | 'magic-missile', targetIndex: number) => {
    if (!combatState || combatState.turn !== 'player') return;
    
    const character = party[characterIndex];
    if (!character || character.currentHP <= 0) return;
    
    let target: Character | Monster;
    if (spellType === 'cure-light-wounds') {
      target = party[targetIndex];
    } else {
      target = combatState.monsters[targetIndex];
    }
    
    if (!target) return;
    
    const result = castSpell(character, spellType, target);
    const newLogs = [...combatState.logs, createCombatLog(result.message)];
    
    if (result.success) {
      if (result.healing && 'class' in target) {
        const newParty = [...party];
        newParty[targetIndex] = {
          ...target,
          currentHP: Math.min(target.maxHP, target.currentHP + result.healing)
        };
        setParty(newParty);
      } else if (result.damage) {
        const newMonsters = [...combatState.monsters];
        newMonsters[targetIndex] = {
          ...newMonsters[targetIndex],
          hp: Math.max(0, newMonsters[targetIndex].hp - result.damage)
        };
        
        if (newMonsters[targetIndex].hp <= 0) {
          newLogs.push(createCombatLog(`${newMonsters[targetIndex].name} is defeated!`));
        }
        
        setCombatState(prev => prev ? {
          ...prev,
          monsters: newMonsters,
          logs: newLogs
        } : null);
        
        if (areMonstersDead(newMonsters)) {
          endCombat(true);
          return;
        }
      }
    }
    
    setCombatState(prev => prev ? { ...prev, logs: newLogs } : null);
    setTimeout(() => enemyTurn(), 1000);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [combatState, party]);

  const attemptFlee = useCallback(() => {
    if (!combatState || combatState.turn !== 'player') return;
    
    const fleeChance = 0.5;
    const success = Math.random() < fleeChance;
    
    if (success) {
      setCombatState(prev => prev ? {
        ...prev,
        logs: [...prev.logs, createCombatLog('The party fled from combat!')]
      } : null);
      setTimeout(() => {
        setCombatState(null);
        setPosition(prev => ({ ...prev, x: Math.max(0, prev.x - 1) }));
      }, 1000);
    } else {
      setCombatState(prev => prev ? {
        ...prev,
        logs: [...prev.logs, createCombatLog('Failed to flee!')]
      } : null);
      setTimeout(() => enemyTurn(), 1000);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [combatState]);

  const enemyTurn = useCallback(() => {
    if (!combatState) return;
    
    setCombatState(prev => prev ? { ...prev, turn: 'enemy' } : null);
    
    const aliveMonsters = combatState.monsters.filter(m => m.hp > 0);
    const aliveParty = party.filter(c => c.currentHP > 0);
    
    if (aliveMonsters.length === 0 || aliveParty.length === 0) return;
    
    const newLogs = [...combatState.logs];
    let newParty = [...party];
    
    aliveMonsters.forEach(monster => {
      const targetIndex = Math.floor(Math.random() * aliveParty.length);
      const target = aliveParty[targetIndex];
      const actualIndex = party.findIndex(c => c.id === target.id);
      
      const result = calculateAttackRoll(monster, target);
      
      if (result.hit) {
        newLogs.push(createCombatLog(`${monster.name} hits ${target.name} for ${result.damage} damage!`));
        newParty[actualIndex] = {
          ...newParty[actualIndex],
          currentHP: Math.max(0, newParty[actualIndex].currentHP - result.damage)
        };
        
        if (newParty[actualIndex].currentHP <= 0) {
          newLogs.push(createCombatLog(`${target.name} has fallen!`));
        }
      } else {
        newLogs.push(createCombatLog(`${monster.name} misses ${target.name}!`));
      }
    });
    
    setParty(newParty);
    setCombatState(prev => prev ? {
      ...prev,
      logs: newLogs,
      turn: 'player'
    } : null);
    
    if (isPartyDead(newParty)) {
      endCombat(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [combatState, party]);

  const endCombat = useCallback((victory: boolean) => {
    if (!combatState) return;
    
    if (victory) {
      const totalXP = combatState.monsters.reduce((sum, m) => sum + m.xpReward, 0);
      const totalGold = combatState.monsters.reduce((sum, m) => sum + m.goldReward, 0);
      
      const newParty = party.map(char => {
        if (char.currentHP > 0) {
          const xpGain = calculateXPGain(char, totalXP);
          return {
            ...char,
            xp: xpGain.newXP,
            level: xpGain.newLevel || char.level,
            gold: char.gold + totalGold
          };
        }
        return char;
      });
      
      setParty(newParty);
      
      const finalLogs = [
        ...combatState.logs,
        createCombatLog(`Victory! Gained ${totalXP} XP and ${totalGold} gold!`)
      ];
      
      setCombatState(prev => prev ? { ...prev, logs: finalLogs, active: false } : null);
      setTimeout(() => setCombatState(null), 3000);
    } else {
      const finalLogs = [
        ...combatState.logs,
        createCombatLog('The party has been defeated!')
      ];
      setCombatState(prev => prev ? { ...prev, logs: finalLogs, active: false } : null);
    }
  }, [combatState, party]);

  const reviveParty = useCallback(() => {
    const revivedParty = party.map(char => ({
      ...char,
      currentHP: char.maxHP
    }));
    setParty(revivedParty);
    resetDungeon();
  }, [party, resetDungeon]);

  const healPartyAtInn = useCallback(async () => {
    const livingParty: Character[] = [];
    const deadCharacters: Character[] = [];
    
    party.forEach(char => {
      if (char.currentHP <= 0) {
        deadCharacters.push(char);
      } else {
        livingParty.push({
          ...char,
          currentHP: char.maxHP
        });
      }
    });
    
    if (deadCharacters.length > 0) {
      for (const deadChar of deadCharacters) {
        await db.addToCemetery(deadChar.id);
      }
      setCemetery(prev => [...deadCharacters, ...prev]);
    }
    
    setParty(livingParty);
    console.log(`Healed ${livingParty.length} party members, ${deadCharacters.length} moved to cemetery`);
  }, [party]);

  return {
    party,
    cemetery,
    position,
    dungeonLevel,
    combatState,
    isLoaded,
    createCharacter,
    addCharacterToParty,
    removeCharacterFromParty,
    reorderParty,
    resetDungeon,
    move,
    playerAttack,
    playerCastSpell,
    attemptFlee,
    reviveParty,
    healPartyAtInn,
    startEncounter,
    canCharacterAttack
  };
});
