#!/usr/bin/env python3
"""
Generic Telegram Bot Client

A reusable Telegram bot client for sending messages with robust error handling,
message formatting, and connection testing. Designed to be easily integrated
into any Python project.

Usage:
    from telegram_client import TelegramClient
    
    client = TelegramClient(bot_token="your_bot_token", chat_id="your_chat_id")
    
    # Test connection
    if client.test_connection():
        # Send simple message
        client.send_message("Hello, World!")
        
        # Send formatted message with HTML
        client.send_html_message("<b>Bold text</b> and <i>italic text</i>")
        
        # Send notification with icon
        client.send_notification("🚨", "Alert", "Something important happened!")
        
        # Send error notification
        client.send_error("Database Connection", "Failed to connect to database", 
                         additional_info="Connection timeout after 30 seconds")

Author: Generated with Claude Code
License: MIT
"""

import requests
import logging
import time
import re
from datetime import datetime
from typing import Optional, Tuple, Dict, Any


class TelegramClient:
    """Generic Telegram Bot Client with robust error handling and message formatting."""
    
    def __init__(self, bot_token: str, chat_id: str, default_parse_mode: str = "HTML"):
        """
        Initialize Telegram client.
        
        Args:
            bot_token: Telegram bot token from @BotFather
            chat_id: Target chat/user ID (can be string or integer)
            default_parse_mode: Default parse mode ('HTML', 'Markdown', or None)
        """
        self.bot_token = bot_token
        self.chat_id = str(chat_id)  # Ensure string for API compatibility
        self.api_url = f"https://api.telegram.org/bot{bot_token}"
        self.default_parse_mode = default_parse_mode
        
        # Configure logging if not already configured
        if not logging.getLogger().handlers:
            logging.basicConfig(level=logging.INFO)
    
    def _clean_message_text(self, message: str) -> str:
        """
        Clean message text to avoid Telegram parsing errors.
        
        Args:
            message: Raw message text
            
        Returns:
            Cleaned message text safe for Telegram API
        """
        if not message:
            return ""
        
        # Convert to string if not already
        message = str(message)
        
        # Remove null bytes and control characters that could cause parsing issues
        cleaned = re.sub(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]', '', message)
        
        # Replace problematic Unicode characters and encode safely
        cleaned = cleaned.encode('utf-8', errors='replace').decode('utf-8', errors='replace')
        
        # Remove replacement characters
        cleaned = cleaned.replace('\ufffd', '')
        
        # For HTML mode, escape problematic characters (but preserve intentional HTML)
        if self.default_parse_mode == "HTML":
            # Only escape < and > that aren't part of valid HTML tags
            cleaned = re.sub(r'<(?![/]?[bi]>|/?(strong|em|code|pre)>)', '&lt;', cleaned)
            cleaned = cleaned.replace('>', '&gt;').replace('&gt;', '>', 1)  # Fix legitimate tags
        
        # Clean up multiple spaces
        cleaned = re.sub(r'\s+', ' ', cleaned).strip()
        
        return cleaned
    
    def send_message(self, message: str, parse_mode: Optional[str] = None, 
                    max_retries: int = 3, disable_web_page_preview: bool = False) -> bool:
        """
        Send message to Telegram with retry logic.
        
        Args:
            message: Message text to send
            parse_mode: Parse mode ('HTML', 'Markdown', or None). Uses default if not specified.
            max_retries: Number of retry attempts on failure
            disable_web_page_preview: Whether to disable link previews
            
        Returns:
            True if message sent successfully, False otherwise
        """
        if not message:
            logging.warning("Attempted to send empty message")
            return False
            
        url = f"{self.api_url}/sendMessage"
        
        # Use provided parse_mode or fall back to default
        if parse_mode is None:
            parse_mode = self.default_parse_mode
        
        # Clean and truncate message to Telegram's limit
        clean_message = self._clean_message_text(message)[:4096]
        
        payload = {
            'chat_id': self.chat_id,
            'text': clean_message,
            'disable_web_page_preview': disable_web_page_preview
        }
        
        # Only add parse_mode if specified
        if parse_mode:
            payload['parse_mode'] = parse_mode
        
        for attempt in range(max_retries):
            try:
                response = requests.post(url, data=payload, timeout=10)
                
                # Handle specific error codes
                if response.status_code == 404:
                    logging.error("Bot token is invalid (404 error)")
                    return False
                elif response.status_code == 403:
                    logging.error("Bot was blocked by user or chat_id is invalid (403 error)")
                    return False
                elif response.status_code == 400:
                    logging.error(f"Bad request (400 error): {response.text}")
                    # Try again without parse_mode if it was the issue
                    if parse_mode and attempt < max_retries - 1:
                        logging.info("Retrying without parse_mode...")
                        return self.send_message(message, parse_mode=None, max_retries=max_retries-attempt-1)
                    return False
                
                response.raise_for_status()
                
                result = response.json()
                if result.get('ok'):
                    logging.debug("Telegram message sent successfully")
                    return True
                else:
                    logging.error(f"Telegram API error: {result}")
                    return False
                    
            except requests.RequestException as e:
                logging.warning(f"Telegram send attempt {attempt + 1} failed: {e}")
                if attempt < max_retries - 1:
                    time.sleep(2 ** attempt)  # Exponential backoff
                else:
                    logging.error(f"Failed to send Telegram message after {max_retries} attempts")
                    return False
        
        return False
    
    def send_html_message(self, message: str, **kwargs) -> bool:
        """
        Send message with HTML formatting.
        
        Args:
            message: Message with HTML formatting
            **kwargs: Additional arguments passed to send_message()
            
        Returns:
            True if message sent successfully, False otherwise
        """
        return self.send_message(message, parse_mode="HTML", **kwargs)
    
    def send_markdown_message(self, message: str, **kwargs) -> bool:
        """
        Send message with Markdown formatting.
        
        Args:
            message: Message with Markdown formatting
            **kwargs: Additional arguments passed to send_message()
            
        Returns:
            True if message sent successfully, False otherwise
        """
        return self.send_message(message, parse_mode="Markdown", **kwargs)
    
    def send_plain_message(self, message: str, **kwargs) -> bool:
        """
        Send plain text message without formatting.
        
        Args:
            message: Plain text message
            **kwargs: Additional arguments passed to send_message()
            
        Returns:
            True if message sent successfully, False otherwise
        """
        return self.send_message(message, parse_mode=None, **kwargs)
    
    def send_notification(self, icon: str, title: str, body: str, 
                         timestamp: bool = True, **kwargs) -> bool:
        """
        Send a formatted notification message.
        
        Args:
            icon: Emoji icon for the notification
            title: Notification title
            body: Notification body text
            timestamp: Whether to include timestamp
            **kwargs: Additional arguments passed to send_message()
            
        Returns:
            True if message sent successfully, False otherwise
        """
        message_parts = [f"{icon} {title}"]
        
        if timestamp:
            current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            message_parts.append(f"Time: {current_time}")
        
        message_parts.append(body)
        
        message = "\n\n".join(message_parts)
        return self.send_message(message, **kwargs)
    
    def send_error(self, error_type: str, error_message: str, 
                  additional_info: Optional[str] = None, **kwargs) -> bool:
        """
        Send a formatted error notification.
        
        Args:
            error_type: Type/category of error
            error_message: Error description
            additional_info: Optional additional information
            **kwargs: Additional arguments passed to send_message()
            
        Returns:
            True if message sent successfully, False otherwise
        """
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        message = f"""🚨 Error Alert

Type: {error_type}
Time: {timestamp}

Error: {error_message}"""
        
        if additional_info:
            clean_info = self._clean_message_text(str(additional_info))
            message += f"\n\nAdditional Info: {clean_info}"
        
        return self.send_message(message, parse_mode=None, **kwargs)
    
    def send_success(self, title: str, message: str, **kwargs) -> bool:
        """
        Send a formatted success notification.
        
        Args:
            title: Success title
            message: Success message
            **kwargs: Additional arguments passed to send_message()
            
        Returns:
            True if message sent successfully, False otherwise
        """
        return self.send_notification("✅", title, message, **kwargs)
    
    def send_warning(self, title: str, message: str, **kwargs) -> bool:
        """
        Send a formatted warning notification.
        
        Args:
            title: Warning title
            message: Warning message
            **kwargs: Additional arguments passed to send_message()
            
        Returns:
            True if message sent successfully, False otherwise
        """
        return self.send_notification("⚠️", title, message, **kwargs)
    
    def send_info(self, title: str, message: str, **kwargs) -> bool:
        """
        Send a formatted informational notification.
        
        Args:
            title: Info title
            message: Info message
            **kwargs: Additional arguments passed to send_message()
            
        Returns:
            True if message sent successfully, False otherwise
        """
        return self.send_notification("ℹ️", title, message, **kwargs)
    
    def test_connection(self) -> Tuple[bool, Dict[str, Any]]:
        """
        Test Telegram bot connection and get bot information.
        
        Returns:
            Tuple of (success: bool, info: dict) where info contains bot details or error message
        """
        try:
            url = f"{self.api_url}/getMe"
            response = requests.get(url, timeout=10)
            
            if response.status_code == 404:
                error_msg = "Bot token is invalid. Please check your bot token."
                logging.error(error_msg)
                return False, {"error": error_msg}
            elif response.status_code == 403:
                error_msg = "Bot token unauthorized. Please check your bot token."
                logging.error(error_msg)
                return False, {"error": error_msg}
            
            response.raise_for_status()
            
            result = response.json()
            if result.get('ok'):
                bot_info = result.get('result', {})
                logging.info(f"Telegram bot connected: {bot_info.get('username', 'Unknown')}")
                return True, bot_info
            else:
                logging.error(f"Telegram bot test failed: {result}")
                return False, {"error": result}
                
        except requests.RequestException as e:
            error_msg = f"Connection test failed: {str(e)}"
            logging.error(error_msg)
            return False, {"error": error_msg}
    
    def get_chat_info(self) -> Tuple[bool, Dict[str, Any]]:
        """
        Get information about the target chat.
        
        Returns:
            Tuple of (success: bool, info: dict) where info contains chat details or error message
        """
        try:
            url = f"{self.api_url}/getChat"
            response = requests.get(url, params={'chat_id': self.chat_id}, timeout=10)
            response.raise_for_status()
            
            result = response.json()
            if result.get('ok'):
                chat_info = result.get('result', {})
                return True, chat_info
            else:
                return False, {"error": result}
                
        except requests.RequestException as e:
            return False, {"error": str(e)}


# Example usage and testing
if __name__ == "__main__":
    import os
    
    # Example configuration - replace with your actual values
    BOT_TOKEN = os.getenv('TELEGRAM_BOT_TOKEN', 'your_bot_token_here')
    CHAT_ID = os.getenv('TELEGRAM_CHAT_ID', 'your_chat_id_here')
    
    if BOT_TOKEN == 'your_bot_token_here' or CHAT_ID == 'your_chat_id_here':
        print("Please set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID environment variables")
        print("or modify the BOT_TOKEN and CHAT_ID variables in this script")
        exit(1)
    
    # Initialize client
    client = TelegramClient(BOT_TOKEN, CHAT_ID)
    
    # Test connection
    success, info = client.test_connection()
    if success:
        print(f"✅ Connected to bot: @{info.get('username')}")
        
        # Send various types of messages
        client.send_message("Hello from TelegramClient!")
        client.send_html_message("<b>Bold</b> and <i>italic</i> text")
        client.send_success("Test Success", "All systems operational")
        client.send_warning("Test Warning", "This is a warning message")
        client.send_error("Test Error", "This is an error message", "Additional debug info")
        
        print("✅ Test messages sent successfully!")
    else:
        print(f"❌ Connection failed: {info}")