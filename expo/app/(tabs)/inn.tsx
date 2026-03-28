import React, { useState } from 'react';
import { View, Text, StyleSheet, TextInput, TouchableOpacity, ScrollView, Alert } from 'react-native';
import { UserPlus, Trash2, Dices, Heart } from 'lucide-react-native';
import { useGame } from '@/contexts/GameContext';
import { CharacterClass } from '@/types/game';
import { CHARACTER_CLASSES } from '@/constants/gameData';
import { useFocusEffect } from 'expo-router';

export default function InnScreen() {
  const { party, createCharacter, addCharacterToParty, removeCharacterFromParty, healPartyAtInn } = useGame();
  const [name, setName] = useState<string>('');
  const [selectedClass, setSelectedClass] = useState<CharacterClass>('Fighter');
  const [hasHealed, setHasHealed] = useState<boolean>(false);

  useFocusEffect(
    React.useCallback(() => {
      if (!hasHealed && party.length > 0) {
        healPartyAtInn();
        setHasHealed(true);
      }
      return () => {
        setHasHealed(false);
      };
    }, [hasHealed, party.length, healPartyAtInn])
  );

  const handleCreateCharacter = () => {
    if (!name.trim()) {
      Alert.alert('Error', 'Please enter a character name');
      return;
    }

    if (party.length >= 6) {
      Alert.alert('Error', 'Party is full (maximum 6 characters)');
      return;
    }

    const character = createCharacter(name.trim(), selectedClass);
    addCharacterToParty(character);
    setName('');
    Alert.alert('Success', `${character.name} the ${character.class} has joined your party!`);
  };

  const handleRemoveCharacter = (characterId: string, characterName: string) => {
    Alert.alert(
      'Remove Character',
      `Remove ${characterName} from the party?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Remove',
          style: 'destructive',
          onPress: () => removeCharacterFromParty(characterId)
        }
      ]
    );
  };

  const classes: CharacterClass[] = ['Fighter', 'Cleric', 'Magic-User', 'Thief', 'Ranger', 'Paladin'];

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <View style={styles.header}>
        <Heart size={48} color="#d4af37" />
        <Text style={styles.title}>The Adventurer&apos;s Inn</Text>
        <Text style={styles.subtitle}>Rest and heal your wounds</Text>
      </View>

      <View style={styles.createSection}>
        <Text style={styles.sectionTitle}>Create New Character</Text>
        
        <TextInput
          style={styles.input}
          value={name}
          onChangeText={setName}
          placeholder="Enter character name..."
          placeholderTextColor="#666"
          maxLength={20}
        />

        <Text style={styles.label}>Choose Class</Text>
        <View style={styles.classGrid}>
          {classes.map((cls) => (
            <TouchableOpacity
              key={cls}
              style={[
                styles.classButton,
                selectedClass === cls && styles.classButtonSelected
              ]}
              onPress={() => setSelectedClass(cls)}
            >
              <Text
                style={[
                  styles.classButtonText,
                  selectedClass === cls && styles.classButtonTextSelected
                ]}
              >
                {cls}
              </Text>
            </TouchableOpacity>
          ))}
        </View>

        <View style={styles.classInfo}>
          <Text style={styles.classInfoTitle}>{selectedClass}</Text>
          <View style={styles.classInfoRow}>
            <Dices size={16} color="#d4af37" />
            <Text style={styles.classInfoText}>
              Hit Die: d{CHARACTER_CLASSES[selectedClass].hitDie}
            </Text>
          </View>
          <Text style={styles.classInfoText}>
            Starting Gold: {CHARACTER_CLASSES[selectedClass].startingGold}
          </Text>
          <Text style={styles.classInfoText}>
            Weapon: {CHARACTER_CLASSES[selectedClass].equipment.weapon.name} ({CHARACTER_CLASSES[selectedClass].equipment.weapon.type})
          </Text>
          <Text style={styles.classInfoText}>
            Armor: {CHARACTER_CLASSES[selectedClass].equipment.armor}
          </Text>
        </View>

        <TouchableOpacity
          style={[styles.createButton, party.length >= 6 && styles.createButtonDisabled]}
          onPress={handleCreateCharacter}
          disabled={party.length >= 6}
        >
          <UserPlus size={20} color={party.length >= 6 ? '#666' : '#1a1a1a'} />
          <Text style={[styles.createButtonText, party.length >= 6 && styles.createButtonTextDisabled]}>
            Create Character
          </Text>
        </TouchableOpacity>
      </View>

      <View style={styles.partySection}>
        <Text style={styles.sectionTitle}>
          Current Party ({party.length}/6)
        </Text>
        
        {party.length === 0 ? (
          <Text style={styles.emptyText}>
            No adventurers in your party yet. Create some characters to begin your quest!
          </Text>
        ) : (
          party.map((character) => (
            <View key={character.id} style={styles.characterCard}>
              <View style={styles.characterInfo}>
                <Text style={styles.characterName}>{character.name}</Text>
                <Text style={styles.characterClass}>{character.class} - Level {character.level}</Text>
                <View style={styles.characterStats}>
                  <Text style={styles.statText}>HP: {character.maxHP}</Text>
                  <Text style={styles.statText}>Gold: {character.gold}</Text>
                </View>
                <View style={styles.attributesRow}>
                  <Text style={styles.attributeText}>STR {character.attributes.STR}</Text>
                  <Text style={styles.attributeText}>DEX {character.attributes.DEX}</Text>
                  <Text style={styles.attributeText}>CON {character.attributes.CON}</Text>
                  <Text style={styles.attributeText}>INT {character.attributes.INT}</Text>
                  <Text style={styles.attributeText}>WIS {character.attributes.WIS}</Text>
                  <Text style={styles.attributeText}>CHA {character.attributes.CHA}</Text>
                </View>
              </View>
              <TouchableOpacity
                style={styles.removeButton}
                onPress={() => handleRemoveCharacter(character.id, character.name)}
              >
                <Trash2 size={20} color="#ff4444" />
              </TouchableOpacity>
            </View>
          ))
        )}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#1a1a1a',
  },
  content: {
    padding: 20,
  },
  header: {
    alignItems: 'center',
    marginBottom: 24,
    marginTop: 20,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold' as const,
    color: '#d4af37',
    marginTop: 12,
  },
  subtitle: {
    fontSize: 14,
    color: '#aaa',
    marginTop: 4,
  },
  createSection: {
    backgroundColor: '#2a2a2a',
    borderRadius: 12,
    padding: 16,
    marginBottom: 24,
    borderWidth: 2,
    borderColor: '#3a3a3a',
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold' as const,
    color: '#d4af37',
    marginBottom: 16,
  },
  input: {
    backgroundColor: '#1a1a1a',
    borderRadius: 8,
    padding: 12,
    color: '#fff',
    fontSize: 16,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: '#3a3a3a',
  },
  label: {
    color: '#ccc',
    fontSize: 14,
    marginBottom: 12,
  },
  classGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginBottom: 16,
  },
  classButton: {
    backgroundColor: '#3a3a3a',
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 8,
    borderWidth: 2,
    borderColor: '#3a3a3a',
  },
  classButtonSelected: {
    backgroundColor: '#d4af37',
    borderColor: '#d4af37',
  },
  classButtonText: {
    color: '#ccc',
    fontSize: 14,
  },
  classButtonTextSelected: {
    color: '#1a1a1a',
    fontWeight: 'bold' as const,
  },
  classInfo: {
    backgroundColor: '#1a1a1a',
    borderRadius: 8,
    padding: 12,
    marginBottom: 16,
    gap: 6,
  },
  classInfoTitle: {
    color: '#d4af37',
    fontSize: 16,
    fontWeight: 'bold' as const,
    marginBottom: 4,
  },
  classInfoRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  classInfoText: {
    color: '#ccc',
    fontSize: 13,
  },
  createButton: {
    backgroundColor: '#d4af37',
    borderRadius: 8,
    padding: 14,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
  },
  createButtonDisabled: {
    backgroundColor: '#3a3a3a',
  },
  createButtonText: {
    color: '#1a1a1a',
    fontSize: 16,
    fontWeight: 'bold' as const,
  },
  createButtonTextDisabled: {
    color: '#666',
  },
  partySection: {
    marginBottom: 24,
  },
  emptyText: {
    color: '#666',
    fontSize: 14,
    textAlign: 'center',
    padding: 24,
  },
  characterCard: {
    backgroundColor: '#2a2a2a',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    borderWidth: 1,
    borderColor: '#3a3a3a',
  },
  characterInfo: {
    flex: 1,
  },
  characterName: {
    color: '#fff',
    fontSize: 18,
    fontWeight: 'bold' as const,
    marginBottom: 4,
  },
  characterClass: {
    color: '#d4af37',
    fontSize: 14,
    marginBottom: 8,
  },
  characterStats: {
    flexDirection: 'row',
    gap: 16,
    marginBottom: 8,
  },
  statText: {
    color: '#aaa',
    fontSize: 13,
  },
  attributesRow: {
    flexDirection: 'row',
    gap: 12,
    flexWrap: 'wrap',
  },
  attributeText: {
    color: '#4ade80',
    fontSize: 12,
    fontWeight: 'bold' as const,
  },
  removeButton: {
    padding: 8,
  },
});
