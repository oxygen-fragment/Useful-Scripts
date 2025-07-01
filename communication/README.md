# TelegramClient - Reusable Telegram Bot Client

A generic, robust Telegram bot client extracted from the XXL Bike Monitor project. Designed for easy integration into any Python project.

## Features

- ✅ **Robust error handling** with retry logic and exponential backoff
- ✅ **Message cleaning** to prevent Telegram API parsing errors
- ✅ **Multiple message formats** (HTML, Markdown, plain text)
- ✅ **Pre-built notification templates** (success, warning, error, info)
- ✅ **Connection testing** and bot information retrieval
- ✅ **Type hints** for better IDE support
- ✅ **Comprehensive logging**

## Quick Start

### 1. Copy the file
```bash
cp telegram_client.py /path/to/your/project/
```

### 2. Install dependencies
```bash
pip install requests
```

### 3. Basic usage
```python
from telegram_client import TelegramClient

# Initialize
client = TelegramClient(
    bot_token="your_bot_token_from_botfather",
    chat_id="your_chat_id"
)

# Test connection
if client.test_connection()[0]:
    # Send messages
    client.send_message("Hello, World!")
    client.send_html_message("<b>Bold text</b>")
    client.send_success("Task Complete", "All systems operational")
    client.send_error("Database Error", "Connection failed")
```

## API Reference

### Core Methods

#### `send_message(message, parse_mode=None, max_retries=3, disable_web_page_preview=False)`
Send a basic message with retry logic.

#### `send_html_message(message, **kwargs)`
Send message with HTML formatting.

#### `send_markdown_message(message, **kwargs)`
Send message with Markdown formatting.

#### `send_plain_message(message, **kwargs)`
Send plain text message without formatting.

### Notification Templates

#### `send_notification(icon, title, body, timestamp=True)`
Send formatted notification with icon and optional timestamp.

#### `send_success(title, message)`
Send success notification with ✅ icon.

#### `send_warning(title, message)`
Send warning notification with ⚠️ icon.

#### `send_error(error_type, error_message, additional_info=None)`
Send error notification with 🚨 icon and detailed formatting.

#### `send_info(title, message)`
Send info notification with ℹ️ icon.

### Utility Methods

#### `test_connection()`
Test bot connection and return bot information.

#### `get_chat_info()`
Get information about the target chat.

## Configuration

### Environment Variables (Recommended)
```bash
export TELEGRAM_BOT_TOKEN="your_bot_token"
export TELEGRAM_CHAT_ID="your_chat_id"
```

### Code Configuration
```python
client = TelegramClient(
    bot_token="1234567890:ABCdefGHIjklMNOpqrstUVwxyz",
    chat_id="123456789",
    default_parse_mode="HTML"  # or "Markdown" or None
)
```

## Error Handling

The client includes comprehensive error handling:

- **Automatic retries** with exponential backoff
- **Message cleaning** to prevent API parsing errors  
- **Specific error codes** (404, 403, 400) handled appropriately
- **Fallback mode** - retries without parse_mode if formatting fails
- **Message length limiting** (4096 character Telegram limit)

## Integration Examples

### Monitoring Script
```python
from telegram_client import TelegramClient
import time

client = TelegramClient(bot_token, chat_id)

def monitor_service():
    try:
        # Your monitoring logic here
        if service_is_healthy():
            client.send_success("Service Health", "All systems operational")
        else:
            client.send_warning("Service Alert", "Service degraded performance")
    except Exception as e:
        client.send_error("Monitor Error", str(e))

# Run monitoring
while True:
    monitor_service()
    time.sleep(300)  # Check every 5 minutes
```

### Web Application Integration
```python
from telegram_client import TelegramClient
from flask import Flask

app = Flask(__name__)
client = TelegramClient(bot_token, chat_id)

@app.route('/api/alert', methods=['POST'])
def send_alert():
    data = request.get_json()
    client.send_notification(
        icon="🚨",
        title=data['title'],
        body=data['message']
    )
    return {"success": True}
```

### Backup Script Notifications
```python
from telegram_client import TelegramClient
import subprocess

client = TelegramClient(bot_token, chat_id)

def run_backup():
    try:
        result = subprocess.run(['backup_script.sh'], check=True, capture_output=True)
        client.send_success(
            "Backup Complete",
            f"Database backup successful\\nSize: {get_backup_size()}"
        )
    except subprocess.CalledProcessError as e:
        client.send_error(
            "Backup Failed",
            "Database backup script failed",
            additional_info=e.stderr.decode()
        )
```

## Getting Bot Token and Chat ID

### Bot Token
1. Message @BotFather on Telegram
2. Send `/newbot`
3. Follow prompts to create your bot
4. Copy the token provided

### Chat ID
**For personal messages:**
1. Message @userinfobot on Telegram
2. Your chat ID will be displayed

**For group chats:**
1. Add your bot to the group
2. Send a message mentioning the bot
3. Visit: `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates`
4. Look for the `chat.id` in the response

## Dependencies

- `requests` - HTTP library for API calls
- `logging` - Built-in Python logging (optional but recommended)

## License

MIT License - Feel free to use in any project!