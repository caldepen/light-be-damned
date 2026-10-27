# Card RPG — Rules v0.5

Version 0.5 · 25 October 2026

## 1. Overview

A party of four heroes delves into a shifting dungeon, fights with cards instead of dice, and comes back again and again until it is strong enough to face the boss.

- **Who plays.** The party is always four heroes: Fighter, Cleric, Thief and Wizard. One player can run the whole party (like Bard's Tale or Wizardry), or players can share the heroes. Enemies are run by the game's automated decks, or by a human Dungeon Master (DM) for a harder game.
- **How a campaign flows.** A module is played over several **runs**. Each run, the party explores, fights and loots, then escapes to town to recover, level up and re-equip. A first run is not expected to reach the boss.
- **Losing.** A hero who goes Down is not dead. If the whole party goes Down, the run ends in a **wipe**: the party returns to town having lost what it found that run.

**Design pillars**

- **The deck is the character sheet.** There are no stat blocks; a hero is the cards in their deck.
- **Randomness comes from the draw.** Card effects are fixed. The uncertainty is which cards you draw, and when.
- **Wounds take your options away.** Injury fills your hand with useless Wound cards.
- **The deck is the clock.** Fighting and exploring both run your deck down; the campfire is the only full reset.

## 2. Components and setup

**Components (prototype list)**

- 4 hero decks of 30 cards, plus advancement cards for levels 2 and 3
- 4 hero boards, each with armor slots and four equipment slots (Weapon, Armor, Off-hand, Trinket)
- White starting gear cards, and the loot deck (gear and consumables)
- Enemy cards (stats) and one action deck per enemy type: goblin, ogre, skeleton, witch
- 2 battle boards of 3×3 squares (heroes and enemies)
- The Provoke track (0–20) with 4 hero tokens
- Map tiles and the tile bag; room decks; Hut Whim cards
- Tokens: Guard, damage markers, Bleed, Stun, toad; the Hut track; rations; the party XP track

**Starting a campaign**

1. Each hero takes their 30-card deck and White starting gear. Party level 1, XP 0.
2. Shuffle the loot deck. It is kept for the whole campaign; items found leave it.

**Starting a run**

1. Each hero shuffles their deck and draws a hand: Fighter 6, Cleric 5, Thief 5, Wizard 4.
2. Take 8 rations (two campfires for a party of four).
3. Set up the module (see section 10): place the entrance tile, shuffle the tile bag, set the Hut track to 0.

## 3. Heroes and cards

Each hero has one **Type**, which decides the cards they use and the skill rolls they are good at.

| Hero | Type | Role | Hand | Starting armor |
| --- | --- | --- | --- | --- |
| Fighter | Strength | Tank: holds Provoke, soaks hits, repairs armor | 6 | Chainmail 4 + Shield 1 |
| Cleric | Spirit | Healer: Wounds, armor, radiant damage | 5 | Chainmail 4 |
| Thief | Agility | Burst damage, mobility, locks and traps | 5 | Leather 2 |
| Wizard | Wits | Ranged and area magic; fragile | 4 | Robes 0 |

| Type | Skill rolls | Attacks |
| --- | --- | --- |
| Strength | Bash doors, lift portcullises, force chests, break free | Swords, axes, shields |
| Agility | Pick locks, disarm traps, sneak, dodge a sprung trap | Daggers, bows |
| Wits | Spot traps and hidden doors, read runes, lore, puzzles | Elemental magic |
| Spirit | Resist curses, sense evil, persuade, purify cursed treasure | Radiant magic, maces, healing |

**Card anatomy.** Every hero card has a name, an effect and a **skill value** from 1 to 6 (bottom right). The effect is used in battle; the skill value only matters for skill rolls when exploring. Each 30-card deck holds five cards of each skill value, so a flip rolls like a six-sided die.

**Special cards**

- **Signature (★).** One per hero: Berserk, Party Heal, Backstab, and the wizard's signature (Fireball, Chain Lightning or Frost Spike, chosen at each campfire).
- **Top tier (▲).** Each hero's four strongest cards. They Exhaust when played.
- **Exhaust.** The card is set aside until the next campfire, instead of going to the discard pile.
- **Recovery (↺).** Pulls cards back from the discard pile. It can never recover Exhausted cards or itself.

## 4. Turn summary (quick reference)

**A battle round**

1. Heroes and enemies take turns one at a time, alternating, starting with a hero.
2. Each hero acts once per round, in any order the party chooses. Turn a hero's card sideways when they've acted. Enemies act front row first, then left to right.
3. When one side has nobody left to act, the other side finishes the round (the party still chooses the order of its remaining heroes). Stunned figures and toads lose their turn without taking a place in the alternation.
4. Extra turns (Bone Storm), in the order they were gained.
5. End of round: Bleed deals its damage; Guard cards played last round are discarded; Guard cards played this round turn sideways.

**Turns and rounds**

- **Turn:** one figure acting once. A hero's turn is playing a card, flipping or passing. An enemy's turn is flipping and playing (including a ◆ phase card plus the card it then plays, and Go Fish). A turn that is skipped (Stun, Polymorph) still counts as that figure's turn.
- **Round:** every figure on both sides takes one turn (or has it skipped), then any extra turns (Bone Storm), then the end-of-round step runs (Bleed, Guard, other round effects). Battles start at round 1.
- **"This turn"** means the acting figure's current turn.
- **"Next turn"** means that figure's next turn, whenever it comes. For a hero who hasn't acted yet this round, that's later this round; for one who already acted, it's next round. So a Stun on a hero who hasn't acted makes them lose this round's turn; a Stun on one who has acted makes them lose next round's.
- **"For X rounds" and "until the end of the next round"** count end-of-round steps, starting with the end of the round in which the card was played. Bleed 2 played in round 1 deals damage at the end of rounds 1 and 2; a Guard card played in round 1 is discarded at the end of round 2.

**A hero's turn**

1. Draw any cards owed (from Disarm or Hex).
2. Either **play** one card from your hand that has a legal effect, **flip** the top card of your deck and play it blind, or **pass**.
3. Before a melee attack you may take one free straight step to get in reach.
4. If the card has a damage, heal or repair effect and was played on a legal target, move your Provoke token up 1 for every point of damage that landed and every Wound removed or armor point repaired (at least 1), then by any Provoke the card names.
5. Discard the card (or Exhaust it) and draw back up to your hand size.

**An enemy's turn**

1. Melee enemies take a free straight step toward the hero highest on the Provoke track.
2. Flip cards equal to its Draw from its type's deck.
3. Phase cards (◆) take effect. Then it plays one card, chosen by morale (Bold or Desperate: highest damage; Timid: lowest).
4. If nothing can be played, it flips one more (Go Fish); otherwise the turn is lost.

**Out of battle**

1. Move through an unexplored opening: reveal a tile, Hut track +1.
2. Enter each room and resolve its card: battle, obstacle, treasure, event or empty.
3. After a won battle: bandage (each hero removes 2 Wounds), draw loot, +1 XP.
4. Camp in an Empty room when decks run low; leave by the entrance when it's time to go home.

## 5. Battle

**The boards.** Heroes and enemies each have a 3×3 board, facing each other front to front. Each board has a front, middle and back row and three lanes (left, centre, right).

- **Lanes.** Both boards share one lane numbering, as seen by the players at the table: the players' left lane is the left lane on both boards, so the two boards form one 6×3 grid seen from above. "Left to right" in enemy turn order and "neighbouring lane" for melee both use this numbering.

- **Placement.** The players place their heroes on any squares of their board. Enemies fill their front row first, then the middle, then the back.
- **Size.** Most figures take one square. Large enemies take 2×2 (the ogre) and start in the front and middle rows of the left and centre lanes; the other enemies then fill the remaining squares, front row first.
- **Down.** A hero or enemy that goes Down is removed from the board.
- **Shifting front.** If a side's front row is empty, its front-most occupied row counts as the front row. Cards that target the "enemy front row" (Quake, Caltrops, Turn Undead) use this shifting front, and never need reach.

**Turn order.** Heroes and enemies alternate, one figure at a time, starting with a hero. Each hero acts once per round, in any order the party chooses. Turn a hero's card sideways when they've acted. Enemies act front row first, then left to right; a large enemy acts by its front-left square. When one side runs out of figures to act, the other side finishes the round. Positions decide when each enemy acts, so the enemies standing in front act first; the party decides when each hero acts.

- **Choosing a hero.** On each hero turn, choose one hero who hasn't acted this round. A Down hero can't be chosen.
- **Lost turns.** A hero or enemy who is Stunned or a toad when the round starts loses this round's turn: it counts as having acted (turn a hero's card sideways) and the Stun is used up. A figure Stunned during the round before it has acted also loses this round's turn. A lost turn takes no place in the alternation, so when one side has figures Down or losing turns, the other side may act several times in a row.
- **Stun and toad together.** One lost turn uses up both: the Stun and one of the toad's turns. A toad with 2 turns left that is also Stunned loses 2 turns, not 3.
- **Extra turns** (Bone Storm) come just before the end-of-round step, after every other figure has acted, in the order the figures gained them.
- **Enemy order** is fixed at the start of each round. An enemy that moves keeps its place in the order, and a figure that joins mid-round (Shriek, Raise Skeletons, Throw Goblin) first acts next round.
- **Round limit.** The tabletop game has none. The digital engine stops a battle after `battle.round_cap` rounds (`data/rules.json`) and records it as a draw, so simulations can count stalled fights.

**Your turn: play, flip or pass.** Play one card from your hand, flip the top card of your deck and play it blind, or pass. Flipping is how you dig past a hand clogged with Wounds or cards you can't use.

- **Legal plays.** You may only play a card from your hand if at least one of its effects has a legal target or use (a heal needs a wounded hero, a melee attack needs an enemy in reach after the free step). You can't play a dead card just to cycle it. Wounds can never be played.
- **Flipping.** A flipped card with a legal effect must be played, and you choose its targets as normal. A flipped card with no legal effect is discarded with no effect (a ▲ or ★ card still Exhausts). A flip draws no replacement, since your hand didn't shrink.
- **Empty hand.** A hero with an empty hand is not Down while their deck has cards; they may flip as normal. A hero with no cards in hand or deck is spent and goes Down (see §6, Armor and Wounds).

- **Draw to replace.** After playing a card from your hand, draw back up to your hand size. A healed Wound is also replaced by a draw.
- **Above hand size.** Cards that draw extra can push a hand above its size. While it is at or above its size, you don't draw replacements.
- **Empty deck.** A hero whose deck runs out finishes the current battle with what is in hand, then sits out every battle until the party camps.

**Movement**

- **Free step.** Before a melee attack, a hero or enemy may step 1 square into an empty adjacent square, on either board, to get in reach.
- **Straight only.** All movement is forward, back or sideways, never diagonal, unless a card says otherwise (Blink, Vault). Attacks can still reach diagonally.
- **Card movement.** Apart from the free step, figures only move when a card says so ("Move to the nearest square in melee reach, then…"). A card that moves you replaces the free step; you can't use both.
- **"Move to the nearest square in melee reach"** (Twin Daggers, Backstab, Ambush) moves any distance, ignoring the straight-only rule, to an empty square within melee reach of the target, on either board. Pick the square closest to you (counting diagonal squares as 1); if several are equally close, you choose.
- **Behind the lines.** A figure on the other side's board reaches, and can be reached by, anything within 1 square of it there.

## 6. Attacks, Provoke and damage

**Attacks** always deal the damage printed on the card. Guard and armor are what stop it.

- **Melee** attacks hit a target within 1 square, including diagonally. A front-row hero reaches the enemy front row in the same or a neighbouring lane. A large enemy is in reach if any of its squares is.
- **Ranged** attacks (marked Ranged) can target any square.
- **Bonuses** (Berserk +1, Bless +2, Feint +2, Arcane Surge +2): a bonus applies to every target of the card, so it adds to each enemy hit, to each bolt of a split attack, and to each hero who gains Guard from it (Bless on Battle Cry or Shield Wall: +2 Guard tokens to each). Bless targets an ally, never the Cleric herself.
- **Add bonuses first, then double.** Divine Light with Bless against undead deals (2 + 2) × 2 = 8.
- **Enemy front row.** Attacks on the enemy front row (Quake, Caltrops) never need reach.

| Area | Hits |
| --- | --- |
| Adjacent | Every enemy within 1 square of you |
| Row | Every enemy in one row |
| Area 2×2 | Every enemy in a chosen 2×2 block |
| Chain | A first target, then each next target within 1 square of the last |

**The Provoke track (threat meter).** One shared track from 0 to 20 with a token for each hero; all tokens start at 0 each battle.

- **Provoke per point.** A card a hero plays earns +1 for every point it lands and every point it heals:
  - Damage counts the points that land: each one that fills an armor slot, marks a Hit Die or adds a Wound. Points absorbed by Guard, hits cancelled by Iron Skin and overkill past an enemy's last Hit Die earn nothing. Steady Strike for 3 on a goblin with one Hd left earns +1; on a fresh goblin (1 armor, 4 Hd) it earns +3.
  - Healing counts each Wound removed (including Wounds Lay on Hands moves to the Cleric) and each armor point repaired, on yourself or an ally.
  - A card with a damage, heal or repair effect played on a legal target earns at least +1, even if Guard absorbs everything or Iron Skin cancels it.
  - Bleed is not damage for this purpose: Bleed ticks, cards whose only effect is Bleed (Burn), Thorns and Lightning Orb's end-of-round damage don't count.
- Cards that name Provoke move the token that many spaces (Challenge +3, War Cry +5). Backstab halves it; Vanish and Blink move it down 3. This is on top of the points above.
- **Order.** The Provoke for points comes first; the card's own Provoke always resolves last, so the card's text has the final word. Backstab for 6 on a goblin with 1 armor and 2 Hd left lands 3: at 5, +3 → 8, then halve → 4.
- Ties: a token moving onto an occupied space goes on top, and the top token counts as highest.
- **Start and limits.** All tokens start on 0, stacked from top to bottom Fighter, Cleric, Thief, Wizard. The track runs from 0 to 20. A token at 20 that gains Provoke goes on top of the 20 stack; a token at 0 that loses Provoke stays where it is.
- Provoke never decays during a battle, so a tank who stops adding to it is eventually overtaken.

**Who enemies attack.** A melee enemy uses its free step to move one square toward the hero highest on the track (if that square is empty), then attacks the highest-Provoke hero it can reach. Turn by turn it works its way toward the top hero, striking whoever stands in its path. Ranged enemy attacks simply target the top hero. A DM must follow these rules unless an enemy card says otherwise.

**Guard.** Playing a Guard card puts it in front of the hero with Guard tokens on it. A hero has at most one Guard card in play; further Guard on that hero only adds tokens to it. Each token absorbs 1 damage. The card turns sideways at the end of the round it was played and is discarded, with any tokens left, at the end of the next round.

- Guard added to a Guard card already in play keeps that card's timing.
- Guard absorbs all damage, Bleed included.
- Enemy Guard (Cower, Rattle) follows the same timing.

**Thorns** reflects the points that got past the fighter's Guard (armor slots filled plus Wounds) to the attacker, as damage that is not an attack. Reflected damage never earns Provoke, and nothing is reflected if Iron Skin cancels the attack.

**Armor and Wounds**

1. Damage that gets past Guard fills armor and shield slots first, one point per slot. Bleed fills them like any other damage.
2. When every slot is full, each further point puts a **Wound** card into your hand, and you discard a non-Wound card of your choice, so your hand size stays the same. You can't discard a Wound this way. If you have no non-Wound card, the Wound is simply added.
3. You are **Down** and leave the board whenever your hand holds nothing but Wounds (at least one), or you have no cards left in hand or deck. On your turn, check whether you're Down once your card has fully resolved and you've drawn to replace. At any other time (enemy turns, end of round), check as soon as a Wound lands. Wounds that land on you while your own card resolves (Thorns, Lay on Hands) count at that one check, however the hand got that way. Wounds count toward hand size, so a hand filled with Wounds gets no replacement draw: taking several Wounds through Lay on Hands can put the Cleric Down, a deliberate sacrifice. An empty hand with cards still in the deck is not Down, but a hit on it adds a Wound, and a hand of just that Wound is Down.

**Healing**

- "Any hero" includes yourself. "Adjacent" (Mend) means within 1 square, diagonals included, and also includes yourself.
- Wounds taken by Lay on Hands enter your hand as if from damage (discard a non-Wound card for each) and can knock you Down. The ally draws a replacement for each Wound removed.

| Armor or shield | Slots |
| --- | --- |
| Plate | 6 |
| Chainmail | 4 |
| Leather | 2 |
| Robes | 0 |
| Shield | 1 (Iron-banded: 2) |

## 7. Enemies

Enemies have no hands. Each enemy card shows its armor and **Hit Dice (Hd)**: damage fills armor first, then Hd boxes, marked with damage tokens. When every Hd is marked, the enemy is Down. Enemy stats are set for a full party of four.

| Enemy | Armor | Hit Dice | Draw | Notes |
| --- | --- | --- | --- | --- |
| Goblin | 1 | 4 | 1 | Weak alone, dangerous in groups |
| Skeleton | 1 | 3 | 1 | Undead |
| Ogre | 3 | 5 | 2 | Size 2×2 |
| Witch (boss) | 2 | 18 | 3 | See section 10 |

**Shared action decks.** Every enemy of a type flips from that type's one deck (all goblins share the goblin deck). When a deck runs out, shuffle its discards into a new one.

**An enemy's turn**

1. It flips cards equal to its **Draw**: simple creatures 1, tougher monsters 2, bosses 3.
2. A **phase card (◆)** takes effect for the rest of the battle, and the enemy then plays another of its flipped cards if it can. Each ◆ card takes effect once per enemy per battle: two ogres can each Rage once, and a deck reshuffle doesn't reset it. A repeat flip of a ◆ card already used by this enemy counts as unflipped.
3. It plays one card, chosen by morale, and discards the rest.
4. **Top-tier enemy cards (▲)** are played once per battle by each enemy; if flipped again, it plays another card.
5. **Go Fish.** If no flipped card can be played (including when a ◆ card leaves it with no other flipped card), it flips one more and plays that if it can. If the Go Fish card is a ◆ card, it takes effect (if this enemy hasn't used it) and the turn ends. Otherwise its turn is lost.

**Playable enemy cards**

- **Melee X:** needs a hero in reach after the free step.
- **Melee X · Throw Y:** always playable; it throws if nothing is in reach.
- **Ranged, and "every hero within 1 square":** need at least one valid target.
- **Self-Guard and utility** (Cower, Rattle, Dim-witted): always playable. A Timid ogre that flips Dim-witted stumbles.
- **Healing and repair** (Reassemble, Healing Brew, Thick Hide): only if something is actually damaged.
- **Summons** (Raise Skeletons, Shriek's extra goblin): need an empty square.
- **Top tier (▲):** once per battle per enemy.
- **Flee:** always playable; it becomes an attack if the goblin isn't hurt enough to run.
- **Vault:** needs an empty middle-row square directly behind a front-row hero.

**Discards.** Discards caused by enemy cards (Disarm, Roar, Hex) never knock a hero Down. The hero must discard a non-Wound card if they have one; if that discard would leave them Down (a hand of only Wounds, or no cards in hand or deck), nothing is discarded. Disarm's and Hex's discards are replaced at the start of the hero's next turn. Roar's is not replaced specially; the hand fills back up the next time the hero plays a card and draws back up to hand size.

Enemy attacks are melee unless marked Ranged.

**Morale** (read off the enemy's Hd)

- **Bold:** fewer than half its Hd marked. It plays its highest-damage card.
- **Timid:** half or more marked. It plays its lowest-damage card.
- **Desperate:** only its last Hd unmarked. It plays its highest-damage card again: a cornered beast's desperate swing.

An enemy's **power** (unmarked armor + unmarked Hd) is what cards like Ambush use to find the weakest enemy.

**DM mode.** A DM flips extra cards and chooses which to play, ignoring morale but still following the Provoke and movement rules. **Standard DM:** flip Draw +1. **Ruthless DM:** flip Draw +3. In solo or co-op play the decks run the enemies automatically.

**Encounter sizes (four heroes).** Standard fight: 5 goblins. Tough fight: an ogre and 4 goblins. Skeletons come in bands of 5.

## 8. After a battle, exploring and camping

**After a won battle**

1. **Bandage.** Every hero, including any who went Down, removes 2 Wounds from their hand and draws replacements. Down heroes get back up. Bandaging restores no armor and no Exhausted cards.
2. **Patch up.** Heroes may play cards for their healing, repair and recovery effects (Mend, Fix Armor, Second Wind and the like), drawing replacements as usual. Fix Armor between battles removes all of the fighter's armor damage.
3. **Loot.** Draw 1 loot card (2 if a Draw 2 monster was in the fight). See section 9.
4. **XP.** The party gains 1 XP.

**The map.** The party explores a map of small tiles, at a much smaller scale than the battle boards. Fights move to the battle boards and return to the map afterwards.

- **Tiles.** Each tile holds one, two or three rooms joined by corridors that enter on one edge and leave by another.
- **Revealing.** Moving through an unexplored opening reveals a new tile. Solo or co-op: draw from the tile bag. DM mode: the DM holds 3 tiles and plays one.
- **Rooms.** Each room shows a symbol: Monsters, Trap, Lock or Puzzle, Treasure, Event or Empty. Entering a room draws a card from the matching room deck (a DM chooses from a hand of room cards). Walking back through cleared rooms is free.
- **Hidden doors.** A faint mark on a wall hides a door. A Wits roll against the number on the mark reveals it.

**Skill rolls.** Every obstacle shows a Type and a target, such as "Rusted portcullis: Strength 4". Attempting it is always the party's choice.

1. Choose a hero, usually the one whose Type matches. A hero of a different Type rolls at −2 (minimum 1).
2. Flip the top card of that hero's deck and read its skill value.
3. Equal or beat the target to succeed. Otherwise the failure text happens (a trap springs, a lock jams) and the Hut track rises by 1. Locks and puzzles may be retried with another flip.
4. The flipped card is spent: discarded, or Exhausted if it is a ▲ or ★ card. About 1 flip in 6 burns one of your best cards.

**Teamwork.** A target above 6 needs two heroes, who each flip and add the values ("Collapsed tunnel: Strength 8").

| Difficulty | Target | Matching Type succeeds |
| --- | --- | --- |
| Easy | 2 | 5 in 6 |
| Normal | 4 | 1 in 2 |
| Hard | 5 | 1 in 3 |
| Very hard | 6 | 1 in 6 |
| Teamwork | 7–10 | 3 in 5 (7) to 1 in 6 (10) |

Beating a Hard or harder obstacle earns 1 XP.

**Traps** start hidden. A Wits roll can spot one. A spotted trap can be avoided, or disarmed with an Agility roll for its salvage (1 loot card). An unspotted trap springs on the hero leading the party, who may make an Agility roll to dodge it.

**Camping.** In any Empty room (or the Hearth), the party may camp: spend 1 ration per hero, Hut track +1, then flip for a wandering monster (none at the Hearth). A campfire fully resets every hero: Wounds and armor damage are cleared, discards and Exhausted cards are shuffled back into the deck, and each hero draws a fresh hand. Curses are lifted.

## 9. Equipment, loot, runs and levels

**Equipment.** Each hero board has four slots: Weapon, Armor, Off-hand and Trinket. Equipment cards are overlays placed on their slot; a better find replaces the card.

- **Rarity.** White (starting gear, no bonus), Green (common), Blue (rare) and Gold (artifacts). Each upgrade adds one clear effect.
- **Who can use it.** Each item shows a Type icon; only a hero of that Type can equip it. Items marked Any fit everyone.
- **Equipping.** Equip or swap any time outside battle. Spare items go in the party pack (4 items); anything more is left behind.
- **Once per battle.** Turn the item sideways when used; straighten it at the start of the next battle.
- **Cursed items** are strong but carry a curse. They can't be unequipped until the curse is lifted by a Spirit 4 roll or at a campfire; the item keeps its bonus.

| Hero | White weapon | White armor | White off-hand |
| --- | --- | --- | --- |
| Fighter | Longsword | Chainmail (4) | Shield (1) |
| Cleric | Mace | Chainmail (4) | Holy symbol |
| Thief | Daggers | Leather (2) | Shortbow |
| Wizard | Staff | Robes (0) | Spellbook |

**Loot drops.** After a won battle, draw 1 loot card (2 if a Draw 2 monster was in it). A chest gives 2; a locked chest gives 3 if opened. Once the Hut track reaches 5, draw one extra and discard one. About a third of the loot deck is consumables: a **Healing Potion** removes 2 Wounds from one hero (outside battle), and a **Ration** adds 1 ration.

**Runs and town**

- **Leaving.** A run ends well when the party walks out through the entrance. Everything found is kept for every future run.
- **Wipe.** If the whole party goes Down, the run ends in town. The party loses everything found on that run, and every hero's Armor reverts to White. Weapons, off-hands, trinkets and earlier finds are kept. XP is kept.
- **Town.** Every hero fully recovers, the party takes 8 fresh rations, and equipment can be swapped freely with the town stash (no limit).
- **The module resets** each run: Hut track to 0, and a freshly shuffled tile bag.

**Levels.** Heroes level up as in D&D, but their hit points never grow: hand size and armor stay the same, and the deck gets better cards instead.

- **Party XP:** +1 per battle won, +1 per Hard or harder obstacle beaten, +2 for walking out at the end of a run.
- **Levelling up** happens in town, for every hero together, when the party reaches a threshold.
- **Advancement cards.** Each hero adds **both** advancement cards for their new level to their deck. For each card added they may remove one starting card, but a deck never drops below 30.

| Level | Party XP | Usually reached |
| --- | --- | --- |
| 2 | 6 | After the first good run |
| 3 | 14 | After the second or third run |
| 4 | 24 | Around runs 4–5 |
| 5 | 36 | Later |

## 10. Module 1: The Witch's Hut

A small hut that never stands in the same place twice. Inside it is far larger than it looks, and it rebuilds its rooms, tunnels, hidden doors and traps every time someone enters. The party hunts the witch's artifact (name to decide). Built for levels 1–3; the witch is tuned for a level 3 party with a few items.

**Setup.** Place the Front Door tile. Set the Inner Study tile aside and shuffle the other tiles into the tile bag. Hut track at 0.

**The Hut track (0–10).** +1 for each tile revealed, each failed skill roll and each campfire.

- At 3, 6 and 9: draw a **Hut Whim**.
- At 4: shuffle the Inner Study into the tile bag (a DM may play it any time from then on).
- At 10 the Hut wakes: every room revealed from then on also draws a Monsters card.

**The Inner Study and the Iron Key.** The Study's iron door cannot be opened, forced or bypassed without the **Iron Key**. A party that reaches the door without it can see the way in but must turn back. The key enters the Treasure room deck only once the party is level 3, placed among its top three cards. It takes no slot or pack space, is kept once the party escapes, and is lost if the party wipes on the run it was found. Using the key opens the door and starts the boss battle. Win, and the party must still get back to the Front Door to keep the artifact and its loot.

**Hut Whims (examples; 12 to write).** Shifting Walls (rotate a revealed tile), Vanishing Door, Locked In (exits seal until a lock is opened), The Black Cat (a loot card for a secret), Bubbling Cauldron (Spirit roll: heal or poison), Gingerbread Pantry (gain a ration), Hall of Mirrors, Bones Stir (3 skeletons attack).

**Room deck (about 30 cards, to write).** Monsters: goblin bands, an ogre and goblins, skeletons. Traps: pit, poison needle, falling ceiling. Locks and puzzles: rune lock, riddle door, barred cellar. Treasure: chests, locked chests, the Iron Key. Events: the cat, the cauldron, a trapped adventurer.

### The Witch (boss)

Size 1, back row · Armor 2 · 18 Hd · Draw 3. She starts the fight with 3 skeletons and stays at range. Her toughness is moderate, but her potions hit hard and she gets nastier as the fight goes on.

- **Bone ward.** While any skeleton stands, she cannot be targeted or hit by any attack or area.
- **In simulation** a level 3 party with a few items beats her about 6 times in 10, and the fight lasts about 8 rounds. A level 1 party in White gear wins about 1 in 6.

| Card | Qty | Effect |
| --- | --- | --- |
| Raise Skeletons | 3 | Place 2 skeletons on empty squares of her board |
| Fire Flask | 3 | Ranged, Area 2×2: 3 damage to every hero in the area |
| Frost Draught | 2 | Ranged: 3 damage + Stun |
| Poison Vial | 2 | Ranged: 2 damage + Bleed 2 |
| Hex | 2 | Ranged: the target discards 2 playable cards, replaced at the start of their next turn |
| Healing Brew | 2 | Clear 3 marked Hd from herself or a skeleton |
| Cackle | 2 | Every hero moves 2 down the Provoke track |
| Polymorph ▲ | 1 | Ranged: the target becomes a toad and skips their next 2 turns |
| Bone Storm ◆ | 1 | Place 3 skeletons. From now on she takes two turns each round: her normal turn, and an extra turn just before the end of the round |

### Skeleton

Armor 1 · 3 Hd · Draw 1 · 10-card deck. Undead: Divine Light deals double damage to them, and Turn Undead stops them.

| Card | Qty | Effect |
| --- | --- | --- |
| Bone Blade | 4 | Melee 2 |
| Rattle | 2 | Guard 1; no attack |
| Clatter Forward | 2 | Move 1 square, then Melee 1 |
| Reassemble | 2 | Clear 1 marked Hd |

## 11. Hero decks

Each deck is 30 cards with five cards of each skill value (1–6).

### Fighter (Strength, hand 6)

| Card | Qty | Skill | Effect |
| --- | --- | --- | --- |
| Raise Shield | 3 | 5 | Guard 2 |
| Brace | 2 | 3 | Guard 3 |
| Taunt | 2 | 2 | Taunt: Provoke +3, Guard 1 |
| Iron Skin | 1 | 4 | Ignore the next attack. Exhaust |
| Challenge | 2 | 2 | Provoke +3 |
| War Cry | 2 | 3 | Provoke +5 |
| Berserk ★ | 1 | 5 | For the rest of the battle, always attack the strongest enemy you can reach; all your attacks +1 damage. Exhaust |
| Battle Cry ▲ | 1 | 3 | All heroes gain Guard 1; Provoke +5. Exhaust |
| Shield Wall ▲ | 1 | 2 | You and one other hero gain Guard 2. Exhaust |
| Charge ▲ | 1 | 5 | Move up to 2 squares, including onto the enemy board, then 2 damage; Provoke +2. Exhaust |
| Quake ▲ | 1 | 4 | Enemy front row: 1 damage + Stun; Provoke +2. Exhaust |
| Thorns | 1 | 1 | For the rest of the battle, any enemy that damages you takes the same damage |
| Calculated Retreat | 1 | 1 | Move to any empty square on your own board |
| Cleave | 3 | 4 | Adjacent: 1 damage + Bleed 2; Provoke +2 |
| Bash | 3 | 6 | 2 damage |
| Steady Strike | 2 | 6 | 3 damage |
| Fix Armor | 2 | 1 | Remove 1 armor damage. Between battles: remove all your armor damage |
| Second Wind ↺ | 1 | 1 | Shuffle up to 3 cards from your discard pile into your deck |

### Cleric (Spirit, hand 5)

| Card | Qty | Skill | Effect |
| --- | --- | --- | --- |
| Mend | 4 | 4 | Remove 1 Wound from an adjacent hero's hand |
| Healing Word | 4 | 3 | Remove 1 Wound from any hero |
| Lay on Hands | 1 | 1 | Take up to 2 Wounds from an ally's hand into yours |
| Party Heal ★ | 1 | 6 | Remove 1 Wound from every hero's hand. Exhaust |
| Greater Heal ▲ | 1 | 4 | Remove 3 Wounds from one hero; they draw 1 extra. Exhaust |
| Sanctify Armor ▲ | 1 | 2 | Remove all armor and shield damage from a hero. Exhaust |
| Sanctuary ▲ | 1 | 3 | All heroes gain Guard 1. Exhaust |
| Consecrate ▲ | 1 | 5 | Ranged, Area 2×2 on either board, or straddling both front rows: enemies take 2 radiant damage (double vs undead); heroes remove 1 Wound or 1 armor damage. Exhaust |
| Lesser Cleanse | 1 | 1 | Remove 1 Wound or 1 armor damage from a hero |
| Cleanse Armor | 1 | 1 | Remove 2 from a hero, any mix of Wounds and armor damage |
| Shield of Faith | 2 | 2 | One hero gains Guard 2 |
| Smite | 4 | 5 | 2 radiant damage |
| Divine Light | 4 | 6 | Ranged: 2 damage, double vs undead |
| Turn Undead | 1 | 2 | Undead in the enemy front row skip their next turn |
| Bless | 1 | 2 | An ally's next damage or Guard card gets +2 |
| Detect Evil | 1 | 1 | Look at the top card of an enemy type's deck |
| Renewal ↺ | 1 | 1 | Any hero shuffles up to 3 cards from their discard pile into their deck |

### Thief (Agility, hand 5)

| Card | Qty | Skill | Effect |
| --- | --- | --- | --- |
| Stab | 5 | 4 | 2 damage |
| Twin Daggers | 2 | 2 | Move to the nearest square in melee reach, then 1 damage to each of two enemies, or 2 to one |
| Shortbow | 4 | 3 | Ranged: 2 damage |
| Poisoned Blade | 3 | 1 | 1 damage + Bleed 2 |
| Feint | 2 | 5 | Your next attack this battle deals +2 |
| Dodge | 2 | 5 | Guard 2 |
| Vanish | 2 | 6 | Provoke −3 |
| Pick Lock | 2 | 6 | Draw 1 card |
| Caltrops | 2 | 2 | Enemy front row: 1 damage |
| Backstab ★ | 1 | 6 | Move to the nearest square in melee reach, then 6 damage; halve your Provoke (round up). Exhaust |
| Ambush ▲ | 1 | 5 | Move into melee reach of the weakest enemy, then 6 damage to it. Exhaust |
| Hamstring ▲ | 1 | 3 | 1 damage + Bleed 2 + Stun. Exhaust |
| Reveal Weakness ▲ | 1 | 1 | Look at the top 3 cards of an enemy type's deck and put them back in any order. Exhaust |
| Smoke Bomb ▲ | 1 | 2 | Move to any empty square on your board; enemies next to your old square are Stunned. Exhaust |
| Scavenge ↺ | 1 | 1 | Return 1 card from your discard pile to your hand |

### Wizard (Wits, hand 4)

| Card | Qty | Skill | Effect |
| --- | --- | --- | --- |
| Fire Bolt | 4 | 5 | Ranged: 3 damage |
| Frost Ray | 4 | 4 | Step back 1 square if able, then Ranged: 2 damage; the target's next attack deals 1 less |
| Spark | 4 | 3 | Ranged: 1 damage to each of two enemies |
| Burn | 3 | 2 | Ranged: Bleed 2 |
| Mage Light | 1 | 1 | Ranged, Area 2×2: 1 damage |
| Arcane Shield | 2 | 1 | Guard 2 |
| Blink | 2 | 2 | Teleport to any empty square on your board; Provoke −3 |
| Study | 3 | 6 | Draw 1 card |
| Detect Magic | 1 | 6 | Look at the top 2 cards of an enemy type's deck |
| Signature ★ | 1 | 6 | Choose at each campfire: Fireball (Ranged, Area 2×2: 3 damage), Chain Lightning (Ranged, Chain: 2 damage to up to 5 enemies) or Frost Spike (Ranged: 5 damage + Stun). Exhaust |
| Elemental Missile ▲ | 1 | 4 | Ranged: three bolts of 2 damage, split among up to 3 enemies. Exhaust |
| Lightning Orb ▲ | 1 | 3 | Guard 2; for two rounds, 1 damage to each enemy in melee with you at the end of each round. Exhaust |
| Frost Wall ▲ | 1 | 1 | Ranged, Row: 2 damage + Stun. Exhaust |
| Arcane Surge ▲ | 1 | 5 | Draw 2 cards; your next spell this battle deals +2 damage. Exhaust |
| Recall ↺ | 1 | 1 | Return 1 card from your discard pile to your hand |

### Advancement cards (levels 2 and 3)

| Hero | Level | Card | Skill | Effect |
| --- | --- | --- | --- | --- |
| Fighter | 2 | Shield Bash | 6 | 2 damage + Stun |
| Fighter | 2 | Hold the Line | 5 | Guard 2; Provoke +3 |
| Fighter | 3 | Whirlwind | 5 | Adjacent: 2 damage; Provoke +2 |
| Fighter | 3 | Rally | 4 | Every hero within 1 square removes 1 Wound |
| Cleric | 2 | Prayer | 5 | Remove 2 Wounds from any hero |
| Cleric | 2 | Holy Strike | 4 | 3 radiant damage |
| Cleric | 3 | Radiant Burst | 5 | Ranged, Area 2×2: 2 radiant damage |
| Cleric | 3 | Blessed Ward | 6 | All heroes gain Guard 1 |
| Thief | 2 | Deadly Shot | 5 | Ranged: 4 damage |
| Thief | 2 | Flurry | 6 | 3 damage |
| Thief | 3 | Shadow Strike | 6 | 4 damage |
| Thief | 3 | Evasion | 5 | Guard 3 |
| Wizard | 2 | Greater Bolt | 6 | Ranged: 4 damage |
| Wizard | 2 | Firestorm | 4 | Ranged, Area 2×2: 2 damage |
| Wizard | 3 | Ice Lance | 5 | Ranged: 4 damage |
| Wizard | 3 | Mana Shield | 6 | Guard 3 |

## 12. Enemy decks and loot deck

### Goblin (Armor 1, 4 Hd, Draw 1; 15-card deck)

A goblin card with Melee and Throw values is played as Melee if the goblin can reach a hero after its free step. Otherwise it throws its weapon: a Ranged attack for the Throw value at the highest-Provoke hero.

| Card | Qty | Effect |
| --- | --- | --- |
| Rusty Blade | 3 | Melee 1 · Throw 1 |
| Spear | 3 | Melee 2 · Throw 1 |
| Shortbow | 2 | Ranged: 1 damage to the hero with the lowest Provoke |
| Gang Up | 1 | Melee 1, +1 for each other goblin in the fight · Throw 1 |
| Scurry | 1 | Move to an empty square in its front row, then Melee 1 · Throw 1 |
| Cower | 1 | Guard 1; no attack |
| Flee | 1 | If half or more of its Hd are marked, it runs away (no loot); otherwise Melee 1 · Throw 1 |
| Shriek | 1 | If it is the last goblin, one more goblin joins the fight; otherwise Melee 1 · Throw 1 |
| Disarm ▲ | 1 | Melee 1 · Throw 1, and the target discards a random playable card (never a Wound), replaced at the start of their next turn. This discard never knocks a hero Down |
| Vault ▲ | 1 | Leap over a front-row hero into the empty middle-row square directly behind them on the heroes' board, then Melee 1 to a hero within 1 square |

### Ogre (Size 2×2, Armor 3, 5 Hd, Draw 2; 20-card deck)

| Card | Qty | Effect |
| --- | --- | --- |
| Backhand | 3 | Melee 1 |
| Club Swing | 4 | Melee 3 |
| Crushing Blow | 2 | Melee 5 |
| Stomp | 3 | 2 damage to every hero within 1 square |
| Grab and Throw | 1 | Melee 2 + Stun |
| Rampage | 1 | Melee 4 to its target and 2 to one hero next to the target |
| Lumber | 1 | Shift one lane sideways, then Melee 3 |
| Roar | 1 | Every hero within 1 square discards 1 card |
| Thick Hide | 1 | Clear 2 marked armor slots; no attack |
| Dim-witted | 1 | It stumbles and does nothing |
| Rage ◆ | 1 | All its attacks deal +1 damage for the rest of the battle |
| Throw Goblin ▲ | 1 | Throw a goblin into an empty back-row square on the heroes' board; it lands with 1 damage to a hero within 1 square. With no goblin, it hurls a rock: Ranged 2 |

The skeleton and witch decks are in section 10.

### Loot deck (sample)

The full deck needs about 50 cards: this gear plus Healing Potions and Rations (about a third of the deck).

| Item | Rarity | Slot | Type | Effect |
| --- | --- | --- | --- | --- |
| Keen Longsword | Green | Weapon | Strength | Once per battle: +2 damage to one melee attack |
| Studded Leather | Green | Armor | Agility | 3 armor slots |
| Iron-banded Shield | Green | Off-hand | Strength | 2 shield slots |
| Healer's Satchel | Green | Off-hand | Spirit | Once per battle: your next heal removes 1 extra Wound |
| Wand of Sparks | Green | Off-hand | Wits | Spark hits up to three enemies |
| Thieves' Tools | Green | Trinket | Agility | +1 to Agility rolls |
| Pilgrim's Charm | Green | Trinket | Spirit | +1 to Spirit rolls |
| Ring of Warding | Green | Trinket | Any | Start each battle with Guard 1 |
| Plate Armor | Blue | Armor | Strength | 6 armor slots; −1 to all skill rolls |
| Elven Chain | Blue | Armor | Any | 4 armor slots |
| Bow of the Hunter | Blue | Off-hand | Agility | Ranged attacks deal +1 damage |
| Staff of Embers | Blue | Weapon | Wits | Fire Bolt and Burn deal +1 damage |
| Boots of Striding | Blue | Trinket | Any | Once per battle: move 1 square before playing a card |
| Ring of Vigor | Blue | Trinket | Any | +1 hand size |
| Hungering Blade | Blue, cursed | Weapon | Strength | All melee attacks +1 damage. Curse: start each battle with 1 Wound in hand |
| Hand of Glory | Blue, cursed | Trinket | Any | +2 to Wits rolls. Curse: Hut track +1 at each campfire |
| Dragonscale Mail | Gold | Armor | Strength or Spirit | 6 armor slots, no skill penalty |
| Shadowfang | Gold | Weapon | Agility | Once per battle, Backstab returns to your hand instead of being Exhausted |

## 13. Reference

| Keyword or icon | Meaning |
| --- | --- |
| Turn | One figure acting once: a hero plays, flips or passes; an enemy flips and plays. A skipped turn (Stun, Polymorph) still counts as that figure's turn |
| Round | Every figure takes one turn (or has it skipped), then the end-of-round step runs. Battles start at round 1 |
| This turn | The acting figure's current turn |
| Next turn | That figure's next turn, whenever it comes: later this round for a hero who hasn't acted yet, next round for one who has |
| For X rounds | Count end-of-round steps, starting with the end of the round the card was played in. "Until the end of the next round" ends at the second one |
| Guard X | Add X Guard tokens; each absorbs 1 damage. Lasts until the end of the next round |
| Provoke +X | Move your token X spaces up the Provoke track |
| Taunt | Provoke +3 and Guard 1 |
| Bleed X | The target takes 1 damage at the end of each round for X rounds, starting with this one. Several Bleeds on one figure each tick separately |
| Stun | The target skips its next turn (for a figure that hasn't acted yet, this round's turn). Stuns don't stack: a figure skips one turn however many Stuns it has. A Stunned toad uses up the Stun and a toad turn together |
| Exhaust | Set the card aside until the next campfire |
| Melee X · Throw Y | Goblins: melee for X if in reach, otherwise a ranged throw for Y |
| ★ | Signature card |
| ▲ | Top-tier card (heroes: Exhausts; enemies: once per battle) |
| ◆ | Enemy phase card: takes effect for the rest of the battle |
| ↺ | Recovery card: pulls cards back from the discard pile |

### Still to design before a playtest

- [ ] About 20 map tiles, plus the Front Door and the Inner Study
- [ ] The room deck (about 30 cards), with obstacle targets and failure text
- [ ] 12 Hut Whim cards
- [ ] The full loot deck (about 50 cards) and the artifact's name
- [ ] Advancement cards for levels 4 and 5

### Later

- Hybrid classes: Paladin (Strength/Spirit), Ranger (Agility/Spirit), Battlemage (Strength/Wits), Bard (Wits/Spirit), each with unique and top-tier cards of its own.
- Raise Dead and Resurrection as rare cleric advancements or scrolls; a revived hero returns in their own back row.
- Cards that change hand size or affect Wounds; 2×3 bosses.
