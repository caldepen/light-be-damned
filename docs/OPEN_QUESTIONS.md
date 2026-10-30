# Open questions

Rules that are ambiguous for implementation. Ask before inventing a rule; once answered, record the decision in `docs/RULES.md` and move the question to Resolved.

## Open

From building rooms and Whims (Milestone 4.3, 2026-10-30). The engine as built is described; the proposal keeps it.

| # | Question | Engine now (proposal: keep) |
| --- | --- | --- |
| 71 | When the Hut track crosses 3, 6 or 9 in the middle of a room (a failed lock roll), when does the Whim resolve? | At once, mid-room, as with a moon (#51): a Bones Stir fight happens before the lock's retry |
| 72 | A roll nobody can make (every standing hero's deck empty): a non-optional check (Bubbling Cauldron), Locked In | The check counts as failed (failure effects, but no Hut +1 since nothing was flipped). Locked In stops; the doorways stay sealed and the log says so |
| 73 | After the Hut wakes, does a declined optional room (the Shrine) draw its Lair card again when the party comes back? | No: one Lair fight per room, the first time the party enters it awake |
| 74 | Who decides when a wandering-monster flip or a campfire check is due if the chosen hero is Down? | Only standing heroes with cards in their deck can flip (as for skill rolls); the campfire flip comes after the reset, when everyone is up |

## Follow-ups

Not rule questions; things to check later.

- **Balance under standard DM (2026-10-26).** Standard DM is the intended default. Re-check campaign balance (wipes, runs to beat the witch) under standard DM once exploration and runs exist. The battle baseline is in CLAUDE.md (Balance baseline).
- **Exploration playtest (2026-10-28).** From `EXPLORATION_SPEC.md` §11: whether a DM placing Lairs everywhere is too strong (with the DM tile hand, later), and whether the map-shifting Whims (Shifting Walls, Hall of Mirrors, Collapse, Doors Slam) are fun or fiddly.

## Resolved (free step, 2026-10-29)

| # | Question | Decision | Where |
| --- | --- | --- | --- |
| 66 | An enemy still out of reach after its step | The free step is for melee only, and enemies decide before moving: with a hero in reach after the step toward the top-Provoke hero, step and attack in melee; otherwise throw (Throw option) from where it stands, without stepping; otherwise take the step and the turn ends. No step before a throw or ranged attack | §4, §5 Movement, §6, §7, §12 |
| 67 | Enemy cards that move (Scurry, Lumber, Clatter Forward, Vault) | Card text wins ("When a card's text conflicts with a general rule, the card wins"): they move as printed, with no free step (ruling #6 now holds for enemies too) | §3 Cards beat rules, §5 Card movement |
| 68 | Large enemies in rows and areas (an ogre straddling both front rows) | Hit if any of its squares is in the targeted row or area, and takes the effect once, never once per square. Every row and area card | §6 Large figures in areas |
| 69 | Choosing between flipped cards when a melee card can reach nobody | Value each card by the damage it would deal this turn (melee only, nobody in reach: 0; Melee · Throw that can't reach the top hero: its Throw). If every playable flipped card is such a 0-value melee card, Go Fish; if still nothing, play a 0-value card: step toward the top hero, turn ends. Cards with no damage but another use (Cower, Rattle, Thick Hide) play as before. Timid enemies picking a 0 card just advance (intended) | §4, §7 Card values, Nothing in reach |
| 70 | Enemy targeting priority | Top-Provoke hero in melee reach now or after the step toward them: step if needed and hit them. Else a Throw or ranged option at the top hero from where it stands. Else (melee only) it must step toward the top hero, then hits the highest-Provoke hero in reach, or the turn ends. Never skip that step to hit a hero already in reach. Cards that name a target (Shortbow, Vault, area cards) follow their text | §5, §6, §7 Targeting priority |

## Resolved (Milestone 4 planning, 2026-10-28)

Exploration with room tiles (`docs/EXPLORATION_SPEC.md`). All recorded in `docs/RULES.md` §8 and §10.

| # | Question | Decision | Where |
| --- | --- | --- | --- |
| 46 | Tile placed at another doorway | Only a doorway the party *chooses* outside its current room is a backtrack (with the check). When the Hut forces the tile to another doorway because it doesn't fit, there is no check | §8 Exploring, Backtracking |
| 47 | Break-through | Uses the first tile set aside. The party chooses where: any wall of an explored room where it fits (AI: prefer the party's room). No Hut +1 beyond the one stir | §8 Nothing fits |
| 48 | Placing the Workshop and Inner Study | At the chosen doorway if they fit there, otherwise against any wall of an explored room where they fit (party's choice; AI: closest to the party). The Hut makes the door | §10 Special tiles |
| 49 | Walking to a shut Study after finding the key | Allowed and free: walking through explored rooms is free and opens no new doorway, so no backtrack check | §8 Walking, §10 |
| 50 | Empty bag | No more exploring. The party can still camp at a known campsite, walk to a placed Study, or leave | §8 Nothing fits |
| 51 | Order when a moon triggers things | Place the tile, moon, Hut track, any Whim resolves, then the party enters the room | §8 Exploring |
| 52 | Hut 10 and Lair rooms | A Lair room is still one fight (its own Lair card). Every other non-corridor room draws an extra Lair card, fought first | §10 Hut track |
| 53 | Whim deck | Shuffle the 12 Whims at the start of each run; draw without repeats within the run | §10 Hut Whims |
| 54 | Only Wounds in hand outside battle | Down (as #33). Stays Down until bandaging after the next won battle, the Shrine, or a campfire. Every hero Down is a wipe | §8 Down outside battle |
| 55 | Traps | Spotting is optional. Every failed skill roll raises the Hut track by 1 (spot, disarm, dodge, locks). Disarm and dodge use the trap's target. A failed disarm springs the trap on the disarmer. The leader is the Fighter, else the first standing hero of Thief, Cleric, Wizard. Only beating a Hard (5+) obstacle gives XP; spotting and dodging never do | §8 Skill rolls, Traps |
| 56 | Optional rooms | The Shrine and Strange font may be declined and come back to later (the Shrine is still once per run). Whims, the Cauldron included, are never optional | §8 Room types, §10 |
| 57 | Retries | Library locks: unlimited, each failure Hut +1. Locked chests: one retry. AI retries while the party's average deck is 8 or more | §8 Skill rolls, §10 Room decks |
| 58 | Locked In | Rolled at once when the Whim resolves; retries until it succeeds, each failure Hut +1 | §10 Hut Whims |
| 59 | Backtrack flip ties | The party chooses among tied heroes (AI: Fighter, Cleric, Thief, Wizard) | §8 Backtracking |
| 60 | The campfire wandering check | After the campfire reset, one hero (party's choice) flips the top card of their fresh deck; skill 1–3 (1 in 2) means 3 goblins attack. The card is spent | §8 Camping |
| 61 | Rewards from wandering fights | No loot and no XP from any wandering fight: backtracking, camping, Whim fights (Bones Stir). Fights from room cards (Lair, Dark ambush, Workshop guardians, the Hut-waking extra) reward as normal | §8 After a won battle, Wandering monsters |
| 62 | Camping | 1 ration per hero, Down heroes included (the campfire gets them up), in an explored campsite. Walking there is free, with no backtrack check | §8 Camping |
| 63 | Who picks for map Whims | The Hut picks at random among legal options (a DM chooses in DM mode). "Dead end": a placed room tile (not special, not the party's room) connected to exactly one other tile, with no open doorways. Removing it can never cut the map in two | §10 Hut Whims |
| 64 | The Black Cat | Optional: "Tell the cat a secret: Hut track +1, draw 1 loot card" | §10 Hut Whims |
| 65 | Battles inside a run | Enemy decks are fresh and shuffled for each battle. At the round cap the remaining enemies withdraw: no loot or XP, no wipe. If every hero is sitting out (empty decks) when a fight starts, it's a wipe | §5 Round limit, §8 |

## Resolved (Milestone 1 build, 2026-10-25)

All recorded in `docs/RULES.md`; section numbers point to where.

| # | Question | Decision | Where |
| --- | --- | --- | --- |
| 27 | Taunt's "step between an ally and an attacker" | Step dropped. Taunt is "Provoke +3, Guard 1" | §11, `heroes.json` |
| 28 | Brace's "you can't attack this turn" | Restriction dropped. Brace is "Guard 3" | §11, `heroes.json` |
| 29 | Do Quake and Caltrops need reach? | No. Cards that target the enemy front row never need reach; text is "Enemy front row: …" | §5 Shifting front, §6 Attacks, §11 |
| 30 | Calculated Retreat | Playable from anywhere: "Move to any empty square on your own board" | §11, `heroes.json` |
| 31 | Order of the Provoke +1 | The automatic +1 first; the card's own Provoke (incl. halving, −3) always last. Backstab at 5: 6, then 3 | §6 Provoke |
| 32 | Bonuses vs undead | Add bonuses first, then double: (2 + 2) × 2 = 8 | §6 Attacks |
| 33 | Running out of playable cards | Down whenever the hand holds only Wounds, or hand and deck are both empty. When it's checked: see #37 | §5 Empty hand, §6 Armor and Wounds |
| 34 | Throw Goblin's landing damage | An attack by the thrown goblin (Iron Skin cancels it; Thorns hits the thrown goblin) | engine as built |
| 35 | Bonuses on multi-target cards | A bonus applies to every target of the card (Bless on Battle Cry, Arcane Surge on Spark). Bless targets an ally only | §6 Attacks, `heroes.json` |
| 36 | Hex and Down | Discards caused by enemy cards never knock a hero Down (Disarm, Roar, Hex); Hex gets `cannot_down` | §7 Discards, `enemies.json` |
| 37 | A Wound taken while your own card resolves | On your turn the Down check waits until your card has fully resolved and you've drawn to replace; mid-card Wounds (Thorns, Lay on Hands) count at that check. Other times, check as soon as a Wound lands. Wounds count toward hand size, so a hand full of Wounds gets no refill | §6 Armor and Wounds |
| 38 | Provoke per card or per point (2026-10-26) | Per point: +1 per damage point that lands (armor, Hd, Wound; not Guard-absorbed, Iron Skin-cancelled or overkill) and per Wound removed or armor point repaired. A damage, heal or repair card on a legal target earns at least 1. Card-named Provoke unchanged and still last. Bleed, Burn, Thorns, Lightning Orb ticks still earn nothing | §5 Hero's turn, §6 Provoke, `rules.json` |
| 39 | Hero turn order (2026-10-26) | Turns still alternate, hero first. On each hero turn the party chooses any hero who hasn't acted this round. Enemies keep the automatic order. Down heroes can't be chosen; a hero Stunned (or a toad) at the start of the round, or Stunned before acting, loses this round's turn and is marked as acted | §4, §5 Turn order |
| 40 | Turn and round (2026-10-26) | Definitions of turn, round, "this turn", "next turn" and "for X rounds" (counting end-of-round steps from the round the card was played) | §4 Turns and rounds, §13 |
| 41 | Enemy order timing (2026-10-26) | Fixed at the start of each round, as ruling #2; movers keep their place | §5 Turn order |
| 42 | Lost turns and the alternation (2026-10-26) | Enemies work like heroes: a Stunned figure (or toad) counts as having acted and takes no place in the alternation, so the other side may act several times in a row. Intended | §5 Lost turns |
| 43 | Owed draws (Hex, Disarm) on a skipped turn | Unchanged: drawn at the next turn the hero actually takes; it can't change what they can play | §7 Discards |
| 44 | Stun and toad together | One lost turn uses up both the Stun and one toad turn | §5, §13 Stun |
| 45 | When extra turns happen (Bone Storm) | Just before the end-of-round step, after every other figure, in the order the figures gained them | §4, §5 Extra turns, §10 Bone Storm |
## Resolved (Milestone 1 planning, 2026-10-25)

All recorded in `docs/RULES.md`; section numbers point to where.

| # | Question | Decision | Where |
| --- | --- | --- | --- |
| 1 | Lane numbering across the two boards | One shared numbering as seen by the players: lane 0 is the players' left on both boards (one 6×3 grid) | §5 Lanes |
| 2 | When is turn order fixed? | At the start of each round; movers keep their slot; newcomers act next round. **Changed by #39** for heroes (the party chooses); still holds for enemies, see open #41 | §5 Turn order |
| 3 | Ogre placement | Front and middle rows of the left and centre lanes; others fill front row first | §5 Size |
| 4 | Playing a card for no effect | Not allowed. Play a card with a legal effect, flip, or pass. Wounds can never be played | §4, §5 Legal plays |
| 5 | A flipped card | Must be played if it has a legal effect (targets chosen as normal); otherwise discarded with no effect (▲/★ still Exhaust); no draw | §5 Flipping |
| 6 | Free step plus card movement | A card that moves you replaces the free step | §5 Card movement |
| 7 | "Move to the nearest square in melee reach" | Any distance, ignores straight-only, empty square in reach of the target on either board, closest to you; ties chosen by the player | §5 Movement |
| 8 | Feint | Text changed to "Your next attack this battle deals +2" | §11, `heroes.json` |
| 9 | Bonuses on multi-target cards | Each target hit, each bolt; Bless on a Guard card adds +2 Guard tokens | §6 Attacks |
| 10 | The Provoke +1 | **Changed by #38** (now per point). Was: card with a damage, heal or repair effect played on a legal target, even if fully absorbed. Bleed (ticks, Burn) and Thorns never count | §6 Provoke |
| 11 | Provoke start order and limits | Start on 0, top to bottom Fighter, Cleric, Thief, Wizard; 0–20; a gain at 20 goes on top; a loss at 0 does nothing | §6 Provoke |
| 12 | Taking a Wound | Discard a non-Wound card of your choice per Wound; never a Wound; with none, the Wound is just added | §6 Armor and Wounds |
| 13 | Empty hand | Not Down while the deck has cards (may flip); a hit then adds a Wound and a hand of just Wounds is Down. *Changed by #33:* empty hand and empty deck is Down | §5 Empty hand, §6 |
| 14 | Guard vs Bleed | Guard absorbs Bleed; Bleed fills armor before Wounds | §6 Guard, Armor and Wounds |
| 15 | Enemy Guard timing | Same as heroes; extra Guard keeps the existing card's timing | §6 Guard |
| 16 | Stacking | Bleeds tick separately; Stuns don't stack | §13 |
| 17 | Thorns | Reflects the points past Guard (armor + Wounds) as non-attack damage; never earns Provoke; nothing if Iron Skin cancels the attack | §6 Thorns |
| 18 | Lay on Hands | Taken Wounds act like damage (discard per Wound, can Down the Cleric); the ally draws replacements | §6 Healing |
| 19 | Roar | Must discard a non-Wound card if possible; can never knock a hero Down (like Disarm); no special replacement | §7 Discards |
| 20 | Heal targets | "Any hero" includes yourself; Mend reaches within 1 square including diagonals and yourself | §6 Healing |
| 21 | Playable enemy cards | Full list | §7 Playable enemy cards |
| 22 | Disarm and ◆ cards | Disarm re-tagged ▲. Each ◆ takes effect once per enemy per battle; reshuffles don't reset it; a used ◆ re-flip counts as unflipped, and with no other card the enemy Goes Fish | §7, §12, `enemies.json` |
| 23 | Go Fish flips a ◆ card | It takes effect (if unused by this enemy) and the turn ends | §7 |
| 24 | Vault | Needs the empty middle-row square directly behind a front-row hero; if unplayable, Go Fish | §7, §12, `enemies.json` |
| 25 | "Enemy front row" on cards | Uses the shifting front | §5 Shifting front |
| 26 | Round limit | None at the table; the engine stops at `battle.round_cap` (30) as a draw | §5, `rules.json` |
