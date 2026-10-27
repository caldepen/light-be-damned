"""Card RPG battle simulator (rules draft v0.4).

Grid: one 6x3 grid. y=0 enemy back, 1 enemy mid, 2 enemy front,
3 hero front, 4 hero mid, 5 hero back; x = lane 0..2 (left..right).
Melee reach = Chebyshev distance 1. Steps are orthogonal only.
"""
import random, sys

W = 'W'
PSCALE = 1.0
PROVOKE = 'point'  # 'point' = +1 per damage/heal point, 'card' = +1 per card that damages/heals
DM = None  # None = automated, 'lite' = sees one extra card, 'full' = picks from whole hand
LOG = []
def log(*a):
    LOG.append(' '.join(str(x) for x in a))

def cheb(a, b): return max(abs(a[0]-b[0]), abs(a[1]-b[1]))

# ---------------------------------------------------------------- figures
class Fig:
    def __init__(s, name, side, cells, hand_size, armor, deck, flips=1):
        s.name, s.side, s.cells = name, side, list(cells)
        s.hand_size, s.armor_max, s.armor_dmg = hand_size, armor, 0
        s.deck = deck[:]; random.shuffle(s.deck)
        s.hand, s.discard = [], []
        s.flips = flips
        s.guard, s.guard_exp = 0, -1
        s.provoke = 0
        s.down = False
        s.stunned = False
        s.bleeds = []          # list of [rounds_left, source_hero]
        s.thorns = False; s.berserk = False; s.iron = False
        s.rage = False; s.used_top = set()
        s.next_bonus = 0; s.aside = []; s.pending = 0; s._hit = False
        s.large = len(cells) > 1
        for _ in range(hand_size): s.draw()
    def draw(s):
        if s.deck: s.hand.append(s.deck.pop()); return True
        return False
    def wounds(s): return s.hand.count(W)
    def nonw(s): return len(s.hand) - s.wounds()
    def power(s): return (s.armor_max - s.armor_dmg) + s.nonw()
    def pos(s): return s.cells[0]
    def __repr__(s): return s.name

def reach(a, b):
    return any(cheb(p, q) <= 1 for p in a.cells for q in b.cells)

class Game:
    def __init__(s, heroes, enemies):
        s.heroes, s.enemies = heroes, enemies
        s.round = 0
        s.stats = dict(wasted=0, throws=0, gofish=0, flips=0)
    def figs(s): return [f for f in s.heroes + s.enemies if not f.down]
    def alive_h(s): return [h for h in s.heroes if not h.down]
    def alive_e(s): return [e for e in s.enemies if not e.down]
    def occupied(s, cell, ignore=None):
        return any(cell in f.cells for f in s.figs() if f is not ignore)
    def empty(s, cell, ignore=None):
        return 0 <= cell[0] <= 5 and 0 <= cell[1] <= 2 and not s.occupied(cell, ignore)

    # -------------------------------------------------- damage & healing
    def damage(s, tgt, amt, src=None, attack=True):
        if tgt.down or amt <= 0: return 0
        if attack and tgt.iron:
            tgt.iron = False; log('   ', tgt, 'Iron Skin ignores the hit'); return 0
        absorbed = min(tgt.guard, amt); tgt.guard -= absorbed; amt -= absorbed
        dealt = 0
        while amt > 0 and not tgt.down:
            amt -= 1; dealt += 1
            if tgt.armor_dmg < tgt.armor_max:
                tgt.armor_dmg += 1
            else:
                s.add_wound(tgt)
        log(f'      {tgt} takes {dealt} (guard {absorbed}) -> armor {tgt.armor_dmg}/{tgt.armor_max}, wounds {tgt.wounds()}')
        if tgt.side == 'H':
            s.stats['hero_dmg'] = s.stats.get('hero_dmg', 0) + dealt
            s.stats['dmg_'+tgt.name] = s.stats.get('dmg_'+tgt.name, 0) + dealt
        if src is not None and src.side == 'H' and dealt:
            if PROVOKE == 'point': src.provoke += dealt
            elif attack or src is not tgt: src._hit = True
        if attack and dealt and tgt.side == 'H' and tgt.thorns and src is not None and src.side == 'E':
            log('   Thorns reflects', dealt, 'to', src)
            s.damage(src, dealt, tgt, attack=False)
        return dealt
    def add_wound(s, f):
        nonw = [i for i, c in enumerate(f.hand) if c != W]
        if not nonw:
            f.hand.append(W)
        else:
            if f.side == 'H':
                i = min(nonw, key=lambda i: VALUE.get(f.hand[i], 1))
            else:
                i = nonw[-1]
            f.discard.append(f.hand[i]); f.hand[i] = W
        if f.hand and f.wounds() == len(f.hand):
            s.knock_down(f)
    def knock_down(s, f):
        if f.down: return
        f.down = True; f.cells = []
        log('   **', f, 'is DOWN **')
    def heal_wound(s, f, n, healer):
        done = 0
        while n > 0 and W in f.hand:
            f.hand.remove(W); f.draw(); n -= 1; done += 1
        if PROVOKE == 'point': healer.provoke += done
        elif done: healer._hit = True
        return done
    def heal_armor(s, f, n, healer):
        d = min(n, f.armor_dmg); f.armor_dmg -= d
        if PROVOKE == 'point': healer.provoke += d
        elif d: healer._hit = True
        return d
    def add_guard(s, f, n):
        if f.guard_exp < s.round: f.guard_exp = s.round + 1; f.guard = 0
        f.guard += n

    # -------------------------------------------------- movement
    def step_toward(s, f, goal_cells, need_decrease=True):
        """one orthogonal step (whole body) reducing distance to goal"""
        def dist(cells): return min(cheb(p, q) for p in cells for q in goal_cells)
        best, bd = None, dist(f.cells)
        for dy, dx in ((1,0),(-1,0),(0,1),(0,-1)):
            new = [(y+dy, x+dx) for y, x in f.cells]
            if all(s.empty(c, ignore=f) for c in new):
                d = dist(new)
                if d < bd: best, bd = new, d
        if best:
            f.cells = best; return True
        return False
    def nearest_reach_cell(s, f, tgt, max_steps=None):
        cands = []
        for y in range(6):
            for x in range(3):
                c = (y, x)
                if s.empty(c, ignore=f) and any(cheb(c, q) <= 1 for q in tgt.cells):
                    d = cheb(c, f.pos())
                    if max_steps is None or abs(c[0]-f.pos()[0]) + abs(c[1]-f.pos()[1]) <= max_steps:
                        cands.append((d, c))
        if not cands: return None
        return min(cands)[1]

# ---------------------------------------------------------------- hero cards
VALUE = {  # discard priority for wounds (low = discard first)
 'Detect Evil':0,'Detect Magic':0,'Reveal Weakness':0.5,'Pick Lock':0.5,'Calculated Retreat':0.5,
 'Fix Armor':1,'Second Wind':1,'Scavenge':1,'Recall':1,'Renewal':1,'Turn Undead':0.2,'Study':1,
 'Feint':1,'Bless':1,'Challenge':1.5,'Raise Shield':1.5,'Mage Light':1.5,'Caltrops':1.5,
}

def hero_melee_targets(g, h):
    """enemies reachable now or after one free orthogonal step; returns list of (enemy, step_cells or None)"""
    res = []
    for e in g.alive_e():
        if reach(h, e): res.append((e, None)); continue
        for dy, dx in ((1,0),(-1,0),(0,1),(0,-1)):
            c = (h.pos()[0]+dy, h.pos()[1]+dx)
            if g.empty(c) and any(cheb(c, q) <= 1 for q in e.cells):
                res.append((e, [c])); break
    return res

def kill_bonus(e, dmg):
    room = (e.armor_max - e.armor_dmg) + e.nonw() + e.guard
    return 3 if dmg >= room else 0

def top_hero(g):
    hs = g.alive_h()
    return max(hs, key=lambda h: h.provoke) if hs else None

def area_targets(g, cells):
    return [e for e in g.alive_e() if any(c in cells for c in e.cells)]

def best_2x2(g):
    best = (0, None)
    for y in range(0, 5):
        for x in range(0, 2):
            cells = [(y,x),(y+1,x),(y,x+1),(y+1,x+1)]
            n = len(area_targets(g, cells))
            if n > best[0]: best = (n, cells)
    return best

def choose(g, h):
    """return (score, action) for best card in hand; action is a closure"""
    opts = []
    top = top_hero(g)
    enemies = g.alive_e()
    if not enemies: return (0, None)
    mel = hero_melee_targets(g, h)
    bonus = h.next_bonus + (1 if h.berserk else 0) + getattr(h, 'perm_bonus', 0)
    def strongest(lst): return max(lst, key=lambda t: t[0].power())
    def weakest_e(): return min(enemies, key=lambda e: e.power())
    def ranged_target(dmg):
        return max(enemies, key=lambda e: (kill_bonus(e, dmg), -e.power()))
    for idx, c in enumerate(h.hand):
        if c == W: continue
        sc, act = 0, None
        # ---------- melee single-target
        MELEE = {'Bash':2,'Steady Strike':3,'Smite':2,'Stab':2,'Poisoned Blade':1,'Shield Bash':2,'Holy Strike':3,'Flurry':3,'Shadow Strike':4}
        if c in MELEE and mel:
            d = MELEE[c] + bonus
            e, step = strongest(mel) if h.berserk else max(mel, key=lambda t: (kill_bonus(t[0], d), -t[0].power()))
            sc = d + kill_bonus(e, d) + (1.5 if c == 'Poisoned Blade' else 0)
            def act(c=c, e=e, step=step, d=d):
                if step: h.cells = step
                g.damage(e, d, h)
                if c == 'Poisoned Blade': e.bleeds.append([2, h])
                if c == 'Shield Bash': e.stunned = True
        elif c in ('Cleave','Whirlwind'):
            adj = [e for e in enemies if reach(h, e)]
            per = 1 if c == 'Cleave' else 2
            if adj:
                sc = len(adj) * (per + bonus + (1.5 if c == 'Cleave' else 0)) + 1
                def act(adj=adj, c=c, per=per):
                    for e in adj:
                        g.damage(e, per + bonus, h)
                        if c == 'Cleave': e.bleeds.append([2, h])
                    h.provoke += 2
        elif c == 'Quake':
            row = area_targets(g, [(2,0),(2,1),(2,2)])
            if len(row) >= 2 or (row and len(enemies) == 1):
                sc = len(row) * (1 + bonus + 2) + 1
                def act(row=row):
                    for e in row: g.damage(e, 1 + bonus, h); e.stunned = True
                    h.provoke += 2
        elif c == 'Charge':
            if not mel:
                e = max(enemies, key=lambda e: e.provoke if False else -e.power())
                cell = g.nearest_reach_cell(h, e, max_steps=2)
                if cell:
                    sc = 2 + bonus + 2
                    def act(e=e, cell=cell):
                        h.cells = [cell]; g.damage(e, 2 + bonus, h); h.provoke += 2
        elif c == 'Berserk' and not h.berserk:
            sc = 3.5
            def act(): h.berserk = True
        elif c == 'Thorns' and not h.thorns:
            sc = 3 if top is h else 1
            def act(): h.thorns = True
        elif c in ('Challenge','War Cry','Taunt','Battle Cry','Hold the Line'):
            amt = {'Challenge':3,'War Cry':5,'Taunt':3,'Battle Cry':5,'Hold the Line':3}[c]
            amt = max(1, round(amt * PSCALE))
            gap = (max(x.provoke for x in g.alive_h() if x is not h) if len(g.alive_h()) > 1 else 0) - h.provoke
            sc = (4 if gap >= 0 else 0.6) + (2 if c == 'Battle Cry' else 0)
            def act(c=c, amt=amt):
                h.provoke += amt
                if c == 'Taunt': g.add_guard(h, 1)
                if c == 'Hold the Line': g.add_guard(h, 2)
                if c == 'Battle Cry':
                    for x in g.alive_h(): g.add_guard(x, 1)
        elif c in ('Brace','Raise Shield','Shield Wall','Dodge','Arcane Shield','Iron Skin','Evasion','Mana Shield'):
            amt = {'Brace':3,'Raise Shield':2,'Shield Wall':2,'Dodge':2,'Arcane Shield':2,'Iron Skin':3,'Evasion':3,'Mana Shield':3}[c]
            sc = (amt * 0.9 if top is h else 0.4) + (0 if h.guard == 0 else -1)
            def act(c=c, amt=amt):
                if c == 'Iron Skin': h.iron = True
                else: g.add_guard(h, amt)
                if c == 'Shield Wall':
                    others = [x for x in g.alive_h() if x is not h]
                    if others: g.add_guard(max(others, key=lambda x: x.provoke), 2)
        elif c == 'Fix Armor' and h.armor_dmg > 0:
            sc = 1.2 if h.armor_dmg >= h.armor_max else 0.7
            def act(): g.heal_armor(h, 1, h)
        elif c == 'Calculated Retreat' and h.pos()[0] <= 2:
            sc = 2
            def act():
                for y in (3,4,5):
                    for x in range(3):
                        if g.empty((y,x)): h.cells = [(y,x)]; return
        # ---------- thief
        elif c in ('Twin Daggers','Backstab','Ambush','Hamstring'):
            if c == 'Ambush': e = weakest_e()
            elif h.berserk: e = max(enemies, key=lambda e: e.power())
            else: e = max(enemies, key=lambda e: e.power()) if c == 'Backstab' else min(enemies, key=lambda e: e.power())
            canmove = c != 'Hamstring'
            ok = reach(h, e) or (canmove and g.nearest_reach_cell(h, e))
            if c == 'Hamstring' and not ok:
                if mel: e = mel[0][0]; ok = True
            if ok:
                d = {'Twin Daggers':2,'Backstab':6,'Ambush':6,'Hamstring':1}[c] + bonus
                sc = d + kill_bonus(e, d) + (2 if c == 'Hamstring' else 0) - (0 if reach(h, e) else 0.5)
                if c in ('Backstab','Ambush') and d < 4: sc -= 2
                def act(c=c, e=e, d=d):
                    if not reach(h, e):
                        cell = g.nearest_reach_cell(h, e)
                        if cell: h.cells = [cell]
                    if c == 'Twin Daggers':
                        others = [x for x in g.alive_e() if x is not e and reach(h, x)]
                        if others and kill_bonus(e, 2) == 0:
                            g.damage(e, 1 + bonus, h); g.damage(others[0], 1 + bonus, h)
                        else: g.damage(e, d, h)
                    else:
                        g.damage(e, d, h)
                    if c == 'Backstab': h.provoke -= (h.provoke + 1) // 2
                    if c == 'Hamstring': e.bleeds.append([2, h]); e.stunned = True
        elif c in ('Shortbow','Fire Bolt','Divine Light','Frost Ray','Frost Spike','Deadly Shot','Greater Bolt','Ice Lance'):
            d = {'Shortbow':2,'Fire Bolt':3,'Divine Light':2,'Frost Ray':2,'Frost Spike':5,'Deadly Shot':4,'Greater Bolt':4,'Ice Lance':4}[c] + bonus
            e = ranged_target(d)
            und = [x for x in enemies if getattr(x, 'undead', False)]
            if c == 'Divine Light' and und:
                e = max(und, key=lambda x: kill_bonus(x, 2 * d)); d = 2 * d
            sc = d + kill_bonus(e, d)
            def act(c=c, e=e, d=d):
                if c == 'Frost Ray' and h.pos()[0] < 5 and g.empty((h.pos()[0]+1, h.pos()[1])):
                    h.cells = [(h.pos()[0]+1, h.pos()[1])]
                g.damage(e, d, h)
                if c == 'Frost Spike': e.stunned = True
        elif c in ('Spark','Elemental Missile','Chain Lightning'):
            per, n = {'Spark':(1,3 if getattr(h, 'wand', False) else 2),'Elemental Missile':(2,3),'Chain Lightning':(2,5)}[c]
            ts = sorted(enemies, key=lambda e: e.power())[:n]
            sc = sum(per + bonus for _ in ts) + (1 if c == 'Spark' else 0)
            def act(ts=ts, per=per):
                for e in ts: g.damage(e, per + bonus, h)
        elif c in ('Burn',):
            e = max(enemies, key=lambda e: e.power()); sc = 2.2
            def act(e=e): e.bleeds.append([2, h])
        elif c in ('Mage Light','Fireball','Consecrate','Firestorm','Radiant Burst'):
            per = {'Mage Light':1,'Fireball':3,'Consecrate':2,'Firestorm':2,'Radiant Burst':2}[c] + bonus
            n, cells = best_2x2(g)
            if c == 'Consecrate':
                # straddle option: two front squares each side
                best = (0, None, [])
                for x in range(2):
                    cells2 = [(2,x),(2,x+1),(3,x),(3,x+1)]
                    es = area_targets(g, cells2)
                    hs = [y for y in g.alive_h() if y.pos() in cells2 and (y.wounds() or y.armor_dmg)]
                    v = len(es) * per + len(hs) * 2
                    if v > best[0]: best = (v, cells2, hs)
                if best[1]:
                    sc = best[0]
                    def act(best=best, per=per):
                        for e in area_targets(g, best[1]): g.damage(e, per, h)
                        for y in best[2]:
                            if y.wounds(): g.heal_wound(y, 1, h)
                            else: g.heal_armor(y, 1, h)
            elif cells:
                sc = n * per + (0 if c != 'Fireball' or n >= 2 else -2)
                def act(cells=cells, per=per):
                    for e in area_targets(g, cells): g.damage(e, per, h)
        elif c == 'Turn Undead':
            und = [x for x in enemies if getattr(x, 'undead', False) and x.cells and max(q[0] for q in x.cells) == 2]
            if und:
                sc = 2 * len(und)
                def act(und=und):
                    for x in und: x.stunned = True
        elif c == 'Frost Wall':
            rows = [[(y,0),(y,1),(y,2)] for y in (0,1,2)]
            row = max(rows, key=lambda r: len(area_targets(g, r)))
            ts = area_targets(g, row)
            if ts:
                sc = len(ts) * (2 + bonus + 2)
                def act(ts=ts):
                    for e in ts: g.damage(e, 2 + bonus, h); e.stunned = True
        elif c == 'Lightning Orb':
            sc = 2.5 if top is h else 1
            def act(): g.add_guard(h, 2)
        elif c == 'Caltrops':
            row = area_targets(g, [(2,0),(2,1),(2,2)])
            if row:
                sc = len(row) * (1 + bonus)
                def act(row=row):
                    for e in row: g.damage(e, 1 + bonus, h)
        elif c in ('Vanish','Blink','Smoke Bomb'):
            sc = 2.5 if (top is h and h.armor_dmg >= h.armor_max) else 0.3
            def act(c=c):
                h.provoke = max(0, h.provoke - 3)
                for y in (5,4):
                    for x in range(3):
                        if g.empty((y,x)):
                            old = h.pos(); h.cells = [(y,x)]
                            if c == 'Smoke Bomb':
                                for e in g.alive_e():
                                    if any(cheb(old, q) <= 1 for q in e.cells): e.stunned = True
                            return
        elif c in ('Feint','Bless'):
            sc = 1.5 if mel or c == 'Bless' else 0.5
            def act(c=c):
                if c == 'Feint': h.next_bonus += 2
                else:
                    t = max(g.alive_h(), key=lambda x: x.provoke)
                    t.next_bonus += 2
        elif c in ('Study','Pick Lock','Arcane Surge'):
            sc = 1.2 if c != 'Arcane Surge' else 2.5
            def act(c=c):
                n = 2 if c == 'Arcane Surge' else 1
                for _ in range(n): h.draw()
                if c == 'Arcane Surge': h.next_bonus += 2
        # ---------- cleric healing
        elif c in ('Mend','Healing Word','Greater Heal','Lay on Hands','Lesser Cleanse','Cleanse Armor','Party Heal','Prayer'):
            hs = g.alive_h()
            hurt = sorted([x for x in hs if x.wounds()], key=lambda x: -x.wounds())
            if c == 'Party Heal':
                if len(hurt) >= 2:
                    sc = 3 * len(hurt)
                    def act(hurt=hurt):
                        for x in hurt: g.heal_wound(x, 1, h)
            elif c in ('Lesser Cleanse','Cleanse Armor'):
                n = 1 if c == 'Lesser Cleanse' else 2
                if hurt:
                    t = hurt[0]; sc = 3 * min(n, t.wounds())
                    def act(t=t, n=n):
                        k = g.heal_wound(t, n, h); g.heal_armor(t, n - k, h)
                else:
                    arm = [x for x in hs if x.armor_dmg >= x.armor_max and x.armor_max > 0]
                    if arm:
                        t = arm[0]; sc = 1.2 * n
                        def act(t=t, n=n): g.heal_armor(t, n, h)
            elif hurt:
                n = {'Mend':1,'Healing Word':1,'Greater Heal':3,'Lay on Hands':2,'Prayer':2}[c]
                t = hurt[0]
                if c == 'Mend' and cheb(t.pos(), h.pos()) > 1: continue
                if c == 'Lay on Hands' and h.nonw() <= 2: continue
                sc = 3 * min(n, t.wounds()) - (1 if c == 'Greater Heal' and t.wounds() < 3 else 0)
                def act(c=c, t=t, n=n):
                    if c == 'Lay on Hands':
                        k = min(2, t.wounds())
                        for _ in range(k): t.hand.remove(W); t.draw(); g.add_wound(h)
                    else:
                        g.heal_wound(t, n, h)
                        if c == 'Greater Heal': t.draw()
        elif c in ('Sanctify Armor',):
            arm = [x for x in g.alive_h() if x.armor_dmg >= 3]
            if arm:
                t = max(arm, key=lambda x: x.armor_dmg); sc = t.armor_dmg * 0.9
                def act(t=t): g.heal_armor(t, t.armor_dmg, h)
        elif c == 'Rally':
            near = [x for x in g.alive_h() if x.wounds() and x.cells and cheb(x.pos(), h.pos()) <= 1]
            if near:
                sc = 3 * len(near)
                def act(near=near):
                    for x in near: g.heal_wound(x, 1, h)
        elif c in ('Shield of Faith','Sanctuary','Blessed Ward'):
            t = top
            sc = 1.8 if c == 'Shield of Faith' else 0.9 * len(g.alive_h())
            def act(c=c, t=t):
                if c == 'Shield of Faith': g.add_guard(t, 2)
                else:
                    for x in g.alive_h(): g.add_guard(x, 1)
        elif c in ('Second Wind','Renewal','Scavenge','Recall'):
            sc = 0.8 if len(h.deck) < 8 and h.discard else 0.1
            def act(c=c):
                if c in ('Second Wind','Renewal'):
                    back = [x for x in h.discard if x != W][:3]
                    for x in back: h.discard.remove(x); h.deck.append(x)
                    random.shuffle(h.deck)
                else:
                    back = [x for x in h.discard if x != W]
                    if back: h.discard.remove(back[-1]); h.hand.append(back[-1])
        if act is not None and sc > 0:
            opts.append((sc, idx, c, act))
    if not opts: return (0, None)
    return max(opts, key=lambda o: o[0])

TOPTIER = {'Battle Cry','Shield Wall','Charge','Quake','Greater Heal','Sanctify Armor','Sanctuary','Consecrate',
           'Ambush','Hamstring','Reveal Weakness','Smoke Bomb','Elemental Missile','Lightning Orb','Frost Wall',
           'Arcane Surge','Berserk','Party Heal','Backstab','Fireball','Iron Skin'}

def hero_turn(g, h):
    while h.pending:
        h.pending -= 1; h.draw()
    best = choose(g, h)
    sc = best[0]
    if best[1] is None or sc < 1.0:
        # Go Fish: flip top of deck and play it if useful
        if h.deck:
            card = h.deck.pop(); g.stats['flips'] += 1
            h.hand.append(card)
            b2 = choose(g, h)
            cand = [b2] if b2[1] is not None and h.hand[b2[1]] == card else []
            # play the flipped card if it has any use, else it's discarded
            h.hand.remove(card)
            tmp = h.hand; h.hand = [card]
            b3 = choose(g, h); h.hand = tmp
            if b3[1] is not None and b3[0] > 0:
                log(f'  {h} flips {card} and plays it'); h._hit = False; b3[3](); h.provoke += 1 if (PROVOKE == 'card' and h._hit) else 0
            else:
                log(f'  {h} flips {card} - no use');
            h.discard.append(card)
            if h.next_bonus and card not in ('Feint','Bless','Arcane Surge'): pass
            return
        if best[1] is None: log(f'  {h} has nothing to do'); return
    sc, idx, c, act = best
    h.hand.pop(idx)
    bonus_before = h.next_bonus
    log(f'  {h} plays {c} (score {sc:.1f})')
    h._hit = False
    act()
    if PROVOKE == 'card' and h._hit: h.provoke += 1
    if c not in ('Feint','Bless','Arcane Surge') and bonus_before and h.next_bonus == bonus_before:
        h.next_bonus = 0
    h.discard.append(c)
    if len(h.hand) < h.hand_size: h.draw()

# ---------------------------------------------------------------- enemy cards
# name: (kind, melee_dmg, throw_dmg)   kinds: dual, melee, ranged, util, phase, top
GOB = {'Rusty Blade':('dual',1,1),'Spear':('dual',2,1),'Shortbow':('bow',0,1),'Gang Up':('gang',1,1),
       'Scurry':('dual',1,1),'Cower':('util',0,0),'Flee':('flee',1,1),'Shriek':('shriek',1,1),
       'Disarm':('phase',0,0),'Vault':('vault',1,0)}
OGR = {'Backhand':('melee',1,0),'Club Swing':('melee',3,0),'Crushing Blow':('melee',5,0),'Stomp':('stomp',2,0),
       'Grab and Throw':('grab',2,0),'Rampage':('rampage',4,0),'Lumber':('melee',3,0),'Roar':('roar',0,0),
       'Thick Hide':('util',0,0),'Dim-witted':('util',0,0),'Rage':('phase',0,0),'Throw Goblin':('throwgob',1,2)}
ECARDS = {**GOB, **OGR}

def enemy_turn(g, e):
    if e.stunned:
        e.stunned = False; log(f'  {e} is stunned'); return
    heroes = g.alive_h()
    if not heroes: return
    top = max(heroes, key=lambda h: h.provoke)
    # free step toward top-provoke hero if not already in reach of them
    if not reach(e, top):
        moved = g.step_toward(e, top.cells)
        if moved: log(f'  {e} steps to {e.cells}')
    reachable = [h for h in heroes if reach(e, h)]
    mtarget = max(reachable, key=lambda h: h.provoke) if reachable else None
    target = mtarget or top
    bold = e.wounds() <= target.wounds() or DM is not None
    nflip = len(e.hand) if DM == 'full' else e.flips + (1 if DM == 'lite' else 0)
    flipped = e.hand[:nflip]
    def playable(c):
        if c == W: return False
        k, m, t = ECARDS[c]
        if k == 'phase': return True
        if c in e.used_top: return False
        if k in ('melee','grab','rampage'): return mtarget is not None
        if k == 'stomp' or k == 'roar': return bool(reachable)
        if k == 'vault':
            return any(g.empty((4,x)) for x in range(3)) and any(g.alive_h())
        return True
    def dmgval(c):
        k, m, t = ECARDS[c]
        if k == 'flee':
            return -1 if e.wounds() > e.nonw() else (m if mtarget else t)
        if k in ('util',): return 0
        if k == 'gang':
            others = len([x for x in g.alive_e() if x is not e and x.name.startswith('Goblin')])
            return (m + others) if mtarget else t
        if k in ('dual','shriek'): return m if mtarget else t
        if k == 'bow': return 1
        if k == 'stomp': return 2 * len(reachable)
        if k == 'rampage': return 6
        if k == 'throwgob': return 2
        if k == 'vault': return 1.5
        if k == 'roar': return 0.5
        return m
    # phase cards
    for c in flipped:
        if c != W and ECARDS[c][0] == 'phase' and c not in e.used_top:
            e.used_top.add(c); e.hand.remove(c); e.discard.append(c)
            if c == 'Rage': e.rage = True; log(f'  {e} flips RAGE')
            if c == 'Disarm':
                t = mtarget or top
                if not mtarget: g.stats['throws'] += 1
                g.damage(t, 1 + (1 if e.rage else 0), e)
                nonw = [x for x in t.hand if x != W]
                if nonw and not t.down:
                    x = random.choice(nonw); t.hand.remove(x); t.discard.append(x); t.pending += 1
                    log(f'  {e} DISARMS {t} ({x}), replaced next turn')
            flipped = e.hand[:nflip]
    cands = [c for c in flipped if playable(c)]
    if not [c for c in flipped if c != W]:
        log(f'  {e} is overwhelmed'); refill(e); return
    if not cands:
        # Go Fish
        g.stats['gofish'] += 1
        if e.deck:
            c = e.deck.pop()
            if playable(c):
                log(f'  {e} goes fish: {c}'); resolve(g, e, c, target, mtarget, reachable, top)
                e.discard.append(c)
            else:
                log(f'  {e} goes fish: {c} - wasted'); e.discard.append(c); g.stats['wasted'] += 1
        return
    c = max(cands, key=dmgval) if bold else min(cands, key=dmgval)
    e.hand.remove(c)
    if ECARDS[c][0] in ('vault','throwgob'): e.used_top.add(c)
    resolve(g, e, c, target, mtarget, reachable, top)
    e.discard.append(c)
    refill(e)

def refill(e):
    while len(e.hand) < e.hand_size and e.deck: e.hand.append(e.deck.pop())

def resolve(g, e, c, target, mtarget, reachable, top):
    if not g.alive_h(): return
    if mtarget is not None and mtarget.down: mtarget = None
    if top.down: top = max(g.alive_h(), key=lambda h: h.provoke)
    k, m, t = ECARDS[c]
    plus = 1 if e.rage else 0
    mood = ''
    if k in ('dual','shriek','gang','flee'):
        if k == 'flee' and e.wounds() > e.nonw():
            log(f'  {e} FLEES'); g.stats['fled']=g.stats.get('fled',0)+1; e.down = True; e.cells = []; return
        if k == 'shriek' and len([x for x in g.alive_e() if x.name.startswith('Goblin')]) == 1:
            for y in (2,1,0):
                for x in range(3):
                    if g.empty((y,x)):
                        ng = Fig(f'Goblin{len(g.enemies)+1}', 'E', [(y,x)], e.hand_size, 1, GOBDECK, flips=2)
                        g.enemies.append(ng); g.stats['shriek']=g.stats.get('shriek',0)+1; log(f'  {e} SHRIEKS - {ng} joins'); return
        if mtarget:
            d = m + plus
            if k == 'gang': d += len([x for x in g.alive_e() if x is not e and x.name.startswith('Goblin')])
            log(f'  {e} {c} (melee) -> {mtarget} for {d}'); g.damage(mtarget, d, e)
        else:
            g.stats['throws'] += 1
            log(f'  {e} throws ({c}) -> {top} for {t+plus}'); g.damage(top, t + plus, e)
    elif k == 'bow':
        low = min(g.alive_h(), key=lambda h: h.provoke)
        log(f'  {e} Shortbow -> {low}'); g.damage(low, 1 + plus, e)
    elif k == 'util':
        if c == 'Cower': g.add_guard(e, 1); log(f'  {e} cowers')
        if c == 'Thick Hide': e.armor_dmg = max(0, e.armor_dmg - 2); log(f'  {e} Thick Hide')
        if c == 'Dim-witted': log(f'  {e} is dim-witted')
    elif k == 'melee':
        log(f'  {e} {c} -> {mtarget} for {m+plus}'); g.damage(mtarget, m + plus, e)
    elif k == 'grab':
        log(f'  {e} Grab and Throw -> {mtarget}'); g.damage(mtarget, 2 + plus, e); mtarget.stunned = True
    elif k == 'rampage':
        log(f'  {e} RAMPAGE -> {mtarget}'); g.damage(mtarget, 4 + plus, e)
        nb = [h for h in g.alive_h() if h is not mtarget and mtarget.cells and cheb(h.pos(), mtarget.pos()) <= 1]
        if nb: g.damage(nb[0], 2 + plus, e)
    elif k == 'stomp':
        log(f'  {e} STOMP'); [g.damage(h, 2 + plus, e) for h in reachable if not h.down]
    elif k == 'roar':
        log(f'  {e} ROAR')
        for h in reachable:
            nonw = [x for x in h.hand if x != W]
            if nonw: h.hand.remove(nonw[0]); h.discard.append(nonw[0])
    elif k == 'vault':
        cells = [(4,x) for x in range(3) if g.empty((4,x))]
        e.cells = [cells[0]]
        near = [h for h in g.alive_h() if reach(e, h)]
        if near:
            t2 = max(near, key=lambda h: h.provoke); log(f'  {e} VAULTS into the party -> {t2}'); g.damage(t2, 1 + plus, e)
    elif k == 'throwgob':
        gobs = [x for x in g.alive_e() if x.name.startswith('Goblin') and x.pos()[0] <= 2]
        spots = [(5,x) for x in range(3) if g.empty((5,x))]
        if gobs and spots:
            gb = gobs[0]; gb.cells = [spots[0]]
            near = [h for h in g.alive_h() if reach(gb, h)]
            log(f'  {e} THROWS {gb} into the back row')
            if near: g.damage(max(near, key=lambda h: h.provoke), 1, gb)
        else:
            log(f'  {e} hurls a rock at {top}'); g.damage(top, 2 + plus, e)

# ---------------------------------------------------------------- decks
FDECK = (['Raise Shield']*3+['Brace']*2+['Taunt']*2+['Iron Skin']+['Challenge']*2+['War Cry']*2+
         ['Berserk','Battle Cry','Shield Wall','Charge','Quake','Thorns','Calculated Retreat']+['Cleave']*3+
         ['Bash']*3+['Steady Strike']*2+['Fix Armor']*2+['Second Wind'])
CDECK = (['Mend']*4+['Healing Word']*4+['Lay on Hands','Party Heal','Greater Heal','Sanctify Armor','Sanctuary',
         'Consecrate','Lesser Cleanse','Cleanse Armor']+['Shield of Faith']*2+['Smite']*4+['Divine Light']*4+
         ['Turn Undead','Bless','Detect Evil','Renewal'])
TDECK = (['Stab']*5+['Twin Daggers']*2+['Shortbow']*4+['Poisoned Blade']*3+['Feint']*2+['Dodge']*2+['Vanish']*2+
         ['Pick Lock']*2+['Caltrops']*2+['Backstab','Ambush','Hamstring','Reveal Weakness','Smoke Bomb','Scavenge'])
WDECK = (['Fire Bolt']*4+['Frost Ray']*4+['Spark']*4+['Burn']*3+['Mage Light']+['Arcane Shield']*2+['Blink']*2+
         ['Study']*3+['Detect Magic','Fireball','Elemental Missile','Lightning Orb','Frost Wall','Arcane Surge','Recall'])
GOBDECK = ['Rusty Blade']*3+['Spear']*3+['Shortbow']*2+['Gang Up','Scurry','Cower','Flee','Shriek','Disarm','Vault']
OGRDECK = (['Backhand']*3+['Club Swing']*4+['Crushing Blow']*2+['Stomp']*3+
           ['Grab and Throw','Rampage','Lumber','Roar','Thick Hide','Dim-witted','Rage','Throw Goblin'])
for d in (FDECK, CDECK, TDECK, WDECK): assert len(d) == 30, len(d)
assert len(GOBDECK) == 15 and len(OGRDECK) == 20

def battle(seed, verbose=False, layout=None):
    random.seed(seed); LOG.clear()
    extra = 2  # four heroes -> +2 hand size for enemies
    L = layout or {'Cleric':(3,0),'Fighter':(3,1),'Thief':(3,2),'Wizard':(5,1)}
    heroes = [Fig('Cleric','H',[L['Cleric']],5,4,CDECK), Fig('Fighter','H',[L['Fighter']],6,5,FDECK),
              Fig('Thief','H',[L['Thief']],5,2,TDECK), Fig('Wizard','H',[L['Wizard']],4,0,WDECK)]
    enemies = [Fig('Ogre','E',[(2,0),(2,1),(1,0),(1,1)],5+extra,3,OGRDECK,flips=3),
               Fig('Goblin1','E',[(2,2)],3+extra,1,GOBDECK,flips=2),
               Fig('Goblin2','E',[(1,2)],3+extra,1,GOBDECK,flips=2),
               Fig('Goblin3','E',[(0,2)],3+extra,1,GOBDECK,flips=2)]
    g = Game(heroes, enemies)
    start_cards = {h.name: len(h.deck) for h in heroes}
    while g.alive_h() and g.alive_e() and g.round < 20:
        g.round += 1
        log(f'--- Round {g.round}')
        hs = sorted(g.alive_h(), key=lambda f: (f.pos()[0], f.pos()[1]))          # front (y=3) first
        es = sorted(g.alive_e(), key=lambda f: (-max(c[0] for c in f.cells), min(c[1] for c in f.cells)))  # y=2 first
        order = []
        for i in range(max(len(hs), len(es))):
            if i < len(hs): order.append(hs[i])
            if i < len(es): order.append(es[i])
        for f in order:
            if f.down or not g.alive_h() or not g.alive_e(): continue
            if f.side == 'H': hero_turn(g, f)
            else: enemy_turn(g, f)
        # end of round: bleed and guard expiry
        for f in g.figs():
            for b in f.bleeds:
                if b[0] > 0 and not f.down:
                    g.damage(f, 1, b[1], attack=False); b[0] -= 1
            f.bleeds = [b for b in f.bleeds if b[0] > 0]
            if f.guard_exp == g.round: f.guard = 0
        state = '; '.join(f'{h.name} A{h.armor_dmg}/{h.armor_max} W{h.wounds()} P{h.provoke}' + (' DOWN' if h.down else '') for h in heroes)
        log('   ', state)
    win = bool(g.alive_h()) and not g.alive_e()
    res = dict(seed=seed, win=win, rounds=g.round,
               downed=[h.name for h in heroes if h.down],
               wounds={h.name: h.wounds() for h in heroes if not h.down},
               armor={h.name: h.armor_dmg for h in heroes},
               cards_used={h.name: start_cards[h.name] - len(h.deck) for h in heroes},
               fled=[e.name for e in enemies if e.down and e.cells == [] and False],
               stats=g.stats)
    if verbose: print('\n'.join(LOG))
    return res

if __name__ == '__main__':
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 10
    verbose = '-v' in sys.argv
    out = [battle(s, verbose and n == 1) for s in range(1, n + 1)]
    for r in out: print(r)
