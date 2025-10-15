#!/usr/bin/env python3
"""
List element mappers: ordered and unordered lists.

This module handles conversion of HTML list elements to DOCX with:
- Support for nested lists
- Comprehensive error handling
- Fallback behaviors for missing styles
- Input validation
"""

import sys
from typing import Dict, Any

from bs4 import Tag
from docx import Document
from docx.shared import Pt


def add_list(
    doc: Document,
    style_config: Dict[str, Any],
    element: Tag
) -> None:
    """
    Add list to document (ordered or unordered).

    Args:
        doc: python-docx Document
        style_config: Style configuration dictionary
        element: HTML ul or ol element

    Raises:
        TypeError: If arguments have wrong type
        ValueError: If element is not a valid list
    """
    # Validate inputs
    if not isinstance(doc, Document):
        raise TypeError(f"doc must be Document, got {type(doc)}")

    if not isinstance(element, Tag):
        raise TypeError(f"element must be Tag, got {type(element)}")

    tag_name = element.name.lower() if element.name else None

    if tag_name not in ("ul", "ol"):
        raise ValueError(f"Invalid list tag: {tag_name}, expected 'ul' or 'ol'")

    # Determine style based on list type
    try:
        if tag_name == "ul":
            style_name = style_config.get("styles", {}).get("bullet_list", "List Bullet")
        else:
            style_name = style_config.get("styles", {}).get("number_list", "List Number")
    except Exception as e:
        print(f"WARNING: Error getting list style: {e}", file=sys.stderr)
        style_name = "List Bullet" if tag_name == "ul" else "List Number"

    # Process each list item
    try:
        list_items = element.find_all("li", recursive=False)
    except Exception as e:
        print(f"WARNING: Error finding list items: {e}", file=sys.stderr)
        return

    if not list_items:
        return  # No items to process

    for item in list_items:
        try:
            _add_list_item(doc, style_config, item, style_name, tag_name)
        except Exception as e:
            print(f"WARNING: Error processing list item: {e}", file=sys.stderr)


def _add_list_item(
    doc: Document,
    style_config: Dict[str, Any],
    item: Tag,
    style_name: str,
    list_type: str
) -> None:
    """
    Add individual list item to document.

    Args:
        doc: python-docx Document
        style_config: Style configuration dictionary
        item: HTML li element
        style_name: Style to apply
        list_type: 'ul' or 'ol'
    """
    # Check for nested lists
    try:
        nested_lists = item.find_all(["ul", "ol"], recursive=False)
    except Exception as e:
        print(f"WARNING: Error finding nested lists: {e}", file=sys.stderr)
        nested_lists = []

    # Get text content excluding nested lists
    text_parts = []
    try:
        for child in item.children:
            if hasattr(child, "name") and child.name in ("ul", "ol"):
                continue  # Skip nested lists
            text_parts.append(str(child))
    except Exception as e:
        print(f"WARNING: Error extracting list item text: {e}", file=sys.stderr)

    text = "".join(text_parts).strip()

    if text:
        try:
            doc.add_paragraph(text, style=style_name)
        except KeyError:
            # Fallback if style not found
            print(f"WARNING: Style '{style_name}' not found, using fallback", file=sys.stderr)
            para = doc.add_paragraph(text)

            # Add bullet or number manually
            try:
                if list_type == "ul":
                    para.style = "Normal"
                    # Add bullet character
                    if para.runs:
                        para.runs[0].text = f"• {text}"
                else:
                    para.style = "Normal"
                    # Numbered list (simple sequential)
            except Exception as e:
                print(f"WARNING: Error applying fallback style: {e}", file=sys.stderr)
        except Exception as e:
            print(f"WARNING: Error adding list item paragraph: {e}", file=sys.stderr)

    # Process nested lists recursively
    for nested_list in nested_lists:
        try:
            add_list(doc, style_config, nested_list)
        except Exception as e:
            print(f"WARNING: Error processing nested list: {e}", file=sys.stderr)


def add_definition_list(
    doc: Document,
    style_config: Dict[str, Any],
    element: Tag
) -> None:
    """
    Add definition list to document (dl/dt/dd).

    Args:
        doc: python-docx Document
        style_config: Style configuration dictionary
        element: HTML dl element

    Raises:
        TypeError: If arguments have wrong type
        ValueError: If element is not a dl tag
    """
    # Validate inputs
    if not isinstance(doc, Document):
        raise TypeError(f"doc must be Document, got {type(doc)}")

    if not isinstance(element, Tag):
        raise TypeError(f"element must be Tag, got {type(element)}")

    if element.name.lower() != "dl":
        raise ValueError(f"Element must be a dl tag, got {element.name}")

    # Process definition terms and descriptions
    try:
        for child in element.children:
            if not hasattr(child, "name"):
                continue

            tag_name = child.name.lower()

            if tag_name == "dt":
                # Definition term - use bold
                text = child.get_text(strip=True)
                if text:
                    try:
                        para = doc.add_paragraph()
                        run = para.add_run(text)
                        run.bold = True
                    except Exception as e:
                        print(f"WARNING: Error adding definition term: {e}", file=sys.stderr)

            elif tag_name == "dd":
                # Definition description - use indented paragraph
                text = child.get_text(strip=True)
                if text:
                    try:
                        para = doc.add_paragraph(text)
                        para.paragraph_format.left_indent = Pt(36)
                    except Exception as e:
                        print(f"WARNING: Error adding definition description: {e}", file=sys.stderr)
    except Exception as e:
        print(f"WARNING: Error processing definition list: {e}", file=sys.stderr)