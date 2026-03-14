# update_db.py

# 1. Your raw data (This could be pulled from an API request in a more advanced script)
raw_data = {
    "Consumables": {
        "Flasks": ["Flask of the Magisters", "Light's Potential", "Draught of Rampant Abandon"],
        "Food": ["Flora Frenzy", "Royal Roast", "Quel'dorei Medley", "Silvermoon Parade"],
        "Runes": ["Void-Touched Augment Rune"],
        "Weapon": ["Thalassian Phoenix Oil"]
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

# 2. A helper function to convert Python dictionaries into WoW Lua tables
def dict_to_lua(data, indent=1):
    lua_str = "{\n"
    spacing = "    " * indent
    
    if isinstance(data, dict):
        for key, value in data.items():
            # If key is an integer string, format as [1], otherwise format as Key
            key_str = f"[{key}]" if str(key).isdigit() else key
            lua_str += f"{spacing}{key_str} = {dict_to_lua(value, indent + 1)},\n"
    elif isinstance(data, list):
        for i, value in enumerate(data, start=1):
            lua_str += f"{spacing}[{i}] = {dict_to_lua(value, indent + 1)},\n"
    elif isinstance(data, str):
        lua_str += f'"{data}"'
    else:
        lua_str += str(data)
        
    lua_str += "    " * (indent - 1) + "}"
    return lua_str

# 3. Construct the final file content
lua_content = f"""local AddonName, ns = ...

-- AUTO-GENERATED DATABASE - DO NOT EDIT MANUALLY
ns.Data = {dict_to_lua(raw_data)}
"""

# 4. Overwrite your Database.lua file
with open('Database.lua', 'w') as file:
    file.write(lua_content)

print("Database.lua has been successfully generated!")