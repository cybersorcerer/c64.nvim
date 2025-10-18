import sys
import re
import json
import argparse

def parse_markdown_sections(file_path):
    """
    Parses a markdown file and splits it into sections based on headers.
    Each section consists of a header line and the content that follows.
    """
    sections = []
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            current_title = None
            content_buffer = []

            for line in f:
                if line.strip().startswith('#'):
                    if current_title:
                        sections.append({
                            "title": current_title,
                            "content": "".join(content_buffer).strip()
                        })
                    
                    current_title = line.strip()
                    content_buffer = []
                elif current_title:
                    content_buffer.append(line)
            
            if current_title:
                sections.append({
                    "title": current_title,
                    "content": "".join(content_buffer).strip()
                })

    except FileNotFoundError:
        print(f"Error: File not found at {file_path}", file=sys.stderr)
        return []
        
    return sections

def search_sections(sections, search_term):
    """
    Searches for a term in the titles of the sections.
    Returns a list of matching sections.
    """
    search_term_lower = search_term.lower()
    return [
        section for section in sections 
        if search_term_lower in section['title'].lower().lstrip('#').strip()
    ]

def main():
    """
    Main function to parse arguments and run the search.
    """
    parser = argparse.ArgumentParser(description="Search for sections in a markdown file.")
    parser.add_argument("search_term", help="The term to search for in section titles.")
    parser.add_argument("--json", action="store_true", help="Output results in JSON format.")
    args = parser.parse_args()
    
    file_path = '/Users/Ronald.Funk/My_Documents/source/gitlab/kickass.nvim/c64ref/c64ref.md'
    
    sections = parse_markdown_sections(file_path)
    
    if not sections:
        print("No sections found or file could not be read.", file=sys.stderr)
        sys.exit(1)
        
    results = search_sections(sections, args.search_term)
    
    if args.json:
        for result in results:
            print(json.dumps(result))
    else:
        if not results:
            print(f"No sections found matching '{args.search_term}'.")
        else:
            print(f"Found {len(results)} matching section(s) for '{args.search_term}':\n")
            for section in results:
                print("="*80)
                print(section['title'])
                print("="*80)
                print(section['content'])
                print("\n")

if __name__ == "__main__":
    main()
