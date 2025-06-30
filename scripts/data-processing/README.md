# Data Processing Scripts

Scripts for data cleaning, transformation, and privacy protection.

## remove_geo_garmin_json.py

### 📝 Description
Removes geolocation data from JSON files exported from Garmin devices. Strips latitude/longitude coordinates while preserving other data structure for privacy protection.

### 🎯 Use Cases
- Privacy protection when sharing GPS/fitness data
- Cleaning Garmin exports before uploading to platforms
- Removing location data from workout logs
- Preparing sanitized data for analysis

### 🔧 Requirements
**Platform:** Cross-platform (Windows/Linux/macOS)
**Dependencies:** 
- Python 3.6+ (built-in json module only)
**Permissions:** Regular user (read/write access to JSON files)

### 📦 Usage
```bash
# Basic usage
python remove_geo_garmin_json.py input.json output.json

# Example
python remove_geo_garmin_json.py garmin_export.json cleaned_export.json
```

### ⚙️ Data Removed
**Coordinate Keys:**
- startLatitude, startLongitude
- endLatitude, endLongitude  
- maxLatitude, maxLongitude
- minLatitude, minLongitude

**Field Enums:**
- END_LONGITUDE, END_LATITUDE objects

### 🔒 Safety Notes
- **Non-destructive**: Creates new output file, preserves original
- Validates JSON structure before processing
- Handles nested data structures recursively
- Preserves all non-geographic data intact

### 🐛 Troubleshooting
**Invalid JSON:**
- Symptom: JSON decode error
- Solution: Verify input file is valid JSON format

**Permission errors:**
- Symptom: Cannot write output file
- Solution: Check write permissions in output directory

**Large files:**
- Symptom: Memory issues with huge JSON files
- Solution: Consider streaming JSON parser for very large files

### 🔗 Related Scripts
- Combine with other privacy protection tools
- Use in data preparation pipelines

---
*Last updated: 2024-12-30*
*Tested on: Python 3.6+ on Windows/Linux/macOS*