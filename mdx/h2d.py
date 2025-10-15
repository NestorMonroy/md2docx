#!/usr/bin/env python3
"""
HTML to DOCX dispatcher.

This module provides the main dispatcher that traverses HTML DOM
and delegates conversion to specialized mapper modules.
"""

from typing import Any, Dict
from bs4 import BeautifulSoup, NavigableString, Tag
from docx import Document

from . import map_text
from . import map_list
from . import map_tbl
from . import map_inline


class Html2Docx:
    """
    Main converter class that dispatches HTML elements to appropriate mappers.

    This class coordinates the conversion process by:
    1. Traversing the HTML DOM tree
    2. Identifying element types
    3. Delegating to specialized mapper functions
    4. Managing the DOCX document state
    """

    def __init__(self, doc: Document, style_config: Dict[str, Any]):
        """
        Initialize converter with document and style configuration.

        Args:
            doc: python-docx Document object
            style_config: Dictionary with style mappings from YAML
        """
        if doc is None:
            raise ValueError("Document cannot be None")

        if not isinstance(style_config, dict):
            raise TypeError("Style config must be a dictionary")

        if "styles" not in style_config:
            raise ValueError("Style config must contain 'styles' key")

        self.doc = doc
        self.style_config = style_config
        self._conversion_count = 0

    def convert(self, soup: BeautifulSoup) -> None:
        """
        Convert BeautifulSoup HTML tree to DOCX.

        Args:
            soup: BeautifulSoup object with parsed HTML
        """
        if soup is None:
            raise ValueError("BeautifulSoup object cannot be None")

        self._conversion_count = 0

        # Process all top-level children
        for element in soup.children:
            self._emit(element)

    def _emit(self, element: Any) -> None:
        """
        Dispatch element to appropriate mapper based on type.

        This is the core routing function that examines each HTML element
        and calls the correct mapper function.

        Args:
            element: HTML element (Tag or NavigableString)
        """
        self._conversion_count += 1

        # Handle text nodes
        if isinstance(element, NavigableString):
            text = str(element).strip()
            if text:
                map_text.add_text(self.doc, self.style_config, text)
            return

        # Handle non-Tag elements
        if not isinstance(element, Tag):
            return

        tag_name = element.name.lower() if element.name else None

        if not tag_name:
            return

        # Dispatch based on tag name
        try:
            if tag_name in ("h1", "h2", "h3", "h4", "h5", "h6"):
                map_text.add_heading(self.doc, self.style_config, element)

            elif tag_name == "p":
                map_text.add_paragraph(self.doc, self.style_config, element)

            elif tag_name == "pre":
                map_text.add_code_block(self.doc, self.style_config, element)

            elif tag_name in ("ul", "ol"):
                map_list.add_list(self.doc, self.style_config, element)

            elif tag_name == "table":
                map_tbl.add_table(self.doc, self.style_config, element)

            elif tag_name == "hr":
                map_text.add_page_break(self.doc, self.style_config)

            elif tag_name == "img":
                map_inline.add_image(self.doc, self.style_config, element)

            elif tag_name == "blockquote":
                map_text.add_blockquote(self.doc, self.style_config, element)

            elif tag_name in ("strong", "b", "em", "i", "code", "a", "span"):
                map_inline.add_inline(self.doc, self.style_config, element)

            elif tag_name in ("div", "section", "article"):
                # Container elements - process children
                for child in element.children:
                    self._emit(child)

            elif tag_name == "br":
                # Line break - add empty paragraph
                self.doc.add_paragraph("")

            else:
                # Unknown element - try to process children as fallback
                for child in element.children:
                    self._emit(child)

        except Exception as e:
            # Log error but continue processing
            import sys
            print(f"WARNING: Error processing {tag_name}: {e}", file=sys.stderr)

            # Try to recover by processing children
            try:
                for child in element.children:
                    self._emit(child)
            except Exception:
                pass

    def get_conversion_stats(self) -> Dict[str, int]:
        """
        Get statistics about the conversion process.

        Returns:
            Dictionary with conversion statistics
        """
        return {
            "elements_processed": self._conversion_count
        }