import { DungeonLevel, Tile, Position, Direction } from '@/types/game';

export function generateDungeon(level: number, width: number = 10, height: number = 10): DungeonLevel {
  const grid: Tile[][] = [];
  
  for (let y = 0; y < height; y++) {
    grid[y] = [];
    for (let x = 0; x < width; x++) {
      grid[y][x] = {
        walls: {
          north: true,
          south: true,
          east: true,
          west: true
        },
        visited: false
      };
    }
  }
  
  const stack: { x: number; y: number }[] = [];
  const startX = 0;
  const startY = 0;
  
  stack.push({ x: startX, y: startY });
  grid[startY][startX].visited = true;
  
  while (stack.length > 0) {
    const current = stack[stack.length - 1];
    const neighbors: { x: number; y: number; dir: Direction }[] = [];
    
    if (current.y > 0 && !grid[current.y - 1][current.x].visited) {
      neighbors.push({ x: current.x, y: current.y - 1, dir: 'north' });
    }
    if (current.y < height - 1 && !grid[current.y + 1][current.x].visited) {
      neighbors.push({ x: current.x, y: current.y + 1, dir: 'south' });
    }
    if (current.x < width - 1 && !grid[current.y][current.x + 1].visited) {
      neighbors.push({ x: current.x + 1, y: current.y, dir: 'east' });
    }
    if (current.x > 0 && !grid[current.y][current.x - 1].visited) {
      neighbors.push({ x: current.x - 1, y: current.y, dir: 'west' });
    }
    
    if (neighbors.length > 0) {
      const next = neighbors[Math.floor(Math.random() * neighbors.length)];
      
      if (next.dir === 'north') {
        grid[current.y][current.x].walls.north = false;
        grid[next.y][next.x].walls.south = false;
      } else if (next.dir === 'south') {
        grid[current.y][current.x].walls.south = false;
        grid[next.y][next.x].walls.north = false;
      } else if (next.dir === 'east') {
        grid[current.y][current.x].walls.east = false;
        grid[next.y][next.x].walls.west = false;
      } else if (next.dir === 'west') {
        grid[current.y][current.x].walls.west = false;
        grid[next.y][next.x].walls.east = false;
      }
      
      grid[next.y][next.x].visited = true;
      stack.push({ x: next.x, y: next.y });
    } else {
      stack.pop();
    }
  }
  
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      grid[y][x].visited = false;
    }
  }
  
  return {
    level,
    grid,
    width,
    height
  };
}

export function canMove(dungeon: DungeonLevel, position: Position): boolean {
  const { x, y, facing } = position;
  const tile = dungeon.grid[y][x];
  
  return !tile.walls[facing];
}

export function moveForward(position: Position): Position {
  const newPos = { ...position };
  
  switch (position.facing) {
    case 'north':
      newPos.y = Math.max(0, position.y - 1);
      break;
    case 'south':
      newPos.y = position.y + 1;
      break;
    case 'east':
      newPos.x = position.x + 1;
      break;
    case 'west':
      newPos.x = Math.max(0, position.x - 1);
      break;
  }
  
  return newPos;
}

export function turnLeft(facing: Direction): Direction {
  const directions: Direction[] = ['north', 'west', 'south', 'east'];
  const currentIndex = directions.indexOf(facing);
  return directions[(currentIndex + 1) % 4];
}

export function turnRight(facing: Direction): Direction {
  const directions: Direction[] = ['north', 'east', 'south', 'west'];
  const currentIndex = directions.indexOf(facing);
  return directions[(currentIndex + 1) % 4];
}

export function checkForEncounter(): boolean {
  return Math.random() < 0.25;
}

export function getViewDescription(dungeon: DungeonLevel, position: Position): {
  hasWallAhead: boolean;
  hasLeftWall: boolean;
  hasRightWall: boolean;
} {
  const tile = dungeon.grid[position.y][position.x];
  const facing = position.facing;
  
  return {
    hasWallAhead: tile.walls[facing],
    hasLeftWall: tile.walls[turnLeft(facing)],
    hasRightWall: tile.walls[turnRight(facing)]
  };
}
