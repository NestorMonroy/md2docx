#!/usr/bin/env python3
"""
Text element mappers: headings, paragraphs, code blocks, page breaks.

This module handles conversion of textual HTML elements to DOCX.
"""

from typing import Dict, Any
from bs4 import Tag
from docx import Document
from docx.shared import Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH


def add_heading(doc: Document, style_config: Dict[str, Any], element: Tag) -> None:
    """
    Add heading to document.

    Args:
        doc: python-docx Document
        style_config: Style configuration dictionary
        element: HTML heading element (h1-h6)
    """
    if not isinstance(element, Tag):
        raise TypeError("Element must be a Tag")

    tag_name = element.name.lower()

    if tag_name not in ("h1", "h2", "h3", "h4", "h5", "h6"):
        raise ValueError(f"Invalid heading tag: {tag_name}")

    text = element.get_text(strip=True)

    if not text:
        return

    # Get style name from config
    headings = style_config.get("styles", {}).get("headings", {})
    style_name = headings.get(tag_name, f"Heading {tag_name[1]}")

    try:
        para = doc.add_paragraph(text, style=style_name)
    except KeyError:
        # Fallback if style not found in template
        para = doc.add_paragraph(text)
        # Apply basic heading formatting
        run = para.runs[0] if para.runs else None
        if run:
            level = int(tag_name[1])
            run.font.size = Pt(18 - (level * 2))
            run.font.bold = True


def add_paragraph(doc: Document, style_config: Dict[str, Any], element: Tag) -> None:
    """
    Add paragraph to document.

    Args:
        doc: python-docx Document
        style_config: Style configuration dictionary
        element: HTML paragraph element
    """
    if not isinstance(element, Tag):
        raise TypeError("Element must be a Tag")

    text = element.get_text()

    if not text.strip():
        return

    style_name = style_config.get("styles", {}).get("paragraph", "Normal")

    try:
        doc.add_paragraph(text, style=style_name)
    except KeyError:
        # Fallback if style not found
        doc.add_paragraph(text)


def add_code_block(doc: Document, style_config: Dict[str, Any], element: Tag) -> None:
    """
    Add code block to document.

    Args:
        doc: python-docx Document
        style_config: Style configuration dictionary
        element: HTML pre element
    """
    if not isinstance(element, Tag):
        raise TypeError("Element must be a Tag")

    # Extract code text, preferring <code> child if present
    code_element = element.find("code")
    text = code_element.get_text() if code_element else element.get_text()

    if not text.strip():
        return

    style_name = style_config.get("styles", {}).get("code_block", "Code")

    try:
        para = doc.add_paragraph(text, style=style_name)
    except KeyError:
        # Fallback with monospace font
        para = doc.add_paragraph(text)
        run = para.runs[0] if para.runs else None
        if run:
            run.font.name = "Courier New"
            run.font.size = Pt(9)


def add_blockquote(doc: Document, style_config: Dict[str, Any], element: Tag) -> None:
    """
    Add blockquote to document.

    Args:
        doc: python-docx Document
        style_config: Style configuration dictionary
        element: HTML blockquote element
    """
    if not isinstance(element, Tag):
        raise TypeError("Element must be a Tag")

    text = element.get_text(strip=True)

    if not text:
        return

    style_name = style_config.get("styles", {}).get("blockquote", "Quote")

    try:
        para = doc.add_paragraph(text, style=style_name)
    except KeyError:
        # Fallback with italic formatting
        para = doc.add_paragraph(text)
        run = para.runs[0] if para.runs else None
        if run:
            run.font.italic = True
        para.paragraph_format.left_indent = Pt(36)


def add_page_break(doc: Document, style_config: Dict[str, Any]) -> None:
    """
    Add page break to document.

    Args:
        doc: python-docx Document
        style_config: Style configuration dictionary
    """
    behaviors = style_config.get("behaviors", {})
    hr_as_page_break = behaviors.get("hr_as_page_break", True)

    if hr_as_page_break:
        doc.add_page_break()
    else:
        # Add horizontal line as alternative
        para = doc.add_paragraph()
        para.alignment = WD_ALIGN_PARAGRAPH.CENTER
        run = para.add_run("─" * 50)
        run.font.color.rgb = RGBColor(192, 192, 192)


def add_text(doc: Document, style_config: Dict[str, Any], text: str) -> None:
    """
    Add plain text to document.

    Args:
        doc: python-docx Document
        style_config: Style configuration dictionary
        text: Text content to add
    """
    if not text or not text.strip():
        return

    style_name = style_config.get("styles", {}).get("paragraph", "Normal")

    try:
        doc.add_paragraph(text, style=style_name)
    except KeyError:
        doc.add_paragraph(text)