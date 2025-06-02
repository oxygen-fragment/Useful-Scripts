#!/usr/bin/env bash
#
# prepare_arxiv.sh
#
# Automate LaTeX paper preparation for arXiv submission.
# Skips BibTeX if no .bib file is found.
#
# Usage: ./prepare_arxiv.sh /path/to/ORIGINAL_PAPER_DIR MAIN_TEX_FILENAME
# Example: ./prepare_arxiv.sh /home/me/my_paper paper.tex
#
# It will:
#  1. Copy your source into tmp_arxiv/
#  2. Merge appendix if detected
#  3. Tweak .sty files (remove "Submitted to...")
#  4. Flatten subdirectories (move figures to root)
#  5. Clean up generated files and strip comments
#  6. Append a \typeout line after \end{document}
#  7. Compile (pdflatex → [bibtex if .bib exists] → pdflatex ×2)
#  8. Keep only .bbl and source; delete .bib
#  9. Create ax.tar inside tmp_arxiv/
#
# You’ll still need to inspect logs, check the final PDF, and fill arXiv metadata manually.

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
for cmd in cp pdflatex sed tar; do
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
    # Insert after \bibliography or \printbibliography; otherwise before \end{document}
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

  rel="${orig#$TMP_DIR/}"          # e.g., "figures/plot1.png"
  fname="$(basename "$orig")"      # e.g., "plot1.png"
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

echo -e "\n=== Step 8: Compiling (pdflatex → [bibtex if .bib exists] → pdflatex ×2) ==="
pushd "$TMP_DIR" > /dev/null

# 9.1 First pdflatex pass
echo "   🔨 Running pdflatex (1st pass)..."
if ! pdflatex -interaction=nonstopmode "$MAIN_TEX_NAME" &> compile1.log; then
  echo "🚨 pdflatex (1st) failed. Inspect '$TMP_DIR/compile1.log'. Exiting."
  popd > /dev/null
  exit 1
fi

# 9.2 Only run BibTeX if there’s a .bib file
mainbase="${MAIN_TEX_NAME%.tex}"
if [[ -f "${mainbase}.bib" ]]; then
  echo "   📖 Running bibtex (because '${mainbase}.bib' exists)…"
  if ! bibtex "$mainbase" &> bibtex.log; then
    echo "🚨 BibTeX failed. Inspect '$TMP_DIR/bibtex.log'. Exiting."
    popd > /dev/null
    exit 1
  fi
else
  echo "ℹ️  No .bib file detected—skipping BibTeX."
fi

# 9.3 Second & third pdflatex passes
echo "   🔨 Running pdflatex (2nd pass)…"
pdflatex -interaction=nonstopmode "$MAIN_TEX_NAME" &> compile2.log

echo "   🔨 Running pdflatex (3rd pass)…"
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

# Delete .bib (arXiv uses .bbl) but only if it existed
if find "$TMP_DIR" -maxdepth 1 -type f -name "*.bib" | grep -q .; then
  find "$TMP_DIR" -type f -name "*.bib" -exec rm -f {} \;
  echo "   ✔️  Deleted .bib files; we'll rely on the .bbl."
else
  echo "ℹ️  No .bib to delete."
fi


####### 11. CREATE TARBALL #######

echo -e "\n=== Step 10: Creating 'ax.tar' inside '$TMP_DIR' ==="
pushd "$TMP_DIR" > /dev/null

# Just tar everything left (should be only needed .tex, .sty/.cls/.bst, figures, .bbl, etc.)
tar -cvvf ax.tar * &> tar.log
echo "✔️  Created 'ax.tar'. Check '$TMP_DIR/tar.log' for details (file list)."

popd > /dev/null


####### 12. FINAL MESSAGE & REMINDERS #######

echo -e "\n✅ All done! Your 'ax.tar' is ready in '$TMP_DIR/'."
echo "   📤 Upload 'ax.tar' to arXiv.org."

echo -e "\n--- IMPORTANT NEXT STEPS ---"
echo "1) On arXiv upload page, inspect the extracted file list. Remove any stray files flagged as unnecessary."
echo "2) Manually check '$TMP_DIR/compile3.log' & '$TMP_DIR/compile2.log' for unresolved warnings or errors."
echo "3) Open '$TMP_DIR/${MAIN_TEX_NAME%.tex}.pdf' and verify everything looks right (figures, tables, cross‐refs)."
echo "4) Fill out arXiv metadata forms—strip LaTeX syntax from Title/Authors/Abstract (see guidance in original script)."
echo "5) Consult your advisor about the best subject‐area classification. Is 'cs.CR' the right spot, or is 'math.ST' more fitting? 🤔"
echo "6) After you set a submission password on arXiv, share it with coauthors so they can update or withdraw if needed."

echo -e "\n🎉 Good luck with your arXiv submission—now with conditional BibTeX! 🎉\n"
