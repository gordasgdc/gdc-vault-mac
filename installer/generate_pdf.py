# Genereaza Instructiuni_Utilizare.pdf pentru GDC Vault, RO/EN/ES, cu
# reportlab (nu depinde de un motor de randare HTML/browser headless -
# WKWebView headless in mediul de build nu randeaza nimic, vezi istoricul
# de commit-uri pentru context). Necesita `pip install reportlab pypdf`
# intr-un venv. Ruleaza cu:
#   python3 installer/generate_pdf.py
# Foloseste Arial (nu Helvetica standard-14) pentru ca diacriticele
# romanesti (s-comma, t-comma) nu exista in WinAnsiEncoding-ul fonturilor
# PDF standard - fara asta, ș/ț ies ca patratele goale.
import os
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, ListFlowable, ListItem, PageBreak, HRFlowable
)

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Instructiuni_Utilizare.pdf")

pdfmetrics.registerFont(TTFont("Arial", "/System/Library/Fonts/Supplemental/Arial.ttf"))
pdfmetrics.registerFont(TTFont("Arial-Bold", "/System/Library/Fonts/Supplemental/Arial Bold.ttf"))
styles = getSampleStyleSheet()
ACCENT = colors.HexColor("#0e8a75")
MUTED = colors.HexColor("#6a6a6a")
FAINT = colors.HexColor("#8a8a8a")
NOTE_BG = colors.HexColor("#f2fbf9")
NOTE_BORDER = colors.HexColor("#35d6be")

title_style = ParagraphStyle("TitleGDC", parent=styles["Title"], fontName="Arial-Bold",
                              fontSize=19, leading=22, spaceAfter=2, textColor=colors.HexColor("#1a1a1a"))
subtitle_style = ParagraphStyle("Subtitle", parent=styles["Normal"], fontName="Arial",
                                 fontSize=11, textColor=MUTED, spaceAfter=20)
h2_style = ParagraphStyle("H2", parent=styles["Heading2"], fontName="Arial-Bold",
                           fontSize=13, textColor=ACCENT, spaceBefore=16, spaceAfter=6)
body_style = ParagraphStyle("Body", parent=styles["Normal"], fontName="Arial",
                             fontSize=10.5, leading=15, textColor=colors.HexColor("#1a1a1a"), spaceAfter=6)
li_style = ParagraphStyle("Li", parent=body_style, spaceAfter=4)
note_style = ParagraphStyle("Note", parent=body_style, backColor=NOTE_BG,
                             borderColor=NOTE_BORDER, borderWidth=0, leftIndent=10, fontSize=10)
footer_style = ParagraphStyle("Footer", parent=styles["Normal"], fontName="Arial",
                               fontSize=8.5, textColor=FAINT, spaceBefore=20)


def section(title, items_html, is_note=False):
    flow = [Paragraph(title, h2_style)]
    for it in items_html:
        flow.append(Paragraph(it, body_style))
    return flow


def bullets(items):
    return ListFlowable(
        [ListItem(Paragraph(it, li_style), leftIndent=14) for it in items],
        bulletType="bullet", start="•", leftIndent=14, spaceBefore=2, spaceAfter=8,
    )


def note(text):
    p = Paragraph(text, note_style)
    return p


def page(lang_data):
    flow = []
    flow.append(Paragraph("GDC Vault", title_style))
    flow.append(Paragraph(lang_data["subtitle"], subtitle_style))

    flow.append(Paragraph(lang_data["h_install"], h2_style))
    flow.append(bullets(lang_data["install"]))

    flow.append(Paragraph(lang_data["h_usage"], h2_style))
    flow.append(Paragraph(lang_data["usage_intro"], body_style))
    flow.append(bullets(lang_data["usage"]))

    flow.append(Paragraph(lang_data["h_trial"], h2_style))
    flow.append(Paragraph(lang_data["trial_intro"], body_style))
    flow.append(bullets(lang_data["trial"]))
    flow.append(note(lang_data["trial_note"]))

    flow.append(Paragraph(lang_data["h_uninstall"], h2_style))
    flow.append(Paragraph(lang_data["uninstall"], body_style))

    flow.append(Paragraph(lang_data["h_support"], h2_style))
    flow.append(Paragraph(lang_data["support"], body_style))

    flow.append(Paragraph("GDC Vault — github.com/gordasgdc/gdc-vault-mac", footer_style))
    return flow


RO = dict(
    subtitle="Instrucțiuni de instalare și utilizare — Română",
    h_install="1. Instalare",
    install=[
        "Descarcă și dezarhivează <b>GDCVault-Mac.zip</b> de pe pagina de descărcare sau din secțiunea Releases de pe GitHub.",
        "Dublu-click pe <b>GDCVault.pkg</b> — pachet semnat și notarizat oficial de Apple, se instalează direct, fără avertismente Gatekeeper.",
        "Urmează pașii instalatorului. Va trebui să accepți Termenii și Condițiile pentru a continua.",
        "Aplicația se instalează automat în folderul Applications.",
    ],
    h_usage="2. Folosire rapidă",
    usage_intro="O intrare = un produs, cu tot ce ține de el pe aceeași fișă: cont de login, cheie de serie, dată de expirare, notițe și atașamente.",
    usage=[
        "<b>Adaugă aplicație</b> — buton vizibil în bara laterală, deschide o fișă nouă.",
        "<b>Parolă / Cheie de serie</b> — stocate în Keychain-ul sistemului, niciodată în clar pe disc.",
        "<b>Atașamente</b> — contracte, facturi, capturi — adăugate direct la fișă.",
        "<b>Export/Import</b> — backup criptat AES-256, protejat cu o parolă Master aleasă de tine.",
    ],
    h_trial="3. Trial și activare",
    trial_intro="Aplicația oferă acces complet timp de <b>15 zile</b> de la prima pornire. După expirare, poți în continuare vizualiza și exporta datele existente — doar adăugarea de intrări noi necesită o licență activă.",
    trial=[
        "Apasă „Donează 5€ pentru licență” — se deschide un mesaj WhatsApp cu ID-ul unic al calculatorului tău.",
        "După ce primești codul de licență, lipește-l în fereastra de activare.",
    ],
    trial_note="<b>Important:</b> dacă schimbi calculatorul, scrie din nou pe WhatsApp — codul se regenerează pentru noul ID.",
    h_uninstall="4. Dezinstalare",
    uninstall="Rulează <b>Dezinstalare_GDCVault.command</b> din arhiva descărcată — șterge aplicația, toate fișierele de date și toate secretele din Keychain.",
    h_support="5. Suport",
    support="Pentru orice întrebare, scrie pe WhatsApp (buton în fereastra de activare) sau deschide un Issue pe GitHub.",
)

EN = dict(
    subtitle="Installation and usage instructions — English",
    h_install="1. Installation",
    install=[
        "Download and unzip <b>GDCVault-Mac.zip</b> from the download page or the GitHub Releases section.",
        "Double-click <b>GDCVault.pkg</b> — a package officially signed and notarized by Apple, installs directly with no Gatekeeper warnings.",
        "Follow the installer steps. You'll need to accept the Terms and Conditions to continue.",
        "The app installs automatically into the Applications folder.",
    ],
    h_usage="2. Quick usage",
    usage_intro="One entry = one product, with everything on the same record: login account, serial key, expiration date, notes and attachments.",
    usage=[
        "<b>Add app</b> — button visible in the sidebar, opens a new record.",
        "<b>Password / Serial key</b> — stored in the system Keychain, never in plain text on disk.",
        "<b>Attachments</b> — contracts, invoices, screenshots — attached directly to the record.",
        "<b>Export/Import</b> — AES-256 encrypted backup, protected with a Master password you choose.",
    ],
    h_trial="3. Trial and activation",
    trial_intro="The app offers full access for <b>15 days</b> from the first launch. After that, you can still view and export existing data — only adding new entries requires an active license.",
    trial=[
        "Tap “Donate €5 for a license” — opens a WhatsApp message with your computer's unique ID.",
        "Once you receive the license code, paste it into the activation window.",
    ],
    trial_note="<b>Important:</b> if you switch computers, message WhatsApp again — the code is regenerated for the new ID.",
    h_uninstall="4. Uninstalling",
    uninstall="Run <b>Dezinstalare_GDCVault.command</b> from the downloaded archive — it removes the app, all data files, and all Keychain secrets.",
    h_support="5. Support",
    support="For any question, message WhatsApp (button in the activation window) or open an Issue on GitHub.",
)

ES = dict(
    subtitle="Instrucciones de instalación y uso — Español",
    h_install="1. Instalación",
    install=[
        "Descarga y descomprime <b>GDCVault-Mac.zip</b> desde la página de descarga o la sección Releases de GitHub.",
        "Doble clic en <b>GDCVault.pkg</b> — paquete firmado y notarizado oficialmente por Apple, se instala directamente sin avisos de Gatekeeper.",
        "Sigue los pasos del instalador. Deberás aceptar los Términos y Condiciones para continuar.",
        "La app se instala automáticamente en la carpeta Aplicaciones.",
    ],
    h_usage="2. Uso rápido",
    usage_intro="Una entrada = un producto, con todo en la misma ficha: cuenta de acceso, clave de serie, fecha de caducidad, notas y adjuntos.",
    usage=[
        "<b>Añadir aplicación</b> — botón visible en la barra lateral, abre una ficha nueva.",
        "<b>Contraseña / Clave de serie</b> — almacenadas en el Keychain del sistema, nunca en texto plano en disco.",
        "<b>Adjuntos</b> — contratos, facturas, capturas — añadidos directamente a la ficha.",
        "<b>Exportar/Importar</b> — copia de seguridad cifrada AES-256, protegida con una contraseña Maestra que tú eliges.",
    ],
    h_trial="3. Prueba y activación",
    trial_intro="La app ofrece acceso completo durante <b>15 días</b> desde el primer inicio. Después, puedes seguir viendo y exportando los datos existentes — solo añadir entradas nuevas requiere una licencia activa.",
    trial=[
        "Pulsa “Donar 5€ por la licencia” — se abre un mensaje de WhatsApp con el ID único de tu ordenador.",
        "Cuando recibas el código de licencia, pégalo en la ventana de activación.",
    ],
    trial_note="<b>Importante:</b> si cambias de ordenador, escribe de nuevo por WhatsApp — el código se regenera para el nuevo ID.",
    h_uninstall="4. Desinstalación",
    uninstall="Ejecuta <b>Dezinstalare_GDCVault.command</b> desde el archivo descargado — elimina la app, todos los archivos de datos y todos los secretos del Keychain.",
    h_support="5. Soporte",
    support="Para cualquier pregunta, escribe por WhatsApp (botón en la ventana de activación) o abre un Issue en GitHub.",
)

doc = SimpleDocTemplate(
    OUT, pagesize=A4,
    leftMargin=2 * cm, rightMargin=2 * cm, topMargin=2.2 * cm, bottomMargin=2.2 * cm,
)

story = []
for i, lang in enumerate([RO, EN, ES]):
    story.extend(page(lang))
    if i < 2:
        story.append(PageBreak())

doc.build(story)
print("wrote", OUT)
