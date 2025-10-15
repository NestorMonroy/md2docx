#!/usr/bin/env python3
"""
Generador programático de estilos ISO 9001:2015 para DOCX.

Este módulo crea todos los estilos necesarios directamente en código,
eliminando la necesidad de plantillas Word externas.

Mejoras v2:
- Validación de inputs
- Manejo robusto de errores
- Funciones con tipo hints
- Mejor logging de warnings
"""

import sys
from typing import Optional

from docx import Document
from docx.shared import Pt, Cm, RGBColor, Inches
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_LINE_SPACING
from docx.enum.style import WD_STYLE_TYPE
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import qn, nsdecls


# =============================================================================
# PALETA DE COLORES CORPORATIVA
# =============================================================================

class CorporateColors:
    """Paleta de colores definida en código."""

    # Color principal (ISO 9001 estándar)
    AZUL_CORPORATIVO = RGBColor(21, 96, 130)  # #156082
    AZUL_HEX = "156082"

    # Colores complementarios
    BLANCO = RGBColor(255, 255, 255)
    NEGRO = RGBColor(0, 0, 0)
    GRIS_OSCURO = RGBColor(51, 51, 51)
    GRIS_MEDIO = RGBColor(96, 96, 96)
    GRIS_CLARO = RGBColor(242, 242, 242)

    # Colores de fondo para código
    FONDO_CODIGO = RGBColor(245, 245, 245)


# =============================================================================
# UTILIDADES XML PARA ESTILOS AVANZADOS
# =============================================================================

def set_cell_shading(cell, hex_color: str) -> None:
    """
    Aplica color de fondo a celda de tabla.

    Args:
        cell: Celda de tabla python-docx
        hex_color: Color en formato hexadecimal (sin #)
    """
    try:
        cell._tc.get_or_add_tcPr().append(
            parse_xml(r'<w:shd {} w:fill="{}"/>'.format(nsdecls('w'), hex_color))
        )
    except Exception as e:
        print(f"WARNING: Error setting cell shading: {e}", file=sys.stderr)


def add_divider(container, color_hex: str, height_pt: int = 2):
    """
    Añade línea divisoria horizontal.

    Args:
        container: Contenedor (header/footer/document)
        color_hex: Color en formato hexadecimal (sin #)
        height_pt: Altura de la línea en puntos

    Returns:
        Paragraph object creado
    """
    try:
        p = container.add_paragraph()
        pPr = p._element.get_or_add_pPr()
        pBdr = OxmlElement('w:pBdr')
        bottom = OxmlElement('w:bottom')
        bottom.set(qn('w:val'), 'single')
        bottom.set(qn('w:sz'), str(height_pt * 4))
        bottom.set(qn('w:color'), color_hex)
        pBdr.append(bottom)
        pPr.append(pBdr)
        return p
    except Exception as e:
        print(f"WARNING: Error adding divider: {e}", file=sys.stderr)
        return container.add_paragraph()  # Fallback


def add_text_field(run, field_instr_text: str) -> None:
    """
    Añade campo de texto dinámico (fecha, página, etc.).

    Args:
        run: Run de python-docx
        field_instr_text: Instrucción del campo
    """
    try:
        r = run._r
        fldChar1 = OxmlElement('w:fldChar')
        fldChar1.set(qn('w:fldCharType'), 'begin')

        instrText = OxmlElement('w:instrText')
        instrText.set(qn('xml:space'), 'preserve')
        instrText.text = field_instr_text

        fldChar2 = OxmlElement('w:fldChar')
        fldChar2.set(qn('w:fldCharType'), 'separate')

        fldChar3 = OxmlElement('w:fldChar')
        fldChar3.set(qn('w:fldCharType'), 'end')

        r.append(fldChar1)
        r.append(instrText)
        r.append(fldChar2)
        r.append(fldChar3)
    except Exception as e:
        print(f"WARNING: Error adding text field: {e}", file=sys.stderr)


# =============================================================================
# GENERADOR DE ESTILOS BASE
# =============================================================================

class StyleGenerator:
    """Generador de estilos programáticos para documentos DOCX."""

    def __init__(self, doc: Document, colors: Optional[CorporateColors] = None):
        """
        Inicializa el generador de estilos.

        Args:
            doc: Documento python-docx
            colors: Clase de colores corporativos (opcional)

        Raises:
            TypeError: Si doc no es Document
        """
        if not isinstance(doc, Document):
            raise TypeError(f"doc must be Document, got {type(doc)}")

        self.doc = doc
        self.colors = colors or CorporateColors()
        self.styles = doc.styles

    def create_all_styles(self) -> None:
        """Crea todos los estilos necesarios con manejo de errores."""
        try:
            self._configure_page_setup()
        except Exception as e:
            print(f"WARNING: Error configuring page setup: {e}", file=sys.stderr)

        try:
            self._create_normal_style()
        except Exception as e:
            print(f"WARNING: Error creating normal style: {e}", file=sys.stderr)

        try:
            self._create_heading_styles()
        except Exception as e:
            print(f"WARNING: Error creating heading styles: {e}", file=sys.stderr)

        try:
            self._create_code_styles()
        except Exception as e:
            print(f"WARNING: Error creating code styles: {e}", file=sys.stderr)

        try:
            self._create_list_styles()
        except Exception as e:
            print(f"WARNING: Error creating list styles: {e}", file=sys.stderr)

        try:
            self._create_table_style()
        except Exception as e:
            print(f"WARNING: Error creating table style: {e}", file=sys.stderr)

        try:
            self._create_quote_style()
        except Exception as e:
            print(f"WARNING: Error creating quote style: {e}", file=sys.stderr)

        try:
            self._create_caption_style()
        except Exception as e:
            print(f"WARNING: Error creating caption style: {e}", file=sys.stderr)

    def _configure_page_setup(self) -> None:
        """Configura márgenes y orientación de página."""
        for section in self.doc.sections:
            try:
                section.left_margin = Cm(3.0)
                section.right_margin = Cm(2.5)
                section.top_margin = Cm(2.5)
                section.bottom_margin = Cm(2.5)
            except Exception as e:
                print(f"WARNING: Error configuring section: {e}", file=sys.stderr)

    def _create_normal_style(self) -> None:
        """Configura estilo Normal (párrafo base)."""
        try:
            normal = self.styles['Normal']
            normal.font.name = 'Arial'
            normal.font.size = Pt(11)
            normal.font.color.rgb = self.colors.GRIS_OSCURO
            normal.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
            normal.paragraph_format.line_spacing_rule = WD_LINE_SPACING.ONE_POINT_FIVE
            normal.paragraph_format.space_after = Pt(6)
        except Exception as e:
            print(f"WARNING: Error creating Normal style: {e}", file=sys.stderr)

    def _create_heading_styles(self) -> None:
        """Crea estilos de títulos jerárquicos (h1-h6)."""
        heading_configs = [
            ('Heading 1', 16, self.colors.AZUL_CORPORATIVO, True, 18, 10),
            ('Heading 2', 14, self.colors.AZUL_CORPORATIVO, True, 14, 8),
            ('Heading 3', 12, self.colors.AZUL_CORPORATIVO, True, 12, 6),
            ('Heading 4', 11, self.colors.NEGRO, True, 10, 6),
            ('Heading 5', 11, self.colors.NEGRO, True, 8, 4),
            ('Heading 6', 10, self.colors.GRIS_MEDIO, True, 6, 4),
        ]

        for style_name, size, color, bold, space_before, space_after in heading_configs:
            try:
                try:
                    style = self.styles[style_name]
                except KeyError:
                    style = self.styles.add_style(style_name, WD_STYLE_TYPE.PARAGRAPH)

                style.font.name = 'Arial'
                style.font.size = Pt(size)
                style.font.bold = bold
                style.font.color.rgb = color
                style.paragraph_format.space_before = Pt(space_before)
                style.paragraph_format.space_after = Pt(space_after)
                style.paragraph_format.line_spacing_rule = WD_LINE_SPACING.ONE_POINT_FIVE
            except Exception as e:
                print(f"WARNING: Error creating {style_name}: {e}", file=sys.stderr)

    def _create_code_styles(self) -> None:
        """Crea estilos para código (bloque e inline)."""
        try:
            try:
                code_style = self.styles['Code']
            except KeyError:
                code_style = self.styles.add_style('Code', WD_STYLE_TYPE.PARAGRAPH)

            code_style.font.name = 'Courier New'
            code_style.font.size = Pt(9)
            code_style.font.color.rgb = self.colors.GRIS_OSCURO
            code_style.paragraph_format.space_before = Pt(6)
            code_style.paragraph_format.space_after = Pt(6)
            code_style.paragraph_format.left_indent = Cm(1)
        except Exception as e:
            print(f"WARNING: Error creating Code style: {e}", file=sys.stderr)

        try:
            try:
                inline_code = self.styles['Intense Emphasis']
            except KeyError:
                inline_code = self.styles.add_style('Intense Emphasis', WD_STYLE_TYPE.CHARACTER)

            inline_code.font.name = 'Courier New'
            inline_code.font.size = Pt(9)
            inline_code.font.color.rgb = RGBColor(199, 37, 78)
        except Exception as e:
            print(f"WARNING: Error creating Intense Emphasis style: {e}", file=sys.stderr)

    def _create_list_styles(self) -> None:
        """Crea estilos para listas (bullet y numeradas)."""
        try:
            try:
                bullet = self.styles['List Bullet']
            except KeyError:
                bullet = self.styles.add_style('List Bullet', WD_STYLE_TYPE.PARAGRAPH)

            bullet.font.name = 'Arial'
            bullet.font.size = Pt(11)
            bullet.paragraph_format.left_indent = Cm(1.27)
            bullet.paragraph_format.space_after = Pt(3)
        except Exception as e:
            print(f"WARNING: Error creating List Bullet style: {e}", file=sys.stderr)

        try:
            try:
                number = self.styles['List Number']
            except KeyError:
                number = self.styles.add_style('List Number', WD_STYLE_TYPE.PARAGRAPH)

            number.font.name = 'Arial'
            number.font.size = Pt(11)
            number.paragraph_format.left_indent = Cm(1.27)
            number.paragraph_format.space_after = Pt(3)
        except Exception as e:
            print(f"WARNING: Error creating List Number style: {e}", file=sys.stderr)

    def _create_table_style(self) -> None:
        """Crea estilo para tablas."""
        try:
            try:
                table_style = self.styles['Table Grid']
            except KeyError:
                table_style = self.styles.add_style('Table Grid', WD_STYLE_TYPE.TABLE)
        except Exception as e:
            print(f"WARNING: Error creating Table Grid style: {e}", file=sys.stderr)

    def _create_quote_style(self) -> None:
        """Crea estilo para citas (blockquote)."""
        try:
            try:
                quote = self.styles['Quote']
            except KeyError:
                quote = self.styles.add_style('Quote', WD_STYLE_TYPE.PARAGRAPH)

            quote.font.name = 'Arial'
            quote.font.size = Pt(11)
            quote.font.italic = True
            quote.font.color.rgb = self.colors.GRIS_MEDIO
            quote.paragraph_format.left_indent = Cm(2)
            quote.paragraph_format.right_indent = Cm(1)
            quote.paragraph_format.space_before = Pt(6)
            quote.paragraph_format.space_after = Pt(6)
        except Exception as e:
            print(f"WARNING: Error creating Quote style: {e}", file=sys.stderr)

    def _create_caption_style(self) -> None:
        """Crea estilo para pies de imagen/tabla."""
        try:
            try:
                caption = self.styles['Caption']
            except KeyError:
                caption = self.styles.add_style('Caption', WD_STYLE_TYPE.PARAGRAPH)

            caption.font.name = 'Arial'
            caption.font.size = Pt(9)
            caption.font.italic = True
            caption.font.color.rgb = self.colors.GRIS_MEDIO
            caption.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.CENTER
            caption.paragraph_format.space_before = Pt(3)
        except Exception as e:
            print(f"WARNING: Error creating Caption style: {e}", file=sys.stderr)


# =============================================================================
# FUNCIÓN PRINCIPAL DE APLICACIÓN
# =============================================================================

def apply_corporate_styles(
        doc: Document,
        iso_elements: bool = True,
        colors: Optional[CorporateColors] = None
) -> Document:
    """
    Aplica estilos corporativos programáticamente a un documento.

    Args:
        doc: Documento python-docx
        iso_elements: Si True, añade elementos ISO 9001 (portada, header, etc.)
        colors: Clase de colores personalizados (opcional)

    Returns:
        Document con estilos aplicados

    Raises:
        TypeError: Si doc no es Document
    """
    if not isinstance(doc, Document):
        raise TypeError(f"doc must be Document, got {type(doc)}")

    colors = colors or CorporateColors()

    # Generar estilos base
    try:
        generator = StyleGenerator(doc, colors)
        generator.create_all_styles()
    except Exception as e:
        print(f"WARNING: Error applying styles: {e}", file=sys.stderr)

    return doc


# =============================================================================
# FUNCIÓN DE CREACIÓN DE DOCUMENTO CON ESTILOS
# =============================================================================

def create_styled_document(iso_elements=False):
    """
    Crea un nuevo documento con todos los estilos aplicados.

    Args:
        iso_elements: Si True, incluye elementos ISO 9001

    Returns:
        Document nuevo con estilos corporativos
    """
    doc = Document()
    doc.core_properties.title = "Documento con Estilos Corporativos"
    doc.core_properties.author = "Pipeline MD→DOCX"

    return apply_corporate_styles(doc, iso_elements=iso_elements)