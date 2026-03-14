import re
import os

# ==========================================
# 1. Configuration & Data
# ==========================================
INTERFACE_VERSION = "120001"
ADDON_VERSION = "1.2.1"

raw_data = {
    "Consumables": {
        "Flasks": ["Flask of the Magisters", "Light's Potential", "Draught of Rampant Abandon"],
        "Food": ["Flora Frenzy", "Royal Roast", "Quel'dorei Medley", "Silvermoon Parade"],
        "Runes": ["Void-Touched Augment Rune"],
        "Weapon": ["Thalassian Phoenix Oil"],
        "Potions": ["Light's Potential", "Draught of Rampant Abandon"], # Added
        "HealthPotions": ["Silvermoon Health Potion"]                   # Added
    },
    "Specs": {
        "HUNTER": {
            "253": { # Beast Mastery
                "Enchants": {
                    "1": "Empowered Rune of Avoidance", # Head
                    "3": "Amirdrassil's Grace",         # Shoulders
                    "5": "Mark of the Worldsoul",       # Chest
                    "7": "Forest Hunter's Armor Kit",   # Legs
                    "8": "Lynx's Dexterity",            # Boots
                    "11": "Zul'jin's Mastery",          # Ring 1
                    "12": "Zul'jin's Mastery",          # Ring 2
                    "16": "Acuity of the Ren'dorei",    # Weapon
                }
            }
        }
    }
}

# ==========================================
# 2. Lua Generator Logic (FIXED)
# ==========================================
def dict_to_lua(data, indent=1):
    spacing = "    " * indent
    
    if isinstance(data, dict):
        lua_str = "{\n"
        for key, value in data.items():
            key_str = f"[{key}]" if str(key).isdigit() else key
            lua_str += f"{spacing}{key_str} = {dict_to_lua(value, indent + 1)},\n"
        lua_str += "    " * (indent - 1) + "}"
        return lua_str
        
    elif isinstance(data, list):
        lua_str = "{\n"
        for i, value in enumerate(data, start=1):
            lua_str += f"{spacing}[{i}] = {dict_to_lua(value, indent + 1)},\n"
        lua_str += "    " * (indent - 1) + "}"
        return lua_str
        
    elif isinstance(data, str):
        return f'"{data}"' # Now it properly returns just the string!
        
    else:
        return str(data)

# ==========================================
# 3. Execution
# ==========================================
print(f"Building MidnightCheck v{ADDON_VERSION} for WoW Interface {INTERFACE_VERSION}...")

lua_content = f"local AddonName, ns = ...\n\n-- AUTO-GENERATED DATABASE - DO NOT EDIT MANUALLY\nns.Data = {dict_to_lua(raw_data)}\n"
with open('Database.lua', 'w') as file:
    file.write(lua_content)
print(" ✔ Database.lua generated successfully.")

# Note: Matching your folder case sensitivity!
if os.path.exists('Midnightcheck.toc'):
    with open('Midnightcheck.toc', 'r') as file:
        toc_content = file.read()

    toc_content = re.sub(r'## Interface: \d+', f'## Interface: {INTERFACE_VERSION}', toc_content)
    toc_content = re.sub(r'## Version: [\d\.]+', f'## Version: {ADDON_VERSION}', toc_content)

    with open('Midnightcheck.toc', 'w') as file:
        file.write(toc_content)
    print(" ✔ Midnightcheck.toc updated successfully.")
else:
    print(" ✖ Midnightcheck.toc not found! Ensure file names match.")