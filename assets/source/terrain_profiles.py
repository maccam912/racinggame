"""Distant landforms; a 46 m vertex guard protects the entire 240 m road band."""
import math

# Profile, relief metres, world-space frequency, phase. No driving data is read
# or changed beyond the nearest road sample already used by the terrain bake.
PROFILES = {
    'glacier_ridge': ('ridge', 105, .0090, .3),
    'aurora_harbor': ('coastal', 45, .0090, 1.7),
    'alpine_meadow': ('hills', 52, .0065, 2.9),
    'frostbite_fjord': ('ridge', 120, .0080, 4.1),
    'tundra_pipeline': ('tundra', 28, .0075, 5.4),
    'rainforest_ruins': ('karst', 88, .0110, 6.8),
    'monsoon_delta': ('wetland', 10, .0090, 8.0),
    'coral_causeway': ('coastal', 38, .0100, 9.3),
    'mangrove_maze': ('wetland', 8, .0110, 10.7),
    'cloudforest_climb': ('ridge', 108, .0070, 12.1),
    'sakura_ring': ('hills', 21, .0070, 13.4),
    'bamboo_gorge': ('karst', 79, .0100, 14.8),
    'lantern_market': ('city', 10, .0060, 16.2),
    'terrace_touge': ('terrace', 42, .0065, 17.6),
    'temple_coast': ('coastal', 58, .0080, 18.9),
    'saltflat_velocity': ('salt', 3, .0070, 20.3),
    'dune_serpent': ('dune', 37, .0150, 21.6),
    'oasis_citadel': ('dune', 28, .0050, 23.0),
    'copper_mesa': ('mesa', 85, .0075, 24.4),
    'storm_chase': ('tundra', 20, .0070, 25.8),
    'steelworks_sprint': ('city', 12, .0055, 27.1),
    'container_corkscrew': ('city', 9, .0060, 28.5),
    'neon_underpass': ('city', 11, .0050, 29.9),
    'windfarm_run': ('hills', 40, .0065, 31.2),
    'festival_speedway': ('hills', 19, .0055, 32.6),
    'lunar_freight': ('crater', 42, .0080, 34.0),
    'orbital_gardens': ('hills', 25, .0070, 35.4),
    'crystal_chasm': ('crystal', 73, .0110, 36.7),
    'mars_badlands': ('mesa', 82, .0085, 38.1),
    'reactor_rift': ('basalt', 58, .0100, 39.5),
}


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x-a)/(b-a)))
    return t*t*(3-2*t)


def hashed(x, z):
    return (math.sin(x*127.1+z*311.7)*43758.5453) % 1.0


def field(x, z):
    ix, iz = math.floor(x), math.floor(z)
    u, v = x-ix, z-iz
    u, v = u*u*(3-2*u), v*v*(3-2*v)
    a, b = hashed(ix, iz), hashed(ix+1, iz)
    c, d = hashed(ix, iz+1), hashed(ix+1, iz+1)
    return (a+(b-a)*u)*(1-v)+(c+(d-c)*u)*v


def relief(identifier, x, z, distance):
    """Metres added to existing cosmetic terrain, zero within the protected band."""
    if identifier not in PROFILES or distance <= 286:
        return 0.0
    kind, amplitude, frequency, phase = PROFILES[identifier]
    u, v = x*frequency+phase, z*frequency-phase*.63
    broad = field(u*.24, v*.24)
    fine = field(u*.65+41.2, v*.65+19.7)
    if kind == 'ridge':
        crest = 1-abs(math.sin(u*.75+math.sin(v*.32)*1.7))
        shape = crest**1.7*(.35+broad*.65)-.10
    elif kind == 'coastal':
        shape = smooth(.35, .8, broad)*(.5+fine*.5)-.04
    elif kind == 'hills':
        shape = (.5+.25*math.sin(u*.7)+.25*math.cos(v*.8))*(.5+broad*.5)-.05
    elif kind == 'tundra':
        shape = (broad-.32)*.7+(fine-.5)*.18
    elif kind == 'karst':
        shape = smooth(.48, .78, fine)**.7*(.4+broad*.6)-.12
    elif kind == 'wetland':
        shape = (broad-.45)*.5
    elif kind == 'city':
        shape = (broad-.35)*.4
    elif kind == 'terrace':
        level = (.5+.5*math.sin(u*.48+math.cos(v*.35)))*4
        step = math.floor(level)
        shape = (step+smooth(.78, 1, level-step))/4-.12
    elif kind == 'salt':
        shape = (broad-.5)*.35
    elif kind == 'dune':
        shape = (.5+.5*math.sin(u+math.sin(v*.45)*1.2))**1.8*(.6+broad*.4)-.18
    elif kind == 'mesa':
        shape = smooth(.32, .68, broad)*.75+smooth(.65, .82, fine)*.25-.13
    elif kind == 'crater':
        # Large bowls fit the 32 m export grid, with rims inside each cell.
        cell_x, cell_z = math.floor(x/300), math.floor(z/300)
        cx = (cell_x+.35+hashed(cell_x, cell_z)*.3)*300
        cz = (cell_z+.35+hashed(cell_x+19.7, cell_z+37.1)*.3)*300
        radius = 70+hashed(cell_x+3.4, cell_z+8.9)*28
        r = math.hypot(x-cx, z-cz)/radius
        rim = math.exp(-((r-1.02)/.20)**2)*.42
        bowl = (1-smooth(.25, .94, r))*.72
        shape = rim-bowl+(broad-.5)*.12
    elif kind == 'crystal':
        ridge = 1-abs(math.sin(u+v*.4+math.sin(v*.6)))
        shape = ridge**2.7*(.5+fine*.5)-.18
    else:  # fractured basalt benches
        shape = smooth(.38, .68, fine)*.58+(broad-.55)*.3
    return amplitude*shape*smooth(286, 436, distance)
