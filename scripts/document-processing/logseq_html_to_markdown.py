import re
import argparse
from bs4 import BeautifulSoup
from datetime import datetime
import html

def extract_logseq_data(html_content):
    """Extract data from Logseq HTML and convert to Markdown"""
    soup = BeautifulSoup(html_content, 'html.parser')
    
    # Find the main query results container
    query_results = soup.find_all('div', class_='custom-query-page-result')
    
    markdown_output = []
    
    # Extract the page title if available
    page_title = soup.find('h1', class_='page-title')
    if page_title:
        markdown_output.append(f"# {page_title.get_text(strip=True)}\n")
    
    # Extract query information
    query_info = soup.find('div', class_='cp__query-builder-filter')
    if query_info:
        query_clauses = query_info.find_all('a', class_='query-clause')
        if query_clauses:
            markdown_output.append("## Query\n")
            markdown_output.append("Tags: " + ", ".join([clause.get_text(strip=True) for clause in query_clauses]) + "\n")
    
    # Process each query result page
    for i, result_page in enumerate(query_results):
        # Extract date/page reference
        page_ref = result_page.find('a', class_='page-ref')
        if page_ref:
            page_name = page_ref.get_text(strip=True)
            markdown_output.append(f"\n## {page_name}\n")
        
        # Extract all blocks within this page
        blocks = result_page.find_all('div', class_='ls-block')
        
        for block in blocks:
            markdown_output.append(process_block(block))
    
    return '\n'.join(markdown_output)

def process_block(block):
    """Process a single block and convert to Markdown"""
    output = []
    
    # Get block content
    block_content = block.find('div', class_='block-content-inner')
    if not block_content:
        return ""
    
    # Check if block has children (nested blocks)
    has_children = block.get('haschild') == 'true'
    
    # Extract priority if exists
    priority = block.find('a', class_='priority')
    priority_text = f"{priority.get_text(strip=True)} " if priority else ""
    
    # Extract main content
    content_parts = []
    
    # Process inline content
    for element in block_content.descendants:
        if element.name is None:  # Text node
            text = str(element).strip()
            if text:
                content_parts.append(text)
        elif element.name == 'b':
            content_parts.append(f"**{element.get_text(strip=True)}**")
        elif element.name == 'i':
            content_parts.append(f"*{element.get_text(strip=True)}*")
        elif element.name == 'a':
            if 'page-ref' in element.get('class', []):
                # Internal page reference
                ref_text = element.get_text(strip=True)
                content_parts.append(f"[[{ref_text}]]")
            elif 'tag' in element.get('class', []):
                tag_text = element.get_text(strip=True)
                content_parts.append(tag_text)
            elif 'external-link' in element.get('class', []):
                href = element.get('href', '')
                link_text = element.get_text(strip=True)
                content_parts.append(f"[{link_text}]({href})")
        elif element.name == 'br':
            content_parts.append('\n')
    
    # Clean up and join content
    content = ' '.join(content_parts)
    content = re.sub(r'\s+', ' ', content)
    content = content.replace(' \n ', '\n')
    
    # Add bullet point
    bullet = "- "
    
    # Combine everything
    if priority_text:
        output.append(f"{bullet}{priority_text}{content}")
    else:
        output.append(f"{bullet}{content}")
    
    # Process child blocks if any
    if has_children:
        children_container = block.find_next_sibling('div', class_='block-children-container')
        if children_container:
            child_blocks = children_container.find_all('div', class_='ls-block')
            for child in child_blocks:
                child_content = process_block(child)
                if child_content:
                    indented = '\n'.join(['  ' + line for line in child_content.split('\n')])
                    output.append(indented)
    
    return '\n'.join(output)

def extract_tags(block):
    """Extract all tags from a block"""
    tags = []
    tag_elements = block.find_all('a', class_='tag')
    for tag in tag_elements:
        tags.append(tag.get_text(strip=True))
    return tags

def clean_markdown(markdown_text):
    """Clean up the generated markdown"""
    # Remove multiple consecutive newlines
    markdown_text = re.sub(r'\n{3,}', '\n\n', markdown_text)
    
    # Fix spacing around bullet points
    markdown_text = re.sub(r'\n-\s+', '\n- ', markdown_text)
    
    # Remove trailing whitespace
    lines = markdown_text.split('\n')
    lines = [line.rstrip() for line in lines]
    
    return '\n'.join(lines)

def convert_logseq_html_to_markdown(html_file_path):
    """
    Convert Logseq HTML export to Markdown
    
    Args:
        html_file_path: Path to the HTML file
    
    Returns:
        Markdown formatted string
    """
    with open(html_file_path, 'r', encoding='utf-8') as file:
        html_content = file.read()
    
    markdown = extract_logseq_data(html_content)
    markdown = clean_markdown(markdown)
    
    return markdown


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Convert Logseq HTML export to Markdown format."
    )
    parser.add_argument(
        "input_html",
        help="Path to the Logseq HTML file to convert."
    )
    parser.add_argument(
        "-o", "--output",
        help="Optional path to save the generated Markdown file. If omitted, output is printed to stdout.",
        default=None
    )
    args = parser.parse_args()

    result_md = convert_logseq_html_to_markdown(args.input_html)
    if args.output:
        try:
            with open(args.output, 'w', encoding='utf-8') as out_f:
                out_f.write(result_md)
            print(f"Markdown successfully written to {args.output}")
        except IOError as e:
            print(f"Error writing to output file: {e}")
    else:
        print(result_md)
