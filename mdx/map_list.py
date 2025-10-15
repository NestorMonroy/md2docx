#!/usr/bin/env python3
"""
List element mappers: ordered and unordered lists.

This module handles conversion of HTML list elements to DOCX.
"""

from typing import Dict, Any
from bs4 import Tag
from docx import Document


def add_list(doc: Document, style_config: Dict[str, Any], element: Tag) -> None:
    """
    Add list to document (ordered or unordered).

    Args:
        doc: python-docx Document
        style_config: Style configuration dictionary
        element: HTML ul or ol element
    """
    if not isinstance(element, Tag):
        raise TypeError("Element must be a Tag")

    tag_name = element.name.lower()

    if tag_name not in ("ul", "ol"):
        raise ValueError(f"Invalid list tag: {tag_name}")

    # Determine style based on list type
    if tag_name == "ul":
        style_name = style_config.get("styles", {}).get("bullet_list", "List Bullet")
    else:
        style_name = style_config.get("styles", {}).get("number_list", "List Number")

    # Process each list item
    list_items = element.find_all("li", recursive=False)

    if not list_items:
        return

    for item in list_items:
        _add_list_item(doc, style_config, item, style_name, tag_name)


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
    nested_lists = item.find_all(["ul", "ol"], recursive=False)

    # Get text content excluding nested lists
    text_parts = []
    for child in item.children:
        if hasattr(child, "name") and child.name in ("ul", "ol"):
            continue
        text_parts.append(str(child))

    text = "".join(text_parts).strip()

    if text:
        try:
            doc.add_paragraph(text, style=style_name)
        except KeyError:
            # Fallback if style not found
            para = doc.add_paragraph(text)
            if list_type == "ul":
                # Add bullet manually
                para.style = "Normal"
                para.text = f"• {text}"
            else:
                # Add number manually (simple sequential)
                para.style = "Normal"

    # Process nested lists recursively
    for nested_list in nested_lists:
        add_list(doc, style_config, nested_list)


def add_definition_list(doc: Document, style_config: Dict[str, Any], element: Tag) -> None:
    """
    Add definition list to document (dl/dt/dd).

    Args:
        doc: python-docx Document
        style_config: Style configuration dictionary
        element: HTML dl element
    """
    if not isinstance(element, Tag):
        raise TypeError("Element must be a Tag")

    if element.name.lower() != "dl":
        raise ValueError("Element must be a dl tag")

    # Process definition terms and descriptions
    for child in element.children:
        if not hasattr(child, "name"):
            continue

        tag_name = child.name.lower()

        if tag_name == "dt":
            # Definition term - use bold
            text = child.get_text(strip=True)
            if text:
                para = doc.add_paragraph()
                run = para.add_run(text)
                run.bold = True

        elif tag_name == "dd":
            # Definition description - use indented paragraph
            text = child.get_text(strip=True)
            if text:
                para = doc.add_paragraph(text)
                from docx.shared import Pt
                para.paragraph_format.left_indent = Pt(36)