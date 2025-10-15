#!/usr/bin/env python3
"""
Inline element mappers: images, strong, emphasis, code, links.

This module handles conversion of inline HTML elements to DOCX.
"""

import os
from pathlib import Path
from typing import Dict, Any
from bs4 import Tag
from docx import Document
from docx.shared import Inches, Pt


def add_image(doc: Document, style_config: Dict[str, Any], element: Tag) -> None:
    """
    Add image to document.

    Args:
        doc: python-docx Document
        style_config: Style configuration dictionary
        element: HTML img element
    """
    if not isinstance(element, Tag):
        raise TypeError("Element must be a Tag")

    if element.name.lower() != "img":
        raise ValueError("Element must be an img tag")

    src = element.get("src")

    if not src:
        return

    # Get default image width from config
    images_config = style_config.get("images", {})
    default_width = images_config.get("default_width_inches", 5.5)

    # Resolve image path
    image_path = _resolve_image_path(src)

    if not image_path:
        # Add placeholder text if image not found
        style_name = style_config.get("styles", {}).get("paragraph", "Normal")
        para = doc.add_paragraph(f"[Image not found: {src}]", style=style_name)
        run = para.runs[0] if para.runs else None
        if run:
            run.font.italic = True
        return

    try:
        # Add image with specified width
        doc.add_picture(str(image_path), width=Inches(default_width))
    except Exception as e:
        # Fallback to error message
        import sys
        print(f"WARNING: Failed to add image {src}: {e}", file=sys.stderr)
        style_name = style_config.get("styles", {}).get("paragraph", "Normal")
        para = doc.add_paragraph(f"[Image error: {src}]", style=style_name)
        run = para.runs[0] if para.runs else None
        if run:
            run.font.italic = True


def _resolve_image_path(src: str) -> Path:
    """
    Resolve image path relative to various base directories.

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


def add_inline(doc: Document, style_config: Dict[str, Any], element: Tag) -> None:
    """
    Add inline formatted element to document.

    Handles: strong, b, em, i, code, a, span

    Args:
        doc: python-docx Document
        style_config: Style configuration dictionary
        element: HTML inline element
    """
    if not isinstance(element, Tag):
        raise TypeError("Element must be a Tag")

    tag_name = element.name.lower()
    text = element.get_text(strip=True)

    if not text:
        return

    # Get parent paragraph or create new one
    style_name = style_config.get("styles", {}).get("paragraph", "Normal")
    para = doc.add_paragraph(style=style_name)

    # Add run with appropriate formatting
    run = para.add_run(text)

    if tag_name in ("strong", "b"):
        run.font.bold = True

    elif tag_name in ("em", "i"):
        run.font.italic = True

    elif tag_name == "code":
        # Inline code formatting
        run.font.name = "Courier New"
        run.font.size = Pt(9)
        style_name = style_config.get("styles", {}).get("inline_code", "Intense Emphasis")
        try:
            para.style = style_name
        except KeyError:
            pass

    elif tag_name == "a":
        # Links - add URL in parentheses
        href = element.get("href")
        if href:
            run.text = f"{text} ({href})"
        run.font.color.rgb = None  # Use theme color
        run.font.underline = True


def add_formatted_text(
        doc: Document,
        style_config: Dict[str, Any],
        text: str,
        bold: bool = False,
        italic: bool = False,
        underline: bool = False,
        font_size: int = None
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
    """
    if not text.strip():
        return

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