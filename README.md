# 🛠️ Useful Scripts

Welcome to **Useful-Scripts** — a growing collection of handy command-line tools for daily tasks, file searching, automation, and more. Each script is designed to solve a specific problem, save time, or simplify your workflow.

Feel free to contribute or customize them to suit your setup.

---

## 📂 How to Use

All scripts are Bash-based. To use any script:

1. Clone this repository or copy the script you need.
2. Make it executable:
   ```bash
   chmod +x find_date_variants.sh
   ```

(or simply run `bash find_date_variants.sh`)

3. Run it with the appropriate arguments (see below for examples).

## 📌 Scripts

### 🔍 `find_date_variants.sh`

Searches for files with names that include common variations of a specific date.

#### ✅ Features:

- Accepts `YYYY-MM-DD` or `YYYYMMDD` format
- Matches different date formats (e.g., `16-11-2021`, `Nov16_2021`, etc.)
- Optionally specify the search path, or defaults to the script’s directory

#### 📦 Usage:

```bash
./find_date_variants.sh 2021-11-16
./find_date_variants.sh /mnt/user/ 2021-11-16
./find_date_variants.sh 20211116
```

------

## 🧩 More Coming Soon

New scripts will be added regularly for:

- File organization
- Backup and sync tasks
- Data processing and cleanup
- Automation of tedious CLI tasks

------

## 🤝 Contributing

Have a useful script? PRs are welcome!

------

## 🧠 License

MIT — do whatever you want, but attribution is appreciated.