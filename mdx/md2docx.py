#!/usr/bin/env python3
"""
Main orchestrator for Markdown to DOCX conversion.

This module handles the complete pipeline:
1. Read Markdown input
2. Convert MD to HTML
3. Parse HTML with BeautifulSoup
4. Apply styles from YAML config
5. Generate DOCX using template
"""

import sys
import argparse
from pathlib import Path
from typing import Dict, Any

try:
    import markdown
    from bs4 import BeautifulSoup
    from docx import Document
    import yaml
except ImportError as e:
    print(f"ERROR: Missing required module: {e}", file=sys.stderr)
    print("Install with: pip install markdown beautifulsoup4 python-docx PyYAML", file=sys.stderr)
    sys.exit(1)

from .h2d import Html2Docx
from .style_generator import create_styled_document, apply_corporate_styles


def parse_arguments() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Convert Markdown to DOCX using corporate template",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    parser.add_argument(
        "--input",
        required=True,
        type=Path,
        help="Input Markdown file path"
    )

    parser.add_argument(
        "--output",
        required=True,
        type=Path,
        help="Output DOCX file path"
    )

    parser.add_argument(
        "--template",
        required=True,
        type=Path,
        help="Template DOCX file with corporate styles"
    )

    parser.add_argument(
        "--style",
        required=True,
        type=Path,
        help="Style configuration YAML file"
    )

    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose output"
    )

    return parser.parse_args()


def validate_inputs(args: argparse.Namespace) -> None:
    """Validate all input files exist and are readable."""
    if not args.input.exists():
        raise FileNotFoundError(f"Input file not found: {args.input}")

    if not args.input.is_file():
        raise ValueError(f"Input path is not a file: {args.input}")

    if not args.template.exists():
        raise FileNotFoundError(f"Template not found: {args.template}")

    if not args.template.is_file():
        raise ValueError(f"Template path is not a file: {args.template}")

    if not args.style.exists():
        raise FileNotFoundError(f"Style config not found: {args.style}")

    if not args.style.is_file():
        raise ValueError(f"Style config path is not a file: {args.style}")


def read_markdown(file_path: Path) -> str:
    """Read Markdown file content."""
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()

        if not content.strip():
            raise ValueError("Input file is empty")

        return content

    except UnicodeDecodeError as e:
        raise ValueError(f"File encoding error: {e}")
    except IOError as e:
        raise IOError(f"Cannot read file: {e}")


def convert_md_to_html(md_text: str) -> str:
    """Convert Markdown text to HTML."""
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


def parse_html(html: str) -> BeautifulSoup:
    """Parse HTML string into BeautifulSoup object."""
    try:
        soup = BeautifulSoup(html, "html.parser")

        if soup is None:
            raise ValueError("HTML parsing produced None")

        return soup

    except Exception as e:
        raise RuntimeError(f"HTML parsing failed: {e}")


def load_style_config(style_path: Path) -> Dict[str, Any]:
    """Load and validate style configuration from YAML."""
    try:
        with open(style_path, "r", encoding="utf-8") as f:
            config = yaml.safe_load(f)

        if not isinstance(config, dict):
            raise ValueError("Style config must be a YAML dictionary")

        if "styles" not in config:
            raise ValueError("Style config missing 'styles' section")

        required_styles = ["headings", "paragraph", "code_block"]
        styles = config["styles"]

        for style in required_styles:
            if style not in styles:
                raise ValueError(f"Style config missing required style: {style}")

        return config

    except yaml.YAMLError as e:
        raise ValueError(f"Invalid YAML syntax: {e}")
    except IOError as e:
        raise IOError(f"Cannot read style config: {e}")


def load_template(template_path: Path) -> Document:
    """Load DOCX template."""
    try:
        doc = Document(str(template_path))

        if doc is None:
            raise ValueError("Template loading produced None")

        return doc

    except Exception as e:
        raise RuntimeError(f"Failed to load template: {e}")


def save_document(doc: Document, output_path: Path) -> None:
    """Save DOCX document to file."""
    try:
        output_path.parent.mkdir(parents=True, exist_ok=True)

        doc.save(str(output_path))

        if not output_path.exists():
            raise IOError("Output file was not created")

        file_size = output_path.stat().st_size
        if file_size < 1000:
            raise ValueError(f"Output file too small: {file_size} bytes")

    except PermissionError as e:
        raise PermissionError(f"Cannot write to output location: {e}")
    except IOError as e:
        raise IOError(f"Failed to save document: {e}")


def main() -> int:
    """Main entry point for MD to DOCX conversion."""
    try:
        args = parse_arguments()

        if args.verbose:
            print(f"Input:    {args.input}")
            print(f"Output:   {args.output}")
            print(f"Template: {args.template}")
            print(f"Style:    {args.style}")
            print()

        if args.verbose:
            print("Validating inputs...")
        validate_inputs(args)

        if args.verbose:
            print("Reading Markdown file...")
        md_text = read_markdown(args.input)

        if args.verbose:
            print(f"Markdown size: {len(md_text)} characters")
            print("Converting Markdown to HTML...")
        html = convert_md_to_html(md_text)

        if args.verbose:
            print(f"HTML size: {len(html)} characters")
            print("Parsing HTML...")
        soup = parse_html(html)

        if args.verbose:
            print("Loading style configuration...")
        style_config = load_style_config(args.style)

        if args.verbose:
            print("Loading template...")
        doc = load_template(args.template)

        if args.verbose:
            print("Converting HTML to DOCX...")
        converter = Html2Docx(doc, style_config)
        converter.convert(soup)

        if args.verbose:
            print("Saving document...")
        save_document(doc, args.output)

        if args.verbose:
            output_size = args.output.stat().st_size
            print(f"Output size: {output_size // 1024} KB")

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
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())