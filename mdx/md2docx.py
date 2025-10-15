#!/usr/bin/env python3
"""
Main orchestrator for Markdown to DOCX conversion.

This module handles the complete pipeline:
1. Read and validate Markdown input
2. Convert MD to HTML using markdown library
3. Parse HTML with BeautifulSoup
4. Load and validate styles from YAML config
5. Load template or generate styles programmatically
6. Convert HTML to DOCX using dispatcher
7. Save and verify output

Error handling: All errors are caught and reported with context.
Validation: Comprehensive input/output validation at each step.
"""

import sys
import os
import argparse
from pathlib import Path
from typing import Dict, Any, Optional

# Check dependencies early
try:
    import markdown
    from bs4 import BeautifulSoup
    from docx import Document
    import yaml
except ImportError as e:
    print(f"ERROR: Missing required module: {e}", file=sys.stderr)
    print("ACCION REQUERIDA: Install dependencies:", file=sys.stderr)
    print("  pip install markdown beautifulsoup4 python-docx PyYAML", file=sys.stderr)
    sys.exit(1)

# Import local modules
try:
    from .h2d import Html2Docx
    from .style_generator import create_styled_document, apply_corporate_styles
except ImportError:
    # Fallback for when run as script
    from h2d import Html2Docx
    from style_generator import create_styled_document, apply_corporate_styles


# =============================================================================
# ARGUMENT PARSING
# =============================================================================

def parse_arguments() -> argparse.Namespace:
    """
    Parse and validate command line arguments.

    Returns:
        Parsed arguments namespace
    """
    parser = argparse.ArgumentParser(
        description="Convert Markdown to DOCX using corporate template",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --input doc.md --output doc.docx --template tpl.docx --style style.yml
  %(prog)s --input doc.md --output doc.docx --style style.yml --verbose
  %(prog)s --input doc.md --output doc.docx --style style.yml
        """
    )

    parser.add_argument(
        "--input",
        required=True,
        type=Path,
        metavar="FILE",
        help="Input Markdown file path"
    )

    parser.add_argument(
        "--output",
        required=True,
        type=Path,
        metavar="FILE",
        help="Output DOCX file path"
    )

    parser.add_argument(
        "--template",
        type=Path,
        metavar="FILE",
        help="Template DOCX file with corporate styles (optional)"
    )

    parser.add_argument(
        "--style",
        required=True,
        type=Path,
        metavar="FILE",
        help="Style configuration YAML file"
    )

    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose output"
    )

    parser.add_argument(
        "--version",
        action="version",
        version="%(prog)s 1.0.0"
    )

    return parser.parse_args()


# =============================================================================
# INPUT VALIDATION
# =============================================================================

def validate_inputs(args: argparse.Namespace) -> None:
    """
    Validate all input files exist and are readable.

    Args:
        args: Parsed command line arguments

    Raises:
        FileNotFoundError: If required file not found
        ValueError: If file is not valid
        PermissionError: If file is not readable
    """
    # Validate input file
    if not args.input.exists():
        raise FileNotFoundError(f"Input file not found: {args.input}")

    if not args.input.is_file():
        raise ValueError(f"Input path is not a file: {args.input}")

    if not os.access(args.input, os.R_OK):
        raise PermissionError(f"Input file is not readable: {args.input}")

    if args.input.stat().st_size == 0:
        raise ValueError(f"Input file is empty: {args.input}")

    # Validate template if provided
    if args.template:
        if not args.template.exists():
            raise FileNotFoundError(f"Template not found: {args.template}")

        if not args.template.is_file():
            raise ValueError(f"Template path is not a file: {args.template}")

        if not os.access(args.template, os.R_OK):
            raise PermissionError(f"Template is not readable: {args.template}")

    # Validate style config
    if not args.style.exists():
        raise FileNotFoundError(f"Style config not found: {args.style}")

    if not args.style.is_file():
        raise ValueError(f"Style config path is not a file: {args.style}")

    if not os.access(args.style, os.R_OK):
        raise PermissionError(f"Style config is not readable: {args.style}")


# =============================================================================
# FILE I/O
# =============================================================================

def read_markdown(file_path: Path) -> str:
    """
    Read Markdown file content with proper encoding.

    Args:
        file_path: Path to Markdown file

    Returns:
        Markdown content as string

    Raises:
        ValueError: If file is empty or has encoding issues
        IOError: If file cannot be read
    """
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()

        if not content.strip():
            raise ValueError(f"Input file is empty: {file_path}")

        return content

    except UnicodeDecodeError as e:
        raise ValueError(f"File encoding error in {file_path}: {e}")
    except IOError as e:
        raise IOError(f"Cannot read file {file_path}: {e}")


# =============================================================================
# MARKDOWN TO HTML CONVERSION
# =============================================================================

def convert_md_to_html(md_text: str) -> str:
    """
    Convert Markdown text to HTML using markdown library.

    Args:
        md_text: Markdown content

    Returns:
        HTML string

    Raises:
        RuntimeError: If conversion fails
    """
    try:
        html = markdown.markdown(
            md_text,
            extensions=[
                "fenced_code",
                "tables",
                "sane_lists",
                "nl2br"
            ],
            output_format="html5"
        )

        if not html.strip():
            raise ValueError("Markdown conversion produced empty HTML")

        return html

    except Exception as e:
        raise RuntimeError(f"Markdown conversion failed: {e}")


# =============================================================================
# HTML PARSING
# =============================================================================

def parse_html(html: str) -> BeautifulSoup:
    """
    Parse HTML string into BeautifulSoup object.

    Args:
        html: HTML content string

    Returns:
        BeautifulSoup object

    Raises:
        RuntimeError: If parsing fails
    """
    try:
        soup = BeautifulSoup(html, "html.parser")

        if soup is None:
            raise ValueError("HTML parsing produced None")

        return soup

    except Exception as e:
        raise RuntimeError(f"HTML parsing failed: {e}")


# =============================================================================
# STYLE CONFIGURATION
# =============================================================================

def load_style_config(style_path: Path) -> Dict[str, Any]:
    """
    Load and validate style configuration from YAML.

    Args:
        style_path: Path to style.yml

    Returns:
        Style configuration dictionary

    Raises:
        ValueError: If YAML is invalid or missing required sections
        IOError: If file cannot be read
    """
    try:
        with open(style_path, "r", encoding="utf-8") as f:
            config = yaml.safe_load(f)

        if not isinstance(config, dict):
            raise ValueError("Style config must be a YAML dictionary")

        if "styles" not in config:
            raise ValueError("Style config missing 'styles' section")

        # Validate required style mappings
        required_styles = ["headings", "paragraph", "code_block"]
        styles = config["styles"]

        for style in required_styles:
            if style not in styles:
                raise ValueError(f"Style config missing required style: {style}")

        return config

    except yaml.YAMLError as e:
        raise ValueError(f"Invalid YAML syntax in {style_path}: {e}")
    except IOError as e:
        raise IOError(f"Cannot read style config {style_path}: {e}")


# =============================================================================
# TEMPLATE LOADING
# =============================================================================

def load_template(template_path: Optional[Path]) -> Document:
    """
    Load DOCX template or create new document with generated styles.

    Args:
        template_path: Path to template.docx (optional)

    Returns:
        python-docx Document object

    Raises:
        RuntimeError: If template loading fails
    """
    try:
        if template_path and template_path.exists():
            doc = Document(str(template_path))
            if doc is None:
                raise ValueError("Template loading produced None")
            return doc
        else:
            # Create document with programmatic styles
            doc = create_styled_document(iso_elements=False)
            if doc is None:
                raise ValueError("Document creation produced None")
            return doc

    except Exception as e:
        raise RuntimeError(f"Failed to load/create document: {e}")


# =============================================================================
# DOCUMENT SAVING
# =============================================================================

def save_document(doc: Document, output_path: Path) -> None:
    """
    Save DOCX document to file with validation.

    Args:
        doc: python-docx Document object
        output_path: Path where to save file

    Raises:
        PermissionError: If cannot write to location
        IOError: If save fails
        ValueError: If output file is invalid
    """
    try:
        # Ensure output directory exists
        output_path.parent.mkdir(parents=True, exist_ok=True)

        # Save document
        doc.save(str(output_path))

        # Verify file was created
        if not output_path.exists():
            raise IOError("Output file was not created")

        # Verify file size is reasonable
        file_size = output_path.stat().st_size
        if file_size < 1000:
            raise ValueError(f"Output file too small: {file_size} bytes")

    except PermissionError as e:
        raise PermissionError(f"Cannot write to {output_path}: {e}")
    except IOError as e:
        raise IOError(f"Failed to save document: {e}")


# =============================================================================
# MAIN CONVERSION FUNCTION
# =============================================================================

def main() -> int:
    """
    Main entry point for MD to DOCX conversion.

    Returns:
        Exit code (0 for success, 1 for error)
    """
    try:
        # Parse arguments
        args = parse_arguments()

        if args.verbose:
            print(f"Input:    {args.input}")
            print(f"Output:   {args.output}")
            print(f"Template: {args.template or 'None (using generated styles)'}")
            print(f"Style:    {args.style}")
            print()

        # Validate inputs
        if args.verbose:
            print("Validating inputs...")
        validate_inputs(args)

        # Read Markdown
        if args.verbose:
            print("Reading Markdown file...")
        md_text = read_markdown(args.input)
        if args.verbose:
            print(f"  Markdown size: {len(md_text)} characters")

        # Convert Markdown to HTML
        if args.verbose:
            print("Converting Markdown to HTML...")
        html = convert_md_to_html(md_text)
        if args.verbose:
            print(f"  HTML size: {len(html)} characters")

        # Parse HTML
        if args.verbose:
            print("Parsing HTML...")
        soup = parse_html(html)
        if args.verbose:
            element_count = len(soup.find_all())
            print(f"  Parsed {element_count} HTML elements")

        # Load style configuration
        if args.verbose:
            print("Loading style configuration...")
        style_config = load_style_config(args.style)

        # Load template or create styled document
        if args.verbose:
            print("Loading template...")
        doc = load_template(args.template)

        # Convert HTML to DOCX
        if args.verbose:
            print("Converting HTML to DOCX...")
        converter = Html2Docx(doc, style_config)
        converter.convert(soup)

        if args.verbose:
            stats = converter.get_conversion_stats()
            print(f"  Processed {stats['elements_processed']} elements")

        # Save document
        if args.verbose:
            print("Saving document...")
        save_document(doc, args.output)

        # Success message
        output_size = args.output.stat().st_size
        if args.verbose:
            print(f"  Output size: {output_size // 1024} KB")

        print(f"SUCCESS: Generated {args.output}")
        return 0

    except FileNotFoundError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1

    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1

    except RuntimeError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1

    except IOError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1

    except PermissionError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1

    except KeyboardInterrupt:
        print("\nERROR: Conversion interrupted by user", file=sys.stderr)
        return 130

    except Exception as e:
        print(f"ERROR: Unexpected error: {e}", file=sys.stderr)
        if args.verbose if 'args' in locals() else False:
            import traceback
            traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())