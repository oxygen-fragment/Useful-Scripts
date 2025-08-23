# Document Processing Scripts

Scripts for academic writing, document preparation, and publication workflows.

## prepare_arxiv.sh

### 📝 Description
Automates LaTeX paper preparation for arXiv submission. Handles compilation, bibliography processing, figure flattening, and creates submission-ready tarball.

### 🎯 Use Cases
- Preparing academic papers for arXiv submission
- Cleaning LaTeX projects for publication
- Automating paper compilation workflows
- Standardizing submission packages

### 🔧 Requirements
**Platform:** Linux/macOS
**Dependencies:** 
- pdflatex, bibtex (TeX Live distribution)
- Standard Unix tools (cp, sed, tar, find)
**Permissions:** Regular user

### 📦 Usage
```bash
# Make executable
chmod +x prepare_arxiv.sh

# Basic usage
./prepare_arxiv.sh /path/to/paper_directory main.tex

# Example
./prepare_arxiv.sh /home/user/my_paper paper.tex
```

### ⚙️ Features
- **Smart bibliography**: Skips BibTeX if no .bib file present
- **Appendix merging**: Automatically merges appendix.tex if found
- **Figure flattening**: Moves figures from subdirs to root, updates references
- **Style cleanup**: Removes "Submitted to..." placeholders
- **Comment stripping**: Removes LaTeX comments for cleaner submission
- **Multi-pass compilation**: Ensures references resolve correctly

### 🔒 Safety Notes
- Works in temporary directory (tmp_arxiv) - original files untouched
- Creates backup of original structure
- Validates inputs before processing
- Preserves original paper directory

### 🐛 Troubleshooting
**Compilation errors:**
- Symptom: pdflatex fails
- Solution: Check logs in tmp_arxiv/ directory, fix LaTeX errors in original

**Missing figures:**
- Symptom: Figure references broken after processing
- Solution: Check figure file extensions match script's supported formats

**BibTeX issues:**
- Symptom: Bibliography not appearing
- Solution: Ensure .bib file has same name as main .tex file

## logseq_html_to_markdown.py
### On Linux
1. Open Logseq 
2. Press `CTRL` + `SHIFT` + `i` (opens 'inspect' window)
3. Copy HTML elements
4. save as `{whatever_you_want}.html`

then:

```python
python logseq_html_to_markdown path/to/input.html -o path/to/output.md
```

### NOTE:
- **Tested on the entire `<body>`** (i.e. hover mouse over `<body>` element -> right click -> `Copy` -> `Copy element` -> save as HTML file)
- **I'm sure it won't be perfect for all use-cases** and you're welcome to contact me or create an issue.

---
*Last updated: 2024-12-30*
*Tested on: Ubuntu 20.04+, macOS with MacTeX*