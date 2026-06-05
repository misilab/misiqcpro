import Foundation

/// Static catalogue of remediation recipes: how to fix every failing check
/// inside the major mastering / NLE applications. Trilingual (FR/EN/ES).
enum RemediationCatalog {

    /// Resolves the localised remediation card for a single check.
    static func guide(for check: Check, locale: AppLocale) -> LocalizedRemediationGuide? {
        guard let key = remediationKey(for: check, locale: locale),
              let g = guides[key] else { return nil }
        return LocalizedRemediationGuide(g, locale: locale)
    }

    /// All distinct remediation guides referenced by failing checks in the report.
    static func guides(for report: QCReport)
    -> [(Check, LocalizedRemediationGuide)] {
        var seen = Set<RemediationKey>()
        var out: [(Check, LocalizedRemediationGuide)] = []
        let failing = report.checks.filter { $0.status != .pass }
        for check in failing {
            guard let key = remediationKey(for: check, locale: report.locale),
                  let g = guides[key], !seen.contains(key) else { continue }
            seen.insert(key)
            out.append((check, LocalizedRemediationGuide(g, locale: report.locale)))
        }
        return out
    }

    // MARK: - Key resolution

    private static let labelToKey: [(L10n.Key, RemediationKey)] = [
        (.lblContainer,        .container),
        (.lblOP,               .operationalPattern),
        (.lblVideoCodec,       .videoCodec),
        (.lblVideoProfile,     .videoProfile),
        (.lblResolution,       .resolution),
        (.lblFramerate,        .framerate),
        (.lblInterlace,        .interlace),
        (.lblVideoBitrate,     .videoBitrate),
        (.lblColorSpace,       .colorSpace),
        (.lblColorPrimaries,   .colorPrimaries),
        (.lblColorTransfer,    .colorTransfer),
        (.lblColorRange,       .colorRange),
        (.lblAspectRatio,      .aspectRatio),
        (.lblGopStructure,     .gopStructure),
        (.lblSignalRange,      .signalRange),
        (.lblFreeze,           .freeze),
        (.lblDuplicateFrames,  .duplicates),
        (.lblStuckPixels,      .stuckPixels),
        (.lblPSE,              .pse),
        (.lblAudioChannels,    .audioChannels),
        (.lblAudioCodec,       .audioCodec),
        (.lblAudioBitDepth,    .audioBitDepth),
        (.lblAudioSampleRate,  .audioSampleRate),
        (.lblTrueAvg,          .loudnessTruePeak),
        (.lblDCOffset,         .dcOffset),
        (.lblTimecodeStart,    .timecodeStart),
        (.lblBlackLongest,     .blackTooLong),
        (.lblSilenceLongest,   .silenceTooLong),
        (.lblFraming,          .framing),
        (.lblLeaderBars,       .leaderBars),
        (.lblLeaderTone,       .leaderTone),
        (.lblSubtitles,        .subtitlesMissing),
        (.lblAFD,              .afdMissing),
        (.lblHDR,              .hdrMetadataMissing),
        (.lblPostRoll,         .postRollMissing),
        (.lblAudioPops,        .audioPops)
    ]

    private static func remediationKey(for check: Check, locale: AppLocale) -> RemediationKey? {
        let label = check.label
        if check.category == .loudness {
            let lower = label.lowercased()
            if lower.contains("true peak") || lower.contains("dbtp") { return .loudnessTruePeak }
            if lower.contains("lra") { return .loudnessLRA }
            return .loudnessIntegrated
        }
        if check.category == .audio && label.localizedCaseInsensitiveContains("phase") {
            return .audioPhase
        }
        for (lkey, rkey) in labelToKey where L10n.t(lkey, locale) == label {
            return rkey
        }
        return nil
    }

    // MARK: - Convenience constructors

    private static func L(_ fr: String, _ en: String, _ es: String) -> LocalizedString {
        LocalizedString(fr: fr, en: en, es: es)
    }

    // MARK: - Catalogue

    private static let guides: [RemediationKey: RemediationGuide] = [

        .container: RemediationGuide(
            title: L("Conteneur non conforme",
                     "Non-compliant container",
                     "Contenedor no conforme"),
            cause: L("Le fichier livré n'est pas dans le format conteneur attendu (typiquement MXF OP1a pour broadcast, ProRes MOV ou MP4 pour OTT). Un mauvais conteneur entraîne un rejet automatique à l'ingestion.",
                     "The delivered file is not in the expected container format (typically MXF OP1a for broadcast, ProRes MOV or MP4 for OTT). A wrong container triggers automatic rejection at ingest.",
                     "El archivo no usa el contenedor esperado (típicamente MXF OP1a para broadcast, ProRes MOV o MP4 para OTT). Un contenedor incorrecto provoca rechazo automático en la ingesta."),
            actions: [
                .init(software: "DaVinci Resolve", steps: [
                    L("Deliver → Render Settings → Format : choisir MXF OP1a (broadcast) ou QuickTime (OTT)",
                      "Deliver → Render Settings → Format: pick MXF OP1a (broadcast) or QuickTime (OTT)",
                      "Deliver → Render Settings → Format: elegir MXF OP1a (broadcast) o QuickTime (OTT)"),
                    L("Codec : sélectionner celui exigé par la chaîne (XDCAM HD422 pour MXF broadcast)",
                      "Codec: select the one required by the broadcaster (XDCAM HD422 for MXF broadcast)",
                      "Codec: elegir el exigido por el emisor (XDCAM HD422 para MXF broadcast)"),
                    L("Add to Render Queue → Start Render",
                      "Add to Render Queue → Start Render",
                      "Add to Render Queue → Start Render")
                ]),
                .init(software: "Adobe Premiere Pro", steps: [
                    L("File → Export → Media",
                      "File → Export → Media",
                      "File → Export → Media"),
                    L("Format : MXF OP1a (XDCAM HD422) broadcast, ou QuickTime ProRes pour OTT",
                      "Format: MXF OP1a (XDCAM HD422) for broadcast, or QuickTime ProRes for OTT",
                      "Format: MXF OP1a (XDCAM HD422) broadcast, o QuickTime ProRes para OTT"),
                    L("Preset : matcher résolution + framerate du master, puis Export",
                      "Preset: match the master's resolution + frame rate, then Export",
                      "Preset: igualar resolución y fps del máster, luego Export")
                ]),
                .init(software: "Avid Media Composer", steps: [
                    L("File → Export → Export As : XDCAM-HD MXF OP1a 50",
                      "File → Export → Export As: XDCAM-HD MXF OP1a 50",
                      "File → Export → Export As: XDCAM-HD MXF OP1a 50"),
                    L("Décocher Same as Source et matcher les specs, puis Save",
                      "Uncheck Same as Source, match the specs, then Save",
                      "Desmarcar Same as Source, igualar specs y guardar")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("ffmpeg -i input.mov -c:v mpeg2video -profile:v 0 -level 4 -pix_fmt yuv422p -b:v 50M -minrate 50M -maxrate 50M -bufsize 25M -bf 2 -g 12 -c:a pcm_s24le -ar 48000 -f mxf_opatom output.mxf",
                      "ffmpeg -i input.mov -c:v mpeg2video -profile:v 0 -level 4 -pix_fmt yuv422p -b:v 50M -minrate 50M -maxrate 50M -bufsize 25M -bf 2 -g 12 -c:a pcm_s24le -ar 48000 -f mxf_opatom output.mxf",
                      "ffmpeg -i input.mov -c:v mpeg2video -profile:v 0 -level 4 -pix_fmt yuv422p -b:v 50M -minrate 50M -maxrate 50M -bufsize 25M -bf 2 -g 12 -c:a pcm_s24le -ar 48000 -f mxf_opatom output.mxf")
                ])
            ]
        ),

        .operationalPattern: RemediationGuide(
            title: L("Operational Pattern MXF incorrect",
                     "Wrong MXF Operational Pattern",
                     "Operational Pattern MXF incorrecto"),
            cause: L("Le MXF a un mauvais Operational Pattern (ex. OP-Atom au lieu d'OP1a). La plupart des chaînes exigent OP1a, qui regroupe vidéo et audio dans un seul essence container.",
                     "The MXF carries the wrong Operational Pattern (e.g. OP-Atom instead of OP1a). Most broadcasters require OP1a, which bundles video and audio in a single essence container.",
                     "El MXF tiene un Operational Pattern incorrecto (p.ej. OP-Atom en lugar de OP1a). La mayoría de emisoras exige OP1a, que agrupa vídeo y audio en un mismo contenedor de esencia."),
            actions: [
                .init(software: "DaVinci Resolve", steps: [
                    L("Deliver → Format : MXF OP1a (et pas OP-Atom)",
                      "Deliver → Format: MXF OP1a (not OP-Atom)",
                      "Deliver → Format: MXF OP1a (no OP-Atom)"),
                    L("Re-render le master complet",
                      "Re-render the full master",
                      "Re-renderizar el máster completo")
                ]),
                .init(software: "Avid Media Composer", steps: [
                    L("Export As : XDCAM-HD MXF OP1a (et non MXF Op-Atom des bins Avid)",
                      "Export As: XDCAM-HD MXF OP1a (not the MXF Op-Atom used inside Avid bins)",
                      "Export As: XDCAM-HD MXF OP1a (no MXF Op-Atom de los bins Avid)")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("Re-mux sans réencodage : ffmpeg -i input.mxf -c copy -f mxf output_op1a.mxf",
                      "Re-mux without re-encode: ffmpeg -i input.mxf -c copy -f mxf output_op1a.mxf",
                      "Re-mux sin recodificar: ffmpeg -i input.mxf -c copy -f mxf output_op1a.mxf")
                ])
            ]
        ),

        .videoCodec: RemediationGuide(
            title: L("Codec vidéo non conforme",
                     "Non-compliant video codec",
                     "Códec de vídeo no conforme"),
            cause: L("Le codec vidéo ne correspond pas à celui attendu. La plupart des broadcasters demandent MPEG-2 422P@HL XDCAM HD422 à 50 Mbps. Les plateformes OTT acceptent souvent ProRes 422 HQ ou H.264 High Profile.",
                     "The video codec doesn't match what's expected. Most broadcasters require MPEG-2 422P@HL XDCAM HD422 at 50 Mbps. OTT platforms often accept ProRes 422 HQ or H.264 High Profile.",
                     "El códec de vídeo no coincide con el esperado. La mayoría de emisoras exige MPEG-2 422P@HL XDCAM HD422 a 50 Mbps. Las plataformas OTT suelen aceptar ProRes 422 HQ o H.264 High Profile."),
            actions: [
                .init(software: "DaVinci Resolve", steps: [
                    L("Deliver → Codec : XDCAM HD422 pour broadcast",
                      "Deliver → Codec: XDCAM HD422 for broadcast",
                      "Deliver → Codec: XDCAM HD422 para broadcast"),
                    L("Pour OTT : Apple ProRes 422 HQ ou DNxHR HQ",
                      "For OTT: Apple ProRes 422 HQ or DNxHR HQ",
                      "Para OTT: Apple ProRes 422 HQ o DNxHR HQ"),
                    L("Data levels : Video (legal range)",
                      "Data levels: Video (legal range)",
                      "Data levels: Video (rango legal)")
                ]),
                .init(software: "Adobe Premiere Pro", steps: [
                    L("Export → Format : MXF OP1a, Codec : XDCAM HD 50 Mbps 4:2:2",
                      "Export → Format: MXF OP1a, Codec: XDCAM HD 50 Mbps 4:2:2",
                      "Export → Format: MXF OP1a, Codec: XDCAM HD 50 Mbps 4:2:2"),
                    L("Pour OTT : QuickTime → Apple ProRes 422 HQ",
                      "For OTT: QuickTime → Apple ProRes 422 HQ",
                      "Para OTT: QuickTime → Apple ProRes 422 HQ")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("ffmpeg -i in.mov -c:v mpeg2video -profile:v 0 -level 4 -b:v 50M -minrate 50M -maxrate 50M -bufsize 25M -pix_fmt yuv422p -bf 2 -g 12 -c:a pcm_s24le out.mxf",
                      "ffmpeg -i in.mov -c:v mpeg2video -profile:v 0 -level 4 -b:v 50M -minrate 50M -maxrate 50M -bufsize 25M -pix_fmt yuv422p -bf 2 -g 12 -c:a pcm_s24le out.mxf",
                      "ffmpeg -i in.mov -c:v mpeg2video -profile:v 0 -level 4 -b:v 50M -minrate 50M -maxrate 50M -bufsize 25M -pix_fmt yuv422p -bf 2 -g 12 -c:a pcm_s24le out.mxf")
                ])
            ]
        ),

        .videoProfile: RemediationGuide(
            title: L("Profil vidéo non conforme",
                     "Non-compliant video profile",
                     "Perfil de vídeo no conforme"),
            cause: L("Le profil interne du codec (Main, High, 422P@HL…) ne correspond pas. Ex. H.264 livré en Main Profile au lieu de High, ou MPEG-2 en MP@ML au lieu de 422P@HL.",
                     "The codec's internal profile (Main, High, 422P@HL…) doesn't match. E.g. H.264 delivered as Main Profile instead of High, or MPEG-2 as MP@ML instead of 422P@HL.",
                     "El perfil interno del códec (Main, High, 422P@HL…) no coincide. P.ej. H.264 entregado en Main Profile en lugar de High, o MPEG-2 en MP@ML en lugar de 422P@HL."),
            actions: [
                .init(software: "DaVinci Resolve", steps: [
                    L("Deliver → Advanced Settings → Profile : High (H.264) ou 422P@HL (MPEG-2)",
                      "Deliver → Advanced Settings → Profile: High (H.264) or 422P@HL (MPEG-2)",
                      "Deliver → Advanced Settings → Profile: High (H.264) o 422P@HL (MPEG-2)")
                ]),
                .init(software: "Adobe Premiere Pro", steps: [
                    L("Export → Video → Profile : High",
                      "Export → Video → Profile: High",
                      "Export → Video → Profile: High"),
                    L("MPEG-2 : Encode → MPEG-2 Profile : 4:2:2 Profile, Level : High",
                      "MPEG-2: Encode → MPEG-2 Profile: 4:2:2 Profile, Level: High",
                      "MPEG-2: Encode → MPEG-2 Profile: 4:2:2 Profile, Level: High")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("H.264 High : -c:v libx264 -profile:v high -level 4.2",
                      "H.264 High: -c:v libx264 -profile:v high -level 4.2",
                      "H.264 High: -c:v libx264 -profile:v high -level 4.2"),
                    L("MPEG-2 422P@HL : -c:v mpeg2video -profile:v 0 -level 4 -pix_fmt yuv422p",
                      "MPEG-2 422P@HL: -c:v mpeg2video -profile:v 0 -level 4 -pix_fmt yuv422p",
                      "MPEG-2 422P@HL: -c:v mpeg2video -profile:v 0 -level 4 -pix_fmt yuv422p")
                ])
            ]
        ),

        .resolution: RemediationGuide(
            title: L("Résolution non conforme",
                     "Non-compliant resolution",
                     "Resolución no conforme"),
            cause: L("Les dimensions de l'image ne correspondent pas. Le standard broadcast HD est 1920×1080. Privilégier un master à la bonne résolution plutôt qu'un simple upscale.",
                     "Image dimensions don't match. HD broadcast standard is 1920×1080. Prefer a master at the right resolution over a simple upscale.",
                     "Las dimensiones no coinciden. El estándar HD broadcast es 1920×1080. Mejor un máster a la resolución correcta que un upscale simple."),
            actions: [
                .init(software: "DaVinci Resolve", steps: [
                    L("Project Settings → Timeline Resolution : 1920×1080 HD",
                      "Project Settings → Timeline Resolution: 1920×1080 HD",
                      "Project Settings → Timeline Resolution: 1920×1080 HD"),
                    L("Clic droit clip → Open in Fusion → Resize en préservant le ratio",
                      "Right-click clip → Open in Fusion → Resize preserving aspect ratio",
                      "Clic derecho → Open in Fusion → Resize preservando relación de aspecto"),
                    L("Deliver → Resolution : 1920×1080 HD",
                      "Deliver → Resolution: 1920×1080 HD",
                      "Deliver → Resolution: 1920×1080 HD")
                ]),
                .init(software: "Adobe Premiere Pro", steps: [
                    L("Sequence Settings → Frame Size : 1920×1080",
                      "Sequence Settings → Frame Size: 1920×1080",
                      "Sequence Settings → Frame Size: 1920×1080"),
                    L("Export → Video → Width 1920, Height 1080",
                      "Export → Video → Width 1920, Height 1080",
                      "Export → Video → Width 1920, Height 1080"),
                    L("Scale to Frame Size sur les clips de résolution différente",
                      "Apply Scale to Frame Size on clips with different resolutions",
                      "Aplicar Scale to Frame Size en clips con otra resolución")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("ffmpeg -i in.mov -vf scale=1920:1080 -c:v ... out.mxf",
                      "ffmpeg -i in.mov -vf scale=1920:1080 -c:v ... out.mxf",
                      "ffmpeg -i in.mov -vf scale=1920:1080 -c:v ... out.mxf")
                ])
            ]
        ),

        .framerate: RemediationGuide(
            title: L("Fréquence d'images non conforme",
                     "Non-compliant frame rate",
                     "Velocidad de imagen no conforme"),
            cause: L("Le framerate de livraison (25i/25p EU, 23.976/24 ciné, 50p/59.94p sport) ne correspond pas. Une conversion mal faite cause judder, frames dupliquées ou décalage A/V.",
                     "Delivery frame rate (25i/25p EU, 23.976/24 cinema, 50p/59.94p sport) doesn't match. A bad conversion causes judder, duplicate frames or A/V drift.",
                     "La velocidad de entrega (25i/25p EU, 23.976/24 cine, 50p/59.94p deportes) no coincide. Una conversión mala causa judder, fotogramas duplicados o desfase A/V."),
            actions: [
                .init(software: "DaVinci Resolve", steps: [
                    L("Project Settings → Timeline Frame Rate : régler au framerate cible",
                      "Project Settings → Timeline Frame Rate: set target frame rate",
                      "Project Settings → Timeline Frame Rate: configurar velocidad objetivo"),
                    L("À faire avant tout import — modification ultérieure casse les clips",
                      "Do this before any import — changing it later breaks clips",
                      "Hacerlo antes de importar — cambiarlo después rompe los clips"),
                    L("Conversion réelle : Inspector → Retime → Optical Flow",
                      "Real conversion: Inspector → Retime → Optical Flow",
                      "Conversión real: Inspector → Retime → Optical Flow")
                ]),
                .init(software: "Adobe Premiere Pro", steps: [
                    L("Sequence Settings → Timebase : 25.00 fps (broadcast EU)",
                      "Sequence Settings → Timebase: 25.00 fps (EU broadcast)",
                      "Sequence Settings → Timebase: 25.00 fps (broadcast EU)"),
                    L("Conversion : clic droit clip → Interpret Footage → Assume This Frame Rate",
                      "Conversion: right-click clip → Interpret Footage → Assume This Frame Rate",
                      "Conversión: clic derecho → Interpret Footage → Assume This Frame Rate")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("Re-time simple (peut dupliquer/dropper) : -r 25",
                      "Simple re-time (may drop/dup): -r 25",
                      "Re-time simple (puede duplicar/quitar): -r 25"),
                    L("Conversion temporelle propre : -vf \"minterpolate=fps=25:mi_mode=mci\"",
                      "Clean temporal conversion: -vf \"minterpolate=fps=25:mi_mode=mci\"",
                      "Conversión temporal limpia: -vf \"minterpolate=fps=25:mi_mode=mci\"")
                ])
            ]
        ),

        .interlace: RemediationGuide(
            title: L("Mode de balayage non conforme",
                     "Non-compliant scan mode",
                     "Modo de barrido no conforme"),
            cause: L("Le master est progressif là où la chaîne demande de l'entrelacé (ou l'inverse). Beaucoup de chaînes EU livrent en 1080i25 (50 trames/s). Mauvais mode = artefacts de scan / aliasing.",
                     "The master is progressive where the broadcaster wants interlaced (or vice versa). Many EU broadcasters require 1080i25 (50 fields/s). Wrong mode = scan artefacts / aliasing.",
                     "El máster es progresivo cuando el emisor pide entrelazado (o al revés). Muchas emisoras EU exigen 1080i25 (50 campos/s). Modo incorrecto = artefactos de barrido / aliasing."),
            actions: [
                .init(software: "DaVinci Resolve", steps: [
                    L("Deliver → Advanced Settings → Field Order : Top Field First (TFF) pour broadcast EU",
                      "Deliver → Advanced Settings → Field Order: Top Field First (TFF) for EU broadcast",
                      "Deliver → Advanced Settings → Field Order: Top Field First (TFF) para broadcast EU"),
                    L("Progressif → entrelacé : Inspector → Video → Field Dominance + sortie interlaced",
                      "Progressive → interlaced: Inspector → Video → Field Dominance + interlaced output",
                      "Progresivo → entrelazado: Inspector → Video → Field Dominance + salida interlaced")
                ]),
                .init(software: "Adobe Premiere Pro", steps: [
                    L("Sequence Settings → Fields : Upper Field First (TFF) pour 1080i EU",
                      "Sequence Settings → Fields: Upper Field First (TFF) for 1080i EU",
                      "Sequence Settings → Fields: Upper Field First (TFF) para 1080i EU"),
                    L("Export → Video → Field Order : Upper",
                      "Export → Video → Field Order: Upper",
                      "Export → Video → Field Order: Upper")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("Progressif → entrelacé : -vf \"interlace=lowpass=1:scan=tff\"",
                      "Progressive → interlaced: -vf \"interlace=lowpass=1:scan=tff\"",
                      "Progresivo → entrelazado: -vf \"interlace=lowpass=1:scan=tff\""),
                    L("Désentrelacement : -vf yadif=1",
                      "Deinterlace: -vf yadif=1",
                      "Desentrelazado: -vf yadif=1")
                ])
            ]
        ),

        .videoBitrate: RemediationGuide(
            title: L("Débit vidéo non conforme",
                     "Non-compliant video bitrate",
                     "Tasa de bits de vídeo no conforme"),
            cause: L("Le débit ne correspond pas (généralement 50 Mbps CBR pour XDCAM HD422). Trop bas dégrade la qualité, trop haut explose les limites d'ingestion.",
                     "Bitrate doesn't match (usually 50 Mbps CBR for XDCAM HD422). Too low degrades quality, too high blows past ingest limits.",
                     "La tasa no coincide (normalmente 50 Mbps CBR para XDCAM HD422). Demasiado baja degrada calidad, demasiado alta supera los límites de ingesta."),
            actions: [
                .init(software: "DaVinci Resolve", steps: [
                    L("Deliver → Advanced Settings → Bit Rate : 50000 kbps",
                      "Deliver → Advanced Settings → Bit Rate: 50000 kbps",
                      "Deliver → Advanced Settings → Bit Rate: 50000 kbps"),
                    L("Rate Control : CBR (Constant Bit Rate)",
                      "Rate Control: CBR (Constant Bit Rate)",
                      "Rate Control: CBR (Constant Bit Rate)"),
                    L("Bufsize / VBV : 25 Mb",
                      "Bufsize / VBV: 25 Mb",
                      "Bufsize / VBV: 25 Mb")
                ]),
                .init(software: "Adobe Premiere Pro", steps: [
                    L("Export → Video → Bitrate Settings : CBR, Target Bitrate 50 Mbps",
                      "Export → Video → Bitrate Settings: CBR, Target Bitrate 50 Mbps",
                      "Export → Video → Bitrate Settings: CBR, Target Bitrate 50 Mbps"),
                    L("Vérifier Estimated File Size que la cible est atteinte",
                      "Check Estimated File Size to confirm target is reached",
                      "Comprobar Estimated File Size para confirmar el objetivo")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("CBR strict : -b:v 50M -minrate 50M -maxrate 50M -bufsize 25M",
                      "Strict CBR: -b:v 50M -minrate 50M -maxrate 50M -bufsize 25M",
                      "CBR estricto: -b:v 50M -minrate 50M -maxrate 50M -bufsize 25M")
                ])
            ]
        ),

        .colorSpace: RemediationGuide(
            title: L("Espace colorimétrique non conforme",
                     "Non-compliant color space",
                     "Espacio de color no conforme"),
            cause: L("L'espace de couleur (BT.709 HD, BT.2020 UHD HDR) n'est pas tagué correctement dans les metadata. Couleurs incorrectes à la lecture côté chaîne.",
                     "Color space (BT.709 HD, BT.2020 UHD HDR) is not correctly tagged in metadata. Incorrect colors at playback on the channel side.",
                     "El espacio de color (BT.709 HD, BT.2020 UHD HDR) no está etiquetado correctamente. Colores incorrectos en la reproducción del emisor."),
            actions: [
                .init(software: "DaVinci Resolve", steps: [
                    L("Project Settings → Color Management → Output Color Space : Rec.709 Gamma 2.4 (HD broadcast)",
                      "Project Settings → Color Management → Output Color Space: Rec.709 Gamma 2.4 (HD broadcast)",
                      "Project Settings → Color Management → Output Color Space: Rec.709 Gamma 2.4 (HD broadcast)"),
                    L("Color Page → clic droit clip → Output Color Space",
                      "Color Page → right-click clip → Output Color Space",
                      "Color Page → clic derecho → Output Color Space")
                ]),
                .init(software: "Adobe Premiere Pro", steps: [
                    L("Sequence Settings → Working Color Space : Rec.709",
                      "Sequence Settings → Working Color Space: Rec.709",
                      "Sequence Settings → Working Color Space: Rec.709"),
                    L("Lumetri Color → Settings → Display Color Space : Rec.709",
                      "Lumetri Color → Settings → Display Color Space: Rec.709",
                      "Lumetri Color → Settings → Display Color Space: Rec.709")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("Tague les 3 metadata : -color_primaries bt709 -color_trc bt709 -colorspace bt709",
                      "Tag all 3 metadata: -color_primaries bt709 -color_trc bt709 -colorspace bt709",
                      "Etiquetar 3 metadatos: -color_primaries bt709 -color_trc bt709 -colorspace bt709")
                ])
            ]
        ),

        .colorPrimaries: RemediationGuide(
            title: L("Primaires couleur non conformes",
                     "Non-compliant color primaries",
                     "Primarios de color no conformes"),
            cause: L("Les color primaries (BT.709, BT.601, BT.2020) sont incorrectes. Souvent un master tagué BT.601 (SD) alors qu'il est en HD.",
                     "Color primaries (BT.709, BT.601, BT.2020) are wrong. Often a master tagged BT.601 (SD) when it is actually HD.",
                     "Los primarios (BT.709, BT.601, BT.2020) son incorrectos. A menudo un máster etiquetado BT.601 (SD) cuando es HD."),
            actions: [
                .init(software: "DaVinci Resolve", steps: [
                    L("Project Settings → Color → Color Science : DaVinci YRGB + Output Rec.709",
                      "Project Settings → Color → Color Science: DaVinci YRGB + Output Rec.709",
                      "Project Settings → Color → Color Science: DaVinci YRGB + Output Rec.709")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("-color_primaries bt709 (HD) ou bt2020 (UHD HDR)",
                      "-color_primaries bt709 (HD) or bt2020 (UHD HDR)",
                      "-color_primaries bt709 (HD) o bt2020 (UHD HDR)")
                ])
            ]
        ),

        .colorTransfer: RemediationGuide(
            title: L("Courbe de transfert (gamma) non conforme",
                     "Non-compliant transfer curve (gamma)",
                     "Curva de transferencia (gamma) no conforme"),
            cause: L("La transfer characteristic (gamma 2.4 BT.709 HD, PQ HDR, HLG HDR) ne correspond pas. Image trop claire/sombre à l'antenne.",
                     "Transfer characteristic (gamma 2.4 BT.709 HD, PQ HDR, HLG HDR) doesn't match. Image too bright/dark on air.",
                     "La transfer characteristic (gamma 2.4 BT.709 HD, PQ HDR, HLG HDR) no coincide. Imagen demasiado clara/oscura en emisión."),
            actions: [
                .init(software: "DaVinci Resolve", steps: [
                    L("Project Settings → Color Management → Output Gamma : Gamma 2.4 (broadcast EU) ou ST.2084 (HDR PQ) ou HLG",
                      "Project Settings → Color Management → Output Gamma: Gamma 2.4 (EU broadcast) or ST.2084 (HDR PQ) or HLG",
                      "Project Settings → Color Management → Output Gamma: Gamma 2.4 (broadcast EU) o ST.2084 (HDR PQ) o HLG")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("-color_trc bt709 (SDR), smpte2084 (HDR PQ), arib-std-b67 (HLG)",
                      "-color_trc bt709 (SDR), smpte2084 (HDR PQ), arib-std-b67 (HLG)",
                      "-color_trc bt709 (SDR), smpte2084 (HDR PQ), arib-std-b67 (HLG)")
                ])
            ]
        ),

        .colorRange: RemediationGuide(
            title: L("Plage de codage (Full vs Video Range) incorrecte",
                     "Wrong color range (Full vs Video)",
                     "Rango de codificación incorrecto (Full vs Video)"),
            cause: L("Master en Full Range (PC, 0–255) alors que la chaîne exige Video Range (Legal, 16–235). Symptôme : image trop contrastée, noirs écrasés, blancs cramés à l'antenne.",
                     "Master in Full Range (PC, 0–255) but the broadcaster requires Video Range (Legal, 16–235). Symptom: image too contrasty, crushed blacks, blown highlights on air.",
                     "Máster en Full Range (PC, 0–255) cuando el emisor exige Video Range (Legal, 16–235). Síntoma: imagen con demasiado contraste, negros aplastados, blancos quemados."),
            actions: [
                .init(software: "DaVinci Resolve", steps: [
                    L("Deliver → Advanced Settings → Data Levels : Video (16-235) — JAMAIS Full pour broadcast",
                      "Deliver → Advanced Settings → Data Levels: Video (16-235) — NEVER Full for broadcast",
                      "Deliver → Advanced Settings → Data Levels: Video (16-235) — NUNCA Full para broadcast"),
                    L("Color Page : éviter les corrections qui dépassent les guides legal",
                      "Color Page: avoid grades that exceed the legal guides",
                      "Color Page: evitar correcciones que pasen las guías legal")
                ]),
                .init(software: "Adobe Premiere Pro", steps: [
                    L("Export → Video → Render at Maximum Depth + cocher Render with Limited Range",
                      "Export → Video → Render at Maximum Depth + check Render with Limited Range",
                      "Export → Video → Render at Maximum Depth + marcar Render with Limited Range"),
                    L("Lumetri Scopes → rien ne dépasse 100 ni ne descend sous 0",
                      "Lumetri Scopes → nothing above 100 or below 0",
                      "Lumetri Scopes → nada por encima de 100 ni debajo de 0")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("-color_range tv (legal/video range, 16-235)",
                      "-color_range tv (legal/video range, 16-235)",
                      "-color_range tv (rango legal/vídeo, 16-235)"),
                    L("Conversion Full → Video : -vf \"scale=in_range=full:out_range=tv\"",
                      "Convert Full → Video: -vf \"scale=in_range=full:out_range=tv\"",
                      "Conversión Full → Video: -vf \"scale=in_range=full:out_range=tv\"")
                ])
            ]
        ),

        .aspectRatio: RemediationGuide(
            title: L("Aspect ratio non conforme",
                     "Non-compliant aspect ratio",
                     "Relación de aspecto no conforme"),
            cause: L("Le ratio d'aspect (16:9 broadcast HD) n'est pas correct. Souvent un master 4:3 SD upscalé sans pillarbox, ou un anamorphique mal tagué.",
                     "Aspect ratio (16:9 HD broadcast) is wrong. Often a 4:3 SD master upscaled without pillarbox, or anamorphic incorrectly tagged.",
                     "La relación (16:9 HD broadcast) no es correcta. A menudo un máster 4:3 SD upscaled sin pillarbox o anamórfico mal etiquetado."),
            actions: [
                .init(software: "DaVinci Resolve", steps: [
                    L("Project Settings → Image Scaling → Pixel Aspect Ratio : Square (1.0) pour HD/UHD",
                      "Project Settings → Image Scaling → Pixel Aspect Ratio: Square (1.0) for HD/UHD",
                      "Project Settings → Image Scaling → Pixel Aspect Ratio: Square (1.0) para HD/UHD"),
                    L("Inspector → Transform → Zoom/Position pour recadrer en 16:9",
                      "Inspector → Transform → Zoom/Position to reframe to 16:9",
                      "Inspector → Transform → Zoom/Position para reencuadrar a 16:9")
                ]),
                .init(software: "Adobe Premiere Pro", steps: [
                    L("Sequence Settings → Pixel Aspect Ratio : Square Pixels (1.0)",
                      "Sequence Settings → Pixel Aspect Ratio: Square Pixels (1.0)",
                      "Sequence Settings → Pixel Aspect Ratio: Square Pixels (1.0)")
                ])
            ]
        ),

        .gopStructure: RemediationGuide(
            title: L("Structure GOP non conforme",
                     "Non-compliant GOP structure",
                     "Estructura GOP no conforme"),
            cause: L("Le GOP n'a pas la longueur attendue (typiquement 12 frames closed pour XDCAM broadcast EU) ou n'est pas closed. Un GOP open empêche le découpage clean en régie.",
                     "GOP isn't the expected length (typically 12 frames closed for EU XDCAM broadcast) or isn't closed. Open GOP prevents clean cutting at master control.",
                     "El GOP no tiene la longitud esperada (típicamente 12 frames closed para XDCAM broadcast EU) o no está closed. GOP open impide cortes limpios en regiduría."),
            actions: [
                .init(software: "DaVinci Resolve", steps: [
                    L("Deliver → Advanced → GOP Size : 12, Closed GOP : ON",
                      "Deliver → Advanced → GOP Size: 12, Closed GOP: ON",
                      "Deliver → Advanced → GOP Size: 12, Closed GOP: ON"),
                    L("B-frames : 2, Reference frames : 1",
                      "B-frames: 2, Reference frames: 1",
                      "B-frames: 2, Reference frames: 1")
                ]),
                .init(software: "Adobe Premiere Pro", steps: [
                    L("Export → Video → GOP Settings : M=3 (B-frames), N=12 (GOP length), Closed GOP : on",
                      "Export → Video → GOP Settings: M=3 (B-frames), N=12 (GOP length), Closed GOP: on",
                      "Export → Video → GOP Settings: M=3 (B-frames), N=12 (GOP length), Closed GOP: on")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("-g 12 -bf 2 -flags +cgop  (cgop = closed GOP)",
                      "-g 12 -bf 2 -flags +cgop  (cgop = closed GOP)",
                      "-g 12 -bf 2 -flags +cgop  (cgop = closed GOP)")
                ])
            ]
        ),

        .signalRange: RemediationGuide(
            title: L("Plage signal vidéo (Y) hors normes",
                     "Video signal range (Y) out of spec",
                     "Rango de señal de vídeo (Y) fuera de norma"),
            cause: L("Des pixels luma dépassent les limites broadcast légales (64–940 sur 10 bits, soit 16–235 sur 8 bits). Cause habituelle : grading laissé en Full Range, blancs cramés non clippés, ou source mal interprétée.",
                     "Some luma pixels exceed the legal broadcast limits (64–940 on 10-bit, 16–235 on 8-bit). Typical causes: grade kept in Full Range, unclipped blown highlights, or wrongly interpreted source.",
                     "Algunos píxeles luma exceden los límites broadcast legales (64–940 en 10 bits, 16–235 en 8 bits). Causa habitual: grading en Full Range, blancos quemados sin clip o fuente mal interpretada."),
            actions: [
                .init(software: "DaVinci Resolve", steps: [
                    L("Color Page → Scopes → Waveform : rien ne dépasse 100 IRE ni ne descend sous 0",
                      "Color Page → Scopes → Waveform: nothing exceeds 100 IRE or drops below 0",
                      "Color Page → Scopes → Waveform: nada por encima de 100 IRE ni debajo de 0"),
                    L("Ajouter un Soft Clip ou Curves en dernier nœud pour ramener dans la plage",
                      "Add a Soft Clip or Curves in the last node to fit the range",
                      "Añadir Soft Clip o Curves en el último nodo para limitar el rango"),
                    L("Deliver → Data Levels : Video (legal)",
                      "Deliver → Data Levels: Video (legal)",
                      "Deliver → Data Levels: Video (legal)")
                ]),
                .init(software: "Adobe Premiere Pro", steps: [
                    L("Effets → Video Limiter sur la séquence master (Reduction Axis : Highlights + Shadows)",
                      "Effects → Video Limiter on the master sequence (Reduction Axis: Highlights + Shadows)",
                      "Effects → Video Limiter en la secuencia master (Reduction Axis: Highlights + Shadows)"),
                    L("Lumetri Scopes → Waveform → vérifier 0–100 IRE",
                      "Lumetri Scopes → Waveform → confirm 0–100 IRE",
                      "Lumetri Scopes → Waveform → verificar 0–100 IRE")
                ]),
                .init(software: "Avid Media Composer", steps: [
                    L("Effects Palette → Image → Safe Color Limiter sur la sortie",
                      "Effects Palette → Image → Safe Color Limiter on output",
                      "Effects Palette → Image → Safe Color Limiter en la salida"),
                    L("Vérifier avec le Waveform interne (Tools → Video Output Tool)",
                      "Verify with the built-in Waveform (Tools → Video Output Tool)",
                      "Verificar con el Waveform interno (Tools → Video Output Tool)")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("Limitation rapide : -vf \"colorlevels=ymin=0.0627:ymax=0.918\"",
                      "Quick limit: -vf \"colorlevels=ymin=0.0627:ymax=0.918\"",
                      "Limitación rápida: -vf \"colorlevels=ymin=0.0627:ymax=0.918\"")
                ])
            ]
        ),

        .freeze: RemediationGuide(
            title: L("Images figées détectées",
                     "Frozen frames detected",
                     "Imágenes congeladas detectadas"),
            cause: L("Une portion du programme reste fixe > 2 s (gel image, plantage capture, mauvais montage). Refusé pour de la diffusion live.",
                     "A portion stays still for > 2 s (frozen frame, capture crash, bad edit). Rejected for live broadcast.",
                     "Una parte queda fija > 2 s (congelación, fallo de captura, montaje incorrecto). Rechazado para emisión en directo."),
            actions: [
                .init(software: "Resolve / Premiere / Avid", steps: [
                    L("Ouvrir la timeline aux timecodes signalés dans le rapport",
                      "Open the timeline at the reported timecodes",
                      "Abrir la timeline en los timecodes reportados"),
                    L("Si gel volontaire (still photo) : valider qu'il est créatif",
                      "If intentional (still photo): confirm it's a creative choice",
                      "Si es congelación intencional (still photo): confirmar que es creativa"),
                    L("Si problème : remonter depuis les rushes ou raccourcir le gel",
                      "If a problem: re-cut from rushes or shorten the freeze",
                      "Si es problema: volver a montar desde brutos o acortar la congelación")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("ffmpeg -ss <tc_start> -i in.mxf -t <duration> -c copy zone.mxf  pour inspection",
                      "ffmpeg -ss <tc_start> -i in.mxf -t <duration> -c copy zone.mxf  for inspection",
                      "ffmpeg -ss <tc_start> -i in.mxf -t <duration> -c copy zone.mxf  para inspección")
                ])
            ]
        ),

        .duplicates: RemediationGuide(
            title: L("Images dupliquées détectées",
                     "Duplicate frames detected",
                     "Imágenes duplicadas detectadas"),
            cause: L("Trop de frames identiques consécutives. Signature classique d'un master converti 24p → 25p sans rééchantillonnage temporel propre.",
                     "Too many consecutive identical frames. Classic signature of a master converted 24p → 25p without clean temporal resampling.",
                     "Demasiados fotogramas idénticos consecutivos. Signo clásico de un máster convertido 24p → 25p sin remuestreo temporal limpio."),
            actions: [
                .init(software: "DaVinci Resolve", steps: [
                    L("Inspector → Retime → Optical Flow → Speed Warp pour les retimes",
                      "Inspector → Retime → Optical Flow → Speed Warp for retimes",
                      "Inspector → Retime → Optical Flow → Speed Warp para retimes"),
                    L("Project Settings → Timeline Frame Rate : matcher la source",
                      "Project Settings → Timeline Frame Rate: match the source",
                      "Project Settings → Timeline Frame Rate: igualar la fuente")
                ]),
                .init(software: "Adobe Premiere Pro", steps: [
                    L("Clic droit clip → Time Interpolation → Optical Flow",
                      "Right-click clip → Time Interpolation → Optical Flow",
                      "Clic derecho → Time Interpolation → Optical Flow"),
                    L("Render avec Maximum Render Quality cochée",
                      "Render with Maximum Render Quality checked",
                      "Render con Maximum Render Quality marcado")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("Conversion propre 24→25 fps : -vf \"minterpolate=fps=25:mi_mode=mci:mc_mode=aobmc\"",
                      "Clean 24→25 fps conversion: -vf \"minterpolate=fps=25:mi_mode=mci:mc_mode=aobmc\"",
                      "Conversión limpia 24→25 fps: -vf \"minterpolate=fps=25:mi_mode=mci:mc_mode=aobmc\"")
                ])
            ]
        ),

        .stuckPixels: RemediationGuide(
            title: L("Pixels stuck / dead pixels",
                     "Stuck / dead pixels",
                     "Píxeles bloqueados / muertos"),
            cause: L("Des pixels restent figés sur toute l'analyse — capteur défectueux, ou quantification trop agressive à l'encodage.",
                     "Pixels stay stuck through the analysis — defective sensor or overly aggressive encoder quantization.",
                     "Píxeles quedan bloqueados durante el análisis — sensor defectuoso o cuantización demasiado agresiva."),
            actions: [
                .init(software: "DaVinci Resolve", steps: [
                    L("Color Page → ResolveFX → Dead Pixel Fixer (Studio) avec les coordonnées du rapport",
                      "Color Page → ResolveFX → Dead Pixel Fixer (Studio) using the report coordinates",
                      "Color Page → ResolveFX → Dead Pixel Fixer (Studio) con las coordenadas del informe"),
                    L("Sinon : Patch Replacer + ouvrir/refermer un nœud sur la zone",
                      "Otherwise: Patch Replacer + open/close a node over the region",
                      "Si no: Patch Replacer + abrir/cerrar un nodo sobre la zona")
                ]),
                .init(software: "After Effects / Premiere", steps: [
                    L("After Effects : Median ou Dust & Scratches localisé via masque",
                      "After Effects: Median or Dust & Scratches localized via mask",
                      "After Effects: Median o Dust & Scratches localizado con máscara"),
                    L("Premiere : masque avec Stabilizer puis remplacement de zone",
                      "Premiere: masked Stabilizer then area replacement",
                      "Premiere: máscara con Stabilizer y reemplazo de zona")
                ])
            ]
        ),

        .pse: RemediationGuide(
            title: L("Risque PSE (épilepsie photosensible)",
                     "PSE (photosensitive epilepsy) risk",
                     "Riesgo PSE (epilepsia fotosensible)"),
            cause: L("Des passages dépassent 3 flashs/seconde de forte variation lumineuse, susceptibles de déclencher des crises. Ofcom (UK) et la réglementation française imposent une certification Harding avant diffusion.",
                     "Some passages exceed 3 high-luma-variation flashes/second, potentially seizure-inducing. Ofcom (UK) and French regulation require Harding certification before air.",
                     "Algunos pasajes superan 3 flashes/segundo de fuerte variación lumínica, posibles inductores de crisis. Ofcom (UK) y la regulación francesa exigen certificación Harding antes de emisión."),
            actions: [
                .init(software: "DaVinci Resolve", steps: [
                    L("Color Page → naviguer aux timecodes du rapport",
                      "Color Page → navigate to the report timecodes",
                      "Color Page → navegar a los timecodes del informe"),
                    L("Réduire contraste / luminance sur ces séquences (Soft Clip + Lift)",
                      "Reduce contrast / luminance on these sequences (Soft Clip + Lift)",
                      "Reducir contraste / luminancia en esas secuencias (Soft Clip + Lift)"),
                    L("Diminuer la saturation des rouges (Harding y est sensible)",
                      "Lower red saturation (Harding is sensitive to it)",
                      "Bajar la saturación de los rojos (Harding es sensible a ello)")
                ]),
                .init(software: "Adobe Premiere Pro", steps: [
                    L("Lumetri Color → Saturation -20 sur les passages flagués",
                      "Lumetri Color → Saturation -20 on flagged passages",
                      "Lumetri Color → Saturation -20 en los pasajes marcados"),
                    L("Crossfade ou blur léger pour adoucir les coupes brutales",
                      "Crossfade or slight blur to soften hard cuts",
                      "Crossfade o blur ligero para suavizar cortes bruscos")
                ]),
                .init(software: "Certified software", steps: [
                    L("Livraison BBC / ARTE / Channel 4 : faire passer le master dans Harding FPA",
                      "BBC / ARTE / Channel 4 delivery: run the master through Harding FPA",
                      "Entrega BBC / ARTE / Channel 4: pasar el máster por Harding FPA"),
                    L("Vector PFC + ajustement manuel des passages signalés",
                      "Vector PFC + manual tweak of flagged passages",
                      "Vector PFC + ajuste manual de los pasajes marcados")
                ])
            ]
        ),

        .audioChannels: RemediationGuide(
            title: L("Nombre de canaux audio non conforme",
                     "Non-compliant audio channel count",
                     "Número de canales de audio no conforme"),
            cause: L("Pas le bon nombre de pistes audio (typiquement 4 / 8 / 16 mono pour MXF broadcast). Bloque le mapping automatique côté chaîne.",
                     "Wrong number of audio tracks (typically 4 / 8 / 16 mono for MXF broadcast). Breaks automatic mapping on the channel side.",
                     "Número de pistas de audio incorrecto (típicamente 4 / 8 / 16 mono para MXF broadcast). Bloquea el mapeo automático del emisor."),
            actions: [
                .init(software: "DaVinci Resolve", steps: [
                    L("Fairlight → ajouter / supprimer des Bus Mono pour matcher la spec",
                      "Fairlight → add / remove Mono Busses to match the spec",
                      "Fairlight → añadir / eliminar Bus Mono para igualar spec"),
                    L("Deliver → Audio → Output : Mono channels, Number of Channels : 8 ou 16",
                      "Deliver → Audio → Output: Mono channels, Number of Channels: 8 or 16",
                      "Deliver → Audio → Output: Mono channels, Number of Channels: 8 o 16")
                ]),
                .init(software: "Adobe Premiere Pro", steps: [
                    L("Sequence Settings → Audio → Audio Output Mapping → cocher Mono channels",
                      "Sequence Settings → Audio → Audio Output Mapping → check Mono channels",
                      "Sequence Settings → Audio → Audio Output Mapping → marcar Mono channels"),
                    L("Export → Audio → Output Channels : Mono, Channels : 8",
                      "Export → Audio → Output Channels: Mono, Channels: 8",
                      "Export → Audio → Output Channels: Mono, Channels: 8")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("Stéréo → 8 mono : ffmpeg -i in.wav -filter_complex \"channelsplit=channel_layout=stereo\" -map ... out.mxf",
                      "Stereo → 8 mono: ffmpeg -i in.wav -filter_complex \"channelsplit=channel_layout=stereo\" -map ... out.mxf",
                      "Estéreo → 8 mono: ffmpeg -i in.wav -filter_complex \"channelsplit=channel_layout=stereo\" -map ... out.mxf")
                ])
            ]
        ),

        .audioCodec: RemediationGuide(
            title: L("Codec audio non conforme",
                     "Non-compliant audio codec",
                     "Códec de audio no conforme"),
            cause: L("L'audio n'est pas en PCM linéaire (24-bit 48 kHz). Un master en AAC/MP3 est refusé pour broadcast.",
                     "Audio is not linear PCM (24-bit 48 kHz). AAC/MP3 masters are rejected for broadcast.",
                     "El audio no es PCM lineal (24-bit 48 kHz). Másteres en AAC/MP3 son rechazados para broadcast."),
            actions: [
                .init(software: "DaVinci Resolve", steps: [
                    L("Deliver → Audio → Codec : Linear PCM, Sample Rate 48 kHz, Bit Depth 24",
                      "Deliver → Audio → Codec: Linear PCM, Sample Rate 48 kHz, Bit Depth 24",
                      "Deliver → Audio → Codec: Linear PCM, Sample Rate 48 kHz, Bit Depth 24")
                ]),
                .init(software: "Adobe Premiere Pro", steps: [
                    L("Export → Audio → Format : PCM Uncompressed, 48 kHz, 24-bit",
                      "Export → Audio → Format: PCM Uncompressed, 48 kHz, 24-bit",
                      "Export → Audio → Format: PCM Uncompressed, 48 kHz, 24-bit")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("-c:a pcm_s24le -ar 48000",
                      "-c:a pcm_s24le -ar 48000",
                      "-c:a pcm_s24le -ar 48000")
                ])
            ]
        ),

        .audioBitDepth: RemediationGuide(
            title: L("Profondeur audio non conforme",
                     "Non-compliant audio bit depth",
                     "Profundidad de audio no conforme"),
            cause: L("Audio en 16-bit alors que la spec demande 24-bit (ou l'inverse). Conversion sale = perte de dynamique audible.",
                     "Audio in 16-bit when the spec wants 24-bit (or vice-versa). Sloppy conversion = audible dynamics loss.",
                     "Audio en 16-bit cuando la spec exige 24-bit (o viceversa). Conversión sucia = pérdida de dinámica audible."),
            actions: [
                .init(software: "DaVinci Resolve", steps: [
                    L("Project Settings → Audio → Bit Depth : 24, puis Deliver Bit Depth : 24",
                      "Project Settings → Audio → Bit Depth: 24, then Deliver Bit Depth: 24",
                      "Project Settings → Audio → Bit Depth: 24, luego Deliver Bit Depth: 24")
                ]),
                .init(software: "Adobe Premiere Pro", steps: [
                    L("Export → Audio → Sample Size : 24-bit",
                      "Export → Audio → Sample Size: 24-bit",
                      "Export → Audio → Sample Size: 24-bit")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("-c:a pcm_s24le (24-bit) ou pcm_s16le (16-bit)",
                      "-c:a pcm_s24le (24-bit) or pcm_s16le (16-bit)",
                      "-c:a pcm_s24le (24-bit) o pcm_s16le (16-bit)")
                ])
            ]
        ),

        .audioSampleRate: RemediationGuide(
            title: L("Fréquence d'échantillonnage audio non conforme",
                     "Non-compliant audio sample rate",
                     "Frecuencia de muestreo de audio no conforme"),
            cause: L("L'audio n'est pas à 48 kHz (standard broadcast). Souvent 44.1 kHz si le master vient d'un mix CD. Le resampling 44.1 → 48 doit utiliser un algorithme propre, jamais un simple stretch.",
                     "Audio is not at 48 kHz (broadcast standard). Often 44.1 kHz when the master comes from a CD mix. Resampling 44.1 → 48 must use a clean algorithm, never a plain stretch.",
                     "El audio no está a 48 kHz (estándar broadcast). A menudo 44.1 kHz si el máster viene de mezcla CD. El resampling 44.1 → 48 debe usar un algoritmo limpio, nunca un simple stretch."),
            actions: [
                .init(software: "DaVinci Resolve", steps: [
                    L("Project Settings → Audio → Sample Rate : 48 kHz",
                      "Project Settings → Audio → Sample Rate: 48 kHz",
                      "Project Settings → Audio → Sample Rate: 48 kHz"),
                    L("Source en 44.1 kHz : importer dans Fairlight → resample automatique au sample rate du projet",
                      "Source at 44.1 kHz: import into Fairlight → auto-resample to project sample rate",
                      "Fuente a 44.1 kHz: importar a Fairlight → resample automático al sample rate del proyecto")
                ]),
                .init(software: "Adobe Premiere Pro", steps: [
                    L("Sequence Settings → Audio → Sample Rate : 48 kHz",
                      "Sequence Settings → Audio → Sample Rate: 48 kHz",
                      "Sequence Settings → Audio → Sample Rate: 48 kHz"),
                    L("Export → Audio → Sample Rate : 48000 Hz",
                      "Export → Audio → Sample Rate: 48000 Hz",
                      "Export → Audio → Sample Rate: 48000 Hz")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("-ar 48000 (SoX HQ via -af aresample=resampler=soxr)",
                      "-ar 48000 (SoX HQ via -af aresample=resampler=soxr)",
                      "-ar 48000 (SoX HQ via -af aresample=resampler=soxr)")
                ])
            ]
        ),

        .audioPhase: RemediationGuide(
            title: L("Phase audio anti-corrélée",
                     "Anti-correlated audio phase",
                     "Fase de audio anticorrelada"),
            cause: L("La phase L/R d'une paire stéréo descend trop souvent en négatif. Symptôme : disparition du signal au down-mix mono côté TV. Cause : canal inversé, mix mal phasé ou retard d'échantillons.",
                     "L/R phase of a stereo pair dips negative too often. Symptom: signal cancels on TV mono down-mix. Cause: inverted channel, mis-phased mix or sample delay.",
                     "La fase L/R de un par estéreo se vuelve negativa demasiado a menudo. Síntoma: la señal desaparece en mono down-mix del TV. Causa: canal invertido, mezcla desfasada o retardo de muestras."),
            actions: [
                .init(software: "Resolve / Fairlight", steps: [
                    L("Mixer → vérifier qu'aucun bouton Phase Invert (Ø) n'est activé sans raison",
                      "Mixer → make sure no Phase Invert (Ø) button is on without reason",
                      "Mixer → comprobar que ningún botón Phase Invert (Ø) esté activado sin razón"),
                    L("Plugin Stereo Width sur la paire suspecte pour resserrer",
                      "Stereo Width plugin on the suspect pair to tighten it",
                      "Plugin Stereo Width en el par sospechoso para apretar"),
                    L("Quick check au casque en mono (bouton Mono master)",
                      "Quick mono check in headphones (Mono button on master)",
                      "Quick check en mono por auriculares (botón Mono master)")
                ]),
                .init(software: "Audition / Premiere", steps: [
                    L("Audition → Effects → Stereo Imagery → Stereo Field Rotate / Phase Inverse",
                      "Audition → Effects → Stereo Imagery → Stereo Field Rotate / Phase Inverse",
                      "Audition → Effects → Stereo Imagery → Stereo Field Rotate / Phase Inverse"),
                    L("Premiere : clic droit clip audio → Audio Channels → vérifier mapping L/R",
                      "Premiere: right-click audio clip → Audio Channels → check L/R mapping",
                      "Premiere: clic derecho clip audio → Audio Channels → verificar mapeo L/R")
                ]),
                .init(software: "Pro Tools", steps: [
                    L("Plug-in Trim avec Phase Invert sur un canal pour tester",
                      "Trim plug-in with Phase Invert on one channel to test",
                      "Plug-in Trim con Phase Invert en un canal para probar"),
                    L("Sonnox Phase Tool ou bx_solo pour aligner et corriger l'anti-phase",
                      "Sonnox Phase Tool or bx_solo to align and fix anti-phase",
                      "Sonnox Phase Tool o bx_solo para alinear y corregir anti-fase")
                ])
            ]
        ),

        .dcOffset: RemediationGuide(
            title: L("DC offset audio détecté",
                     "Audio DC offset detected",
                     "DC offset de audio detectado"),
            cause: L("Composante continue non nulle (> 1%), souvent carte son mal calibrée. Cause des clics aux montages et réduit la headroom.",
                     "Non-zero DC component (> 1%), often a poorly calibrated sound card. Causes clicks at edits and lowers headroom.",
                     "Componente continua no nula (> 1%), a menudo una tarjeta de sonido mal calibrada. Causa clics en montajes y reduce headroom."),
            actions: [
                .init(software: "Resolve / Fairlight", steps: [
                    L("Plug-ins → Equaliser → High Pass filter à 20 Hz sur chaque piste",
                      "Plug-ins → Equaliser → High Pass filter at 20 Hz on each track",
                      "Plug-ins → Equaliser → High Pass filter a 20 Hz en cada pista"),
                    L("Ou Plug-ins → Utility → DC Offset Removal",
                      "Or Plug-ins → Utility → DC Offset Removal",
                      "O Plug-ins → Utility → DC Offset Removal")
                ]),
                .init(software: "Audition / Premiere", steps: [
                    L("Audition → Diagnostics → DC Offset → Repair All",
                      "Audition → Diagnostics → DC Offset → Repair All",
                      "Audition → Diagnostics → DC Offset → Repair All"),
                    L("Premiere : effet Highpass à 20 Hz sur la piste",
                      "Premiere: Highpass effect at 20 Hz on the track",
                      "Premiere: efecto Highpass a 20 Hz en la pista")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("-af highpass=f=20 (filtre passe-haut 20 Hz qui annule le DC)",
                      "-af highpass=f=20 (high-pass at 20 Hz cancels DC)",
                      "-af highpass=f=20 (paso alto 20 Hz cancela el DC)")
                ])
            ]
        ),

        .loudnessIntegrated: RemediationGuide(
            title: L("Loudness intégré hors cible",
                     "Integrated loudness off target",
                     "Loudness integrado fuera de objetivo"),
            cause: L("Le LUFS intégré EBU R128 s'écarte de la cible (-23 LUFS ±1 broadcast EU, -16 LUFS streaming OTT). Trop fort = rejet, trop bas = remontée forcée côté chaîne.",
                     "EBU R128 integrated LUFS is off target (-23 LUFS ±1 EU broadcast, -16 LUFS OTT streaming). Too loud = reject, too quiet = forced gain-up on the channel side.",
                     "El LUFS integrado EBU R128 está fuera del objetivo (-23 LUFS ±1 broadcast EU, -16 LUFS streaming OTT). Demasiado alto = rechazo, demasiado bajo = subida forzada por el emisor."),
            actions: [
                .init(software: "Resolve / Fairlight", steps: [
                    L("Mixer → Master → Plug-ins → Loudness Meter (intégré ou Waves WLM / Nugen VisLM)",
                      "Mixer → Master → Plug-ins → Loudness Meter (built-in or Waves WLM / Nugen VisLM)",
                      "Mixer → Master → Plug-ins → Loudness Meter (integrado o Waves WLM / Nugen VisLM)"),
                    L("Ajuster le gain master jusqu'à -23 LUFS (±0.5)",
                      "Adjust master gain to -23 LUFS (±0.5)",
                      "Ajustar ganancia master hasta -23 LUFS (±0.5)"),
                    L("Re-render le master complet pour valider",
                      "Re-render the full master to validate",
                      "Re-renderizar el máster completo para validar")
                ]),
                .init(software: "Audition", steps: [
                    L("Effects → Amplitude → Match Loudness → Target : ITU-R BS.1770-4 → -23 LUFS",
                      "Effects → Amplitude → Match Loudness → Target: ITU-R BS.1770-4 → -23 LUFS",
                      "Effects → Amplitude → Match Loudness → Target: ITU-R BS.1770-4 → -23 LUFS"),
                    L("Premiere : Dynamic Link vers Audition pour le master",
                      "Premiere: Dynamic Link into Audition for the master",
                      "Premiere: Dynamic Link a Audition para el máster")
                ]),
                .init(software: "Pro Tools", steps: [
                    L("Plug-in WLM Plus ou ML4000 sur le master bus",
                      "WLM Plus or ML4000 plug-in on the master bus",
                      "Plug-in WLM Plus o ML4000 en el master bus"),
                    L("Ajuster la trim du master pour cibler -23 LUFS intégré",
                      "Trim the master to hit -23 LUFS integrated",
                      "Ajustar el trim del máster para -23 LUFS integrado")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("Norm one-pass (preview) : ffmpeg -i in.wav -af loudnorm=I=-23:LRA=18:TP=-3 out.wav",
                      "One-pass norm (preview): ffmpeg -i in.wav -af loudnorm=I=-23:LRA=18:TP=-3 out.wav",
                      "Norm one-pass (preview): ffmpeg -i in.wav -af loudnorm=I=-23:LRA=18:TP=-3 out.wav"),
                    L("Broadcast-grade : two-pass loudnorm (mesure puis correction)",
                      "Broadcast-grade: two-pass loudnorm (measure then correct)",
                      "Broadcast-grade: two-pass loudnorm (medir y corregir)")
                ])
            ]
        ),

        .loudnessTruePeak: RemediationGuide(
            title: L("True Peak dépassé",
                     "True Peak exceeded",
                     "True Peak superado"),
            cause: L("Pics inter-samples > -3 dBTP broadcast EU ou -1 dBTP OTT. Distorsion clippée sur les décodeurs à la diffusion.",
                     "Inter-sample peaks > -3 dBTP EU broadcast or -1 dBTP OTT. Clipped distortion on consumer decoders at playback.",
                     "Picos inter-muestra > -3 dBTP broadcast EU o -1 dBTP OTT. Distorsión por clipping en decodificadores en reproducción."),
            actions: [
                .init(software: "Resolve / Fairlight", steps: [
                    L("Mixer → Master → True Peak Limiter (Waves L2, Nugen ISL, Sonnox Inflator)",
                      "Mixer → Master → True Peak Limiter (Waves L2, Nugen ISL, Sonnox Inflator)",
                      "Mixer → Master → True Peak Limiter (Waves L2, Nugen ISL, Sonnox Inflator)"),
                    L("Ceiling : -3 dBTP (broadcast) ou -1 dBTP (OTT), puis re-render",
                      "Ceiling: -3 dBTP (broadcast) or -1 dBTP (OTT), then re-render",
                      "Ceiling: -3 dBTP (broadcast) o -1 dBTP (OTT), luego re-render")
                ]),
                .init(software: "Adobe Audition", steps: [
                    L("Effects → Amplitude → Hard Limiter : Max Amplitude -3 dBTP, Look Ahead 5 ms",
                      "Effects → Amplitude → Hard Limiter: Max Amplitude -3 dBTP, Look Ahead 5 ms",
                      "Effects → Amplitude → Hard Limiter: Max Amplitude -3 dBTP, Look Ahead 5 ms"),
                    L("Cocher Link Channels",
                      "Check Link Channels",
                      "Marcar Link Channels")
                ]),
                .init(software: "Pro Tools", steps: [
                    L("Nugen ISL en True Peak mode, ceiling -3 dBTP",
                      "Nugen ISL in True Peak mode, ceiling -3 dBTP",
                      "Nugen ISL en True Peak mode, ceiling -3 dBTP")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("loudnorm avec TP=-3 (broadcast) ou TP=-1 (OTT) : -af loudnorm=I=-23:TP=-3:LRA=18",
                      "loudnorm with TP=-3 (broadcast) or TP=-1 (OTT): -af loudnorm=I=-23:TP=-3:LRA=18",
                      "loudnorm con TP=-3 (broadcast) o TP=-1 (OTT): -af loudnorm=I=-23:TP=-3:LRA=18")
                ])
            ]
        ),

        .loudnessLRA: RemediationGuide(
            title: L("LRA (Loudness Range) hors plage",
                     "LRA (Loudness Range) out of bounds",
                     "LRA (Loudness Range) fuera de rango"),
            cause: L("Le LRA dépasse la tolérance (≤ 20 LU). Programme à dynamique trop large pour de l'écoute domestique broadcast.",
                     "LRA exceeds tolerance (≤ 20 LU). Programme too dynamic for home broadcast listening.",
                     "El LRA supera la tolerancia (≤ 20 LU). Programa demasiado dinámico para escucha doméstica broadcast."),
            actions: [
                .init(software: "Resolve / Fairlight", steps: [
                    L("Mixer → Master → Compressor (ratio 2:1, threshold -28 dB, attack 30 ms, release 100 ms)",
                      "Mixer → Master → Compressor (ratio 2:1, threshold -28 dB, attack 30 ms, release 100 ms)",
                      "Mixer → Master → Compressor (ratio 2:1, threshold -28 dB, attack 30 ms, release 100 ms)"),
                    L("Vérifier LRA cible avec Loudness Meter intégré",
                      "Verify target LRA with the built-in Loudness Meter",
                      "Verificar LRA objetivo con el Loudness Meter integrado")
                ]),
                .init(software: "Adobe Audition", steps: [
                    L("Effects → Amplitude → Multiband Compressor preset Broadcast → LRA < 18 LU",
                      "Effects → Amplitude → Multiband Compressor preset Broadcast → LRA < 18 LU",
                      "Effects → Amplitude → Multiband Compressor preset Broadcast → LRA < 18 LU")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("-af loudnorm=I=-23:LRA=18:TP=-3 (cible LRA = 18)",
                      "-af loudnorm=I=-23:LRA=18:TP=-3 (target LRA = 18)",
                      "-af loudnorm=I=-23:LRA=18:TP=-3 (objetivo LRA = 18)")
                ])
            ]
        ),

        .timecodeStart: RemediationGuide(
            title: L("Timecode de départ incorrect",
                     "Wrong start timecode",
                     "Timecode de inicio incorrecto"),
            cause: L("Le TC de la 1ʳᵉ image n'est pas conforme (00:00:00:00 France TV/TF1, 01:00:00:00 M6, 10:00:00:00 Canal+). Souvent un master sans timecode ou un export qui repart à 00.",
                     "First-frame TC doesn't match spec (00:00:00:00 France TV/TF1, 01:00:00:00 M6, 10:00:00:00 Canal+). Usually a master without TC or an export that restarts at 00.",
                     "El TC del primer fotograma no es conforme (00:00:00:00 France TV/TF1, 01:00:00:00 M6, 10:00:00:00 Canal+). A menudo un máster sin TC o un export que parte de 00."),
            actions: [
                .init(software: "DaVinci Resolve", steps: [
                    L("Edit Page → clic droit première frame → Set Current Timecode → valeur attendue",
                      "Edit Page → right-click first frame → Set Current Timecode → expected value",
                      "Edit Page → clic derecho primer fotograma → Set Current Timecode → valor esperado"),
                    L("Deliver → File → Use Timeline Timecode : ON, puis re-render",
                      "Deliver → File → Use Timeline Timecode: ON, then re-render",
                      "Deliver → File → Use Timeline Timecode: ON, luego re-render")
                ]),
                .init(software: "Adobe Premiere Pro", steps: [
                    L("Sequence → Settings → Video → Set Start Timecode",
                      "Sequence → Settings → Video → Set Start Timecode",
                      "Sequence → Settings → Video → Set Start Timecode"),
                    L("Export → cocher Use Sequence Start as Timecode",
                      "Export → check Use Sequence Start as Timecode",
                      "Export → marcar Use Sequence Start as Timecode")
                ]),
                .init(software: "Avid Media Composer", steps: [
                    L("Clip → Set TC → entrer le timecode de start exigé",
                      "Clip → Set TC → enter the required start timecode",
                      "Clip → Set TC → introducir el timecode de inicio requerido"),
                    L("Export As → cocher Match Sequence Timecode",
                      "Export As → check Match Sequence Timecode",
                      "Export As → marcar Match Sequence Timecode")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("-timecode 01:00:00:00 force le TC d'écriture du MXF",
                      "-timecode 01:00:00:00 forces the MXF write TC",
                      "-timecode 01:00:00:00 fuerza el TC de escritura del MXF")
                ])
            ]
        ),

        .blackTooLong: RemediationGuide(
            title: L("Noir vidéo trop long",
                     "Video black too long",
                     "Negro de vídeo demasiado largo"),
            cause: L("Un noir complet dépasse la durée tolérée (souvent 1 s chez TF1). Amorce technique oubliée, transition trop longue ou trou dans le programme.",
                     "A full black exceeds tolerated duration (often 1 s at TF1). Forgotten technical leader, too-long transition or hole in the programme.",
                     "Un negro completo supera la duración tolerada (a menudo 1 s en TF1). Amorce técnica olvidada, transición demasiado larga o hueco en el programa."),
            actions: [
                .init(software: "Resolve / Premiere / Avid", steps: [
                    L("Ouvrir la timeline aux timecodes du rapport",
                      "Open the timeline at the report timecodes",
                      "Abrir la timeline en los timecodes del informe"),
                    L("Amorce technique : la retirer (le PAD doit commencer par la 1ʳᵉ image)",
                      "Technical leader: remove it (PAD must start on the 1st image)",
                      "Amorce técnica: quitarla (el PAD debe empezar en el 1er fotograma)"),
                    L("Trou involontaire : récupérer le bon plan ou raccourcir la transition",
                      "Accidental hole: pull the correct shot back or shorten the transition",
                      "Hueco involuntario: recuperar el plano correcto o acortar la transición")
                ])
            ]
        ),

        .silenceTooLong: RemediationGuide(
            title: L("Silence audio trop long",
                     "Audio silence too long",
                     "Silencio de audio demasiado largo"),
            cause: L("Un silence (< -60 dB) dépasse la durée tolérée (souvent 10 s chez TF1). Piste coupée par erreur ou silence artistique jugé trop long.",
                     "A silence (< -60 dB) exceeds tolerated duration (often 10 s at TF1). Track muted by mistake or artistic silence judged too long.",
                     "Un silencio (< -60 dB) supera la duración tolerada (a menudo 10 s en TF1). Pista muteada por error o silencio artístico demasiado largo."),
            actions: [
                .init(software: "Resolve / Fairlight", steps: [
                    L("Naviguer aux timecodes du rapport",
                      "Navigate to the report timecodes",
                      "Navegar a los timecodes del informe"),
                    L("Piste coupée : raccorder le clip avec son ambiance",
                      "Muted track: rejoin the clip with its ambience",
                      "Pista muteada: reconectar el clip con su ambiente"),
                    L("Silence artistique : ajouter une ambiance basse (-50 dB) pour signaler que le programme continue",
                      "Artistic silence: add a low ambience (-50 dB) so the programme is heard as continuing",
                      "Silencio artístico: añadir un ambiente bajo (-50 dB) para indicar que el programa continúa")
                ]),
                .init(software: "Adobe Premiere Pro", steps: [
                    L("Vérifier au timecode → si toutes les pistes muettes, raccorder ambiance",
                      "Inspect at timecode → if all tracks are silent, rejoin ambience",
                      "Inspeccionar en timecode → si todas las pistas mudas, reconectar ambiente"),
                    L("Effects → Audio → Multiband Compressor pour rehausser légèrement",
                      "Effects → Audio → Multiband Compressor to lift slightly",
                      "Effects → Audio → Multiband Compressor para subir ligeramente")
                ])
            ]
        ),

        .framing: RemediationGuide(
            title: L("Cadrage (letterbox / pillarbox) incorrect",
                     "Wrong framing (letterbox / pillarbox)",
                     "Encuadre incorrecto (letterbox / pillarbox)"),
            cause: L("Bandes noires non centrées ou mal proportionnées. La chaîne refuse les masters avec bandes intégrées — ils doivent être full frame 16:9.",
                     "Black bars not centered or wrongly proportioned. The channel refuses masters with embedded bars — they must be full frame 16:9.",
                     "Bandas negras no centradas o mal proporcionadas. El emisor rechaza másteres con bandas integradas — deben ser full frame 16:9."),
            actions: [
                .init(software: "DaVinci Resolve", steps: [
                    L("Edit Page → Inspector → Transform → Zoom + Position pour plein écran 16:9",
                      "Edit Page → Inspector → Transform → Zoom + Position to fill 16:9",
                      "Edit Page → Inspector → Transform → Zoom + Position para llenar 16:9"),
                    L("Bandes cinéma 2.39:1 : crop propre, pas de matte boxes superposées",
                      "2.39:1 cinema bars: clean crop, no stacked matte boxes",
                      "Bandas cine 2.39:1: crop limpio, sin matte boxes apilados")
                ]),
                .init(software: "Adobe Premiere Pro", steps: [
                    L("Effects → Transform → Crop pour retirer les bandes",
                      "Effects → Transform → Crop to remove the bars",
                      "Effects → Transform → Crop para quitar las bandas"),
                    L("Vérifier que l'image active occupe tout le frame 1920×1080",
                      "Confirm active image fills the full 1920×1080 frame",
                      "Confirmar que la imagen activa llena el frame 1920×1080")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("Crop letterbox : -vf \"crop=1920:816:0:132,scale=1920:1080\"",
                      "Letterbox crop: -vf \"crop=1920:816:0:132,scale=1920:1080\"",
                      "Crop letterbox: -vf \"crop=1920:816:0:132,scale=1920:1080\"")
                ])
            ]
        ),

        .leaderBars: RemediationGuide(
            title: L("Mires SMPTE/EBU manquantes en tête de PAD",
                     "Missing SMPTE/EBU bars leader",
                     "Faltan barras SMPTE/EBU en amorce"),
            cause: L("Le master ne commence pas par 30 s de mires couleur EBU 75% attendues pour la calibration côté régie.",
                     "Master doesn't start with 30 s of 75% EBU color bars expected for master-control calibration.",
                     "El máster no comienza con 30 s de barras EBU 75% esperadas para calibración en regiduría."),
            actions: [
                .init(software: "DaVinci Resolve", steps: [
                    L("Edit Page → File → New Generator → SMPTE Bars (ou EBU Bars 75%)",
                      "Edit Page → File → New Generator → SMPTE Bars (or EBU Bars 75%)",
                      "Edit Page → File → New Generator → SMPTE Bars (o EBU Bars 75%)"),
                    L("Ajouter 30 s en tête de timeline avant le programme",
                      "Add 30 s at the head of the timeline before the programme",
                      "Añadir 30 s al inicio de la timeline antes del programa"),
                    L("TC : commencer à 00:58:30:00 si TC IN programme = 01:00:00:00",
                      "TC: start at 00:58:30:00 if programme TC IN = 01:00:00:00",
                      "TC: empezar a 00:58:30:00 si TC IN programa = 01:00:00:00")
                ]),
                .init(software: "Adobe Premiere Pro", steps: [
                    L("File → New → Bars and Tone (75% EBU), durée 30 s",
                      "File → New → Bars and Tone (75% EBU), 30 s long",
                      "File → New → Bars and Tone (75% EBU), 30 s")
                ]),
                .init(software: "Avid Media Composer", steps: [
                    L("Tools → Bars + Tone Generator → EBU 75% bars + 1 kHz tone, insérer en tête",
                      "Tools → Bars + Tone Generator → EBU 75% bars + 1 kHz tone, insert at head",
                      "Tools → Bars + Tone Generator → EBU 75% bars + 1 kHz tone, insertar al inicio")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("Générer mires + tone : ffmpeg -f lavfi -i smptebars=size=1920x1080:rate=25 -f lavfi -i sine=frequency=1000:sample_rate=48000 -t 30 -c:v mpeg2video -b:v 50M -c:a pcm_s24le bars_tone.mxf",
                      "Generate bars + tone: ffmpeg -f lavfi -i smptebars=size=1920x1080:rate=25 -f lavfi -i sine=frequency=1000:sample_rate=48000 -t 30 -c:v mpeg2video -b:v 50M -c:a pcm_s24le bars_tone.mxf",
                      "Generar barras + tone: ffmpeg -f lavfi -i smptebars=size=1920x1080:rate=25 -f lavfi -i sine=frequency=1000:sample_rate=48000 -t 30 -c:v mpeg2video -b:v 50M -c:a pcm_s24le bars_tone.mxf"),
                    L("Concaténer avec le programme via -filter_complex concat",
                      "Concatenate with the programme via -filter_complex concat",
                      "Concatenar con el programa vía -filter_complex concat")
                ])
            ]
        ),

        .leaderTone: RemediationGuide(
            title: L("1 kHz tone manquant ou hors niveau",
                     "1 kHz tone missing or off level",
                     "Tono 1 kHz ausente o fuera de nivel"),
            cause: L("Le tone 1 kHz à -18 dBFS (standard EBU R128) n'est pas présent ou est hors niveau. Sans tone, la régie ne peut pas calibrer la chaîne audio.",
                     "1 kHz tone at -18 dBFS (EBU R128 standard) is missing or off level. Master control can't calibrate the audio chain.",
                     "El tono 1 kHz a -18 dBFS (estándar EBU R128) no está o está fuera de nivel. Sin tono, la regiduría no puede calibrar la cadena de audio."),
            actions: [
                .init(software: "Resolve / Fairlight", steps: [
                    L("File → New Generator → 1 kHz Tone à -18 dBFS",
                      "File → New Generator → 1 kHz Tone at -18 dBFS",
                      "File → New Generator → 1 kHz Tone a -18 dBFS"),
                    L("Placer sur toutes les pistes pendant les 30 s de mires",
                      "Place on all tracks during the 30 s of bars",
                      "Colocar en todas las pistas durante los 30 s de barras")
                ]),
                .init(software: "Adobe Audition", steps: [
                    L("Effects → Generate → Tones → Frequency 1000 Hz, Amplitude -18 dBFS",
                      "Effects → Generate → Tones → Frequency 1000 Hz, Amplitude -18 dBFS",
                      "Effects → Generate → Tones → Frequency 1000 Hz, Amplitude -18 dBFS"),
                    L("Insérer dans Premiere sur toutes les pistes audio de l'amorce",
                      "Insert in Premiere on all audio tracks of the leader",
                      "Insertar en Premiere en todas las pistas de audio de la amorce")
                ]),
                .init(software: "Avid Media Composer", steps: [
                    L("Tools → Audio Tool → Calibrate Tone : 1 kHz @ -18 dBFS (-20 dBFS si US)",
                      "Tools → Audio Tool → Calibrate Tone: 1 kHz @ -18 dBFS (-20 dBFS for US)",
                      "Tools → Audio Tool → Calibrate Tone: 1 kHz @ -18 dBFS (-20 dBFS si US)")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("ffmpeg -f lavfi -i \"sine=frequency=1000:sample_rate=48000\" -af volume=-18dB -t 30 tone.wav",
                      "ffmpeg -f lavfi -i \"sine=frequency=1000:sample_rate=48000\" -af volume=-18dB -t 30 tone.wav",
                      "ffmpeg -f lavfi -i \"sine=frequency=1000:sample_rate=48000\" -af volume=-18dB -t 30 tone.wav")
                ])
            ]
        ),

        .subtitlesMissing: RemediationGuide(
            title: L("Sous-titres / closed captions absents",
                     "Subtitles / closed captions missing",
                     "Subtítulos / closed captions ausentes"),
            cause: L("La chaîne attend des sous-titres embarqués (CC608/708, DVB sub, teletext, EBU-STL). Critique pour les obligations légales d'accessibilité.",
                     "Channel expects embedded subtitles (CC608/708, DVB sub, teletext, EBU-STL). Critical for accessibility regulation.",
                     "El emisor espera subtítulos embebidos (CC608/708, DVB sub, teletext, EBU-STL). Crítico para obligaciones legales de accesibilidad."),
            actions: [
                .init(software: "DaVinci Resolve", steps: [
                    L("Edit Page → Inspector → Subtitle Track → Import .srt ou .stl",
                      "Edit Page → Inspector → Subtitle Track → Import .srt or .stl",
                      "Edit Page → Inspector → Subtitle Track → Import .srt o .stl"),
                    L("Deliver → Subtitle Settings → Embedded (CC608/708) ou Sidecar SRT/STL",
                      "Deliver → Subtitle Settings → Embedded (CC608/708) or Sidecar SRT/STL",
                      "Deliver → Subtitle Settings → Embedded (CC608/708) o Sidecar SRT/STL")
                ]),
                .init(software: "Adobe Premiere Pro", steps: [
                    L("Window → Captions → New Captions Track → CEA-608 ou CEA-708",
                      "Window → Captions → New Captions Track → CEA-608 or CEA-708",
                      "Window → Captions → New Captions Track → CEA-608 o CEA-708"),
                    L("Importer .scc, .srt ou taper manuellement",
                      "Import .scc, .srt or type manually",
                      "Importar .scc, .srt o escribir manualmente"),
                    L("Export → Captions → Embed in Output Video",
                      "Export → Captions → Embed in Output Video",
                      "Export → Captions → Embed in Output Video")
                ]),
                .init(software: "EZTitles / Spot / Annotation Edit", steps: [
                    L("Outils pro pour création / mise au point de sous-titres timecodés",
                      "Pro tools for creation / refinement of timed subtitles",
                      "Herramientas pro para creación / ajuste de subtítulos por timecode"),
                    L("Export EBU-STL (broadcast EU), .scc (US CC608/708) ou .srt sidecar",
                      "Export EBU-STL (EU broadcast), .scc (US CC608/708) or .srt sidecar",
                      "Export EBU-STL (broadcast EU), .scc (US CC608/708) o .srt sidecar")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("Embed SRT : ffmpeg -i in.mxf -i subs.srt -c copy -c:s mov_text out.mp4",
                      "Embed SRT: ffmpeg -i in.mxf -i subs.srt -c copy -c:s mov_text out.mp4",
                      "Embed SRT: ffmpeg -i in.mxf -i subs.srt -c copy -c:s mov_text out.mp4"),
                    L("Embed CC608 : outil dédié (CCExtractor + injection user_data MPEG-2)",
                      "Embed CC608: dedicated tool (CCExtractor + MPEG-2 user_data injection)",
                      "Embed CC608: herramienta dedicada (CCExtractor + inyección user_data MPEG-2)")
                ])
            ]
        ),

        .afdMissing: RemediationGuide(
            title: L("Flag AFD (Active Format Description) absent",
                     "AFD (Active Format Description) flag missing",
                     "Flag AFD (Active Format Description) ausente"),
            cause: L("Le bitstream MPEG-2 ne contient pas le flag AFD SMPTE 2016-1, qui indique la portion 16:9 active. Sans AFD, le zoom intelligent en diffusion SD est impossible.",
                     "MPEG-2 bitstream lacks the SMPTE 2016-1 AFD flag indicating the active 16:9 portion. Without AFD, intelligent zoom for SD playback is impossible.",
                     "El bitstream MPEG-2 no contiene el flag AFD SMPTE 2016-1 que indica la zona 16:9 activa. Sin AFD, el zoom inteligente en SD es imposible."),
            actions: [
                .init(software: "DaVinci Resolve", steps: [
                    L("Resolve ne tague pas AFD nativement — re-mux MXF avec outil dédié post-export",
                      "Resolve doesn't tag AFD natively — re-mux MXF with a dedicated tool post-export",
                      "Resolve no etiqueta AFD nativamente — re-mux MXF con herramienta dedicada post-export")
                ]),
                .init(software: "Adobe Premiere Pro", steps: [
                    L("Export → MXF OP1a → Advanced → AFD Settings : AFD 10 (16:9 full frame) ou AFD 8",
                      "Export → MXF OP1a → Advanced → AFD Settings: AFD 10 (16:9 full frame) or AFD 8",
                      "Export → MXF OP1a → Advanced → AFD Settings: AFD 10 (16:9 full frame) o AFD 8")
                ]),
                .init(software: "Avid Media Composer", steps: [
                    L("Project Settings → AFD : valeur adaptée (10 = 16:9 full frame le plus courant)",
                      "Project Settings → AFD: appropriate value (10 = 16:9 full frame, most common)",
                      "Project Settings → AFD: valor apropiado (10 = 16:9 full frame, más común)"),
                    L("Le tag sera injecté à l'export XDCAM-HD MXF",
                      "Tag will be injected on XDCAM-HD MXF export",
                      "El tag se inyectará en el export XDCAM-HD MXF")
                ]),
                .init(software: "Third-party / outils tiers", steps: [
                    L("FFmpeg ne sait pas insérer AFD natif : passer par BMX, Avid Interplay, Vantage ou Clipster",
                      "FFmpeg can't insert native AFD: use BMX, Avid Interplay, Vantage or Clipster",
                      "FFmpeg no puede insertar AFD nativo: usar BMX, Avid Interplay, Vantage o Clipster")
                ])
            ]
        ),

        .hdrMetadataMissing: RemediationGuide(
            title: L("Métadonnées HDR statiques incomplètes",
                     "Static HDR metadata incomplete",
                     "Metadatos HDR estáticos incompletos"),
            cause: L("Pour un master HDR10, Netflix / Apple TV+ / Max exigent Mastering Display + MaxCLL/MaxFALL. Sans ces tags, le TV ne sait pas à quel niveau tone-mapper.",
                     "For an HDR10 master, Netflix / Apple TV+ / Max require Mastering Display + MaxCLL/MaxFALL. Without these tags, TVs can't tone-map correctly.",
                     "Para un máster HDR10, Netflix / Apple TV+ / Max exigen Mastering Display + MaxCLL/MaxFALL. Sin estos tags, los TV no pueden tone-mappear correctamente."),
            actions: [
                .init(software: "DaVinci Resolve", steps: [
                    L("Project Settings → Color Management : DaVinci YRGB + Output Rec.2020 ST.2084",
                      "Project Settings → Color Management: DaVinci YRGB + Output Rec.2020 ST.2084",
                      "Project Settings → Color Management: DaVinci YRGB + Output Rec.2020 ST.2084"),
                    L("Deliver → Advanced Settings → HDR Metadata : cocher Mastering Display + Content Light Level",
                      "Deliver → Advanced Settings → HDR Metadata: check Mastering Display + Content Light Level",
                      "Deliver → Advanced Settings → HDR Metadata: marcar Mastering Display + Content Light Level"),
                    L("Renseigner MaxCLL (≈1000 cd/m²) et MaxFALL (≈400 cd/m²) après mesure",
                      "Fill MaxCLL (≈1000 cd/m²) and MaxFALL (≈400 cd/m²) after measurement",
                      "Rellenar MaxCLL (≈1000 cd/m²) y MaxFALL (≈400 cd/m²) tras medir")
                ]),
                .init(software: "Adobe Premiere Pro", steps: [
                    L("Export → Video → Color → Override HDR Metadata",
                      "Export → Video → Color → Override HDR Metadata",
                      "Export → Video → Color → Override HDR Metadata"),
                    L("Renseigner MaxCLL, MaxFALL, Mastering Display Primaries (P3 D65 ou Rec.2020) et Luminance",
                      "Fill MaxCLL, MaxFALL, Mastering Display Primaries (P3 D65 or Rec.2020) and Luminance",
                      "Rellenar MaxCLL, MaxFALL, Mastering Display Primaries (P3 D65 o Rec.2020) y Luminance")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("x265 : -x265-params \"hdr-opt=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(10000000,1):max-cll=1000,400\"",
                      "x265: -x265-params \"hdr-opt=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(10000000,1):max-cll=1000,400\"",
                      "x265: -x265-params \"hdr-opt=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(10000000,1):max-cll=1000,400\"")
                ]),
                .init(software: "Dedicated tools", steps: [
                    L("Dolby Vision Professional Tools pour le mastering Vision",
                      "Dolby Vision Professional Tools for Vision mastering",
                      "Dolby Vision Professional Tools para mastering Vision"),
                    L("MediaInfo : vérifier après injection que tous les champs sont remontés",
                      "MediaInfo: verify after injection that all fields are present",
                      "MediaInfo: verificar tras inyectar que todos los campos están presentes")
                ])
            ]
        ),

        .postRollMissing: RemediationGuide(
            title: L("Post-roll absent (coupe brutale en fin)",
                     "Post-roll missing (hard cut at end)",
                     "Post-roll ausente (corte brusco al final)"),
            cause: L("Le programme se termine sans noir de fin. La régie a besoin d'un post-roll (≥ 1 s, souvent 5-10 s) pour gérer la transition.",
                     "Programme ends without trailing black. Master control needs a post-roll (≥ 1 s, often 5-10 s) to manage the transition.",
                     "El programa termina sin negro final. La regiduría necesita un post-roll (≥ 1 s, a menudo 5-10 s) para gestionar la transición."),
            actions: [
                .init(software: "DaVinci Resolve", steps: [
                    L("Edit Page → ajouter un clip de noir (Solid Color noir) en fin de timeline",
                      "Edit Page → add a black clip (Solid Color black) at the end of the timeline",
                      "Edit Page → añadir clip negro (Solid Color black) al final de la timeline"),
                    L("Durée typique : 5 s broadcast EU, 10 s broadcast US",
                      "Typical duration: 5 s EU broadcast, 10 s US broadcast",
                      "Duración típica: 5 s broadcast EU, 10 s broadcast US")
                ]),
                .init(software: "Adobe Premiere Pro", steps: [
                    L("File → New → Black Video, 5-10 s, glisser après la dernière image",
                      "File → New → Black Video, 5-10 s, drop after the last frame",
                      "File → New → Black Video, 5-10 s, arrastrar tras el último fotograma")
                ]),
                .init(software: "Avid Media Composer", steps: [
                    L("Bin → New Slug (clip noir) 5 s, insérer en fin et muter l'audio",
                      "Bin → New Slug (black clip) 5 s, insert at end and mute audio",
                      "Bin → New Slug (clip negro) 5 s, insertar al final y mutear audio")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("Concaténer un noir : ffmpeg -i in.mxf -f lavfi -i color=black:size=1920x1080:rate=25:duration=5 -filter_complex \"[0:v][1:v]concat=n=2:v=1\" out.mxf",
                      "Concat a black: ffmpeg -i in.mxf -f lavfi -i color=black:size=1920x1080:rate=25:duration=5 -filter_complex \"[0:v][1:v]concat=n=2:v=1\" out.mxf",
                      "Concatenar un negro: ffmpeg -i in.mxf -f lavfi -i color=black:size=1920x1080:rate=25:duration=5 -filter_complex \"[0:v][1:v]concat=n=2:v=1\" out.mxf")
                ])
            ]
        ),

        .audioPops: RemediationGuide(
            title: L("Pops / clicks audio détectés",
                     "Audio pops / clicks detected",
                     "Pops / clics de audio detectados"),
            cause: L("Sauts de niveau > 6 dB en moins de 50 ms. Causes : raccords sans crossfade, drop d'échantillons, bug d'export. Audibles comme clics, refusés en broadcast pro.",
                     "Level jumps > 6 dB within less than 50 ms. Causes: edits without crossfade, sample drops, export bug. Audible as clicks, rejected in pro broadcast.",
                     "Saltos de nivel > 6 dB en menos de 50 ms. Causas: cortes sin crossfade, drop de muestras, bug de export. Audibles como clics, rechazados en broadcast pro."),
            actions: [
                .init(software: "Resolve / Fairlight", steps: [
                    L("Naviguer aux timecodes du rapport",
                      "Navigate to the report timecodes",
                      "Navegar a los timecodes del informe"),
                    L("Crossfade 20 ms minimum sur chaque coupure (clic droit → Add Cross Fade)",
                      "20 ms minimum crossfade on every cut (right-click → Add Cross Fade)",
                      "Crossfade 20 ms mínimo en cada corte (clic derecho → Add Cross Fade)"),
                    L("Si pop dû à un drop : remonter le segment depuis les rushes",
                      "If pop from a drop: re-cut the segment from rushes",
                      "Si el pop viene de un drop: remontar el segmento desde brutos")
                ]),
                .init(software: "Adobe Audition", steps: [
                    L("Diagnostics → Click/Pop Eliminator (preset Light) → Repair All",
                      "Diagnostics → Click/Pop Eliminator (preset Light) → Repair All",
                      "Diagnostics → Click/Pop Eliminator (preset Light) → Repair All"),
                    L("Spectral Frequency Display → masque + healing brush sur le pop",
                      "Spectral Frequency Display → mask + healing brush on the pop",
                      "Spectral Frequency Display → máscara + healing brush sobre el pop")
                ]),
                .init(software: "iZotope RX / Pro Tools", steps: [
                    L("RX → De-Click (module dédié), Spectral repair en backup",
                      "RX → De-Click (dedicated module), Spectral repair as backup",
                      "RX → De-Click (módulo dedicado), Spectral repair de respaldo"),
                    L("Pro Tools : AudioSuite RX De-Click sur les segments concernés",
                      "Pro Tools: AudioSuite RX De-Click on affected segments",
                      "Pro Tools: AudioSuite RX De-Click en los segmentos afectados")
                ]),
                .init(software: "FFmpeg", steps: [
                    L("Crossfade : -filter_complex \"[0:a][1:a]acrossfade=d=0.02:c1=tri:c2=tri\"",
                      "Crossfade: -filter_complex \"[0:a][1:a]acrossfade=d=0.02:c1=tri:c2=tri\"",
                      "Crossfade: -filter_complex \"[0:a][1:a]acrossfade=d=0.02:c1=tri:c2=tri\"")
                ])
            ]
        )
    ]
}
