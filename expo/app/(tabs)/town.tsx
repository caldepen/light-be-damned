import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView } from 'react-native';
import { useRouter } from 'expo-router';
import { Castle, Users, Skull, Image as ImageIcon } from 'lucide-react-native';
import { useGame } from '@/contexts/GameContext';

export default function TownScreen() {
  const router = useRouter();
  const { party, isLoaded } = useGame();

  if (!isLoaded) {
    return (
      <View style={styles.container}>
        <Text style={styles.loadingText}>Loading...</Text>
      </View>
    );
  }

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <View style={styles.header}>
        <Castle size={64} color="#d4af37" />
        <Text style={styles.title}>Town of Thornhaven</Text>
      </View>

      <View style={styles.storyBox}>
        <Text style={styles.storyText}>
          Darkness has fallen upon Thornhaven. The sacred church at the center of town, 
          once a beacon of hope, has been seized by demons from the depths below.
        </Text>
        <Text style={[styles.storyText, styles.storyTextSpaced]}>
          High Priestess Elara has been dragged into the ancient catacombs beneath the church, 
          where unspeakable horrors now dwell. The townsfolk cower in fear, their prayers 
          unanswered.
        </Text>
        <Text style={[styles.storyText, styles.storyTextSpaced]}>
          Only a brave party of adventurers can venture into the darkness and rescue her 
          before it&apos;s too late...
        </Text>
      </View>

      {party.length > 0 && (
        <View style={styles.partyBox}>
          <View style={styles.partyHeader}>
            <Users size={20} color="#d4af37" />
            <Text style={styles.partyTitle}>Current Party</Text>
          </View>
          {party.map((character, index) => (
            <View key={character.id} style={styles.partyMember}>
              <Text style={styles.partyMemberName}>
                {index + 1}. {character.name}
              </Text>
              <Text style={styles.partyMemberClass}>{character.class}</Text>
              <Text style={styles.partyMemberHP}>
                HP: {character.currentHP}/{character.maxHP}
              </Text>
            </View>
          ))}
        </View>
      )}

      <View style={styles.actions}>
        <TouchableOpacity
          style={styles.button}
          onPress={() => router.push('/inn')}
        >
          <Users size={24} color="#1a1a1a" />
          <Text style={styles.buttonText}>Visit the Inn</Text>
          <Text style={styles.buttonSubtext}>Recruit adventurers</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.button, styles.buttonDanger, party.length === 0 && styles.buttonDisabled]}
          onPress={() => party.length > 0 && router.push('/catacombs')}
          disabled={party.length === 0}
        >
          <Skull size={24} color={party.length === 0 ? '#666' : '#fff'} />
          <Text style={[styles.buttonText, party.length === 0 && styles.buttonTextDisabled]}>
            Enter the Catacombs
          </Text>
          {party.length === 0 && (
            <Text style={styles.buttonSubtext}>Recruit a party first!</Text>
          )}
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.button, styles.buttonAdmin]}
          onPress={() => router.push('/admin-images')}
        >
          <ImageIcon size={24} color="#1a1a1a" />
          <Text style={styles.buttonText}>Image Manager</Text>
          <Text style={styles.buttonSubtext}>Add creature & wall images</Text>
        </TouchableOpacity>
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
  loadingText: {
    color: '#d4af37',
    fontSize: 18,
    textAlign: 'center',
    marginTop: 40,
  },
  header: {
    alignItems: 'center',
    marginBottom: 24,
    marginTop: 20,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold' as const,
    color: '#d4af37',
    marginTop: 12,
    textAlign: 'center',
  },
  storyBox: {
    backgroundColor: '#2a2a2a',
    borderRadius: 12,
    padding: 20,
    marginBottom: 24,
    borderWidth: 2,
    borderColor: '#3a3a3a',
  },
  storyText: {
    color: '#ccc',
    fontSize: 16,
    lineHeight: 24,
  },
  storyTextSpaced: {
    marginTop: 16,
  },
  partyBox: {
    backgroundColor: '#2a2a2a',
    borderRadius: 12,
    padding: 16,
    marginBottom: 24,
    borderWidth: 2,
    borderColor: '#d4af37',
  },
  partyHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 12,
    gap: 8,
  },
  partyTitle: {
    fontSize: 18,
    fontWeight: 'bold' as const,
    color: '#d4af37',
  },
  partyMember: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#3a3a3a',
  },
  partyMemberName: {
    color: '#fff',
    fontSize: 14,
    flex: 1,
  },
  partyMemberClass: {
    color: '#aaa',
    fontSize: 12,
    marginRight: 12,
  },
  partyMemberHP: {
    color: '#4ade80',
    fontSize: 12,
  },
  actions: {
    gap: 16,
  },
  button: {
    backgroundColor: '#d4af37',
    borderRadius: 12,
    padding: 20,
    alignItems: 'center',
    gap: 8,
  },
  buttonDanger: {
    backgroundColor: '#8b0000',
  },
  buttonDisabled: {
    backgroundColor: '#3a3a3a',
  },
  buttonText: {
    color: '#1a1a1a',
    fontSize: 18,
    fontWeight: 'bold' as const,
  },
  buttonTextDisabled: {
    color: '#666',
  },
  buttonSubtext: {
    color: '#1a1a1a',
    fontSize: 12,
    opacity: 0.7,
  },
  buttonAdmin: {
    backgroundColor: '#4a5aff',
  },
});
