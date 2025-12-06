import React from 'react';
import { View, StyleSheet, Dimensions } from 'react-native';
import { Image } from 'expo-image';
import { DungeonLevel, Position } from '@/types/game';
import { getViewDescription } from '@/utils/dungeon';
import { wallImages } from '@/assets/dungeon/walls';

const SCREEN_WIDTH = Dimensions.get('window').width;
const DUNGEON_HEIGHT = 400;

type DungeonRendererProps = {
  dungeonLevel: DungeonLevel;
  position: Position;
  inCombat: boolean;
};

export default function DungeonRenderer({ dungeonLevel, position, inCombat }: DungeonRendererProps) {
  const view = getViewDescription(dungeonLevel, position);

  const calculateDepth = () => {
    let depth = 0;
    let tempPos = { ...position };
    
    while (depth < 3 && !dungeonLevel.grid[tempPos.y]?.[tempPos.x]?.walls[tempPos.facing]) {
      depth++;
      switch (tempPos.facing) {
        case 'north': tempPos.y -= 1; break;
        case 'south': tempPos.y += 1; break;
        case 'east': tempPos.x += 1; break;
        case 'west': tempPos.x -= 1; break;
      }
      if (tempPos.x < 0 || tempPos.y < 0 || tempPos.x >= dungeonLevel.width || tempPos.y >= dungeonLevel.height) {
        break;
      }
    }
    
    return depth;
  };

  const depth = calculateDepth();

  const renderFloor = () => {
    return (
      <View style={styles.floorContainer}>
        {depth >= 2 && (
          <View style={[styles.floorFar, { backgroundColor: '#2a1810' }]} />
        )}
        {depth >= 1 && (
          <View style={[styles.floorMid, { backgroundColor: '#3a2010' }]} />
        )}
        <View style={[styles.floorClose, { backgroundColor: '#4a3020' }]} />
      </View>
    );
  };

  const renderCeiling = () => {
    return (
      <View style={styles.ceilingContainer}>
        {depth >= 2 && (
          <View style={[styles.ceilingFar, { backgroundColor: '#1a1a1a' }]} />
        )}
        {depth >= 1 && (
          <View style={[styles.ceilingMid, { backgroundColor: '#2a2a2a' }]} />
        )}
        <View style={[styles.ceilingClose, { backgroundColor: '#3a3a3a' }]} />
      </View>
    );
  };

  const renderBackWalls = () => {
    const layers = [];

    if (depth === 0) {
      layers.push(
        <View
          key="back-front"
          style={[styles.backWallFront, { backgroundColor: '#4a4a4a' }]}
        />
      );
    } else if (depth === 1) {
      layers.push(
        <View
          key="back-mid"
          style={[styles.backWallMid, { backgroundColor: '#4a4a4a' }]}
        />
      );
    } else if (depth >= 2) {
      layers.push(
        <View
          key="back-far"
          style={[styles.backWallFar, { backgroundColor: '#4a4a4a' }]}
        />
      );
    }

    return layers;
  };

  const renderSideWalls = () => {
    return (
      <>
        {view.hasLeftWall && (
          <View style={styles.leftWallContainer}>
            {depth >= 2 && wallImages.left.far && (
              <Image source={wallImages.left.far} style={styles.leftWallFar} contentFit="cover" />
            )}
            {depth >= 2 && !wallImages.left.far && (
              <View style={[styles.leftWallFar, { backgroundColor: '#3a3a3a' }]} />
            )}
            {depth >= 1 && wallImages.left.mid && (
              <Image source={wallImages.left.mid} style={styles.leftWallMid} contentFit="cover" />
            )}
            {depth >= 1 && !wallImages.left.mid && (
              <View style={[styles.leftWallMid, { backgroundColor: '#3a3a3a' }]} />
            )}
            {wallImages.left.close ? (
              <Image source={wallImages.left.close} style={styles.leftWallClose} contentFit="cover" />
            ) : (
              <View style={[styles.leftWallClose, { backgroundColor: '#3a3a3a' }]} />
            )}
          </View>
        )}
        
        {view.hasRightWall && (
          <View style={styles.rightWallContainer}>
            {depth >= 2 && wallImages.right.far && (
              <Image source={wallImages.right.far} style={styles.rightWallFar} contentFit="cover" />
            )}
            {depth >= 2 && !wallImages.right.far && (
              <View style={[styles.rightWallFar, { backgroundColor: '#3a3a3a' }]} />
            )}
            {depth >= 1 && wallImages.right.mid && (
              <Image source={wallImages.right.mid} style={styles.rightWallMid} contentFit="cover" />
            )}
            {depth >= 1 && !wallImages.right.mid && (
              <View style={[styles.rightWallMid, { backgroundColor: '#3a3a3a' }]} />
            )}
            {wallImages.right.close ? (
              <Image source={wallImages.right.close} style={styles.rightWallClose} contentFit="cover" />
            ) : (
              <View style={[styles.rightWallClose, { backgroundColor: '#3a3a3a' }]} />
            )}
          </View>
        )}
      </>
    );
  };

  return (
    <View style={styles.dungeonCanvas}>
      {renderCeiling()}
      <View style={styles.middleSection}>
        {renderSideWalls()}
        <View style={styles.centerSection}>
          {renderBackWalls()}
        </View>
      </View>
      {renderFloor()}
      
      {inCombat && (
        <View style={styles.combatOverlay}>
          <View style={styles.combatIndicator} />
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  dungeonCanvas: {
    width: SCREEN_WIDTH - 40,
    height: DUNGEON_HEIGHT,
    backgroundColor: '#0a0a0a',
    borderWidth: 3,
    borderColor: '#d4af37',
    borderRadius: 8,
    overflow: 'hidden',
    position: 'relative',
  },
  
  ceilingContainer: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: DUNGEON_HEIGHT * 0.3,
    alignItems: 'center',
  },
  ceilingClose: {
    position: 'absolute',
    bottom: 0,
    width: '100%',
    height: '40%',
    borderBottomWidth: 2,
    borderBottomColor: '#000',
  },
  ceilingMid: {
    position: 'absolute',
    bottom: 0,
    width: '70%',
    height: '30%',
    borderBottomWidth: 1,
    borderBottomColor: '#000',
  },
  ceilingFar: {
    position: 'absolute',
    bottom: 0,
    width: '40%',
    height: '20%',
    borderBottomWidth: 1,
    borderBottomColor: '#000',
  },
  
  middleSection: {
    position: 'absolute',
    top: DUNGEON_HEIGHT * 0.3,
    left: 0,
    right: 0,
    height: DUNGEON_HEIGHT * 0.4,
    flexDirection: 'row',
  },
  centerSection: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  
  leftWallContainer: {
    position: 'absolute',
    left: 0,
    top: 0,
    bottom: 0,
    width: '35%',
    justifyContent: 'center',
  },
  leftWallClose: {
    position: 'absolute',
    left: 0,
    width: '100%',
    height: '100%',
    borderRightWidth: 3,
    borderRightColor: '#000',
  },
  leftWallMid: {
    position: 'absolute',
    left: '20%',
    width: '60%',
    height: '70%',
    top: '15%',
    borderRightWidth: 2,
    borderRightColor: '#000',
  },
  leftWallFar: {
    position: 'absolute',
    left: '35%',
    width: '40%',
    height: '40%',
    top: '30%',
    borderRightWidth: 1,
    borderRightColor: '#000',
  },
  
  rightWallContainer: {
    position: 'absolute',
    right: 0,
    top: 0,
    bottom: 0,
    width: '35%',
    justifyContent: 'center',
  },
  rightWallClose: {
    position: 'absolute',
    right: 0,
    width: '100%',
    height: '100%',
    borderLeftWidth: 3,
    borderLeftColor: '#000',
  },
  rightWallMid: {
    position: 'absolute',
    right: '20%',
    width: '60%',
    height: '70%',
    top: '15%',
    borderLeftWidth: 2,
    borderLeftColor: '#000',
  },
  rightWallFar: {
    position: 'absolute',
    right: '35%',
    width: '40%',
    height: '40%',
    top: '30%',
    borderLeftWidth: 1,
    borderLeftColor: '#000',
  },
  
  backWallFront: {
    width: '60%',
    height: '100%',
    borderWidth: 3,
    borderColor: '#000',
  },
  backWallMid: {
    width: '40%',
    height: '70%',
    borderWidth: 2,
    borderColor: '#000',
  },
  backWallFar: {
    width: '25%',
    height: '40%',
    borderWidth: 1,
    borderColor: '#000',
  },
  
  floorContainer: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    height: DUNGEON_HEIGHT * 0.3,
    alignItems: 'center',
  },
  floorClose: {
    position: 'absolute',
    top: 0,
    width: '100%',
    height: '60%',
    borderTopWidth: 2,
    borderTopColor: '#000',
  },
  floorMid: {
    position: 'absolute',
    top: 0,
    width: '70%',
    height: '40%',
    borderTopWidth: 1,
    borderTopColor: '#000',
  },
  floorFar: {
    position: 'absolute',
    top: 0,
    width: '40%',
    height: '20%',
    borderTopWidth: 1,
    borderTopColor: '#000',
  },
  
  combatOverlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: 'rgba(139, 0, 0, 0.1)',
  },
  combatIndicator: {
    width: 100,
    height: 100,
    borderRadius: 50,
    borderWidth: 4,
    borderColor: '#ff0000',
    backgroundColor: 'rgba(255, 0, 0, 0.2)',
  },
});
