import { saveMonsterType, saveWallImage, getAllMonsterTypes, getWallImage } from '@/lib/database';
import { MONSTER_DATA } from '@/constants/gameData';

export async function initializeDefaultMonsters() {
  console.log('Initializing default monsters...');
  
  for (const [monsterType, data] of Object.entries(MONSTER_DATA)) {
    await saveMonsterType(
      monsterType,
      data.maxHP,
      data.attack,
      data.defense,
      data.xpReward,
      data.goldReward,
      data.canFlee || false,
      data.canCallAllies || false,
      undefined
    );
  }
  
  console.log('Default monsters initialized without images');
}

export async function setMonsterImage(monsterName: string, assetKey: string) {
  const monsterData = MONSTER_DATA[monsterName as keyof typeof MONSTER_DATA];
  
  if (!monsterData) {
    console.error(`Monster type "${monsterName}" not found`);
    return;
  }
  
  await saveMonsterType(
    monsterName,
    monsterData.maxHP,
    monsterData.attack,
    monsterData.defense,
    monsterData.xpReward,
    monsterData.goldReward,
    monsterData.canFlee || false,
    monsterData.canCallAllies || false,
    assetKey
  );
  
  console.log(`Image set for ${monsterName}: ${assetKey}`);
}

export async function setWallImageAsset(position: 'left' | 'right' | 'back', assetKey: string) {
  await saveWallImage(position, assetKey);
  console.log(`Wall image set for ${position}: ${assetKey}`);
}

export async function listAllMonsters() {
  const monsters = await getAllMonsterTypes();
  console.log('All monsters:', monsters);
  return monsters;
}

export async function listAllWallImages() {
  const left = await getWallImage('left');
  const right = await getWallImage('right');
  const back = await getWallImage('back');
  
  const result = { left, right, back };
  console.log('Wall images:', result);
  return result;
}
