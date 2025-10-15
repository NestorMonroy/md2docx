#!/usr/bin/env python3
"""
Stack validation utility for DOCX pipeline.

This module provides comprehensive validation of the Python environment,
dependencies, and module integrity.
"""

import sys
import os
from pathlib import Path
from typing import List, Tuple, Dict, Any


def check_python_version() -> Tuple[bool, str]:
    """
    Verify Python version meets requirements.

    Returns:
        (success, message) tuple
    """
    required_major = 3
    required_minor = 6

    actual = sys.version_info

    if actual.major < required_major or \
            (actual.major == required_major and actual.minor < required_minor):
        return (
            False,
            f"Python {required_major}.{required_minor}+ required, "
            f"got {actual.major}.{actual.minor}.{actual.micro}"
        )

    return (
        True,
        f"Python {actual.major}.{actual.minor}.{actual.micro} OK"
    )


def check_dependencies() -> List[Tuple[bool, str, str]]:
    """
    Check all required Python dependencies.

    Returns:
        List of (success, package_name, message) tuples
    """
    required_packages = [
        ("markdown", "3.0"),
        ("bs4", "4.0"),  # beautifulsoup4
        ("docx", "1.0"),  # python-docx
        ("yaml", "5.0"),  # PyYAML
    ]

    results = []

    for package_name, min_version in required_packages:
        try:
            if package_name == "bs4":
                import bs4
                version = bs4.__version__
            elif package_name == "docx":
                import docx
                version = docx.__version__
            elif package_name == "yaml":
                import yaml
                version = yaml.__version__
            elif package_name == "markdown":
                import markdown
                version = markdown.__version__
            else:
                raise ImportError(f"Unknown package: {package_name}")

            results.append((
                True,
                package_name,
                f"version {version}"
            ))

        except ImportError as e:
            results.append((
                False,
                package_name,
                f"NOT INSTALLED: {e}"
            ))
        except Exception as e:
            results.append((
                False,
                package_name,
                f"ERROR: {e}"
            ))

    return results


def check_module_syntax() -> List[Tuple[bool, str, str]]:
    """
    Check syntax of all Python modules in the package.

    Returns:
        List of (success, module_name, message) tuples
    """
    modules = [
        "__init__",
        "md2docx",
        "h2d",
        "map_text",
        "map_list",
        "map_tbl",
        "map_inline",
        "style_generator",
    ]

    results = []
    package_dir = Path(__file__).parent

    for module_name in modules:
        module_file = package_dir / f"{module_name}.py"

        if not module_file.exists():
            results.append((
                False,
                module_name,
                f"FILE NOT FOUND: {module_file}"
            ))
            continue

        try:
            import py_compile
            py_compile.compile(str(module_file), doraise=True)
            results.append((
                True,
                module_name,
                "syntax OK"
            ))
        except py_compile.PyCompileError as e:
            results.append((
                False,
                module_name,
                f"SYNTAX ERROR: {e}"
            ))
        except Exception as e:
            results.append((
                False,
                module_name,
                f"ERROR: {e}"
            ))

    return results


def check_module_imports() -> List[Tuple[bool, str, str]]:
    """
    Check if all modules can be imported.

    Returns:
        List of (success, module_name, message) tuples
    """
    modules = [
        "md2docx",
        "h2d",
        "map_text",
        "map_list",
        "map_tbl",
        "map_inline",
        "style_generator",
    ]

    results = []

    for module_name in modules:
        try:
            __import__(f"mdx.{module_name}")
            results.append((
                True,
                module_name,
                "import OK"
            ))
        except ImportError as e:
            results.append((
                False,
                module_name,
                f"IMPORT ERROR: {e}"
            ))
        except Exception as e:
            results.append((
                False,
                module_name,
                f"ERROR: {e}"
            ))

    return results


def check_environment_vars() -> List[Tuple[bool, str, str]]:
    """
    Check required environment variables.

    Returns:
        List of (success, var_name, message) tuples
    """
    required_vars = [
        "DOCX_VENV",
        "DOCX_PYTHON",
        "DOCX_SCRIPTS_DIR",
    ]

    optional_vars = [
        "DOCX_SRC_DIR",
        "DOCX_IMG_DIR",
        "DOCX_BUILD_DIR",
        "DOCX_TPL",
        "DOCX_STYLE_YML",
    ]

    results = []

    # Check required vars
    for var_name in required_vars:
        value = os.environ.get(var_name)
        if value:
            results.append((
                True,
                var_name,
                f"set to: {value}"
            ))
        else:
            results.append((
                False,
                var_name,
                "NOT SET (required)"
            ))

    # Check optional vars
    for var_name in optional_vars:
        value = os.environ.get(var_name)
        if value:
            results.append((
                True,
                var_name,
                f"set to: {value}"
            ))
        else:
            results.append((
                True,
                var_name,
                "not set (optional)"
            ))

    return results


def run_all_checks(verbose: bool = False) -> bool:
    """
    Run all validation checks.

    Args:
        verbose: If True, print detailed results

    Returns:
        True if all critical checks pass, False otherwise
    """
    all_passed = True

    print("[INFO] Validating DOCX Pipeline Stack")
    print()

    # Python version
    success, message = check_python_version()
    status = "[OK]" if success else "[FAIL]"
    print(f"{status} Python Version: {message}")
    if not success:
        all_passed = False
    print()

    # Dependencies
    print("[INFO] Checking Python dependencies...")
    dep_results = check_dependencies()
    for success, package, message in dep_results:
        status = "[OK]" if success else "[FAIL]"
        print(f"  {status} {package}: {message}")
        if not success:
            all_passed = False
    print()

    # Module syntax
    print("[INFO] Checking module syntax...")
    syntax_results = check_module_syntax()
    for success, module, message in syntax_results:
        status = "[OK]" if success else "[FAIL]"
        if verbose or not success:
            print(f"  {status} {module}.py: {message}")
        if not success:
            all_passed = False
    if not verbose:
        passed = sum(1 for s, _, _ in syntax_results if s)
        total = len(syntax_results)
        print(f"  [{passed}/{total}] modules syntax OK")
    print()

    # Module imports
    if verbose:
        print("[INFO] Checking module imports...")
        import_results = check_module_imports()
        for success, module, message in import_results:
            status = "[OK]" if success else "[FAIL]"
            print(f"  {status} {module}: {message}")
            if not success:
                all_passed = False
        print()

    # Environment variables
    if verbose:
        print("[INFO] Checking environment variables...")
        env_results = check_environment_vars()
        for success, var, message in env_results:
            status = "[OK]" if success else "[WARN]"
            print(f"  {status} {var}: {message}")
            # Only fail on required vars
            if not success and "required" in message:
                all_passed = False
        print()

    # Summary
    if all_passed:
        print("[SUCCESS] All validation checks passed")
        return True
    else:
        print("[ERROR] Some validation checks failed")
        print("[INFO] Run with --verbose for detailed diagnostics")
        return False


def main():
    """Main entry point for validation script."""
    import argparse

    parser = argparse.ArgumentParser(
        description="Validate DOCX Pipeline Python stack"
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Show detailed validation results"
    )

    args = parser.parse_args()

    success = run_all_checks(verbose=args.verbose)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()