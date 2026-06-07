#!/usr/bin/env swift
// MisiQC Pro — Customer Welcome PDF renderer (FR / EN / ES)
// ---------------------------------------------------------------------------
// Generates a branded "Install & License Activation" PDF that customers
// receive with their licence key after purchasing on Payhip. Renders the same
// 3-page guide in 3 languages back-to-back (FR, EN, ES), each section opening
// with the brand logo cover so customers can jump to their language.
//
// Usage:
//   swift scripts/render_customer_pdf.swift
//
// Output:
//   scripts/output/MisiQC-Pro-Guide-Installation.pdf

import Foundation
import AppKit

let projectRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
let outputDir = projectRoot.appendingPathComponent("scripts/output")
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
let pdfURL = outputDir.appendingPathComponent("MisiQC-Pro-Guide-Installation.pdf")

let appVersion = "1.0.4"

// MARK: - Brand colours

let gradientStart = NSColor(calibratedRed: 0.157, green: 0.788, blue: 1.000, alpha: 1)
let gradientMid   = NSColor(calibratedRed: 0.404, green: 0.298, blue: 1.000, alpha: 1)
let gradientEnd   = NSColor(calibratedRed: 1.000, green: 0.224, blue: 0.494, alpha: 1)
let accentBlue    = NSColor(calibratedRed: 0.180, green: 0.475, blue: 0.960, alpha: 1)
let accentMint    = NSColor(calibratedRed: 0.118, green: 0.682, blue: 0.408, alpha: 1)
let accentPeach   = NSColor(calibratedRed: 0.937, green: 0.510, blue: 0.114, alpha: 1)
let primaryText   = NSColor(calibratedWhite: 0.15, alpha: 1)
let secondaryText = NSColor(calibratedWhite: 0.45, alpha: 1)
let mutedBG       = NSColor(calibratedWhite: 0.97, alpha: 1)
let mutedBorder   = NSColor(calibratedWhite: 0.85, alpha: 1)

let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)   // A4 portrait @ 72 dpi
let margin: CGFloat = 48

// MARK: - PDF context

let data = NSMutableData()
guard let consumer = CGDataConsumer(data: data) else { exit(1) }
var mediaBox = pageRect
guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { exit(1) }
let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)

// MARK: - Strings

enum Lang: String { case fr, en, es }

struct Card { let title: String?; let body: String; let accent: NSColor }

struct LangStrings {
    let subtitle: String
    let welcome: String
    let section1: String
    let install: [Card]
    let section2: String
    let activationIntro: String
    let activationSteps: [String]
    let activationResult: Card
    let section3: String
    let knowingBullets: [String]
    let section4: String
    let updatesCard: Card
    let supportCard: Card
    let section5: String
    let terms: [String]
    let signoff: String
    let author: String
    let footerLabel: String
}

let strings: [Lang: LangStrings] = [
    .fr: LangStrings(
        subtitle: "Guide d'installation & activation de licence",
        welcome: "Bienvenue 🎬 — vous voilà équipé du contrôle qualité PAD.",
        section1: "Installation de MisiQC Pro",
        install: [
            Card(title: "Étape 1 — Télécharger l'application",
                 body: "Rendez-vous sur la page de téléchargement officielle :\n\nhttps://github.com/misilab/misiqcpro/releases/latest\n\nCliquez sur le fichier MisiQC-Pro-X.Y.Z.dmg pour récupérer la dernière version (~65 Mo).",
                 accent: accentBlue),
            Card(title: "Étape 2 — Installer dans Applications",
                 body: "Double-cliquez sur le .dmg téléchargé. Une fenêtre apparaît avec MisiQC Pro à gauche et un raccourci Applications à droite. Glissez l'app dans le raccourci Applications. C'est tout.",
                 accent: accentBlue),
            Card(title: "Étape 3 — Premier lancement",
                 body: "Ouvrez MisiQC Pro depuis le dossier Applications ou le Launchpad. L'app est notarisée par Apple — aucune alerte bloquante au premier lancement.",
                 accent: accentMint),
        ],
        section2: "Activer votre licence à vie 🔑",
        activationIntro: "Votre clé de licence vous a été envoyée par email après votre achat sur Payhip. Elle ressemble à : XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX (8 groupes de 5 caractères, soit 47 caractères au total).",
        activationSteps: [
            "Lancez MisiQC Pro.",
            "Menu MisiQC Pro → Réglages… (ou ⌘ ,).",
            "Cliquez sur l'onglet 🔑 Licence.",
            "Copiez la clé entière depuis l'email (⌘C).",
            "Collez (⌘V) dans le champ « Clé reçue par email ». Le compteur sous le champ doit afficher 40 / 40 en vert.",
            "Cliquez sur Activer.",
        ],
        activationResult: Card(title: "Résultat attendu",
                               body: "✅ « Merci ! Licence à vie active. » Le bandeau d'essai disparaît automatiquement et tous les exports (PDF rapport, CSV, guide de correction) sont débloqués.",
                               accent: accentMint),
        section3: "Important à savoir",
        knowingBullets: [
            "Licence à vie — votre clé n'expire jamais. Les mises à jour majeures sont incluses.",
            "Multi-Mac — la clé est valable sur tous vos Macs personnels.",
            "Stockage sécurisé — la clé est conservée dans votre Trousseau macOS.",
            "Traçabilité — le nom de votre Mac + les 5 premiers caractères de votre clé apparaissent discrètement en pied de page des rapports PDF, pour décourager le partage non autorisé.",
        ],
        section4: "Mises à jour & support",
        updatesCard: Card(title: "Mises à jour automatiques",
                          body: "MisiQC Pro vérifie automatiquement les mises à jour au lancement. Vous pouvez aussi forcer la vérification via le menu MisiQC Pro → Vérifier les mises à jour…",
                          accent: accentBlue),
        supportCard: Card(title: "Support",
                          body: "Une question, un bug, une demande de fonctionnalité ?\nContact : contact@misiraca.com — Site : www.misiraca.com\n\nPour les bugs : précisez la version (Menu MisiQC Pro → À propos), votre version de macOS, une description et idéalement un fichier exemple.",
                          accent: accentBlue),
        section5: "Conditions de licence",
        terms: [
            "✅ Usage personnel et professionnel illimité sur vos Macs.",
            "✅ Génération de rapports PDF / CSV illimitée.",
            "✅ Mises à jour gratuites à vie.",
            "❌ Revente, partage ou distribution de la clé interdits.",
            "❌ Reverse-engineering interdit.",
            "Le partage non autorisé d'une clé peut être tracé via les rapports PDF générés.",
        ],
        signoff: "Merci pour votre confiance, et bons contrôles qualité !",
        author: "— Matthieu Misiraca, développeur de MisiQC Pro",
        footerLabel: "Guide d'installation"
    ),

    .en: LangStrings(
        subtitle: "Install & license activation guide",
        welcome: "Welcome 🎬 — you're all set for PAD quality control.",
        section1: "Installing MisiQC Pro",
        install: [
            Card(title: "Step 1 — Download the app",
                 body: "Go to the official download page:\n\nhttps://github.com/misilab/misiqcpro/releases/latest\n\nClick on the MisiQC-Pro-X.Y.Z.dmg file to download the latest version (~65 MB).",
                 accent: accentBlue),
            Card(title: "Step 2 — Install in Applications",
                 body: "Double-click the downloaded .dmg. A window appears with MisiQC Pro on the left and an Applications shortcut on the right. Drag the app onto the Applications shortcut. Done.",
                 accent: accentBlue),
            Card(title: "Step 3 — First launch",
                 body: "Open MisiQC Pro from the Applications folder or Launchpad. The app is notarized by Apple — no blocking alert on first launch.",
                 accent: accentMint),
        ],
        section2: "Activate your lifetime licence 🔑",
        activationIntro: "Your licence key was emailed to you after your purchase on Payhip. It looks like: XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX (8 groups of 5 characters, 47 characters total).",
        activationSteps: [
            "Launch MisiQC Pro.",
            "Menu MisiQC Pro → Settings… (or ⌘ ,).",
            "Click the 🔑 License tab.",
            "Copy the full key from the email (⌘C).",
            "Paste (⌘V) into the « License key (from email) » field. The counter under the field should read 40 / 40 in green.",
            "Click Activate.",
        ],
        activationResult: Card(title: "Expected result",
                               body: "✅ « Thanks! Lifetime license active. » The trial banner disappears automatically and all exports (PDF report, CSV, remediation guide) are unlocked.",
                               accent: accentMint),
        section3: "Good to know",
        knowingBullets: [
            "Lifetime licence — your key never expires. Major updates are included.",
            "Multi-Mac — the key is valid on all your personal Macs.",
            "Secure storage — the key is stored in your macOS Keychain.",
            "Traceability — your Mac name and the first 5 characters of your key appear discreetly in the footer of PDF reports, to discourage unauthorised sharing.",
        ],
        section4: "Updates & support",
        updatesCard: Card(title: "Automatic updates",
                          body: "MisiQC Pro checks for updates automatically at launch. You can also force a check via menu MisiQC Pro → Check for Updates…",
                          accent: accentBlue),
        supportCard: Card(title: "Support",
                          body: "A question, a bug, a feature request?\nContact: contact@misiraca.com — Site: www.misiraca.com\n\nFor bugs, please specify the version (Menu MisiQC Pro → About), your macOS version, a description and ideally a sample file.",
                          accent: accentBlue),
        section5: "Licence terms",
        terms: [
            "✅ Unlimited personal and professional use on your Macs.",
            "✅ Unlimited PDF / CSV report generation.",
            "✅ Free updates for life.",
            "❌ Resale, sharing or distribution of the key is forbidden.",
            "❌ Reverse-engineering is forbidden.",
            "Unauthorised key sharing may be traced via the generated PDF reports.",
        ],
        signoff: "Thank you for your trust, and happy quality-checking!",
        author: "— Matthieu Misiraca, developer of MisiQC Pro",
        footerLabel: "Installation guide"
    ),

    .es: LangStrings(
        subtitle: "Guía de instalación y activación de licencia",
        welcome: "Bienvenido 🎬 — listo para el control de calidad PAD.",
        section1: "Instalación de MisiQC Pro",
        install: [
            Card(title: "Paso 1 — Descargar la aplicación",
                 body: "Ve a la página de descarga oficial:\n\nhttps://github.com/misilab/misiqcpro/releases/latest\n\nHaz clic en el archivo MisiQC-Pro-X.Y.Z.dmg para obtener la última versión (~65 MB).",
                 accent: accentBlue),
            Card(title: "Paso 2 — Instalar en Aplicaciones",
                 body: "Haz doble clic en el .dmg descargado. Aparece una ventana con MisiQC Pro a la izquierda y un acceso directo Aplicaciones a la derecha. Arrastra la app al acceso directo Aplicaciones. Eso es todo.",
                 accent: accentBlue),
            Card(title: "Paso 3 — Primer lanzamiento",
                 body: "Abre MisiQC Pro desde la carpeta Aplicaciones o desde Launchpad. La app está notarizada por Apple — sin ninguna alerta bloqueante al primer arranque.",
                 accent: accentMint),
        ],
        section2: "Activa tu licencia de por vida 🔑",
        activationIntro: "Tu clave de licencia te fue enviada por correo electrónico tras la compra en Payhip. Se parece a: XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX (8 grupos de 5 caracteres, 47 caracteres en total).",
        activationSteps: [
            "Inicia MisiQC Pro.",
            "Menú MisiQC Pro → Ajustes… (o ⌘ ,).",
            "Haz clic en la pestaña 🔑 Licencia.",
            "Copia la clave completa desde el correo (⌘C).",
            "Pega (⌘V) en el campo « Clave de licencia (del email) ». El contador bajo el campo debe mostrar 40 / 40 en verde.",
            "Haz clic en Activar.",
        ],
        activationResult: Card(title: "Resultado esperado",
                               body: "✅ « ¡Gracias! Licencia de por vida activa. » El banner de prueba desaparece automáticamente y se desbloquean todas las exportaciones (PDF, CSV, guía de corrección).",
                               accent: accentMint),
        section3: "Importante saberlo",
        knowingBullets: [
            "Licencia de por vida — tu clave nunca caduca. Las actualizaciones mayores están incluidas.",
            "Multi-Mac — la clave es válida en todos tus Macs personales.",
            "Almacenamiento seguro — la clave se guarda en el Llavero de macOS.",
            "Trazabilidad — el nombre de tu Mac y los 5 primeros caracteres de tu clave aparecen discretamente en el pie de página de los PDF generados, para desalentar el uso compartido no autorizado.",
        ],
        section4: "Actualizaciones y soporte",
        updatesCard: Card(title: "Actualizaciones automáticas",
                          body: "MisiQC Pro busca actualizaciones automáticamente al inicio. También puedes forzar la búsqueda desde el menú MisiQC Pro → Buscar actualizaciones…",
                          accent: accentBlue),
        supportCard: Card(title: "Soporte",
                          body: "¿Pregunta, error o solicitud de función?\nContacto: contact@misiraca.com — Web: www.misiraca.com\n\nPara los errores: indica la versión (Menú MisiQC Pro → Acerca de), tu versión de macOS, una descripción y, si es posible, un archivo de ejemplo.",
                          accent: accentBlue),
        section5: "Términos de la licencia",
        terms: [
            "✅ Uso personal y profesional ilimitado en tus Macs.",
            "✅ Generación ilimitada de informes PDF / CSV.",
            "✅ Actualizaciones gratuitas de por vida.",
            "❌ Está prohibido revender, compartir o distribuir la clave.",
            "❌ Está prohibida la ingeniería inversa.",
            "El uso compartido no autorizado de una clave puede rastrearse mediante los informes PDF generados.",
        ],
        signoff: "¡Gracias por tu confianza y feliz control de calidad!",
        author: "— Matthieu Misiraca, desarrollador de MisiQC Pro",
        footerLabel: "Guía de instalación"
    ),
]

// MARK: - Drawing helpers

func drawString(_ s: String, at point: CGPoint, font: NSFont,
                color: NSColor = primaryText, maxWidth: CGFloat? = nil) {
    if let maxWidth {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color, .paragraphStyle: style
        ]
        let rect = CGRect(x: point.x, y: point.y, width: maxWidth, height: 2000)
        (s as NSString).draw(in: rect, withAttributes: attrs)
    } else {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        (s as NSString).draw(at: point, withAttributes: attrs)
    }
}

func drawDownward(_ s: String, x: CGFloat, topY: CGFloat, width: CGFloat,
                  font: NSFont, color: NSColor, lineHeight: CGFloat) -> CGFloat {
    let style = NSMutableParagraphStyle()
    style.lineBreakMode = .byWordWrapping
    style.minimumLineHeight = lineHeight
    style.maximumLineHeight = lineHeight
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: color, .paragraphStyle: style
    ]
    let bounds = (s as NSString).boundingRect(
        with: CGSize(width: width, height: 5000),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: attrs
    )
    let height = ceil(bounds.height) + 2
    let rect = CGRect(x: x, y: topY - height, width: width, height: height)
    (s as NSString).draw(in: rect, withAttributes: attrs)
    return height
}

func stringHeight(_ s: String, font: NSFont, width: CGFloat,
                  lineHeight: CGFloat) -> CGFloat {
    let style = NSMutableParagraphStyle()
    style.lineBreakMode = .byWordWrapping
    style.minimumLineHeight = lineHeight
    style.maximumLineHeight = lineHeight
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: style]
    return ceil((s as NSString).boundingRect(
        with: CGSize(width: width, height: 5000),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: attrs).height) + 2
}

// MARK: - Brand logo (Core Graphics, mirrors DesignSystem/BrandLogo)

func drawBrandLogo(in rect: CGRect) {
    let pixelSize = max(64, Int(rect.width * 4))
    let image = brandLogoImage(pixelSize: pixelSize)
    image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
}

func brandLogoImage(pixelSize: Int) -> NSImage {
    let size = CGFloat(pixelSize)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixelSize, pixelsHigh: pixelSize,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 4 * pixelSize, bitsPerPixel: 32
    ) else { return NSImage(size: NSSize(width: 1, height: 1)) }
    NSGraphicsContext.saveGraphicsState()
    guard let nsCtx = NSGraphicsContext(bitmapImageRep: bitmap) else {
        NSGraphicsContext.restoreGraphicsState()
        return NSImage(size: NSSize(width: 1, height: 1))
    }
    NSGraphicsContext.current = nsCtx
    let ctx = nsCtx.cgContext
    let radius = size * 0.225
    let bgPath = CGPath(roundedRect: CGRect(x: 0, y: 0, width: size, height: size),
                        cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.saveGState(); ctx.addPath(bgPath); ctx.clip()
    let colorspace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        CGColor(red: 0.157, green: 0.788, blue: 1.0, alpha: 1),
        CGColor(red: 0.404, green: 0.298, blue: 1.0, alpha: 1),
        CGColor(red: 1.0,   green: 0.224, blue: 0.494, alpha: 1)
    ] as CFArray
    let gradient = CGGradient(colorsSpace: colorspace, colors: colors,
                              locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size),
                           end: CGPoint(x: size, y: 0), options: [])
    let hl = CGGradient(colorsSpace: colorspace, colors: [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.4),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0)
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(hl, start: CGPoint(x: 0, y: size),
                           end: CGPoint(x: 0, y: size * 0.5), options: [])
    ctx.restoreGState()
    let lineWidth = size * 0.105
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.setLineWidth(lineWidth)
    ctx.setLineCap(.round); ctx.setLineJoin(.round)
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x * size, y: (1.0 - y) * size)
    }
    let amp: CGFloat = 0.085, yMid: CGFloat = 0.50
    ctx.beginPath()
    ctx.move(to: p(0.12, yMid))
    ctx.addQuadCurve(to: p(0.22, yMid), control: p(0.17, yMid - amp))
    ctx.addQuadCurve(to: p(0.32, yMid), control: p(0.27, yMid + amp))
    ctx.addQuadCurve(to: p(0.42, yMid), control: p(0.37, yMid - amp))
    ctx.addLine(to: p(0.53, 0.72))
    ctx.addLine(to: p(0.86, 0.28))
    ctx.strokePath()
    NSGraphicsContext.restoreGraphicsState()
    let image = NSImage(size: NSSize(width: size, height: size))
    image.addRepresentation(bitmap)
    return image
}

// MARK: - Page elements

func drawCoverHeader(s: LangStrings, langCode: String, startY: CGFloat) -> CGFloat {
    let bandHeight: CGFloat = 200
    let bandRect = CGRect(x: 0, y: pageRect.height - bandHeight,
                          width: pageRect.width, height: bandHeight)
    let cs = CGColorSpaceCreateDeviceRGB()
    let grad = CGGradient(colorsSpace: cs, colors: [
        gradientStart.cgColor, gradientMid.cgColor, gradientEnd.cgColor
    ] as CFArray, locations: [0, 0.55, 1])!
    ctx.saveGState()
    ctx.addRect(bandRect); ctx.clip()
    ctx.drawLinearGradient(grad,
                           start: CGPoint(x: 0, y: bandRect.maxY),
                           end: CGPoint(x: bandRect.width, y: bandRect.minY),
                           options: [])
    ctx.restoreGState()

    let logoSize: CGFloat = 84
    let logoY = bandRect.maxY - 30 - logoSize
    drawBrandLogo(in: CGRect(x: margin, y: logoY, width: logoSize, height: logoSize))

    drawString("MisiQC Pro",
               at: CGPoint(x: margin + logoSize + 18,
                           y: logoY + logoSize - 38),
               font: .systemFont(ofSize: 30, weight: .heavy),
               color: .white)
    drawString(s.subtitle,
               at: CGPoint(x: margin + logoSize + 18,
                           y: logoY + logoSize - 62),
               font: .systemFont(ofSize: 12.5, weight: .medium),
               color: NSColor(calibratedWhite: 1, alpha: 0.85),
               maxWidth: pageRect.width - (margin + logoSize + 18) - margin)

    // Language chip on top-right
    let chipText = langCode.uppercased()
    let chipFont = NSFont.systemFont(ofSize: 11, weight: .heavy)
    let chipSize = (chipText as NSString).size(withAttributes: [.font: chipFont])
    let chipPad: CGFloat = 8
    let chipW = chipSize.width + chipPad * 2
    let chipH: CGFloat = 22
    let chipRect = CGRect(x: pageRect.width - margin - chipW,
                          y: bandRect.maxY - 28 - chipH,
                          width: chipW, height: chipH)
    NSColor(calibratedWhite: 1, alpha: 0.22).setFill()
    NSBezierPath(roundedRect: chipRect, xRadius: chipH/2, yRadius: chipH/2).fill()
    drawString(chipText,
               at: CGPoint(x: chipRect.minX + chipPad,
                           y: chipRect.midY - chipSize.height/2),
               font: chipFont, color: .white)

    drawString(s.welcome,
               at: CGPoint(x: margin, y: bandRect.minY + 20),
               font: .systemFont(ofSize: 11, weight: .medium),
               color: NSColor(calibratedWhite: 1, alpha: 0.85),
               maxWidth: pageRect.width - margin * 2)
    return bandRect.minY - 28
}

func drawSectionHeader(_ title: String, number: Int, at y: CGFloat) -> CGFloat {
    let chipSize: CGFloat = 22
    let chipRect = CGRect(x: margin, y: y - chipSize, width: chipSize, height: chipSize)
    accentBlue.setFill()
    NSBezierPath(ovalIn: chipRect).fill()
    drawString("\(number)",
               at: CGPoint(x: chipRect.midX - 4, y: chipRect.midY - 7),
               font: .systemFont(ofSize: 12, weight: .heavy),
               color: .white)
    drawString(title,
               at: CGPoint(x: chipRect.maxX + 10, y: y - 18),
               font: .systemFont(ofSize: 15, weight: .heavy),
               color: primaryText)
    return y - 30
}

func drawCard(_ card: Card, atTopY y: CGFloat) -> CGFloat {
    let innerWidth = pageRect.width - margin * 2 - 24
    let bodyHeight = stringHeight(card.body, font: .systemFont(ofSize: 10.5),
                                  width: innerWidth, lineHeight: 14)
    let titleHeight: CGFloat = card.title != nil ? 18 : 0
    let pad: CGFloat = 14
    let totalHeight = titleHeight + bodyHeight + pad * 2
    let rect = CGRect(x: margin, y: y - totalHeight,
                      width: pageRect.width - margin * 2, height: totalHeight)
    mutedBG.setFill()
    NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
    mutedBorder.setStroke()
    let border = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
    border.lineWidth = 0.5
    border.stroke()
    card.accent.withAlphaComponent(0.9).setFill()
    NSBezierPath(rect: CGRect(x: rect.minX, y: rect.minY,
                              width: 3, height: rect.height)).fill()

    var cursorY = rect.maxY - pad
    if let title = card.title {
        drawString(title,
                   at: CGPoint(x: rect.minX + pad + 6, y: cursorY - 12),
                   font: .systemFont(ofSize: 11, weight: .heavy),
                   color: card.accent)
        cursorY -= titleHeight
    }
    _ = drawDownward(card.body, x: rect.minX + pad + 6, topY: cursorY,
                     width: innerWidth - 6,
                     font: .systemFont(ofSize: 10.5),
                     color: primaryText, lineHeight: 14)
    return rect.minY - 14
}

func drawBullet(_ text: String, atTopY y: CGFloat) -> CGFloat {
    let bx = margin + 32
    let bullet = "•"
    drawString(bullet, at: CGPoint(x: bx, y: y - 12),
               font: .systemFont(ofSize: 11, weight: .bold), color: accentBlue)
    let h = drawDownward(text, x: bx + 12, topY: y,
                         width: pageRect.width - bx - 12 - margin,
                         font: .systemFont(ofSize: 10.5),
                         color: primaryText, lineHeight: 14)
    return y - h - 4
}

func startNewPage() -> CGFloat {
    ctx.beginPDFPage(nil)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx
    return pageRect.height
}

func endPage(footerLabel: String, footerNumber: Int) {
    let footer = "MisiQC Pro v\(appVersion) · \(footerLabel) · contact@misiraca.com · \(footerNumber)"
    let f = NSFont.systemFont(ofSize: 8, weight: .medium)
    let w = (footer as NSString).size(withAttributes: [.font: f]).width
    drawString(footer,
               at: CGPoint(x: (pageRect.width - w) / 2, y: 18),
               font: f, color: secondaryText)
    NSColor(calibratedWhite: 0.88, alpha: 1).setStroke()
    let sep = NSBezierPath()
    sep.move(to: CGPoint(x: margin, y: 36))
    sep.line(to: CGPoint(x: pageRect.width - margin, y: 36))
    sep.lineWidth = 0.4
    sep.stroke()
    NSGraphicsContext.restoreGraphicsState()
    ctx.endPDFPage()
}

// MARK: - Render one language section (3 pages)

var totalPage = 0

func renderLanguageSection(_ lang: Lang) {
    guard let s = strings[lang] else { return }
    let langCode = lang.rawValue

    // ===== Page 1: Cover + Installation =====
    totalPage += 1
    var y = startNewPage()
    y = drawCoverHeader(s: s, langCode: langCode, startY: y)

    y = drawSectionHeader(s.section1, number: 1, at: y)
    for card in s.install { y = drawCard(card, atTopY: y) }
    endPage(footerLabel: s.footerLabel, footerNumber: totalPage)

    // ===== Page 2: Activation =====
    totalPage += 1
    y = startNewPage()
    y -= margin
    y = drawSectionHeader(s.section2, number: 2, at: y)
    y = drawCard(Card(title: nil, body: s.activationIntro, accent: accentMint),
                 atTopY: y)
    for step in s.activationSteps { y = drawBullet(step, atTopY: y) }
    y -= 8
    y = drawCard(s.activationResult, atTopY: y)
    y = drawSectionHeader(s.section3, number: 3, at: y)
    for k in s.knowingBullets { y = drawBullet(k, atTopY: y) }
    endPage(footerLabel: s.footerLabel, footerNumber: totalPage)

    // ===== Page 3: Updates + support + terms + sign-off =====
    totalPage += 1
    y = startNewPage()
    y -= margin
    y = drawSectionHeader(s.section4, number: 4, at: y)
    y = drawCard(s.updatesCard, atTopY: y)
    y = drawCard(s.supportCard, atTopY: y)
    y = drawSectionHeader(s.section5, number: 5, at: y)
    for t in s.terms { y = drawBullet(t, atTopY: y) }
    y -= 24
    drawString(s.signoff,
               at: CGPoint(x: margin, y: y - 14),
               font: .systemFont(ofSize: 13, weight: .heavy),
               color: primaryText,
               maxWidth: pageRect.width - margin * 2)
    drawString(s.author,
               at: CGPoint(x: margin, y: y - 32),
               font: .systemFont(ofSize: 11, weight: .medium),
               color: secondaryText,
               maxWidth: pageRect.width - margin * 2)
    endPage(footerLabel: s.footerLabel, footerNumber: totalPage)
}

// MARK: - Build the PDF

for lang in [Lang.fr, .en, .es] {
    renderLanguageSection(lang)
}

ctx.closePDF()
try (data as Data).write(to: pdfURL)
print("✅ \(pdfURL.lastPathComponent) generated (\(totalPage) pages) at \(pdfURL.path)")
