import json

# Keys to remove wherever they appear
KEYS_TO_REMOVE = {
    "startLatitude",
    "startLongitude",
    "endLatitude",
    "endLongitude",
    "maxLatitude",
    "maxLongitude",
    "minLatitude",
    "minLongitude",
}

# fieldEnum values whose entire objects should be removed from lists
FIELD_ENUMS_TO_REMOVE = {
    "END_LONGITUDE",
    "END_LATITUDE",
}

def remove_geo_keys(obj):
    """
    Recursively:
     1) Remove any dict entries whose key is in KEYS_TO_REMOVE.
     2) If obj is a list, drop any element that's a dict with fieldEnum in FIELD_ENUMS_TO_REMOVE.
    """
    if isinstance(obj, dict):
        # 1) strip out unwanted keys at this level
        for k in list(obj.keys()):
            if k in KEYS_TO_REMOVE:
                obj.pop(k)
        # then recurse into all remaining values
        for v in obj.values():
            remove_geo_keys(v)

    elif isinstance(obj, list):
        cleaned = []
        for item in obj:
            # drop whole blocks with matching fieldEnum
            if isinstance(item, dict) and item.get("fieldEnum") in FIELD_ENUMS_TO_REMOVE:
                continue
            # otherwise recurse
            remove_geo_keys(item)
            cleaned.append(item)
        # replace in-place
        obj[:] = cleaned

    return obj

def clean_json_file(input_path, output_path):
    # Load JSON
    with open(input_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # Clean it
    remove_geo_keys(data)

    # Write back out
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

if __name__ == "__main__":
    import argparse
    p = argparse.ArgumentParser(description="Strip geo keys & certain fieldEnum blocks from JSON")
    p.add_argument("infile",  help="path to input .json")
    p.add_argument("outfile", help="path to write cleaned .json")
    args = p.parse_args()

    clean_json_file(args.infile, args.outfile)
