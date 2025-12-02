# Adding Images to Your Dungeon Crawler

This game now supports PNG images for creatures and dungeon walls!

## How to Add Images

### Step 1: Upload Your Images
1. Create your PNG images (creatures, walls, etc.)
2. Upload them to the Rork project using the attachments feature
3. Reference them with `@asset_name` (e.g., `@giant_rat`, `@wall_left`)

### Step 2: Use the Image Manager
1. Go to the **Town** tab
2. Click the **Image Manager** button
3. Click **Initialize Default Monsters** (first time only)

### Step 3: Assign Images
1. For each monster (Giant Rat, Goblin):
   - Click "Set Image" or "Change Image"
   - Enter the asset key (e.g., `@giant_rat` or `giant_rat`)
   - Click Save

2. For dungeon walls (Left, Right, Back):
   - Click "Set Image" or "Change Image"
   - Enter the asset key (e.g., `@wall_left` or `wall_left`)
   - Click Save

## Asset Naming Examples

**Monsters:**
- `@giant_rat` - Image for Giant Rat
- `@goblin` - Image for Goblin

**Walls:**
- `@wall_left` - Left wall image
- `@wall_right` - Right wall image
- `@wall_back` - Back wall image (dead end)

## Image Requirements

- **Format:** PNG (recommended for transparency)
- **Monster images:** 60x60px or larger, square format works best
- **Wall images:** Any size, but consistent dimensions recommended
  - Back wall: Appears centered in the dungeon view
  - Left/Right walls: Fill the side panels

## How It Works

1. Images are stored in the SQLite database by reference
2. The game fetches images from Rork's project assets URL
3. If no image is set, the game falls back to the original ASCII/geometric art
4. Images are cached by expo-image for performance

## Adding More Monsters in the Future

To add new monster types:
1. Add the monster definition to `constants/gameData.ts`
2. The Image Manager will automatically detect it
3. Upload the PNG and assign it via the Image Manager

## Technical Details

- Database tables: `monsters`, `dungeon_walls`
- Asset URL pattern: `https://rork.app/pa/{projectId}/{assetKey}`
- Utilities: `utils/imageManager.ts`, `utils/assets.ts`
- Database functions: `lib/database.ts`
