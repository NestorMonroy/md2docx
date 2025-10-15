"""
DOCX Pipeline - Markdown to DOCX conversion package

This package provides a complete pipeline for converting Markdown documents
to professionally styled DOCX files with support for:
- Corporate styling (ISO 9001:2015 compatible)
- Template-based or programmatic style generation
- Comprehensive HTML element mapping
- Image handling with intelligent path resolution
- Robust error handling and validation

Architecture:
    md2docx.py       -> Main orchestrator (MD -> HTML -> DOCX)
    h2d.py           -> HTML to DOCX dispatcher
    map_text.py      -> Text and heading mappers
    map_list.py      -> List mappers (ordered/unordered)
    map_tbl.py       -> Table mappers
    map_inline.py    -> Inline formatting mappers
    style_generator.py -> Programmatic style generation
"""

__version__ = "1.0.0"
__author__ = "DOCX Pipeline Team"

import sys

# Attempt to import main components
_import_errors = []

try:
    from .md2docx import main as convert_main
except ImportError as e:
    _import_errors.append(f"md2docx: {e}")
    convert_main = None

try:
    from .h2d import Html2Docx
except ImportError as e:
    _import_errors.append(f"h2d: {e}")
    Html2Docx = None

try:
    from .style_generator import (
        create_styled_document,
        apply_corporate_styles,
        CorporateColors
    )
except ImportError as e:
    _import_errors.append(f"style_generator: {e}")
    create_styled_document = None
    apply_corporate_styles = None
    CorporateColors = None

# Report import errors to stderr
if _import_errors:
    print("WARNING: Some mdx modules failed to import:", file=sys.stderr)
    for error in _import_errors:
        print(f"  - {error}", file=sys.stderr)
    print("Some functionality may not be available.", file=sys.stderr)

# Export public API
__all__ = [
    'convert_main',
    'Html2Docx',
    'create_styled_document',
    'apply_corporate_styles',
    'CorporateColors',
]

# Module health check function
def check_dependencies():
    """
    Check if all required dependencies are available.

    Returns:
        tuple: (success: bool, missing: list)
    """
    required = ['markdown', 'bs4', 'docx', 'yaml']
    missing = []

    for module_name in required:
        try:
            __import__(module_name)
        except ImportError:
            missing.append(module_name)

    return (len(missing) == 0, missing)

# Perform dependency check on import
_deps_ok, _deps_missing = check_dependencies()
if not _deps_ok:
    print(
        f"WARNING: Missing dependencies: {', '.join(_deps_missing)}",
        file=sys.stderr
    )
    print(
        "Install with: pip install markdown beautifulsoup4 python-docx PyYAML",
        file=sys.stderr
    )