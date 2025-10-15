#!/usr/bin/env python3
"""
Table element mapper.

This module handles conversion of HTML table elements to DOCX tables.
"""

from typing import Dict, Any, List
from bs4 import Tag
from docx import Document
from docx.shared import Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH


def add_table(doc: Document, style_config: Dict[str, Any], element: Tag) -> None:
    """
    Add table to document.

    Args:
        doc: python-docx Document
        style_config: Style configuration dictionary
        element: HTML table element
    """
    if not isinstance(element, Tag):
        raise TypeError("Element must be a Tag")

    if element.name.lower() != "table":
        raise ValueError("Element must be a table tag")

    # Extract table data
    rows_data = _extract_table_data(element)

    if not rows_data:
        return

    # Determine dimensions
    num_rows = len(rows_data)
    num_cols = max(len(row) for row in rows_data) if rows_data else 0

    if num_rows == 0 or num_cols == 0:
        return

    # Get table style from config
    style_name = style_config.get("styles", {}).get("table", "Table Grid")

    try:
        table = doc.add_table(rows=num_rows, cols=num_cols, style=style_name)
    except KeyError:
        # Fallback if style not found
        table = doc.add_table(rows=num_rows, cols=num_cols)

    # Populate table cells
    for row_idx, row_data in enumerate(rows_data):
        for col_idx, cell_data in enumerate(row_data):
            if col_idx < num_cols:
                cell = table.cell(row_idx, col_idx)
                _populate_cell(cell, cell_data)


def _extract_table_data(table_element: Tag) -> List[List[Dict[str, Any]]]:
    """
    Extract table data from HTML table element.

    Args:
        table_element: HTML table element

    Returns:
        List of rows, where each row is a list of cell data dictionaries
    """
    rows_data = []

    # Process thead, tbody, tfoot sections
    for section in ["thead", "tbody", "tfoot"]:
        section_element = table_element.find(section)
        if section_element:
            rows = section_element.find_all("tr", recursive=False)
        elif section == "tbody" and not table_element.find("tbody"):
            # If no tbody, get tr directly from table
            rows = table_element.find_all("tr", recursive=False)
        else:
            continue

        for row in rows:
            row_data = []
            cells = row.find_all(["th", "td"], recursive=False)

            for cell in cells:
                cell_info = {
                    "text": cell.get_text(strip=True),
                    "is_header": cell.name.lower() == "th"
                }
                row_data.append(cell_info)

            if row_data:
                rows_data.append(row_data)

        # Only process tbody if no sections found
        if section == "tbody" and rows_data:
            break

    return rows_data


def _populate_cell(cell, cell_data: Dict[str, Any]) -> None:
    """
    Populate a table cell with text and formatting.

    Args:
        cell: python-docx table cell
        cell_data: Dictionary with cell text and properties
    """
    text = cell_data.get("text", "")
    is_header = cell_data.get("is_header", False)

    # Set cell text
    cell.text = text

    # Apply header formatting if needed
    if is_header and cell.paragraphs:
        para = cell.paragraphs[0]
        for run in para.runs:
            run.font.bold = True

        # Center align header cells
        para.alignment = WD_ALIGN_PARAGRAPH.CENTER


def add_simple_table(
        doc: Document,
        style_config: Dict[str, Any],
        headers: List[str],
        rows: List[List[str]]
) -> None:
    """
    Add a simple table with headers and data rows.

    This is a convenience function for programmatically creating tables.

    Args:
        doc: python-docx Document
        style_config: Style configuration dictionary
        headers: List of header strings
        rows: List of rows, where each row is a list of cell strings
    """
    if not headers:
        raise ValueError("Headers cannot be empty")

    num_cols = len(headers)
    num_rows = len(rows) + 1  # +1 for header row

    style_name = style_config.get("styles", {}).get("table", "Table Grid")

    try:
        table = doc.add_table(rows=num_rows, cols=num_cols, style=style_name)
    except KeyError:
        table = doc.add_table(rows=num_rows, cols=num_cols)

    # Add headers
    header_row = table.rows[0]
    for col_idx, header_text in enumerate(headers):
        cell = header_row.cells[col_idx]
        cell.text = header_text
        if cell.paragraphs:
            para = cell.paragraphs[0]
            for run in para.runs:
                run.font.bold = True
            para.alignment = WD_ALIGN_PARAGRAPH.CENTER

    # Add data rows
    for row_idx, row_data in enumerate(rows, start=1):
        for col_idx, cell_text in enumerate(row_data):
            if col_idx < num_cols:
                table.cell(row_idx, col_idx).text = cell_text