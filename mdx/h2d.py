#!/usr/bin/env python3
"""
HTML to DOCX dispatcher.

This module provides the main dispatcher that traverses HTML DOM
and delegates conversion to specialized mapper modules.

Improvements:
- Comprehensive error handling
- Better logging and debugging
- Robust element processing
- Graceful degradation on errors
"""

import sys
from typing import Any, Dict, Optional

from bs4 import BeautifulSoup, NavigableString, Tag
from docx import Document

try:
    from . import map_text
    from . import map_list
    from . import map_tbl
    from . import map_inline
except ImportError:
    # Fallback for direct script execution
    import map_text
    import map_list
    import map_tbl
    import map_inline


class Html2Docx:
    """
    Main converter class that dispatches HTML elements to appropriate mappers.

    This class coordinates the conversion process by:
    1. Traversing the HTML DOM tree
    2. Identifying element types
    3. Delegating to specialized mapper functions
    4. Managing the DOCX document state
    5. Tracking conversion statistics
    6. Handling errors gracefully
    """

    def __init__(self, doc: Document, style_config: Dict[str, Any]):
        """
        Initialize converter with document and style configuration.

        Args:
            doc: python-docx Document object
            style_config: Dictionary with style mappings from YAML

        Raises:
            ValueError: If doc is None or style_config invalid
            TypeError: If arguments have wrong type
        """
        if doc is None:
            raise ValueError("Document cannot be None")

        if not isinstance(style_config, dict):
            raise TypeError(f"Style config must be a dictionary, got {type(style_config)}")

        if "styles" not in style_config:
            raise ValueError("Style config must contain 'styles' key")

        if not isinstance(style_config["styles"], dict):
            raise TypeError("Style config 'styles' must be a dictionary")

        self.doc = doc
        self.style_config = style_config
        self._conversion_count = 0
        self._error_count = 0
        self._skipped_count = 0

    def convert(self, soup: BeautifulSoup) -> None:
        """
        Convert BeautifulSoup HTML tree to DOCX.

        Args:
            soup: BeautifulSoup object with parsed HTML

        Raises:
            ValueError: If soup is None
            RuntimeError: If conversion fails critically
        """
        if soup is None:
            raise ValueError("BeautifulSoup object cannot be None")

        self._conversion_count = 0
        self._error_count = 0
        self._skipped_count = 0

        # Process all top-level children
        for element in soup.children:
            try:
                self._emit(element)
            except Exception as e:
                self._error_count += 1
                print(
                    f"WARNING: Error processing top-level element: {e}",
                    file=sys.stderr
                )

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
                try:
                    map_text.add_text(self.doc, self.style_config, text)
                except Exception as e:
                    self._error_count += 1
                    print(f"WARNING: Error adding text: {e}", file=sys.stderr)
            return

        # Handle non-Tag elements
        if not isinstance(element, Tag):
            self._skipped_count += 1
            return

        tag_name = element.name.lower() if element.name else None

        if not tag_name:
            self._skipped_count += 1
            return

        # Dispatch based on tag name with error handling
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

            elif tag_name in ("div", "section", "article", "main", "header", "footer", "nav"):
                # Container elements - process children
                for child in element.children:
                    self._emit(child)

            elif tag_name == "br":
                # Line break - add empty paragraph
                self.doc.add_paragraph("")

            else:
                # Unknown element - try to process children as fallback
                self._skipped_count += 1
                for child in element.children:
                    self._emit(child)

        except Exception as e:
            # Log error but continue processing
            self._error_count += 1
            print(
                f"WARNING: Error processing {tag_name} element: {e}",
                file=sys.stderr
            )

            # Try to recover by processing children
            try:
                for child in element.children:
                    self._emit(child)
            except Exception as child_error:
                print(
                    f"WARNING: Error processing children of {tag_name}: {child_error}",
                    file=sys.stderr
                )

    def get_conversion_stats(self) -> Dict[str, int]:
        """
        Get statistics about the conversion process.

        Returns:
            Dictionary with conversion statistics:
                - elements_processed: Total elements encountered
                - errors: Number of errors encountered
                - skipped: Number of elements skipped
        """
        return {
            "elements_processed": self._conversion_count,
            "errors": self._error_count,
            "skipped": self._skipped_count
        }


# =============================================================================
# CONVENIENCE FUNCTION
# =============================================================================

def convert_html_to_docx(
    html: str,
    doc: Document,
    style_config: Dict[str, Any]
) -> Dict[str, int]:
    """
    Convenience function to convert HTML string to DOCX.

    Args:
        html: HTML content string
        doc: python-docx Document object
        style_config: Style configuration dictionary

    Returns:
        Conversion statistics dictionary

    Raises:
        ValueError: If inputs are invalid
        RuntimeError: If conversion fails
    """
    if not html or not html.strip():
        raise ValueError("HTML content cannot be empty")

    try:
        soup = BeautifulSoup(html, "html.parser")
    except Exception as e:
        raise RuntimeError(f"Failed to parse HTML: {e}")

    converter = Html2Docx(doc, style_config)
    converter.convert(soup)

    return converter.get_conversion_stats()