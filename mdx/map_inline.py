#!/usr/bin/env python3
"""
Inline element mappers: images, strong, emphasis, code, links.

This module handles conversion of inline HTML elements to DOCX with:
- Image path resolution with multiple fallback strategies
- Inline formatting (bold, italic, code, links)
- Comprehensive error handling
- Graceful degradation
"""

import sys
import os
from pathlib import Path
from typing import Dict, Any, Optional

from bs4 import Tag
from docx import Document
from docx.shared import Inches, Pt


def add_image(
    doc: Document,
    style_config: Dict[str, Any],
    element: Tag
) -> None:
    """
    Add image to document.

    Args:
        doc: python-docx Document
        style_config: Style configuration dictionary
        element: HTML img element

    Raises:
        TypeError: If arguments have wrong type
        ValueError: If element is not an img tag
    """
    # Validate inputs
    if not isinstance(doc, Document):
        raise TypeError(f"doc must be Document, got {type(doc)}")

    if not isinstance(element, Tag):
        raise TypeError(f"element must be Tag, got {type(element)}")

    if element.name.lower() != "img":
        raise ValueError(f"Element must be an img tag, got {element.name}")

    # Get image source
    src = element.get("src")

    if not src:
        return  # No source attribute

    # Get default image width from config
    try:
        images_config = style_config.get("images", {})
        default_width = images_config.get("default_width_inches", 5.5)
    except Exception as e:
        print(f"WARNING: Error getting image config: {e}", file=sys.stderr)
        default_width = 5.5

    # Resolve image path
    try:
        image_path = _resolve_image_path(src)
    except Exception as e:
        print(f"WARNING: Error resolving image path: {e}", file=sys.stderr)
        image_path = None

    if not image_path:
        # Add placeholder text if image not found
        try:
            style_name = style_config.get("styles", {}).get("paragraph", "Normal")
            para = doc.add_paragraph(f"[Image not found: {src}]", style=style_name)

            if para.runs:
                para.runs[0].font.italic = True
        except Exception as e:
            print(f"WARNING: Error adding image placeholder: {e}", file=sys.stderr)
        return

    # Add image with specified width
    try:
        doc.add_picture(str(image_path), width=Inches(default_width))
    except Exception as e:
        # Fallback to error message
        print(f"WARNING: Failed to add image {src}: {e}", file=sys.stderr)

        try:
            style_name = style_config.get("styles", {}).get("paragraph", "Normal")
            para = doc.add_paragraph(f"[Image error: {src}]", style=style_name)

            if para.runs:
                para.runs[0].font.italic = True
        except Exception:
            pass  # Ignore cascading errors


def _resolve_image_path(src: str) -> Optional[Path]:
    """
    Resolve image path relative to various base directories.

    Strategy:
    1. Try as absolute path
    2. Try as relative path from current directory
    3. Try relative to DOCX_IMG_DIR environment variable
    4. Try relative to DOCX_SRC_DIR environment variable

    Args:
        src: Image source path from HTML

    Returns:
        Resolved Path object if file exists, None otherwise
    """
    # Try as absolute path
    if os.path.isabs(src):
        path = Path(src)
        if path.exists() and path.is_file():
            return path

    # Try as relative path from current directory
    path = Path(src)
    if path.exists() and path.is_file():
        return path

    # Try relative to docs/images
    try:
        docs_images = Path(os.environ.get("DOCX_IMG_DIR", "docs/images"))
        path = docs_images / src
        if path.exists() and path.is_file():
            return path
    except Exception:
        pass

    # Try relative to docs
    try:
        docs_dir = Path(os.environ.get("DOCX_SRC_DIR", "docs"))
        path = docs_dir / src
        if path.exists() and path.is_file():
            return path
    except Exception:
        pass

    return None


def add_inline(
    doc: Document,
    style_config: Dict[str, Any],
    element: Tag
) -> None:
    """
    Add inline formatted element to document.

    Handles: strong, b, em, i, code, a, span

    Args:
        doc: python-docx Document
        style_config: Style configuration dictionary
        element: HTML inline element

    Raises:
        TypeError: If arguments have wrong type
    """
    # Validate inputs
    if not isinstance(doc, Document):
        raise TypeError(f"doc must be Document, got {type(doc)}")

    if not isinstance(element, Tag):
        raise TypeError(f"element must be Tag, got {type(element)}")

    tag_name = element.name.lower() if element.name else None
    text = element.get_text(strip=True)

    if not text:
        return  # Skip empty elements

    # Get parent paragraph or create new one
    try:
        style_name = style_config.get("styles", {}).get("paragraph", "Normal")
        para = doc.add_paragraph(style=style_name)
    except Exception as e:
        print(f"WARNING: Error creating paragraph: {e}", file=sys.stderr)
        try:
            para = doc.add_paragraph()
        except Exception:
            return  # Cannot create paragraph

    # Add run with appropriate formatting
    try:
        run = para.add_run(text)

        if tag_name in ("strong", "b"):
            run.font.bold = True

        elif tag_name in ("em", "i"):
            run.font.italic = True

        elif tag_name == "code":
            # Inline code formatting
            try:
                run.font.name = "Courier New"
                run.font.size = Pt(9)

                # Try to apply inline code style
                style_name = style_config.get("styles", {}).get("inline_code", "Intense Emphasis")
                try:
                    para.style = style_name
                except KeyError:
                    pass  # Style not found, keep default
            except Exception as e:
                print(f"WARNING: Error applying code formatting: {e}", file=sys.stderr)

        elif tag_name == "a":
            # Links - add URL in parentheses
            href = element.get("href")
            if href:
                run.text = f"{text} ({href})"

            try:
                run.font.color.rgb = None  # Use theme color
                run.font.underline = True
            except Exception as e:
                print(f"WARNING: Error applying link formatting: {e}", file=sys.stderr)

    except Exception as e:
        print(f"WARNING: Error adding inline element: {e}", file=sys.stderr)


def add_formatted_text(
    doc: Document,
    style_config: Dict[str, Any],
    text: str,
    bold: bool = False,
    italic: bool = False,
    underline: bool = False,
    font_size: Optional[int] = None
) -> None:
    """
    Add formatted text to document.

    This is a convenience function for programmatically adding formatted text.

    Args:
        doc: python-docx Document
        style_config: Style configuration dictionary
        text: Text content
        bold: Apply bold formatting
        italic: Apply italic formatting
        underline: Apply underline formatting
        font_size: Font size in points

    Raises:
        TypeError: If arguments have wrong type
    """
    # Validate inputs
    if not isinstance(doc, Document):
        raise TypeError(f"doc must be Document, got {type(doc)}")

    if not isinstance(text, str):
        raise TypeError(f"text must be str, got {type(text)}")

    if not text.strip():
        return  # Skip empty text

    try:
        style_name = style_config.get("styles", {}).get("paragraph", "Normal")
        para = doc.add_paragraph(style=style_name)
        run = para.add_run(text)

        if bold:
            run.font.bold = True

        if italic:
            run.font.italic = True

        if underline:
            run.font.underline = True

        if font_size:
            run.font.size = Pt(font_size)

    except Exception as e:
        print(f"WARNING: Error adding formatted text: {e}", file=sys.stderr)