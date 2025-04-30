import json

# List of keys to remove
KEYS_TO_REMOVE = {
    "startLatitude",
    "startLongitude",
    "endLatitude",
    "endLongitude",
}

def remove_geo_keys(obj):
    """
    Recursively remove any dict entries whose key is in KEYS_TO_REMOVE.
    Works on nested dicts and lists.
    """
    if isinstance(obj, dict):
        # First, remove unwanted keys at this level
        for key in list(obj.keys()):
            if key in KEYS_TO_REMOVE:
                obj.pop(key)
        # Then recurse into remaining values
        for value in obj.values():
            remove_geo_keys(value)

    elif isinstance(obj, list):
        # Recurse into each item of the list
        for item in obj:
            remove_geo_keys(item)

    # primitives (str, int, etc.) are left untouched
    return obj

def clean_json_file(input_path, output_path):
    # Load the JSON data
    with open(input_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # Remove the geo keys
    cleaned = remove_geo_keys(data)

    # Write back out (pretty-printed)
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(cleaned, f, ensure_ascii=False, indent=2)

if __name__ == "__main__":
    import argparse

    p = argparse.ArgumentParser(description="Strip lat/long fields from a JSON file")
    p.add_argument("infile", help="Path to input JSON")
    p.add_argument("outfile", help="Path where cleaned JSON will be written")
    args = p.parse_args()

    clean_json_file(args.infile, args.outfile)
