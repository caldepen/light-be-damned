import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, TextInput, TouchableOpacity, ScrollView, Alert } from 'react-native';
import { Stack } from 'expo-router';
import { Image } from 'expo-image';
import { setMonsterImage, setWallImageAsset, listAllMonsters, listAllWallImages, initializeDefaultMonsters } from '@/utils/imageManager';
import { getProjectAssetUrl } from '@/utils/assets';

export default function AdminImagesScreen() {
  const [isAuthenticated, setIsAuthenticated] = useState<boolean>(false);
  const [passwordInput, setPasswordInput] = useState<string>('');
  const [monsters, setMonsters] = useState<{
    name: string;
    imageAsset: string | null;
  }[]>([]);
  const [wallImages, setWallImages] = useState<{
    left: string | null;
    right: string | null;
    back: string | null;
  }>({ left: null, right: null, back: null });
  
  const [editingMonster, setEditingMonster] = useState<string | null>(null);
  const [editingWall, setEditingWall] = useState<'left' | 'right' | 'back' | null>(null);
  const [inputValue, setInputValue] = useState<string>('');

  const ADMIN_PASSWORD = 'dungeon2025';

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    const monstersList = await listAllMonsters();
    setMonsters(monstersList);
    
    const walls = await listAllWallImages();
    setWallImages(walls);
  };

  const handleSaveMonsterImage = async (monsterName: string, assetKey: string) => {
    try {
      await setMonsterImage(monsterName, assetKey);
      Alert.alert('Success', `Image set for ${monsterName}`);
      setEditingMonster(null);
      setInputValue('');
      await loadData();
    } catch (err) {
      console.error('Error saving monster image:', err);
      Alert.alert('Error', 'Failed to save monster image');
    }
  };

  const handleSaveWallImage = async (position: 'left' | 'right' | 'back', assetKey: string) => {
    try {
      await setWallImageAsset(position, assetKey);
      Alert.alert('Success', `Wall image set for ${position}`);
      setEditingWall(null);
      setInputValue('');
      await loadData();
    } catch (err) {
      console.error('Error saving wall image:', err);
      Alert.alert('Error', 'Failed to save wall image');
    }
  };

  const handleInitializeDefaults = async () => {
    try {
      await initializeDefaultMonsters();
      Alert.alert('Success', 'Default monsters initialized');
      await loadData();
    } catch (err) {
      console.error('Error initializing defaults:', err);
      Alert.alert('Error', 'Failed to initialize defaults');
    }
  };

  const handleLogin = () => {
    if (passwordInput === ADMIN_PASSWORD) {
      setIsAuthenticated(true);
      setPasswordInput('');
    } else {
      Alert.alert('Error', 'Incorrect password');
      setPasswordInput('');
    }
  };

  if (!isAuthenticated) {
    return (
      <>
        <Stack.Screen options={{ title: 'Admin', headerStyle: { backgroundColor: '#1a1a1a' }, headerTintColor: '#d4af37' }} />
        <View style={styles.loginContainer}>
          <Text style={styles.loginTitle}>Admin Access</Text>
          <TextInput
            style={styles.passwordInput}
            value={passwordInput}
            onChangeText={setPasswordInput}
            placeholder="Enter password"
            placeholderTextColor="#666"
            secureTextEntry
            onSubmitEditing={handleLogin}
          />
          <TouchableOpacity style={styles.loginButton} onPress={handleLogin}>
            <Text style={styles.loginButtonText}>Login</Text>
          </TouchableOpacity>
        </View>
      </>
    );
  }

  return (
    <>
      <Stack.Screen options={{ title: 'Image Manager', headerStyle: { backgroundColor: '#1a1a1a' }, headerTintColor: '#d4af37' }} />
      <ScrollView style={styles.container}>
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Instructions</Text>
          <Text style={styles.instructionText}>
            1. Upload your PNG images to the project
          </Text>
          <Text style={styles.instructionText}>
            2. Reference them using @asset_name
          </Text>
          <Text style={styles.instructionText}>
            3. Enter the asset key below (with or without @)
          </Text>
          <Text style={styles.instructionText}>
            4. The images will be stored in the database
          </Text>
          
          <TouchableOpacity 
            style={styles.initButton}
            onPress={handleInitializeDefaults}
          >
            <Text style={styles.initButtonText}>Initialize Default Monsters</Text>
          </TouchableOpacity>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Wall Images</Text>
          
          {(['left', 'right', 'back'] as const).map((position) => (
            <View key={position} style={styles.item}>
              <View style={styles.itemHeader}>
                <Text style={styles.itemName}>{position.toUpperCase()} Wall</Text>
                {wallImages[position] && (
                  <Image 
                    source={{ uri: getProjectAssetUrl(wallImages[position]!) }}
                    style={styles.thumbnail}
                    contentFit="cover"
                  />
                )}
              </View>
              
              {editingWall === position ? (
                <View style={styles.editForm}>
                  <TextInput
                    style={styles.input}
                    value={inputValue}
                    onChangeText={setInputValue}
                    placeholder="@wall_left or wall_left"
                    placeholderTextColor="#666"
                  />
                  <View style={styles.buttonRow}>
                    <TouchableOpacity 
                      style={[styles.button, styles.buttonSave]}
                      onPress={() => handleSaveWallImage(position, inputValue)}
                    >
                      <Text style={styles.buttonText}>Save</Text>
                    </TouchableOpacity>
                    <TouchableOpacity 
                      style={[styles.button, styles.buttonCancel]}
                      onPress={() => {
                        setEditingWall(null);
                        setInputValue('');
                      }}
                    >
                      <Text style={styles.buttonText}>Cancel</Text>
                    </TouchableOpacity>
                  </View>
                </View>
              ) : (
                <TouchableOpacity 
                  style={styles.editButton}
                  onPress={() => {
                    setEditingWall(position);
                    setInputValue(wallImages[position] || '');
                  }}
                >
                  <Text style={styles.editButtonText}>
                    {wallImages[position] ? 'Change Image' : 'Set Image'}
                  </Text>
                </TouchableOpacity>
              )}
            </View>
          ))}
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Monster Images</Text>
          
          {monsters.map((monster) => (
            <View key={monster.name} style={styles.item}>
              <View style={styles.itemHeader}>
                <Text style={styles.itemName}>{monster.name}</Text>
                {monster.imageAsset && (
                  <Image 
                    source={{ uri: getProjectAssetUrl(monster.imageAsset) }}
                    style={styles.thumbnail}
                    contentFit="contain"
                  />
                )}
              </View>
              
              {editingMonster === monster.name ? (
                <View style={styles.editForm}>
                  <TextInput
                    style={styles.input}
                    value={inputValue}
                    onChangeText={setInputValue}
                    placeholder="@giant_rat or giant_rat"
                    placeholderTextColor="#666"
                  />
                  <View style={styles.buttonRow}>
                    <TouchableOpacity 
                      style={[styles.button, styles.buttonSave]}
                      onPress={() => handleSaveMonsterImage(monster.name, inputValue)}
                    >
                      <Text style={styles.buttonText}>Save</Text>
                    </TouchableOpacity>
                    <TouchableOpacity 
                      style={[styles.button, styles.buttonCancel]}
                      onPress={() => {
                        setEditingMonster(null);
                        setInputValue('');
                      }}
                    >
                      <Text style={styles.buttonText}>Cancel</Text>
                    </TouchableOpacity>
                  </View>
                </View>
              ) : (
                <TouchableOpacity 
                  style={styles.editButton}
                  onPress={() => {
                    setEditingMonster(monster.name);
                    setInputValue(monster.imageAsset || '');
                  }}
                >
                  <Text style={styles.editButtonText}>
                    {monster.imageAsset ? 'Change Image' : 'Set Image'}
                  </Text>
                </TouchableOpacity>
              )}
            </View>
          ))}
        </View>
      </ScrollView>
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0a0a0a',
  },
  section: {
    padding: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#2a2a2a',
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: 'bold' as const,
    color: '#d4af37',
    marginBottom: 16,
  },
  instructionText: {
    color: '#aaa',
    fontSize: 14,
    marginBottom: 8,
  },
  initButton: {
    backgroundColor: '#4a5aff',
    padding: 12,
    borderRadius: 8,
    marginTop: 12,
    alignItems: 'center',
  },
  initButtonText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: 'bold' as const,
  },
  item: {
    backgroundColor: '#1a1a1a',
    padding: 16,
    borderRadius: 8,
    marginBottom: 12,
  },
  itemHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  itemName: {
    fontSize: 16,
    fontWeight: 'bold' as const,
    color: '#fff',
    flex: 1,
  },
  thumbnail: {
    width: 50,
    height: 50,
    borderRadius: 4,
    backgroundColor: '#2a2a2a',
  },
  editForm: {
    gap: 12,
  },
  input: {
    backgroundColor: '#2a2a2a',
    color: '#fff',
    padding: 12,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#3a3a3a',
  },
  buttonRow: {
    flexDirection: 'row',
    gap: 8,
  },
  button: {
    flex: 1,
    padding: 12,
    borderRadius: 8,
    alignItems: 'center',
  },
  buttonSave: {
    backgroundColor: '#1e5a1e',
  },
  buttonCancel: {
    backgroundColor: '#666',
  },
  buttonText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: 'bold' as const,
  },
  editButton: {
    backgroundColor: '#2a2a2a',
    padding: 10,
    borderRadius: 8,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#3a3a3a',
  },
  editButtonText: {
    color: '#d4af37',
    fontSize: 14,
  },
  loginContainer: {
    flex: 1,
    backgroundColor: '#0a0a0a',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  loginTitle: {
    fontSize: 24,
    fontWeight: 'bold' as const,
    color: '#d4af37',
    marginBottom: 32,
  },
  passwordInput: {
    backgroundColor: '#2a2a2a',
    color: '#fff',
    padding: 16,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#3a3a3a',
    width: '100%',
    maxWidth: 300,
    marginBottom: 16,
    fontSize: 16,
  },
  loginButton: {
    backgroundColor: '#d4af37',
    padding: 16,
    borderRadius: 8,
    width: '100%',
    maxWidth: 300,
    alignItems: 'center',
  },
  loginButtonText: {
    color: '#000',
    fontSize: 16,
    fontWeight: 'bold' as const,
  },
});
