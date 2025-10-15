#!/usr/bin/env python3
"""
Table element mapper.

This module handles conversion of HTML table elements to DOCX tables with:
- Support for thead, tbody, tfoot
- Header cell formatting
- Comprehensive error handling
- Fallback behaviors
"""

import sys
from typing import Dict, Any, List

from bs4 import Tag
from docx import Document
from docx.shared import Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH


def add_table(
    doc: Document,
    style_config: Dict[str, Any],
    element: Tag
) -> None:
    """
    Add table to document.

    Args:
        doc: python-docx Document
        style_config: Style configuration dictionary
        element: HTML table element

    Raises:
        TypeError: If arguments have wrong type
        ValueError: If element is not a valid table
    """
    # Validate inputs
    if not isinstance(doc, Document):
        raise TypeError(f"doc must be Document, got {type(doc)}")

    if not isinstance(element, Tag):
        raise TypeError(f"element must be Tag, got {type(element)}")

    if element.name.lower() != "table":
        raise ValueError(f"Element must be a table tag, got {element.name}")

    # Extract table data
    try:
        rows_data = _extract_table_data(element)
    except Exception as e:
        print(f"WARNING: Error extracting table data: {e}", file=sys.stderr)
        return

    if not rows_data:
        return  # Empty table

    # Determine dimensions
    try:
        num_rows = len(rows_data)
        num_cols = max(len(row) for row in rows_data) if rows_data else 0
    except Exception as e:
        print(f"WARNING: Error calculating table dimensions: {e}", file=sys.stderr)
        return

    if num_rows == 0 or num_cols == 0:
        return  # Invalid dimensions

    # Get table style from config
    try:
        style_name = style_config.get("styles", {}).get("table", "Table Grid")
    except Exception as e:
        print(f"WARNING: Error getting table style: {e}", file=sys.stderr)
        style_name = "Table Grid"

    # Create table
    try:
        table = doc.add_table(rows=num_rows, cols=num_cols, style=style_name)
    except KeyError:
        # Fallback if style not found
        print(f"WARNING: Style '{style_name}' not found, using default", file=sys.stderr)
        try:
            table = doc.add_table(rows=num_rows, cols=num_cols)
        except Exception as e:
            print(f"WARNING: Error creating table: {e}", file=sys.stderr)
            return
    except Exception as e:
        print(f"WARNING: Error creating table: {e}", file=sys.stderr)
        return

    # Populate table cells
    for row_idx, row_data in enumerate(rows_data):
        for col_idx, cell_data in enumerate(row_data):
            if col_idx < num_cols:
                try:
                    cell = table.cell(row_idx, col_idx)
                    _populate_cell(cell, cell_data)
                except Exception as e:
                    print(
                        f"WARNING: Error populating cell ({row_idx},{col_idx}): {e}",
                        file=sys.stderr
                    )


def _extract_table_data(table_element: Tag) -> List[List[Dict[str, Any]]]:
    """
    Extract table data from HTML table element.

    Args:
        table_element: HTML table element

    Returns:
        List of rows, where each row is a list of cell data dictionaries
    """
    rows_data = []

    try:
        # Process thead, tbody, tfoot sections
        for section in ["thead", "tbody", "tfoot"]:
            section_element = table_element.find(section)

            if section_element:
                try:
                    rows = section_element.find_all("tr", recursive=False)
                except Exception as e:
                    print(f"WARNING: Error finding rows in {section}: {e}", file=sys.stderr)
                    continue
            elif section == "tbody" and not table_element.find("tbody"):
                # If no tbody, get tr directly from table
                try:
                    rows = table_element.find_all("tr", recursive=False)
                except Exception as e:
                    print(f"WARNING: Error finding rows in table: {e}", file=sys.stderr)
                    continue
            else:
                continue

            for row in rows:
                row_data = []
                try:
                    cells = row.find_all(["th", "td"], recursive=False)
                except Exception as e:
                    print(f"WARNING: Error finding cells in row: {e}", file=sys.stderr)
                    continue

                for cell in cells:
                    try:
                        cell_info = {
                            "text": cell.get_text(strip=True),
                            "is_header": cell.name.lower() == "th"
                        }
                        row_data.append(cell_info)
                    except Exception as e:
                        print(f"WARNING: Error processing cell: {e}", file=sys.stderr)
                        row_data.append({"text": "", "is_header": False})

                if row_data:
                    rows_data.append(row_data)

            # Only process tbody if no sections found
            if section == "tbody" and rows_data:
                break

    except Exception as e:
        print(f"WARNING: Error extracting table data: {e}", file=sys.stderr)

    return rows_data


def _populate_cell(cell, cell_data: Dict[str, Any]) -> None:
    """
    Populate a table cell with text and formatting.

    Args:
        cell: python-docx table cell
        cell_data: Dictionary with cell text and properties
    """
    try:
        text = cell_data.get("text", "")
        is_header = cell_data.get("is_header", False)

        # Set cell text
        cell.text = text

        # Apply header formatting if needed
        if is_header and cell.paragraphs:
            try:
                para = cell.paragraphs[0]

                # Make bold
                for run in para.runs:
                    run.font.bold = True

                # Center align header cells
                para.alignment = WD_ALIGN_PARAGRAPH.CENTER
            except Exception as e:
                print(f"WARNING: Error applying header formatting: {e}", file=sys.stderr)
    except Exception as e:
        print(f"WARNING: Error populating cell: {e}", file=sys.stderr)


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

    Raises:
        TypeError: If arguments have wrong type
        ValueError: If headers is empty
    """
    # Validate inputs
    if not isinstance(doc, Document):
        raise TypeError(f"doc must be Document, got {type(doc)}")

    if not headers:
        raise ValueError("Headers cannot be empty")

    if not isinstance(headers, list):
        raise TypeError(f"headers must be list, got {type(headers)}")

    num_cols = len(headers)
    num_rows = len(rows) + 1  # +1 for header row

    # Get style name
    try:
        style_name = style_config.get("styles", {}).get("table", "Table Grid")
    except Exception as e:
        print(f"WARNING: Error getting table style: {e}", file=sys.stderr)
        style_name = "Table Grid"

    # Create table
    try:
        table = doc.add_table(rows=num_rows, cols=num_cols, style=style_name)
    except KeyError:
        try:
            table = doc.add_table(rows=num_rows, cols=num_cols)
        except Exception as e:
            print(f"WARNING: Error creating simple table: {e}", file=sys.stderr)
            return
    except Exception as e:
        print(f"WARNING: Error creating simple table: {e}", file=sys.stderr)
        return

    # Add headers
    try:
        header_row = table.rows[0]
        for col_idx, header_text in enumerate(headers):
            try:
                cell = header_row.cells[col_idx]
                cell.text = header_text

                if cell.paragraphs:
                    para = cell.paragraphs[0]
                    for run in para.runs:
                        run.font.bold = True
                    para.alignment = WD_ALIGN_PARAGRAPH.CENTER
            except Exception as e:
                print(f"WARNING: Error adding header cell: {e}", file=sys.stderr)
    except Exception as e:
        print(f"WARNING: Error adding headers: {e}", file=sys.stderr)

    # Add data rows
    try:
        for row_idx, row_data in enumerate(rows, start=1):
            for col_idx, cell_text in enumerate(row_data):
                if col_idx < num_cols:
                    try:
                        table.cell(row_idx, col_idx).text = cell_text
                    except Exception as e:
                        print(
                            f"WARNING: Error adding data cell ({row_idx},{col_idx}): {e}",
                            file=sys.stderr
                        )
    except Exception as e:
        print(f"WARNING: Error adding data rows: {e}", file=sys.stderr)