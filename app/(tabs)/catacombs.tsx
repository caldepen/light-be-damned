import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView, Platform } from 'react-native';
import { Image } from 'expo-image';
import { ArrowUp, RotateCcw, RotateCw, Sword, Wand2, Flag } from 'lucide-react-native';
import { useGame } from '@/contexts/GameContext';
import { Character } from '@/types/game';
import { getViewDescription } from '@/utils/dungeon';
import { getProjectAssetUrl } from '@/utils/assets';
import DungeonRenderer from '@/components/DungeonRenderer';

export default function CatacombsScreen() {
  const {
    party,
    position,
    dungeonLevel,
    combatState,
    move,
    playerAttack,
    playerCastSpell,
    attemptFlee,
    reviveParty,
    reorderParty,
    canCharacterAttack
  } = useGame();

  const [selectedCharacter, setSelectedCharacter] = useState<number>(0);
  const [selectedTarget, setSelectedTarget] = useState<number>(0);
  const [swapSourceIndex, setSwapSourceIndex] = useState<number | null>(null);

  const view = getViewDescription(dungeonLevel, position);
  const aliveParty = party.filter(c => c.currentHP > 0);
  const isPartyDead = aliveParty.length === 0;

  const renderDungeonView = () => {
    return (
      <View style={styles.dungeonView}>
        <DungeonRenderer 
          dungeonLevel={dungeonLevel}
          position={position}
          inCombat={!!combatState}
        />
        
        <Text style={styles.directionText}>Facing: {position.facing.toUpperCase()}</Text>
        <Text style={styles.positionText}>Position: ({position.x}, {position.y})</Text>
      </View>
    );
  };

  const renderCombat = () => {
    if (!combatState) return null;

    const aliveMonsters = combatState.monsters.filter(m => m.hp > 0);

    return (
      <View style={styles.combatContainer}>
        <Text style={styles.combatTitle}>COMBAT!</Text>
        
        <View style={styles.monstersSection}>
          <Text style={styles.combatSectionTitle}>Enemies:</Text>
          {combatState.monsters.map((monster, index) => (
            <MonsterCard
              key={monster.id}
              monster={monster}
              index={index}
              isSelected={selectedTarget === index}
              onPress={() => monster.hp > 0 && setSelectedTarget(index)}
            />
          ))}
        </View>

        <View style={styles.combatActions}>
          <Text style={styles.combatSectionTitle}>Actions:</Text>
          {(() => {
            const selectedChar = party[selectedCharacter];
            const attackCheck = selectedChar ? canCharacterAttack(selectedChar, selectedCharacter) : { canAttack: false };
            return attackCheck.canAttack ? null : (
              <Text style={styles.warningText}>{attackCheck.reason}</Text>
            );
          })()}
          <View style={styles.actionButtons}>
            <TouchableOpacity
              style={[
                styles.actionButton,
                (combatState.turn !== 'player' || 
                 !party[selectedCharacter] || 
                 !canCharacterAttack(party[selectedCharacter], selectedCharacter).canAttack) && styles.actionButtonDisabled
              ]}
              onPress={() => playerAttack(selectedCharacter, selectedTarget)}
              disabled={
                combatState.turn !== 'player' || 
                aliveMonsters.length === 0 || 
                !party[selectedCharacter] || 
                !canCharacterAttack(party[selectedCharacter], selectedCharacter).canAttack
              }
            >
              <Sword size={20} color="#fff" />
              <Text style={styles.actionButtonText}>Attack</Text>
            </TouchableOpacity>

            {(party[selectedCharacter]?.class === 'Cleric' || party[selectedCharacter]?.class === 'Magic-User') && (
              <TouchableOpacity
                style={[styles.actionButton, styles.actionButtonSpell, combatState.turn !== 'player' && styles.actionButtonDisabled]}
                onPress={() => {
                  const spellType = party[selectedCharacter].class === 'Cleric' ? 'cure-light-wounds' : 'magic-missile';
                  const targetIndex = spellType === 'cure-light-wounds' ? selectedCharacter : selectedTarget;
                  playerCastSpell(selectedCharacter, spellType, targetIndex);
                }}
                disabled={combatState.turn !== 'player'}
              >
                <Wand2 size={20} color="#fff" />
                <Text style={styles.actionButtonText}>Cast Spell</Text>
              </TouchableOpacity>
            )}

            <TouchableOpacity
              style={[styles.actionButton, styles.actionButtonFlee, combatState.turn !== 'player' && styles.actionButtonDisabled]}
              onPress={attemptFlee}
              disabled={combatState.turn !== 'player'}
            >
              <Flag size={20} color="#fff" />
              <Text style={styles.actionButtonText}>Flee</Text>
            </TouchableOpacity>
          </View>
        </View>

        <View style={styles.combatLog}>
          <Text style={styles.combatSectionTitle}>Combat Log:</Text>
          <ScrollView style={styles.logScroll} nestedScrollEnabled>
            {combatState.logs.slice(-6).reverse().map((log, logIndex) => (
              <Text key={`log-${logIndex}-${log.id || Date.now()}`} style={styles.logText}>
                {log.message}
              </Text>
            ))}
          </ScrollView>
        </View>
      </View>
    );
  };

  if (isPartyDead) {
    return (
      <View style={styles.gameOverContainer}>
        <Text style={styles.gameOverTitle}>GAME OVER</Text>
        <Text style={styles.gameOverText}>
          Your party has been defeated in the catacombs...
        </Text>
        <TouchableOpacity style={styles.reviveButton} onPress={reviveParty}>
          <Text style={styles.reviveButtonText}>Return to Town</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <ScrollView style={styles.scrollContainer}>
        {renderDungeonView()}
        
        {!combatState && (
          <View style={styles.movementControls}>
            <View style={styles.controlRow}>
              <TouchableOpacity
                style={styles.controlButton}
                onPress={() => move('left')}
              >
                <RotateCcw size={24} color="#d4af37" />
                <Text style={styles.controlButtonText}>Turn Left</Text>
              </TouchableOpacity>

              <TouchableOpacity
                style={[
                  styles.controlButton,
                  styles.controlButtonForward,
                  view.hasWallAhead && styles.controlButtonDisabled
                ]}
                onPress={() => !view.hasWallAhead && move('forward')}
                disabled={view.hasWallAhead}
              >
                <ArrowUp size={24} color={view.hasWallAhead ? '#666' : '#fff'} />
                <Text style={[styles.controlButtonText, view.hasWallAhead && styles.controlButtonTextDisabled]}>
                  Forward
                </Text>
              </TouchableOpacity>

              <TouchableOpacity
                style={styles.controlButton}
                onPress={() => move('right')}
              >
                <RotateCw size={24} color="#d4af37" />
                <Text style={styles.controlButtonText}>Turn Right</Text>
              </TouchableOpacity>
            </View>
          </View>
        )}

        {combatState && renderCombat()}

        <PartyFormation 
          party={party} 
          selectedCharacter={selectedCharacter}
          onSelectCharacter={setSelectedCharacter}
          onReorder={reorderParty}
          swapSourceIndex={swapSourceIndex}
          onSwapStart={setSwapSourceIndex}
        />
      </ScrollView>
    </View>
  );
}

type CharacterCardProps = {
  character: Character;
  index: number;
  isSelected: boolean;
  isSwapSource: boolean;
  onSelect: () => void;
  onLongPress: () => void;
};

function CharacterCard({ character, index, isSelected, isSwapSource, onSelect, onLongPress }: CharacterCardProps) {
  return (
    <TouchableOpacity
      style={[
        styles.partyMemberCard,
        isSelected && styles.partyMemberCardSelected,
        isSwapSource && styles.partyMemberCardSwapSource,
        character.currentHP <= 0 && styles.partyMemberCardDead,
      ]}
      onPress={onSelect}
      onLongPress={onLongPress}
      delayLongPress={500}
      activeOpacity={0.7}
    >
      <View style={styles.partyMemberInfo}>
        <Text style={[styles.partyMemberName, character.currentHP <= 0 && styles.textDead]}>
          {character.name}
        </Text>
        <Text style={[styles.partyMemberClass, character.currentHP <= 0 && styles.textDead]}>
          {character.class} Lv.{character.level}
        </Text>
        <Text style={[styles.partyMemberWeapon, character.currentHP <= 0 && styles.textDead]}>
          {character.equipment.weapon.name} ({character.equipment.weapon.type})
        </Text>
      </View>
      <Text
        style={[
          styles.partyMemberHP,
          character.currentHP <= 0 && styles.textDead,
          character.currentHP < character.maxHP * 0.3 && styles.textDanger,
        ]}
      >
        HP: {character.currentHP}/{character.maxHP}
      </Text>
    </TouchableOpacity>
  );
}

type PartyFormationProps = {
  party: Character[];
  selectedCharacter: number;
  onSelectCharacter: (index: number) => void;
  onReorder: (newOrder: Character[]) => void;
  swapSourceIndex: number | null;
  onSwapStart: (index: number | null) => void;
};

type MonsterCardProps = {
  monster: { id: string; name: string; type: string; hp: number; maxHP: number };
  index: number;
  isSelected: boolean;
  onPress: () => void;
};

function MonsterCard({ monster, isSelected, onPress }: MonsterCardProps) {
  const [imageAsset, setImageAsset] = React.useState<string | null>(null);

  React.useEffect(() => {
    if (Platform.OS === 'web') {
      return;
    }
    
    let isMounted = true;
    
    const loadImage = async () => {
      const { getMonsterImage } = await import('@/lib/database');
      const asset = await getMonsterImage(monster.type);
      if (isMounted) {
        setImageAsset(asset);
      }
    };
    
    loadImage();
    
    return () => {
      isMounted = false;
    };
  }, [monster.type]);

  return (
    <TouchableOpacity
      style={[
        styles.monsterCard,
        monster.hp <= 0 && styles.monsterCardDead,
        isSelected && styles.monsterCardSelected
      ]}
      onPress={onPress}
      disabled={monster.hp <= 0}
    >
      {imageAsset && (
        <Image 
          source={{ uri: getProjectAssetUrl(imageAsset) }}
          style={styles.monsterImage}
          contentFit="contain"
        />
      )}
      <View style={styles.monsterInfo}>
        <Text style={[styles.monsterName, monster.hp <= 0 && styles.textDead]}>
          {monster.name}
        </Text>
        <Text style={[styles.monsterHP, monster.hp <= 0 && styles.textDead]}>
          HP: {monster.hp}/{monster.maxHP}
        </Text>
      </View>
    </TouchableOpacity>
  );
}

function PartyFormation({ party, selectedCharacter, onSelectCharacter, onReorder, swapSourceIndex, onSwapStart }: PartyFormationProps) {
  const handleLongPress = (index: number) => {
    onSwapStart(index);
  };

  const handleSlotPress = (index: number) => {
    if (swapSourceIndex !== null) {
      if (swapSourceIndex === index) {
        onSwapStart(null);
      } else {
        const newParty = [...party];
        [newParty[swapSourceIndex], newParty[index]] = [newParty[index], newParty[swapSourceIndex]];
        onReorder(newParty);
        
        if (selectedCharacter === swapSourceIndex) {
          onSelectCharacter(index);
        } else if (selectedCharacter === index) {
          onSelectCharacter(swapSourceIndex);
        }
        
        onSwapStart(null);
      }
    } else {
      onSelectCharacter(index);
    }
  };

  const frontRow = party.slice(0, 3);
  const backRow = party.slice(3, 6);

  return (
    <View style={styles.partyFormation}>
      <Text style={styles.partySectionTitle}>Party Formation:</Text>
      <Text style={styles.formationSubtitle}>
        {swapSourceIndex !== null ? 'Tap another position to swap' : 'Long-press to swap positions'}
      </Text>
      
      <View style={styles.formationRow}>
        <Text style={styles.rowLabel}>Front Row:</Text>
        <View style={styles.rowContainer}>
          {[0, 1, 2].map((slotIndex) => {
            const character = frontRow[slotIndex];
            const actualIndex = slotIndex;
            return (
              <View
                key={slotIndex}
                style={styles.partySlot}
              >
                {character ? (
                  <CharacterCard
                    character={character}
                    index={actualIndex}
                    isSelected={selectedCharacter === actualIndex}
                    isSwapSource={swapSourceIndex === actualIndex}
                    onSelect={() => handleSlotPress(actualIndex)}
                    onLongPress={() => handleLongPress(actualIndex)}
                  />
                ) : (
                  <View style={styles.emptySlot}>
                    <Text style={styles.emptySlotText}>Empty</Text>
                  </View>
                )}
              </View>
            );
          })}
        </View>
      </View>

      <View style={styles.formationRow}>
        <Text style={styles.rowLabel}>Back Row:</Text>
        <View style={styles.rowContainer}>
          {[0, 1, 2].map((slotIndex) => {
            const character = backRow[slotIndex];
            const actualIndex = slotIndex + 3;
            return (
              <View
                key={slotIndex}
                style={styles.partySlot}
              >
                {character ? (
                  <CharacterCard
                    character={character}
                    index={actualIndex}
                    isSelected={selectedCharacter === actualIndex}
                    isSwapSource={swapSourceIndex === actualIndex}
                    onSelect={() => handleSlotPress(actualIndex)}
                    onLongPress={() => handleLongPress(actualIndex)}
                  />
                ) : (
                  <View style={styles.emptySlot}>
                    <Text style={styles.emptySlotText}>Empty</Text>
                  </View>
                )}
              </View>
            );
          })}
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0a0a0a',
  },
  scrollContainer: {
    flex: 1,
  },
  dungeonView: {
    backgroundColor: '#1a1a1a',
    padding: 20,
    alignItems: 'center',
  },
  directionText: {
    color: '#d4af37',
    fontSize: 16,
    fontWeight: 'bold' as const,
    marginTop: 12,
  },
  positionText: {
    color: '#aaa',
    fontSize: 12,
    marginTop: 4,
  },
  movementControls: {
    padding: 20,
  },
  controlRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: 12,
  },
  controlButton: {
    flex: 1,
    backgroundColor: '#2a2a2a',
    padding: 16,
    borderRadius: 12,
    alignItems: 'center',
    gap: 8,
    borderWidth: 2,
    borderColor: '#3a3a3a',
  },
  controlButtonForward: {
    backgroundColor: '#1e5a1e',
    borderColor: '#2a7a2a',
  },
  controlButtonDisabled: {
    backgroundColor: '#1a1a1a',
    borderColor: '#2a2a2a',
  },
  controlButtonText: {
    color: '#d4af37',
    fontSize: 12,
    fontWeight: 'bold' as const,
  },
  controlButtonTextDisabled: {
    color: '#666',
  },
  combatContainer: {
    padding: 20,
    gap: 16,
  },
  combatTitle: {
    fontSize: 24,
    fontWeight: 'bold' as const,
    color: '#ff4444',
    textAlign: 'center',
  },
  monstersSection: {
    gap: 8,
  },
  combatSectionTitle: {
    fontSize: 16,
    fontWeight: 'bold' as const,
    color: '#d4af37',
    marginBottom: 8,
  },
  monsterCard: {
    backgroundColor: '#2a2a2a',
    padding: 12,
    borderRadius: 8,
    flexDirection: 'row',
    justifyContent: 'flex-start',
    alignItems: 'center',
    borderWidth: 2,
    borderColor: '#3a3a3a',
    gap: 12,
  },
  monsterImage: {
    width: 60,
    height: 60,
    borderRadius: 4,
  },
  monsterInfo: {
    flex: 1,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  monsterCardDead: {
    opacity: 0.5,
  },
  monsterCardSelected: {
    borderColor: '#ff4444',
    backgroundColor: '#3a2a2a',
  },
  monsterName: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold' as const,
  },
  monsterHP: {
    color: '#ff4444',
    fontSize: 14,
  },
  combatActions: {
    gap: 8,
  },
  actionButtons: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  actionButton: {
    backgroundColor: '#8b0000',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 8,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  actionButtonSpell: {
    backgroundColor: '#4a5aff',
  },
  actionButtonFlee: {
    backgroundColor: '#666',
  },
  actionButtonDisabled: {
    opacity: 0.5,
  },
  actionButtonText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: 'bold' as const,
  },
  combatLog: {
    backgroundColor: '#1a1a1a',
    borderRadius: 8,
    padding: 12,
    minHeight: 120,
    maxHeight: 120,
  },
  logScroll: {
    flex: 1,
  },
  logText: {
    color: '#ccc',
    fontSize: 12,
    marginBottom: 4,
  },
  partyFormation: {
    padding: 20,
    gap: 16,
  },
  partySectionTitle: {
    fontSize: 16,
    fontWeight: 'bold' as const,
    color: '#d4af37',
  },
  formationSubtitle: {
    fontSize: 12,
    color: '#888',
    marginTop: -8,
  },
  formationRow: {
    gap: 8,
  },
  rowLabel: {
    fontSize: 14,
    fontWeight: 'bold' as const,
    color: '#aaa',
    marginBottom: 4,
  },
  rowContainer: {
    flexDirection: 'row',
    gap: 8,
  },
  partySlot: {
    flex: 1,
    minHeight: 80,
  },
  emptySlot: {
    flex: 1,
    backgroundColor: '#1a1a1a',
    borderRadius: 8,
    borderWidth: 2,
    borderColor: '#3a3a3a',
    borderStyle: 'dashed',
    justifyContent: 'center',
    alignItems: 'center',
    minHeight: 80,
  },
  emptySlotText: {
    color: '#666',
    fontSize: 12,
  },
  partyMemberCard: {
    flex: 1,
    backgroundColor: '#2a2a2a',
    padding: 12,
    borderRadius: 8,
    borderWidth: 2,
    borderColor: '#3a3a3a',
    minHeight: 80,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  partyMemberCardSelected: {
    borderColor: '#d4af37',
    backgroundColor: '#3a3a2a',
  },
  partyMemberCardSwapSource: {
    borderColor: '#4ade80',
    backgroundColor: '#2a3a2a',
    borderWidth: 3,
  },
  partyMemberCardDead: {
    opacity: 0.5,
  },
  partyMemberInfo: {
    flex: 1,
    marginRight: 8,
  },
  partyMemberName: {
    color: '#fff',
    fontSize: 14,
    fontWeight: 'bold' as const,
  },
  partyMemberClass: {
    color: '#aaa',
    fontSize: 12,
  },
  partyMemberWeapon: {
    color: '#888',
    fontSize: 11,
    marginTop: 2,
  },
  warningText: {
    color: '#ff8844',
    fontSize: 12,
    marginBottom: 8,
    fontStyle: 'italic' as const,
  },
  partyMemberHP: {
    color: '#4ade80',
    fontSize: 13,
    fontWeight: 'bold' as const,
  },
  textDead: {
    color: '#666',
  },
  textDanger: {
    color: '#ff4444',
  },
  gameOverContainer: {
    flex: 1,
    backgroundColor: '#0a0a0a',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 40,
  },
  gameOverTitle: {
    fontSize: 48,
    fontWeight: 'bold' as const,
    color: '#8b0000',
    marginBottom: 24,
  },
  gameOverText: {
    fontSize: 18,
    color: '#ccc',
    textAlign: 'center',
    marginBottom: 40,
  },
  reviveButton: {
    backgroundColor: '#d4af37',
    paddingHorizontal: 32,
    paddingVertical: 16,
    borderRadius: 12,
  },
  reviveButtonText: {
    color: '#1a1a1a',
    fontSize: 18,
    fontWeight: 'bold' as const,
  },
});
