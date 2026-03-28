import React from 'react';
import { View, Text, StyleSheet, ScrollView } from 'react-native';
import { Skull } from 'lucide-react-native';
import { useGame } from '@/contexts/GameContext';

export default function CemeteryScreen() {
  const { cemetery } = useGame();

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <View style={styles.header}>
        <Skull size={48} color="#999" />
        <Text style={styles.title}>The Cemetery</Text>
        <Text style={styles.subtitle}>In memory of fallen heroes</Text>
      </View>

      <View style={styles.cemeterySection}>
        <Text style={styles.sectionTitle}>
          Fallen Heroes ({cemetery.length})
        </Text>
        
        {cemetery.length === 0 ? (
          <Text style={styles.emptyText}>
            No heroes have fallen yet. May their luck hold...
          </Text>
        ) : (
          cemetery.map((character) => (
            <View key={character.id} style={styles.tombstone}>
              <View style={styles.tombstoneHeader}>
                <Skull size={24} color="#666" />
                <Text style={styles.characterName}>{character.name}</Text>
              </View>
              <Text style={styles.characterClass}>
                {character.class} - Level {character.level}
              </Text>
              <View style={styles.divider} />
              <View style={styles.characterStats}>
                <Text style={styles.statText}>HP: {character.maxHP}</Text>
                <Text style={styles.statText}>XP: {character.xp}</Text>
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
              <Text style={styles.epitaph}>
                &ldquo;They fell in the darkness of the catacombs&rdquo;
              </Text>
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
    backgroundColor: '#0a0a0a',
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
    color: '#999',
    marginTop: 12,
  },
  subtitle: {
    fontSize: 14,
    color: '#666',
    marginTop: 4,
    fontStyle: 'italic' as const,
  },
  cemeterySection: {
    marginBottom: 24,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold' as const,
    color: '#999',
    marginBottom: 16,
  },
  emptyText: {
    color: '#555',
    fontSize: 14,
    textAlign: 'center',
    padding: 24,
    fontStyle: 'italic' as const,
  },
  tombstone: {
    backgroundColor: '#1a1a1a',
    borderRadius: 12,
    padding: 16,
    marginBottom: 16,
    borderWidth: 2,
    borderColor: '#2a2a2a',
  },
  tombstoneHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    marginBottom: 8,
  },
  characterName: {
    color: '#ccc',
    fontSize: 20,
    fontWeight: 'bold' as const,
  },
  characterClass: {
    color: '#999',
    fontSize: 14,
    marginBottom: 12,
  },
  divider: {
    height: 1,
    backgroundColor: '#2a2a2a',
    marginBottom: 12,
  },
  characterStats: {
    flexDirection: 'row',
    gap: 16,
    marginBottom: 12,
  },
  statText: {
    color: '#777',
    fontSize: 13,
  },
  attributesRow: {
    flexDirection: 'row',
    gap: 12,
    flexWrap: 'wrap',
    marginBottom: 12,
  },
  attributeText: {
    color: '#666',
    fontSize: 12,
    fontWeight: 'bold' as const,
  },
  epitaph: {
    color: '#555',
    fontSize: 12,
    fontStyle: 'italic' as const,
    textAlign: 'center',
    marginTop: 8,
  },
});
