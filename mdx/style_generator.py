#!/usr/bin/env python3
"""
Generador programático de estilos ISO 9001:2015 para DOCX.

Este módulo crea todos los estilos necesarios directamente en código,
eliminando la necesidad de plantillas Word externas.
"""

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

def set_cell_shading(cell, hex_color):
    """Aplica color de fondo a celda de tabla."""
    cell._tc.get_or_add_tcPr().append(
        parse_xml(r'<w:shd {} w:fill="{}"/>'.format(nsdecls('w'), hex_color))
    )


def add_divider(container, color_hex, height_pt=2):
    """Añade línea divisoria horizontal."""
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


def add_text_field(run, field_instr_text):
    """Añade campo de texto dinámico (fecha, página, etc.)."""
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


# =============================================================================
# GENERADOR DE ESTILOS BASE
# =============================================================================

class StyleGenerator:
    """Generador de estilos programáticos para documentos DOCX."""

    def __init__(self, doc: Document, colors=None):
        """
        Inicializa el generador de estilos.

        Args:
            doc: Documento python-docx
            colors: Clase de colores corporativos (opcional)
        """
        self.doc = doc
        self.colors = colors or CorporateColors()
        self.styles = doc.styles

    def create_all_styles(self):
        """Crea todos los estilos necesarios."""
        self._configure_page_setup()
        self._create_normal_style()
        self._create_heading_styles()
        self._create_code_styles()
        self._create_list_styles()
        self._create_table_style()
        self._create_quote_style()
        self._create_caption_style()

    def _configure_page_setup(self):
        """Configura márgenes y orientación de página."""
        for section in self.doc.sections:
            section.left_margin = Cm(3.0)
            section.right_margin = Cm(2.5)
            section.top_margin = Cm(2.5)
            section.bottom_margin = Cm(2.5)

    def _create_normal_style(self):
        """Configura estilo Normal (párrafo base)."""
        normal = self.styles['Normal']
        normal.font.name = 'Arial'
        normal.font.size = Pt(11)
        normal.font.color.rgb = self.colors.GRIS_OSCURO
        normal.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
        normal.paragraph_format.line_spacing_rule = WD_LINE_SPACING.ONE_POINT_FIVE
        normal.paragraph_format.space_after = Pt(6)

    def _create_heading_styles(self):
        """Crea estilos de títulos jerárquicos (h1-h6)."""
        heading_configs = [
            # (style_name, size_pt, color, bold, space_before, space_after)
            ('Heading 1', 16, self.colors.AZUL_CORPORATIVO, True, 18, 10),
            ('Heading 2', 14, self.colors.AZUL_CORPORATIVO, True, 14, 8),
            ('Heading 3', 12, self.colors.AZUL_CORPORATIVO, True, 12, 6),
            ('Heading 4', 11, self.colors.NEGRO, True, 10, 6),
            ('Heading 5', 11, self.colors.NEGRO, True, 8, 4),
            ('Heading 6', 10, self.colors.GRIS_MEDIO, True, 6, 4),
        ]

        for style_name, size, color, bold, space_before, space_after in heading_configs:
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

    def _create_code_styles(self):
        """Crea estilos para código (bloque e inline)."""
        # Estilo de bloque de código
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

        # Estilo de código inline
        try:
            inline_code = self.styles['Intense Emphasis']
        except KeyError:
            inline_code = self.styles.add_style('Intense Emphasis', WD_STYLE_TYPE.CHARACTER)

        inline_code.font.name = 'Courier New'
        inline_code.font.size = Pt(9)
        inline_code.font.color.rgb = RGBColor(199, 37, 78)  # Rojo oscuro

    def _create_list_styles(self):
        """Crea estilos para listas (bullet y numeradas)."""
        # Lista con viñetas
        try:
            bullet = self.styles['List Bullet']
        except KeyError:
            bullet = self.styles.add_style('List Bullet', WD_STYLE_TYPE.PARAGRAPH)

        bullet.font.name = 'Arial'
        bullet.font.size = Pt(11)
        bullet.paragraph_format.left_indent = Cm(1.27)
        bullet.paragraph_format.space_after = Pt(3)

        # Lista numerada
        try:
            number = self.styles['List Number']
        except KeyError:
            number = self.styles.add_style('List Number', WD_STYLE_TYPE.PARAGRAPH)

        number.font.name = 'Arial'
        number.font.size = Pt(11)
        number.paragraph_format.left_indent = Cm(1.27)
        number.paragraph_format.space_after = Pt(3)

    def _create_table_style(self):
        """Crea estilo para tablas."""
        try:
            table_style = self.styles['Table Grid']
        except KeyError:
            table_style = self.styles.add_style('Table Grid', WD_STYLE_TYPE.TABLE)

        # Las propiedades específicas de tabla se aplican al crearla
        # Aquí solo aseguramos que el estilo existe

    def _create_quote_style(self):
        """Crea estilo para citas (blockquote)."""
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

    def _create_caption_style(self):
        """Crea estilo para pies de imagen/tabla."""
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


# =============================================================================
# GENERADOR DE ELEMENTOS ISO 9001
# =============================================================================

class ISO9001Generator:
    """Generador de elementos específicos de ISO 9001:2015."""

    def __init__(self, doc: Document, colors=None):
        self.doc = doc
        self.colors = colors or CorporateColors()

    def add_cover_band(self, text="SISTEMA DE GESTIÓN DE LA CALIDAD – ISO 9001:2015"):
        """Añade franja de portada."""
        table = self.doc.add_table(rows=1, cols=1)
        cell = table.cell(0, 0)
        set_cell_shading(cell, self.colors.AZUL_HEX)

        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER

        run = p.add_run(text)
        run.font.color.rgb = self.colors.BLANCO
        run.font.size = Pt(16)
        run.font.bold = True

    def add_header_footer(self, doc_code="PR-SGC-01", version="1.0", title="Manual de Procedimientos SGC"):
        """Añade encabezado y pie de página ISO."""
        section = self.doc.sections[0]

        # Encabezado
        header = section.header
        table_h = header.add_table(rows=1, cols=3, width=Inches(6))
        h0, h1, h2 = table_h.rows[0].cells

        h0.text = "[ LOGO ]"
        h0.paragraphs[0].alignment = WD_ALIGN_PARAGRAPH.LEFT

        p1 = h1.paragraphs[0]
        p1.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p1.add_run(title).bold = True

        p2 = h2.paragraphs[0]
        p2.alignment = WD_ALIGN_PARAGRAPH.RIGHT
        p2.add_run(f"{doc_code} | Ver. {version} | ")
        add_text_field(p2.add_run(), r'DATE \@ "d \'de\' MMMM \'de\' yyyy"')

        add_divider(header, self.colors.AZUL_HEX, 2)

        # Pie de página
        footer = section.footer
        table_f = footer.add_table(rows=1, cols=3, width=Inches(6))
        f0, f1, f2 = table_f.rows[0].cells

        f0.paragraphs[0].add_run("SGC – ISO 9001:2015")

        pf = f1.paragraphs[0]
        pf.alignment = WD_ALIGN_PARAGRAPH.CENTER
        pf.add_run("Página ")
        add_text_field(pf.add_run(), "PAGE")
        pf.add_run(" de ")
        add_text_field(pf.add_run(), "NUMPAGES")

        f2.paragraphs[0].alignment = WD_ALIGN_PARAGRAPH.RIGHT
        f2.paragraphs[0].add_run("Organización/Proyecto")

        add_divider(footer, self.colors.AZUL_HEX, 2)

    def add_identification_table(self, data=None):
        """Añade tabla de identificación documental."""
        default_data = {
            "Código del documento:": "PR-SGC-01",
            "Versión:": "1.0",
            "Fecha de emisión:": "",
            "Estado:": "VIGENTE",
            "Próxima revisión:": "",
            "Elaboró:": "Analista de Sistemas",
            "Revisó:": "Coordinadora de Calidad",
            "Aprobó:": "Gerente de Operaciones",
            "Distribución:": "Dirección, Calidad, TI",
            "Sustituye a:": "Versión anterior",
        }

        data = data or default_data

        self.doc.add_paragraph("IDENTIFICACIÓN DOCUMENTAL", style='Heading 2')

        table = self.doc.add_table(rows=len(data), cols=2)
        table.style = 'Table Grid'

        for i, (key, value) in enumerate(data.items()):
            table.cell(i, 0).text = key

            if "Fecha" in key:
                add_text_field(
                    table.cell(i, 1).paragraphs[0].add_run(),
                    r'DATE \@ "d \'de\' MMMM \'de\' yyyy"'
                )
            else:
                table.cell(i, 1).text = value

    def add_change_control_table(self):
        """Añade tabla de control de cambios."""
        self.doc.add_paragraph("CONTROL DE CAMBIOS (ISO 7.5.3.2)", style='Heading 2')

        table = self.doc.add_table(rows=2, cols=5)
        table.style = 'Table Grid'

        headers = ["Versión", "Fecha", "Descripción del cambio", "Elaboró", "Aprobó"]
        for j, header in enumerate(headers):
            cell = table.cell(0, j)
            cell.text = header
            set_cell_shading(cell, self.colors.AZUL_HEX)

            for run in cell.paragraphs[0].runs:
                run.font.color.rgb = self.colors.BLANCO
                run.font.bold = True

        # Fila de ejemplo
        table.cell(1, 0).text = "1.0"
        add_text_field(
            table.cell(1, 1).paragraphs[0].add_run(),
            r'DATE \@ "d \'de\' MMMM \'de\' yyyy"'
        )
        table.cell(1, 2).text = "Emisión inicial del documento"
        table.cell(1, 3).text = "Usuario"
        table.cell(1, 4).text = "Aprobador"


# =============================================================================
# FUNCIÓN PRINCIPAL DE APLICACIÓN
# =============================================================================

def apply_corporate_styles(doc: Document, iso_elements=True, colors=None):
    """
    Aplica estilos corporativos programáticamente a un documento.

    Args:
        doc: Documento python-docx
        iso_elements: Si True, añade elementos ISO 9001 (portada, header, etc.)
        colors: Clase de colores personalizados (opcional)

    Returns:
        Document con estilos aplicados
    """
    colors = colors or CorporateColors()

    # Generar estilos base
    generator = StyleGenerator(doc, colors)
    generator.create_all_styles()

    # Añadir elementos ISO si se solicita
    if iso_elements:
        iso_gen = ISO9001Generator(doc, colors)
        # Los elementos ISO se añaden bajo demanda, no automáticamente
        # Para evitar duplicados en cada conversión

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