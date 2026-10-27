"""Reference only (prototype quality). Defaults match rules v0.5.
Run: python3 hut.py 100   -> plays 100 campaigns.

Full-campaign simulator for The Witch's Hut (rules draft v0.4 as of 24 Oct).

Battle rules come from sim.py; enemies use Hit Dice + shared type decks (as sim2) with
witch and skeletons added. On top: skill rolls, exploration, Hut track, loot/equipment,
party XP and levels, Iron Key gate, runs / town / wipe.
"""
import random, statistics as st
from collections import Counter, defaultdict
import sim
from sim import Fig, Game, W, LOG, log, reach, cheb, ECARDS

sim.PROVOKE = 'card'

# ------------------------------------------------------------------ hero data
TYPE = {'Fighter': 'Strength', 'Cleric': 'Spirit', 'Thief': 'Agility', 'Wizard': 'Wits'}
FORMATION = {'Thief': (3, 0), 'Fighter': (3, 1), 'Cleric': (3, 2), 'Wizard': (5, 1)}
BASE = {'Fighter': dict(hand=6, armor=4, shield=1), 'Cleric': dict(hand=5, armor=4, shield=0),
        'Thief': dict(hand=5, armor=2, shield=0), 'Wizard': dict(hand=4, armor=0, shield=0)}
DECKS = {'Fighter': sim.FDECK, 'Cleric': sim.CDECK, 'Thief': sim.TDECK, 'Wizard': sim.WDECK}
SKILL = {  # skill values from the rules doc
 'Raise Shield':5,'Brace':3,'Taunt':2,'Iron Skin':4,'Challenge':2,'War Cry':3,'Berserk':5,'Battle Cry':3,'Shield Wall':2,
 'Charge':5,'Quake':4,'Thorns':1,'Calculated Retreat':1,'Cleave':4,'Bash':6,'Steady Strike':6,'Fix Armor':1,'Second Wind':1,
 'Mend':4,'Healing Word':3,'Lay on Hands':1,'Party Heal':6,'Greater Heal':4,'Sanctify Armor':2,'Sanctuary':3,'Consecrate':5,
 'Lesser Cleanse':1,'Cleanse Armor':1,'Shield of Faith':2,'Smite':5,'Divine Light':6,'Turn Undead':2,'Bless':2,'Detect Evil':1,'Renewal':1,
 'Stab':4,'Twin Daggers':2,'Shortbow':3,'Poisoned Blade':1,'Feint':5,'Dodge':5,'Vanish':6,'Pick Lock':6,'Caltrops':2,'Backstab':6,
 'Ambush':5,'Hamstring':3,'Reveal Weakness':1,'Smoke Bomb':2,'Scavenge':1,
 'Fire Bolt':5,'Frost Ray':4,'Spark':3,'Burn':2,'Mage Light':1,'Arcane Shield':1,'Blink':2,'Study':6,'Detect Magic':6,'Fireball':6,
 'Elemental Missile':4,'Lightning Orb':3,'Frost Wall':1,'Arcane Surge':5,'Recall':1,
 # advancement cards
 'Shield Bash':6,'Whirlwind':5,'Prayer':5,'Holy Strike':4,'Deadly Shot':5,'Flurry':6,'Greater Bolt':6,'Firestorm':4,
 'Hold the Line':5,'Rally':4,'Radiant Burst':5,'Blessed Ward':6,'Shadow Strike':6,'Evasion':5,'Ice Lance':5,'Mana Shield':6,
}
assert all(c in SKILL for d in DECKS.values() for c in d)
for name, d in DECKS.items():
    cnt = Counter(SKILL[c] for c in d)
    assert all(cnt[v] == 5 for v in range(1, 7)), (name, cnt)

PER_LEVEL = 2
ADVANCE = {'Fighter': ['Shield Bash', 'Whirlwind'], 'Cleric': ['Prayer', 'Holy Strike'],
           'Thief': ['Deadly Shot', 'Flurry'], 'Wizard': ['Greater Bolt', 'Firestorm']}
ADVANCE2 = {'Fighter': [('Shield Bash', 'Hold the Line'), ('Whirlwind', 'Rally')],
            'Cleric': [('Prayer', 'Holy Strike'), ('Radiant Burst', 'Blessed Ward')],
            'Thief': [('Deadly Shot', 'Flurry'), ('Shadow Strike', 'Evasion')],
            'Wizard': [('Greater Bolt', 'Firestorm'), ('Ice Lance', 'Mana Shield')]}
REMOVE = {'Fighter': ['Calculated Retreat', 'Thorns', 'Challenge', 'Challenge', 'Taunt', 'Second Wind', 'Taunt', 'Brace'],
          'Cleric': ['Detect Evil', 'Bless', 'Lay on Hands', 'Lesser Cleanse', 'Renewal', 'Shield of Faith', 'Shield of Faith', 'Cleanse Armor'],
          'Thief': ['Reveal Weakness', 'Pick Lock', 'Pick Lock', 'Caltrops', 'Caltrops', 'Scavenge', 'Twin Daggers', 'Twin Daggers'],
          'Wizard': ['Detect Magic', 'Mage Light', 'Recall', 'Blink', 'Blink', 'Burn', 'Burn', 'Burn']}

def level_up(full, lvl):
    """add this level's advancement card(s) to every hero's deck and cut as many starting cards"""
    for h in TYPE:
        adds = ADVANCE2[h][(lvl - 2) % 2] if PER_LEVEL == 2 else (ADVANCE[h][(lvl - 2) % 2],)
        for add in adds:
            full[h].append(add)
            rem = next((c for c in REMOVE[h] if c in full[h]), None)
            if rem: full[h].remove(rem)
XP_LEVELS = [0, 6, 14, 24, 36]

# ------------------------------------------------------------------ loot
# name: (slot, types or 'Any', rarity, copies)
ITEMS = {
 'Keen Longsword': ('Weapon', ['Strength'], 'Green', 2), 'Studded Leather': ('Armor', ['Agility'], 'Green', 2),
 'Iron-banded Shield': ('Off-hand', ['Strength'], 'Green', 2), "Healer's Satchel": ('Off-hand', ['Spirit'], 'Green', 2),
 'Wand of Sparks': ('Off-hand', ['Wits'], 'Green', 2), "Thieves' Tools": ('Trinket', ['Agility'], 'Green', 2),
 "Pilgrim's Charm": ('Trinket', ['Spirit'], 'Green', 2), 'Ring of Warding': ('Trinket', 'Any', 'Green', 2),
 'Plate Armor': ('Armor', ['Strength'], 'Blue', 1), 'Elven Chain': ('Armor', 'Any', 'Blue', 1),
 'Bow of the Hunter': ('Off-hand', ['Agility'], 'Blue', 1), 'Staff of Embers': ('Weapon', ['Wits'], 'Blue', 1),
 'Boots of Striding': ('Trinket', 'Any', 'Blue', 1), 'Ring of Vigor': ('Trinket', 'Any', 'Blue', 1),
 'Dragonscale Mail': ('Armor', ['Strength', 'Spirit'], 'Gold', 1), 'Shadowfang': ('Weapon', ['Agility'], 'Gold', 1),
 'Hungering Blade': ('Weapon', ['Strength'], 'Blue', 1), 'Hand of Glory': ('Trinket', 'Any', 'Blue', 1),
}
ARMOR_SLOTS = {'Studded Leather': 3, 'Plate Armor': 6, 'Elven Chain': 4, 'Dragonscale Mail': 6}
EXPOSURE = {'Fighter': 1.0, 'Cleric': 0.7, 'Thief': 0.7, 'Wizard': 0.35}

def can_use(hero, item):
    t = ITEMS[item][1]
    return t == 'Any' or TYPE[hero] in t

def item_value(hero, item):
    """how much better this item is than the White default in its slot, for this hero"""
    if not can_use(hero, item): return -1
    slot = ITEMS[item][0]
    if slot == 'Armor':
        v = (ARMOR_SLOTS[item] - BASE[hero]['armor']) * EXPOSURE[hero]
        if item == 'Plate Armor': v -= 0.6
        return v
    return {'Keen Longsword': 1.5, 'Iron-banded Shield': 1.0, "Healer's Satchel": 0.4, 'Wand of Sparks': 1.2,
            "Thieves' Tools": 1.0 if hero == 'Thief' else 0.1, "Pilgrim's Charm": 0.8 if hero == 'Cleric' else 0.1,
            'Ring of Warding': 1.2 * EXPOSURE[hero] + 0.3, 'Bow of the Hunter': 2.0, 'Staff of Embers': 2.0,
            'Boots of Striding': 0.3, 'Ring of Vigor': 3.0, 'Shadowfang': 1.0, 'Hungering Blade': 2.2,
            'Hand of Glory': 1.0 if hero == 'Wizard' else 0.2}[item]

# ------------------------------------------------------------------ enemies
WITCH = {'Raise Skeletons': ('raise', 2.5, 0), 'Fire Flask': ('flask', 3, 0), 'Frost Draught': ('frost', 3, 0),
         'Poison Vial': ('poison', 2.5, 0), 'Hex': ('hex', 2, 0), 'Healing Brew': ('brew', 1, 0),
         'Cackle': ('cackle', 0.5, 0), 'Polymorph': ('poly', 4, 0), 'Bone Storm': ('storm', 5, 0)}
SKEL = {'Bone Blade': ('melee', 2, 0), 'Rattle': ('rattle', 0, 0), 'Clatter Forward': ('melee', 1, 0),
        'Reassemble': ('reasm', 0.2, 0)}
ECARDS.update(WITCH); ECARDS.update(SKEL)
WITCHDECK = (['Raise Skeletons']*3 + ['Fire Flask']*3 + ['Frost Draught']*2 + ['Poison Vial']*2 + ['Hex']*2 +
             ['Healing Brew']*2 + ['Cackle']*2 + ['Polymorph', 'Bone Storm'])
SKELDECK = ['Bone Blade']*4 + ['Rattle']*2 + ['Clatter Forward']*2 + ['Reassemble']*2
TOPCARDS = {'Vault', 'Throw Goblin', 'Polymorph', 'Bone Storm'}
WITCH_HD, WITCH_ARMOR = 18, 2
WARD = True
FLASK = 3
FROST = 3
POISON = 2
TWO_TURNS = True
STORM_TWO = True
RAISE_N = 2
START_SKEL = 3
CONSUMABLES = {'Healing Potion': 14, 'Ration': 8}
KEY_TOP = True

class Shared:
    def __init__(s):
        s.deck = {'Goblin': sim.GOBDECK[:], 'Ogre': sim.OGRDECK[:], 'Witch': WITCHDECK[:], 'Skeleton': SKELDECK[:]}
        s.disc = {k: [] for k in s.deck}
        for d in s.deck.values(): random.shuffle(d)
    def flip(s, t, n):
        out = []
        for _ in range(n):
            if not s.deck[t]:
                s.deck[t] = s.disc[t]; s.disc[t] = []; random.shuffle(s.deck[t])
            if s.deck[t]: out.append(s.deck[t].pop())
        return out

def mk(name, etype, cells, hd, armor, draw, undead=False, ranged=False):
    e = Fig(name, 'E', cells, hd, armor, ['G'] * hd, flips=draw)
    e.etype, e.undead, e.ranged = etype, undead, ranged
    return e
GOB_HD, SKEL_HD, OGRE_HD, EXTRA = 4, 3, 5, 0
def goblin(n, c): return mk(f'Goblin{n}', 'Goblin', [c], GOB_HD, 1, 1)
def skeleton(n, c): return mk(f'Skel{n}', 'Skeleton', [c], SKEL_HD, 1, 1, undead=True)
def ogre(): return mk('Ogre', 'Ogre', [(2,0),(2,1),(1,0),(1,1)], OGRE_HD, 3, 2)
def witch(): return mk('Witch', 'Witch', [(0,1)], WITCH_HD, WITCH_ARMOR, 3, ranged=True)

ENEMY_SQUARES = [(2,0),(2,1),(2,2),(1,0),(1,1),(1,2),(0,0),(0,1),(0,2)]
def encounter(kind):
    if kind == 'gob5': return [goblin(i+1, c) for i, c in enumerate(ENEMY_SQUARES[:5 + EXTRA])]
    if kind == 'gob3': return [goblin(i+1, c) for i, c in enumerate(ENEMY_SQUARES[:3])]
    if kind == 'skel5': return [skeleton(i+1, c) for i, c in enumerate(ENEMY_SQUARES[:5 + EXTRA])]
    if kind == 'skel3': return [skeleton(i+1, c) for i, c in enumerate(ENEMY_SQUARES[:3])]
    if kind == 'tough': return [ogre()] + [goblin(i+1, c) for i, c in enumerate([(2,2),(1,2),(0,2),(0,1),(0,0)][:4 + EXTRA])]
    if kind == 'witch': return [witch()] + [skeleton(i+1, c) for i, c in enumerate([(2,0),(2,2),(2,1),(1,0),(1,2)][:START_SKEL])]
    raise ValueError(kind)

def morale(e):
    marked, hd = e.wounds(), e.hand_size
    if marked == hd - 1: return 'desperate'
    if marked * 2 >= hd: return 'timid'
    return 'bold'

def place_skeletons(g, n):
    placed = 0
    for c in ENEMY_SQUARES:
        if placed == n: break
        if g.empty(c):
            g.enemies.append(skeleton(len(g.enemies) + 1, c)); placed += 1
    return placed

def enemy_turn(g, e):
    if e.stunned:
        e.stunned = False; log(f'  {e} is stunned'); return
    heroes = g.alive_h()
    if not heroes: return
    top = max(heroes, key=lambda h: h.provoke)
    if not e.ranged and not reach(e, top):
        if g.step_toward(e, top.cells): log(f'  {e} steps to {e.cells}')
    reachable = [h for h in heroes if reach(e, h)]
    mtarget = max(reachable, key=lambda h: h.provoke) if reachable else None
    target = mtarget or top
    mood = morale(e)
    flipped = g.shared.flip(e.etype, e.flips)
    def playable(c):
        k = ECARDS[c][0]
        if c in e.used_top: return False
        if k in ('melee', 'grab', 'rampage'): return mtarget is not None
        if k in ('stomp', 'roar'): return bool(reachable)
        if k == 'vault': return any(g.empty((4, x)) for x in range(3))
        if k == 'brew': return any(x.wounds() for x in g.alive_e())
        if k == 'reasm': return e.wounds() > 0
        if k == 'raise': return any(g.empty(c) for c in ENEMY_SQUARES)
        return True
    def dmgval(c):
        k, m, tv = ECARDS[c]
        if k == 'flee': return -1 if e.wounds() * 2 >= e.hand_size else (m if mtarget else tv)
        if k == 'util': return 0
        if k == 'gang':
            return (m + len([x for x in g.alive_e() if x is not e and x.etype == 'Goblin'])) if mtarget else tv
        if k in ('dual', 'shriek'): return m if mtarget else tv
        if k == 'bow': return 1
        if k == 'stomp': return 2 * len(reachable)
        if k == 'rampage': return 6
        if k == 'throwgob': return 2
        if k == 'vault': return 1.5
        if k == 'roar': return 0.5
        return m
    rest = []
    for c in flipped:
        if ECARDS[c][0] == 'phase':
            if c not in e.used_top:
                e.used_top.add(c)
                if c == 'Rage': e.rage = True; log(f'  {e} flips RAGE')
                if c == 'Disarm':
                    tt = mtarget or top
                    g.damage(tt, 1 + (1 if e.rage else 0), e)
                    nonw = [x for x in tt.hand if x != W]
                    if nonw and not tt.down:
                        x = random.choice(nonw); tt.hand.remove(x); tt.discard.append(x); tt.pending += 1
                        log(f'  {e} DISARMS {tt} ({x})')
            g.shared.disc[e.etype].append(c)
        else:
            rest.append(c)
    cands = [c for c in rest if playable(c)]
    if not cands:
        extra = g.shared.flip(e.etype, 1)
        rest += extra
        cands = [c for c in extra if ECARDS[c][0] != 'phase' and playable(c)]
        if not cands: log(f'  {e} finds nothing to do')
    if cands:
        c = min(cands, key=dmgval) if mood == 'timid' else max(cands, key=dmgval)
        if c in TOPCARDS: e.used_top.add(c)
        log(f'  {e} ({mood}) plays {c}')
        resolve(g, e, c, target, mtarget, reachable, top)
    g.shared.disc[e.etype].extend(rest)

def resolve(g, e, c, target, mtarget, reachable, top):
    k = ECARDS[c][0]
    hs = g.alive_h()
    if not hs: return
    if top.down: top = max(hs, key=lambda h: h.provoke)
    plus = 1 if e.rage else 0
    if k == 'raise':
        log(f'  {e} raises {place_skeletons(g, RAISE_N)} skeletons')
    elif k == 'storm':
        log(f'  {e} BONE STORM: {place_skeletons(g, 3)} skeletons')
        if STORM_TWO: e.two = True
        else: e.flips = 4
    elif k == 'flask':
        best, cells = 0, [top.pos()]
        for y in (0, 1, 2, 3, 4):
            for x in (0, 1):
                cs = [(y,x),(y+1,x),(y,x+1),(y+1,x+1)]
                n = sum(1 for h in hs if h.pos() in cs)
                if n > best: best, cells = n, cs
        ts = [h for h in hs if h.pos() in cells]
        log(f'  {e} Fire Flask hits {ts}')
        for h in ts: g.damage(h, FLASK + plus, e)
    elif k == 'frost':
        log(f'  {e} Frost Draught -> {top}'); g.damage(top, FROST + plus, e); top.stunned = True
    elif k == 'poison':
        log(f'  {e} Poison Vial -> {top}'); g.damage(top, POISON + plus, e); top.bleeds.append([2, e])
    elif k == 'hex':
        nonw = [x for x in top.hand if x != W]
        for x in random.sample(nonw, min(2, len(nonw))):
            top.hand.remove(x); top.discard.append(x); top.pending += 1
        log(f'  {e} Hexes {top}')
    elif k == 'brew':
        hurt = max(g.alive_e(), key=lambda x: x.wounds())
        n = 0
        while n < 3 and W in hurt.hand:
            hurt.hand[hurt.hand.index(W)] = 'G'; n += 1
        log(f'  {e} Healing Brew clears {n} Hd on {hurt}')
    elif k == 'cackle':
        for h in hs: h.provoke = max(0, h.provoke - 2)
        log(f'  {e} cackles')
    elif k == 'poly':
        top.toad = 2; log(f'  {e} POLYMORPHS {top}')
    elif k == 'shriek' and len([x for x in g.alive_e() if x.etype == 'Goblin']) == 1:
        sq = next((c for c in ENEMY_SQUARES if g.empty(c)), None)
        if sq: g.enemies.append(goblin(len(g.enemies) + 1, sq)); log(f'  {e} SHRIEKS for help')
    elif k == 'rattle':
        g.add_guard(e, 1)
    elif k == 'reasm':
        if W in e.hand: e.hand[e.hand.index(W)] = 'G'
    else:
        sim.resolve(g, e, c, target, mtarget, reachable, top)

# ------------------------------------------------------------------ battle
def fight(g):
    g.round = 0
    while g.alive_h() and g.alive_e() and g.round < 25:
        g.round += 1
        log(f'--- Round {g.round}')
        hs = sorted(g.alive_h(), key=lambda f: (f.pos()[0], f.pos()[1]))
        es = sorted(g.alive_e(), key=lambda f: (-max(c[0] for c in f.cells), min(c[1] for c in f.cells)))
        order = []
        for i in range(max(len(hs), len(es))):
            if i < len(hs): order.append(hs[i])
            if i < len(es): order.append(es[i])
        if TWO_TURNS:
            for b in [x for x in es if x.etype == 'Witch' and (not STORM_TWO or getattr(x, 'two', False))]: order.append(b)
        for f in order:
            if f.down or not g.alive_h() or not g.alive_e(): continue
            if f.side == 'H':
                if getattr(f, 'toad', 0):
                    f.toad -= 1; log(f'  {f} is a toad'); continue
                if f.stunned:
                    f.stunned = False; log(f'  {f} is stunned'); continue
                hidden = []
                if WARD and any(x.etype == 'Skeleton' for x in g.alive_e()):
                    hidden = [x for x in g.enemies if x.etype == 'Witch']
                    for x in hidden: g.enemies.remove(x)
                try:
                    sim.hero_turn(g, f)
                finally:
                    g.enemies.extend(hidden)
            else:
                enemy_turn(g, f)
        for f in g.figs():
            for b in f.bleeds:
                if b[0] > 0 and not f.down:
                    g.damage(f, 1, b[1], attack=False); b[0] -= 1
            f.bleeds = [b for b in f.bleeds if b[0] > 0]
            if f.guard_exp == g.round: f.guard = 0
    return bool(g.alive_h()) and not g.alive_e()

# ------------------------------------------------------------------ party
class Party:
    def __init__(s):
        s.xp, s.level = 0, 1
        s.gear = {h: {} for h in TYPE}          # hero -> slot -> item
        s.stash = []                             # items kept in town
        s.key = False
        s.loot = []                              # loot deck (persists over the campaign)
        for it, (slot, t, r, n) in ITEMS.items(): s.loot += [it] * n
        for it, n in CONSUMABLES.items(): s.loot += [it] * n
        random.shuffle(s.loot)
        s.full = {h: DECKS[h][:] for h in TYPE}  # each hero's complete deck
        s.heroes = {}
    def build_heroes(s):
        s.heroes = {}
        for h in TYPE:
            gear = s.gear[h]
            armor = ARMOR_SLOTS.get(gear.get('Armor'), BASE[h]['armor'])
            shield = 2 if gear.get('Off-hand') == 'Iron-banded Shield' else BASE[h]['shield']
            hand = BASE[h]['hand'] + (1 if gear.get('Trinket') == 'Ring of Vigor' else 0)
            f = Fig(h, 'H', [FORMATION[h]], hand, armor + shield, s.full[h])
            f.perm_bonus = 1 if (gear.get('Weapon') in ('Hungering Blade', 'Staff of Embers') or gear.get('Off-hand') == 'Bow of the Hunter') else 0
            f.wand = gear.get('Off-hand') == 'Wand of Sparks'
            f.roll_bonus = defaultdict(int)
            if gear.get('Trinket') == "Thieves' Tools": f.roll_bonus['Agility'] += 1
            if gear.get('Trinket') == "Pilgrim's Charm": f.roll_bonus['Spirit'] += 1
            if gear.get('Trinket') == 'Hand of Glory': f.roll_bonus['Wits'] += 2
            if gear.get('Armor') == 'Plate Armor': f.roll_bonus['all'] -= 1
            f.cursed = set(i for i in gear.values() if i in ('Hungering Blade', 'Hand of Glory'))
            s.heroes[h] = f
        return s.heroes
    def all_items(s):
        return [i for g in s.gear.values() for i in g.values()] + s.stash
    def optimise(s):
        """town: reassign every owned item to the best hero/slot"""
        pool = s.all_items(); s.gear = {h: {} for h in TYPE}; s.stash = []
        for it in sorted(pool, key=lambda i: -max(item_value(h, i) for h in TYPE)):
            slot = ITEMS[it][0]
            best = max(TYPE, key=lambda h: item_value(h, it) - item_value(h, s.gear[h][slot]) if slot in s.gear[h] else item_value(h, it))
            cur = s.gear[best].get(slot)
            gain = item_value(best, it) - (item_value(best, cur) if cur else 0)
            if gain > 0:
                if cur: s.stash.append(cur)
                s.gear[best][slot] = it
            else:
                s.stash.append(it)

# ------------------------------------------------------------------ run
ROOMS = ['Monsters'] * 35 + ['Trap'] * 15 + ['Lock'] * 15 + ['Treasure'] * 15 + ['Event'] * 8 + ['Empty'] * 12
MONSTERS = ['gob5'] * 50 + ['skel5'] * 25 + ['tough'] * 25
TILES = [1] * 6 + [2] * 9 + [3] * 5

class Run:
    def __init__(s, party, stats):
        s.p, s.S = party, stats
        s.hut, s.rations, s.whims = 0, 8, set()
        s.bag = TILES[:]; random.shuffle(s.bag)
        s.study_in = False
        s.treasure = ['chest'] * 5 + ['locked'] * 3 + (['key'] if (party.level >= 3 and not party.key) else [])
        random.shuffle(s.treasure)
        if KEY_TOP and 'key' in s.treasure:
            s.treasure.remove('key'); s.treasure.insert(len(s.treasure) - random.randint(1, 3) + 1, 'key')
        s.found = []          # items found this run
        s.key_found = False
        s.camp_spot = False
        s.heroes = party.build_heroes()
        s.dummy = Game(list(s.heroes.values()), [])
        s.battles = 0; s.rooms = 0; s.camps = 0
    # ---------- helpers
    def alive(s): return [h for h in s.heroes.values() if not h.down]
    def avg_deck(s):
        a = s.alive()
        return st.mean(len(h.deck) for h in a) if a else 0
    def hut_up(s, n=1):
        for _ in range(n):
            s.hut += 1
            if s.hut in (3, 6, 9) and s.hut not in s.whims:
                s.whims.add(s.hut); s.whim()
            if s.hut == 4 and not s.study_in:
                s.study_in = True; s.bag.insert(random.randint(0, len(s.bag)), 'study')
    def roll(s, typ, target, who=None):
        """flip a deck card for a skill roll; returns success or None if nobody can roll"""
        cands = [h for h in s.alive() if h.deck]
        if not cands: return None
        h = who if (who in cands) else max(cands, key=lambda x: (TYPE[x.name] == typ, len(x.deck)))
        card = h.deck.pop(); h.discard.append(card)
        v = SKILL[card] + h.roll_bonus[typ] + h.roll_bonus['all'] - (0 if TYPE[h.name] == typ else 2)
        s.S['rolls'] += 1
        if card in sim.TOPTIER: s.S['top_burned'] += 1
        ok = max(1, v) >= target
        s.S['roll_ok'] += ok
        return ok
    def gain_loot(s, n):
        drawn = []
        extra = 1 if s.hut >= 5 else 0
        for _ in range(n + extra):
            if s.p.loot: drawn.append(s.p.loot.pop())
        val = lambda i: 0.5 if i in CONSUMABLES else max(item_value(h, i) for h in TYPE)
        if extra and drawn:
            worst = min(drawn, key=val); drawn.remove(worst); s.p.loot.insert(0, worst)
        for it in drawn:
            if it in CONSUMABLES:
                s.S['consumables'] += 1
                if it == 'Ration': s.rations += 1
                else:
                    hurt = [h for h in s.alive() if h.wounds()]
                    if hurt:
                        t = max(hurt, key=lambda h: h.wounds())
                        for _ in range(min(2, t.wounds())): t.hand.remove(W); t.draw()
                continue
            s.found.append(it); s.S['items'] += 1
            # equip at once if it helps someone (party pack of 4 holds the rest)
            slot = ITEMS[it][0]
            best = max(TYPE, key=lambda h: item_value(h, it) - item_value(h, s.p.gear[h].get(slot)) if s.p.gear[h].get(slot) else item_value(h, it))
            cur = s.p.gear[best].get(slot)
            if item_value(best, it) - (item_value(best, cur) if cur else 0) > 0:
                if cur: s.p.stash.append(cur)
                s.p.gear[best][slot] = it
                s.apply_gear(best)
            else:
                s.p.stash.append(it)
    def apply_gear(s, hname):
        """refresh a hero's stats mid-run after equipping (keep hand/deck/damage)"""
        h = s.heroes[hname]; gear = s.p.gear[hname]
        armor = ARMOR_SLOTS.get(gear.get('Armor'), BASE[hname]['armor'])
        shield = 2 if gear.get('Off-hand') == 'Iron-banded Shield' else BASE[hname]['shield']
        h.armor_max = armor + shield; h.armor_dmg = min(h.armor_dmg, h.armor_max)
        h.hand_size = BASE[hname]['hand'] + (1 if gear.get('Trinket') == 'Ring of Vigor' else 0)
        h.perm_bonus = 1 if (gear.get('Weapon') in ('Hungering Blade', 'Staff of Embers') or gear.get('Off-hand') == 'Bow of the Hunter') else 0
        h.wand = gear.get('Off-hand') == 'Wand of Sparks'
        h.roll_bonus = defaultdict(int)
        if gear.get('Trinket') == "Thieves' Tools": h.roll_bonus['Agility'] += 1
        if gear.get('Trinket') == "Pilgrim's Charm": h.roll_bonus['Spirit'] += 1
        if gear.get('Trinket') == 'Hand of Glory': h.roll_bonus['Wits'] += 2
        if gear.get('Armor') == 'Plate Armor': h.roll_bonus['all'] -= 1
        if gear.get('Weapon') == 'Hungering Blade' or gear.get('Trinket') == 'Hand of Glory':
            h.cursed = getattr(h, 'cursed', set()) | {i for i in gear.values() if i in ('Hungering Blade', 'Hand of Glory')}
    # ---------- battles
    def battle(s, kind):
        g = Game(list(s.heroes.values()), encounter(kind)); g.shared = Shared()
        for h in s.heroes.values():
            h.provoke = 0; h.guard = 0; h.guard_exp = -1; h.bleeds = []; h.stunned = False; h.toad = 0
            h.thorns = h.berserk = h.iron = False; h.next_bonus = 0
            while h.pending: h.pending -= 1; h.draw()
            h.cells = [] if h.down else [FORMATION[h.name]]
            if h.down: continue
            gear = s.p.gear[h.name]
            if gear.get('Trinket') == 'Ring of Warding': h.guard, h.guard_exp = 1, 2
            if gear.get('Weapon') == 'Keen Longsword': h.next_bonus = 2
            if 'Hungering Blade' in getattr(h, 'cursed', set()): g.add_wound(h)
        # empty-deck heroes sit out
        sitting = [h for h in s.alive() if not h.deck]
        for h in sitting: h.cells = []; h.down = True
        win = fight(g)
        for h in sitting: h.down = False; h.cells = [FORMATION[h.name]]
        s.battles += 1; s.S['battles'] += 1
        s.S[f'battle_{kind}'] += 1
        if not win:
            s.S[f'lost_{kind}'] += 1
            return False
        s.p.xp += 1
        s.S['downs_in_won'] += sum(1 for h in s.heroes.values() if h.down)
        # bandaging + between-battle cards
        for h in s.heroes.values():
            if h.down and not (h.deck or h.hand): continue
            h.down = False
            for _ in range(2):
                if W in h.hand: h.hand.remove(W); h.draw()
        s.patch_up()
        drops = 2 if kind in ('tough',) else 1
        if kind != 'witch': s.gain_loot(drops)
        return True
    def patch_up(s):
        hs = s.heroes
        f, c = hs['Fighter'], hs['Cleric']
        def play(h, card):
            h.hand.remove(card); h.discard.append(card)
            if len(h.hand) < h.hand_size: h.draw()
        if not f.down and f.armor_dmg >= 2 and 'Fix Armor' in f.hand:
            play(f, 'Fix Armor'); f.armor_dmg = 0
        if not c.down:
            for _ in range(6):
                hurt = sorted([x for x in hs.values() if not x.down and x.wounds()], key=lambda x: -x.wounds())
                card = next((k for k in ('Mend', 'Healing Word', 'Prayer', 'Lesser Cleanse', 'Cleanse Armor') if k in c.hand), None)
                if hurt and card:
                    n = 2 if card in ('Prayer', 'Cleanse Armor') else 1
                    for _ in range(min(n, hurt[0].wounds())): hurt[0].hand.remove(W); hurt[0].draw()
                    play(c, card); continue
                break
    def camp(s):
        s.rations -= 4; s.camps += 1; s.S['camps'] += 1
        for h in s.heroes.values():
            if 'Hand of Glory' in getattr(h, 'cursed', set()): s.hut_up()
            h.cursed = set()                          # curses lifted at a campfire
            h.deck = s.p.full[h.name][:]; random.shuffle(h.deck); h.hand = []; h.discard = []
            for _ in range(h.hand_size): h.draw()
            h.armor_dmg = 0; h.down = False
        s.hut_up()
        if random.random() < 0.5:
            s.S['wandering'] += 1
            return s.battle('gob3')
        return True
    # ---------- rooms
    def whim(s):
        r = random.random()
        s.S['whims'] += 1
        if r < 0.25: return s.battle('skel3')
        if r < 0.40: s.rations += 1
        elif r < 0.55: s.gain_loot(1)
        elif r < 0.70:
            ok = s.roll('Spirit', 4, s.heroes['Cleric'])
            for h in s.alive():
                if ok: h.armor_dmg = max(0, h.armor_dmg - 1)
                else: s.dummy.damage(h, 1, attack=False)
        return True
    def room(s, sym):
        s.rooms += 1; s.S['rooms'] += 1; s.S['room_' + sym] += 1
        if s.hut >= 10 and sym != 'Monsters':
            if not s.battle('gob5'): return False
        if sym == 'Monsters':
            return s.battle(random.choice(MONSTERS))
        if sym == 'Empty':
            s.camp_spot = True
        elif sym == 'Trap':
            hard = random.random() < 0.4; tgt = 5 if hard else 4
            spotted = s.roll('Wits', tgt, s.heroes['Wizard'])
            if spotted:
                th = s.heroes['Thief']
                if not th.down and len(th.deck) > 10:
                    if s.roll('Agility', tgt, th):
                        s.gain_loot(1); s.p.xp += hard
                    else: s.dummy.damage(th, 2 + hard, attack=False); s.hut_up()
            else:
                lead = s.heroes['Fighter'] if not s.heroes['Fighter'].down else s.alive()[0]
                s.dummy.damage(lead, 2 + hard, attack=False); s.S['traps_sprung'] += 1
        elif sym == 'Lock':
            typ = random.choice(['Agility'] * 5 + ['Wits'] * 3 + ['Strength'] * 2)
            hard = random.random() < 0.4; tgt = 5 if hard else 4
            who = {'Agility': 'Thief', 'Wits': 'Wizard', 'Strength': 'Fighter'}[typ]
            for attempt in range(3):
                if s.avg_deck() < 8 and attempt: break
                ok = s.roll(typ, tgt, s.heroes[who])
                if ok is None: break
                if ok:
                    s.gain_loot(1); s.p.xp += hard; s.S['locks_opened'] += 1; break
                s.hut_up()
        elif sym == 'Treasure':
            if not s.treasure: s.gain_loot(1); return True
            t = s.treasure.pop()
            if t == 'chest': s.gain_loot(2)
            elif t == 'key': s.key_found = True; s.S['key_found_run'] = s.S.get('key_found_run') or s.S['run_no']
            else:
                for attempt in range(2):
                    ok = s.roll('Agility', 5, s.heroes['Thief'])
                    if ok: s.gain_loot(3); s.p.xp += 1; break
                    s.hut_up()
        elif sym == 'Event':
            if random.random() < 0.5: s.gain_loot(1)
            else:
                ok = s.roll('Spirit', 4, s.heroes['Cleric'])
                for h in s.alive():
                    if ok: h.armor_dmg = max(0, h.armor_dmg - 1)
                    else: s.dummy.damage(h, 1, attack=False)
        return True
    # ---------- the delve
    def play(s):
        have_key = lambda: s.p.key or s.key_found
        while True:
            hunting = have_key() and s.p.level >= 3
            if not s.alive(): return 'wipe'
            low = s.avg_deck() < (12 if hunting else 9) or any(not h.deck for h in s.alive())
            if low:
                if s.camp_spot and s.rations >= 4:
                    if not s.camp(): return 'wipe'
                    continue
                return 'escaped'
            if s.hut >= 10 and not hunting: return 'escaped'
            if not s.bag: return 'escaped'
            tile = s.bag.pop(); s.hut_up()
            if tile == 'study':
                s.S['study_found'] += 1
                if not have_key():
                    s.S['study_locked'] += 1; continue
                if s.avg_deck() < 18 and s.camp_spot and s.rations >= 4:
                    if not s.camp(): return 'wipe'
                s.S['witch_fights'] += 1
                s.S['witch_level'].append(s.p.level)
                s.S['witch_gear'].append(sum(1 for g in s.p.gear.values() for i in g.values()))
                if s.battle('witch'):
                    if s.hut >= 10 and not s.battle('gob5'): return 'wipe'
                    return 'witch'
                return 'wipe'
            for _ in range(tile):
                if not s.room(random.choice(ROOMS)): return 'wipe'

def campaign(seed, max_runs=12):
    random.seed(seed); LOG.clear()
    p = Party()
    S = Counter(); S['witch_level'] = []; S['witch_gear'] = []
    history = []
    for r in range(1, max_runs + 1):
        S['run_no'] = r
        while p.level < 5 and p.xp >= XP_LEVELS[p.level]:
            p.level += 1
            level_up(p.full, p.level)
        p.optimise()
        run = Run(p, S)
        xp0 = p.xp
        out = run.play()
        if out in ('escaped', 'witch'):
            p.xp += 2
            if run.key_found: p.key = True
        else:  # wipe: lose this run's finds and every hero's armor
            for it in run.found:
                slot_owner = next(((hg, sl) for hg in p.gear.values() for sl, x in hg.items() if x == it), None)
                if slot_owner: del slot_owner[0][slot_owner[1]]
                elif it in p.stash: p.stash.remove(it)
                p.loot.insert(0, it)
            for hg in p.gear.values():
                if 'Armor' in hg: p.loot.insert(0, hg.pop('Armor'))
        history.append(dict(run=r, out=out, level=p.level, xp=p.xp - xp0, battles=run.battles, rooms=run.rooms,
                            camps=run.camps, hut=run.hut, items=len(run.found), key=p.key))
        if out == 'witch': break
    return history, S

if __name__ == '__main__':
    import sys
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    res = [campaign(s) for s in range(1, n + 1)]
    done = [h for h, S in res if h[-1]['out'] == 'witch']
    print(f'{n} campaigns: witch beaten in {len(done)/n:.0%}; median runs', sorted(len(h) for h in done)[len(done)//2] if done else '-')
