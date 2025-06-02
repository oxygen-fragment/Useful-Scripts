#!/usr/bin/env bash
#
# prepare_arxiv.sh
#
# Automate LaTeX paper preparation for arXiv submission.
# Usage: ./prepare_arxiv.sh /path/to/original_paper main.tex
#
# It will:
#  1. Copy your source into tmp/
#  2. Merge appendix if detected
#  3. Tweak style files (remove "Submitted to...")
#  4. Flatten subdirectories (move figures to root)
#  5. Clean up generated files and comments
#  6. Append a \typeout line to force multiple pdflatex passes
#  7. Compile (pdflatex → bibtex → pdflatex ×2)
#  8. Keep only .bbl and source files; delete .bib
#  9. Create ax.tar within tmp/
# 10. Prompt you to double-check before arXiv upload
#
# You’ll still need to inspect the log, check the PDF, and
# handle any manual metadata entry for arXiv. Read the “Guidance” section below.

set -euo pipefail

####### 1. ARGUMENT CHECKS & SETUP #######

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 /path/to/ORIGINAL_PAPER_DIR MAIN_TEX_FILENAME"
  echo "Example: $0 /home/me/my_paper paper.tex"
  exit 1
fi

SRC_DIR="$1"
MAIN_TEX_NAME="$2"

# Verify source directory
if [[ ! -d "$SRC_DIR" ]]; then
  echo "🚨 ERROR: Source directory '$SRC_DIR' does not exist."
  exit 1
fi

# Verify main .tex exists
if [[ ! -f "$SRC_DIR/$MAIN_TEX_NAME" ]]; then
  echo "🚨 ERROR: Main TeX file '$MAIN_TEX_NAME' not found in '$SRC_DIR'."
  exit 1
fi

# Check for required commands
for cmd in cp pdflatex bibtex sed tar; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "🚨 ERROR: '$cmd' is required but not found in PATH."
    exit 1
  fi
done

echo "✅ Environment looks good. Beginning arXiv prep..."

# Define TMP_DIR (wiped each run)
TMP_DIR="tmp_arxiv"
echo "ℹ️  Using temporary working folder: '$TMP_DIR'"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"


####### 2. DEEP COPY ORIGINAL PAPER #######

echo -e "\n=== Step 1: Copying source into '$TMP_DIR' ==="
cp -r "$SRC_DIR"/. "$TMP_DIR"/
echo "✔️  Copied all files from '$SRC_DIR' → '$TMP_DIR'."


####### 3. APPENDIX MERGE (IF DETECTED) #######

echo -e "\n=== Step 2: Checking for an 'appendix.tex' to merge ==="
MAIN_TEX_PATH="$TMP_DIR/$MAIN_TEX_NAME"
APPENDIX_TEX_PATH="$TMP_DIR/appendix.tex"

if [[ -f "$APPENDIX_TEX_PATH" ]]; then
  if grep -q '\\appendix' "$MAIN_TEX_PATH"; then
    echo "ℹ️  '\\appendix' already present in main .tex. Skipping merge."
  else
    echo "ℹ️  Found 'appendix.tex'. Appending it to main document..."
    # Insert after \bibliography or \printbibliography if possible; otherwise before \end{document}
    if grep -q '\\bibliography' "$MAIN_TEX_PATH"; then
      sed -i '/\\bibliography/ a \
\
% ===== Merged appendix =====\
\\appendix\
\\input{appendix}\
' "$MAIN_TEX_PATH"
      echo "✔️  Inserted \\appendix \\input{appendix} after \\bibliography."
    elif grep -q '\\printbibliography' "$MAIN_TEX_PATH"; then
      sed -i '/\\printbibliography/ a \
\
% ===== Merged appendix =====\
\\appendix\
\\input{appendix}\
' "$MAIN_TEX_PATH"
      echo "✔️  Inserted \\appendix \\input{appendix} after \\printbibliography."
    else
      sed -i '/\\end{document}/ i \
\
% ===== Merged appendix =====\
\\appendix\
\\input{appendix}\
' "$MAIN_TEX_PATH"
      echo "✔️  Inserted \\appendix \\input{appendix} before \\end{document}."
    fi
  fi
else
  echo "ℹ️  No 'appendix.tex' found. Skipping merge."
fi


####### 4. STYLE FILE CLEANUP #######

echo -e "\n=== Step 3: Tidying up any .sty files (remove 'Submitted to...') ==="
STY_FILES=$(find "$TMP_DIR" -maxdepth 1 -type f -name "*.sty")

if [[ -z "$STY_FILES" ]]; then
  echo "ℹ️  No .sty files at top level to tweak."
else
  for sty in $STY_FILES; do
    if grep -q -i "Submitted to" "$sty"; then
      echo "   ✏️  Removing placeholder 'Submitted to...' lines in $sty"
      sed -i '/Submitted to/dI' "$sty"
      echo "   ✔️  Cleared 'Submitted to...' from $(basename "$sty")"
    else
      echo "   ℹ️  No 'Submitted to...' found in $(basename "$sty")."
    fi
  done
  echo "⚠️  If your paper is already published, manually update any publication-metadata in .sty files."
fi


####### 5. FLATTEN SUBDIRECTORIES (FIGURES → ROOT) #######

echo -e "\n=== Step 4: Flattening subdirectories for figure files ==="
# Supported figure extensions
FIG_EXTENSIONS="pdf png jpg jpeg eps"

# Find all figure files in subdirectories (excluding root)
find "$TMP_DIR" -type f \( -iname "*.pdf" -o -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.eps" \) | while read -r orig; do
  # Skip if already in root of TMP_DIR
  if [[ "$(dirname "$orig")" == "$TMP_DIR" ]]; then
    continue
  fi

  rel="${orig#$TMP_DIR/}"          # e.g., "figures/plot1.pdf"
  fname="$(basename "$orig")"      # e.g., "plot1.pdf"
  base_noext="${fname%.*}"         # e.g., "plot1"

  # If a file of same name already exists in root, generate a unique suffix
  if [[ -e "$TMP_DIR/$fname" ]]; then
    count=1
    while [[ -e "$TMP_DIR/${base_noext}_${count}.${fname##*.}" ]]; do
      ((count++))
    done
    newname="${base_noext}_${count}.${fname##*.}"
  else
    newname="$fname"
  fi

  echo "   📂 Moving '$rel' → '$newname'"
  mv "$orig" "$TMP_DIR/$newname"

  # Update references in all .tex: drop directory prefix
  # We assume references in .tex use the path without extension or with extension
  orig_noext="${rel%.*}"       # e.g., "figures/plot1"
  new_noext="${newname%.*}"    # e.g., "plot1" or "plot1_1"
  echo "     🔍 Rewriting references: '$orig_noext' → '$new_noext'"
  find "$TMP_DIR" -type f -name "*.tex" -exec sed -i "s@${orig_noext}@${new_noext}@g" {} \;
done

# Clean up any now-empty directories
echo "   🗑️  Deleting empty dirs..."
find "$TMP_DIR" -type d -empty -not -path "$TMP_DIR" -exec rmdir {} \; || true
echo "✔️  Subdirectory flattening complete."


####### 6. CLEAN UNNECESSARY FILES (BUILD ARTIFACTS, HIDDEN DIRS) #######

echo -e "\n=== Step 5: Deleting LaTeX build artifacts and hidden dirs ==="
# Remove common LaTeX-generated files
find "$TMP_DIR" -type f \( \
    -iname "*.aux" -o -iname "*.log" -o -iname "*.out" -o -iname "*.toc" \
    -o -iname "*.lof" -o -iname "*.lot" -o -iname "*.fls" -o -iname "*.fdb_latexmk" \
    -o -iname "*.synctex.gz" -o -iname "*.blg" -o -iname "*.bbl" -o -iname "*.pdf" \
  \) -exec rm -f {} \;
echo "   ✔️  Removed old .aux/.log/.pdf/.bbl/etc."

# Remove hidden directories (e.g., .git, .github, .svn)
echo "   🗑️  Removing hidden directories..."
find "$TMP_DIR" -type d -name ".*" -exec rm -rf {} + || true

echo "✔️  Pre-compile cleanup done."


####### 7. STRIP OUT LaTeX COMMENT LINES #######

echo -e "\n=== Step 6: Stripping lines starting with '%' from all .tex files ==="
find "$TMP_DIR" -type f -name "*.tex" | while read -r texfile; do
  echo "   ✂️  Processing $(basename "$texfile")"
  # Delete lines whose first non-whitespace char is %
  sed -i '/^[[:space:]]*%/d' "$texfile"
done
echo "✔️  All top-level LaTeX comments removed."


####### 8. APPEND \typeout LINE TO MAIN .TEX #######

echo -e "\n=== Step 7: Adding \\typeout line after \\end{document} ==="
if grep -q "\\end{document}" "$MAIN_TEX_PATH"; then
  sed -i '/\\end{document}/a \
\\typeout{get arXiv to do 4 passes: Label(s) may have changed. Rerun}\
' "$MAIN_TEX_PATH"
  echo "✔️  Appended \\typeout after \\end{document} in $(basename "$MAIN_TEX_PATH")."
else
  echo "⚠️  Could not find '\\end{document}' in main .tex. Please insert manually."
fi


####### 9. COMPILE UNTIL REFERENCES RESOLVE #######

echo -e "\n=== Step 8: Compiling (pdflatex → bibtex → pdflatex ×2) ==="
pushd "$TMP_DIR" > /dev/null

# 9.1 First pass
echo "   🔨 Running pdflatex (1st pass)..."
if ! pdflatex -interaction=nonstopmode "$MAIN_TEX_NAME" &> compile1.log; then
  echo "🚨 pdflatex (1st) failed. Inspect '$TMP_DIR/compile1.log'. Exiting."
  popd > /dev/null
  exit 1
fi

# 9.2 BibTeX
mainbase="${MAIN_TEX_NAME%.tex}"
if [[ -f "${mainbase}.aux" ]]; then
  echo "   📖 Running bibtex..."
  if ! bibtex "$mainbase" &> bibtex.log; then
    echo "🚨 BibTeX failed. Inspect '$TMP_DIR/bibtex.log'. Exiting."
    popd > /dev/null
    exit 1
  fi
else
  echo "⚠️  No .aux found; skipping bibtex. Do you use biblatex? Adjust script accordingly."
fi

# 9.3 Second & third pdflatex passes
echo "   🔨 Running pdflatex (2nd pass)..."
pdflatex -interaction=nonstopmode "$MAIN_TEX_NAME" &> compile2.log

echo "   🔨 Running pdflatex (3rd pass)..."
pdflatex -interaction=nonstopmode "$MAIN_TEX_NAME" &> compile3.log

echo "✔️  Compilation steps complete. Check logs if there were warnings."

popd > /dev/null


####### 10. KEEP ONLY .bbl & SOURCE; DELETE .bib #######

echo -e "\n=== Step 9: Cleaning generated files, keeping only .bbl and sources ==="
# Remove all generated except .bbl
find "$TMP_DIR" -type f \( \
    -iname "*.aux" -o -iname "*.log" -o -iname "*.out" -o -iname "*.toc" \
    -o -iname "*.lof" -o -iname "*.lot" -o -iname "*.fls" -o -iname "*.fdb_latexmk" \
    -o -iname "*.synctex.gz" -o -iname "*.blg" -o -iname "*.pdf" \
  \) -exec rm -f {} \;
echo "   ✔️  Removed generated files except .bbl."

# Delete .bib (arXiv uses .bbl)
find "$TMP_DIR" -type f -name "*.bib" -exec rm -f {} \;
echo "   ✔️  Deleted .bib files; we'll rely on the .bbl."


####### 11. CREATE TARBALL #######

echo -e "\n=== Step 10: Creating 'ax.tar' inside '$TMP_DIR' ==="
pushd "$TMP_DIR" > /dev/null

# Ensure only the necessary files are included: .tex, .sty/.cls/.bst, figures, .bbl, any other required source
# We just tar everything remaining (should be correct after cleanup)
tar -cvvf ax.tar * &> tar.log
echo "✔️  Created 'ax.tar'. Check '$TMP_DIR/tar.log' for details (file list)."

popd > /dev/null


####### 12. FINAL MESSAGE & REMINDERS #######

echo -e "\n✅ All done! Your 'ax.tar' is ready in '$TMP_DIR/'."
echo "   📤 Upload 'ax.tar' to arXiv.org."

echo -e "\n--- IMPORTANT NEXT STEPS ---"
echo "1) On arXiv upload page, inspect extracted file list carefully. Remove any stray files flagged as unnecessary."
echo "2) Manually check '$TMP_DIR/compile3.log' & '$TMP_DIR/compile2.log' for unresolved warnings or errors."
echo "3) Open '$TMP_DIR/${MAIN_TEX_NAME%.tex}.pdf' (if you kept it from a prior compile) or compile locally once more to confirm appearance."
echo "4) arXiv metadata: see guidance below on formatting Title/Authors/Abstract."
echo "5) Remember to consult your advisor about subject-area classification—and INVITE thought: is 'cs.CR' really the best home, or should you target 'math.ST'? 🤔"
echo "6) After you choose a submission password on arXiv, share that password with coauthors so they can update or withdraw the submission if needed."

echo -e "\n🎉 Good luck with your arXiv submission! 🎉\n"
