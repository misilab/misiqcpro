import Foundation

/// Lightweight, hand-rolled localisation table. We keep all translatable
/// strings here so they're easy to find and to extend.
enum L10n {

    static func t(_ key: Key, _ locale: AppLocale) -> String {
        return strings[key]?[locale] ?? strings[key]?[.fr] ?? key.rawValue
    }

    enum Key: String {
        // Header
        case appName
        case appSubtitle

        // Section headers
        case sectionChannel
        case sectionVariant
        case sectionFile
        case sectionReport

        // Channel column tagline
        case profileChannelHint

        // Drop zone
        case dropEmpty
        case dropHint
        case dropChoose

        // Stat cards
        case statFound
        case statPass
        case statWarn
        case statFail

        // Action buttons
        case actionLaunch
        case actionReset
        case actionClear
        case actionExportPDF
        case actionExportCSV
        case actionExportRemediation
        case actionRevealFile
        case actionNewAnalysis

        // Verdicts
        case verdictPass
        case verdictWarn
        case verdictFail
        case verdictGlobal

        // Empty / progress
        case emptyState
        case emptyHint
        case analyzing
        case stageProbe
        case stageLoudness
        case stageBlack
        case stageSilence
        case stageFinalize

        // Errors
        case errorTitle
        case okButton

        // Footer
        case footerCredit

        // Settings
        case settingsTitle
        case settingsLanguage
        case settingsLanguageNote
        case settingsDefaultProfile
        case settingsDefaultVariant
        case settingsDetection
        case settingsBlackThreshold
        case settingsSilenceThreshold
        case settingsAbout
        case settingsAboutBody
        case settingsResetButton
        case settingsResetConfirm

        // Menu titles
        case menuFile
        case menuAnalysis
        case menuProfile
        case menuVariant
        case menuView
        case menuHelp
        case menuOpenFile
        case menuShowReport

        // Misc UI
        case actionShowSpecs
        case errorNoProfileSelected
        case settingsToleranceLevel
        case settingsToleranceSection
        case settingsToleranceFooter

        // Check categories
        case catContainer, catVideo, catAudio, catLoudness, catStructure

        // Pipeline stages
        case stageGOP, stageInterlace, stageCrop, stagePhase, stageAudioStats
        case stageFreeze, stageDuplicate, stageDeadPixel, stagePSE, stageSignalRange
        case stageLeader, stageAudioPops, stageMetadataExtras

        // Check labels
        case lblContainer, lblOP, lblVideoCodec, lblVideoProfile, lblResolution, lblFramerate
        case lblInterlace, lblVideoBitrate, lblColorSpace, lblColorPrimaries, lblColorTransfer
        case lblColorRange, lblAspectRatio, lblGopStructure, lblScanMode, lblFraming
        case lblSignalRange, lblFreeze, lblDuplicateFrames, lblStuckPixels, lblPSE
        case lblAudioChannels, lblAudioCodec, lblAudioBitDepth, lblAudioSampleRate
        case lblTrueAvg, lblDCOffset, lblTimecodeStart, lblBlackLongest, lblSilenceLongest
        case lblTotalDuration, lblBlackDetected, lblVideoStream
        case lblLeaderBars, lblLeaderTone, lblSubtitles, lblAFD, lblHDR
        case lblPostRoll, lblAudioPops

        // Detected / not-detected and report fragments for new checks
        case valDetected, valNotDetected
        case valBarsLine, valToneLine, valTrailingBlack, valHardCut
        case valNoPops, valPopsLine, valPopsSample
        case valAFDAbsent, valAFDCode
        case valNoHDR, valHDRMaster, valHDRCLL, valHDRPipeline
        case valExpectedHDR, valExpectedTone, valExpectedPostRollRecommend
        case valSubsStreams

        // AFD codes (SMPTE 2016-1)
        case afd0, afd2, afd3, afd4, afd8, afd9, afd10, afd11, afd13, afd14, afd15
        case afdCodeFallback

        // Remediation PDF strings
        case remedPDFTitle, remedPDFSubtitle
        case remedFile, remedProfile, remedToFix
        case remedHowToUseTitle, remedHowToUseBody
        case remedRunningFooter
        case remedPageHeader
        case remedNothingToFix

        // Main report PDF strings
        case rptPDFSubtitle, rptPDFContinued
        case rptInfoFile, rptInfoProfile, rptInfoDuration, rptInfoAnalyzedAt
        case rptVerdictGlobal
        case rptSignature
        case rptDateFormat

        // Common terms reused across checks
        case valPresent, valAbsent
        case valNone
        case valInformational
        case errPDFWriteFailed

        // Aspect ratio / color range
        case valComputedDAR
        case detColorRangeNotSet

        // Signal range
        case fmtSignalActual, fmtSignalRangeExpected
        case fmtSignalMeanWarn, fmtSignalMeanFail
        case fmtSignalPeakWarn, fmtSignalPeakFail
        case fmtSignalYWarn, fmtSignalYFail
        case valInfraBlack, valSuperWhite
        case fmtSignalKindLabel
        case fmtSignalPass, detSignalWarn, detSignalFail
        case errSignalUnavailable

        // Black / silence
        case valNoBlackDetected, fmtBlackActual
        case valNoSilenceAnomaly, fmtSilenceActual
        case fmtBlackSegmentsCount

        // Freeze
        case fmtFreezeActual, fmtFreezeDetail, expFreezeNone

        // Duplicates
        case fmtDupActual, expDupCadence
        case detDupUnknown, detDupPass, detDupWarn, detDupFail

        // Framing
        case expFramingFull, fmtFramingActual
        case detFramingBoth, detLetterbox, detPillarbox

        // Phase
        case expPhaseMono, fmtPhaseActual
        case detPhasePass, detPhaseWarn, detPhaseFail
        case lblPhasePrefix

        // DC offset
        case expDCOffset, fmtDCActual
        case detDCWarn, detDCFail

        // PSE
        case expPSE, fmtPSEActual
        case detPSEPass, detPSEWarn, detPSEFail

        // Dead pixels
        case expDeadPixel, fmtDeadPixelActual
        case detDeadPixelPass, detDeadPixelWarn, detDeadPixelFail

        // Channel confidence tooltips
        case tipConfVerified, tipConfStandard, tipConfGeneric

        // Loudness dynamic label suffixes
        case lblLoudnessIntegrated, lblLoudnessTruePeak, lblLoudnessLRA

        // Licence / trial
        case licenseSettingsTab, licenseSectionStatus, licenseSectionActivate
        case licenseStatusTrial, licenseStatusLicensed, licenseStatusExpired
        case licenseTrialBanner, licenseTrialBannerExpired
        case licenseLastDay
        case licenseEnterKey, licenseEnterKeyPlaceholder, licenseActivateButton
        case licenseDeactivateButton, licenseBuyButton
        case licenseErrorMalformed, licenseErrorSignature
        case licenseErrorExpired, licenseErrorUnsupported
        case licenseActivatedTitle, licenseActivatedMessage
        case licenseExpiredTitle, licenseExpiredMessage
        case licenseHost
        case licenseWatermark, licenseWatermarkTrial
        case licenseRestrictExports
        case licenseStatusLifetime
        case licenseExpiryLifetime

        // Sparkle updates
        case menuCheckUpdates

        // SpecDetailView strings
        case specHeaderContainer, specHeaderVideo, specHeaderAudio, specHeaderLoudness
        case specHeaderStructure
        case specFormat, specOperationalPattern, specShim, specCodec, specProfile
        case specResolution, specFramerate, specInterlace, specFieldOrder, specBitrate
        case specBitrateMode, specGOP, specGOPClosed, specColorSpace, specColorPrimaries
        case specColorTransfer, specColorRange, specAspectRatio, specAudioCodec
        case specAudioBitDepth, specAudioSampleRate, specAcceptedTracks
        case specMappingPrefix, specIntegratedLUFS, specMaxTruePeak, specMaxLRA, specMaxShortTerm
        case specTCStart, specDropFrame, specMaxBlack, specMaxSilence, specSlate
        case specSlateAllowed, specSlateForbidden, specReference
        case yes, no, interlaced, progressive

        // Interlace verdicts (idet)
        case scanTFF, scanBFF, scanProgressive, scanUndetermined
        case scanCountTFF, scanCountBFF, scanCountProgressive, scanCountUndetermined
        case scanPsFDetail, scanInterlacedOnProgressiveDetail, scanUndeterminedDetail

        // Timeline + help popover
        case timelineTitle
        case timelineHelpTitle
        case timelineHelpIntro
        case timelineLegendYAVG
        case timelineLegendYMIN
        case timelineLegendYMAX
        case timelineLegendBRNG
        case timelineLegendTOUT
        case timelineLegendVREP
        case timelineHelpNote
    }

    // MARK: - Translations

    private static let strings: [Key: [AppLocale: String]] = [
        .appName: [
            .fr: "MisiQC Pro",
            .en: "MisiQC Pro",
            .es: "MisiQC Pro"
        ],
        .appSubtitle: [
            .fr: "Contrôle qualité PAD — Prêt à diffuser",
            .en: "Broadcast Master QC — Ready to air",
            .es: "Control de calidad PAD — Listo para emisión"
        ],

        .sectionChannel: [
            .fr: "Profil chaîne", .en: "Channel profile", .es: "Perfil de canal"
        ],
        .sectionVariant: [
            .fr: "Version audio à contrôler",
            .en: "Audio version to check",
            .es: "Versión de audio a comprobar"
        ],
        .sectionFile: [
            .fr: "Fichier à contrôler",
            .en: "File to check",
            .es: "Archivo a comprobar"
        ],
        .sectionReport: [
            .fr: "Rapport", .en: "Report", .es: "Informe"
        ],

        .profileChannelHint: [
            .fr: "Choisis une chaîne pour appliquer son cahier des charges.",
            .en: "Pick a channel to apply its delivery spec.",
            .es: "Elige un canal para aplicar sus normas."
        ],

        .dropEmpty: [
            .fr: "Aucun fichier sélectionné",
            .en: "No file selected",
            .es: "Sin archivo seleccionado"
        ],
        .dropHint: [
            .fr: "Glissez un master ici ou cliquez sur Choisir",
            .en: "Drop a master here or click Choose",
            .es: "Suelta un máster aquí o pulsa Elegir"
        ],
        .dropChoose: [
            .fr: "Choisir", .en: "Choose", .es: "Elegir"
        ],

        .statFound: [.fr: "Trouvés", .en: "Found", .es: "Hallados"],
        .statPass:  [.fr: "Conformes", .en: "Passed", .es: "Conformes"],
        .statWarn:  [.fr: "Alertes", .en: "Warnings", .es: "Advertencias"],
        .statFail:  [.fr: "Échecs", .en: "Failed", .es: "Fallos"],

        .actionLaunch: [
            .fr: "Lancer l'analyse",
            .en: "Start analysis",
            .es: "Iniciar análisis"
        ],
        .actionReset: [
            .fr: "Réinitialiser", .en: "Reset", .es: "Reiniciar"
        ],
        .actionClear: [
            .fr: "Effacer", .en: "Clear", .es: "Borrar"
        ],
        .actionExportPDF: [
            .fr: "Exporter PDF", .en: "Export PDF", .es: "Exportar PDF"
        ],
        .actionExportCSV: [
            .fr: "Exporter CSV", .en: "Export CSV", .es: "Exportar CSV"
        ],
        .actionExportRemediation: [
            .fr: "Guide de correction PDF",
            .en: "Remediation guide PDF",
            .es: "Guía de corrección PDF"
        ],
        .actionRevealFile: [
            .fr: "Voir le fichier", .en: "Show file", .es: "Mostrar archivo"
        ],
        .actionNewAnalysis: [
            .fr: "Nouvelle analyse", .en: "New analysis", .es: "Nuevo análisis"
        ],

        .verdictPass: [.fr: "Conforme", .en: "Pass", .es: "Conforme"],
        .verdictWarn: [.fr: "Avertissement", .en: "Warning", .es: "Advertencia"],
        .verdictFail: [.fr: "Non conforme", .en: "Fail", .es: "No conforme"],
        .verdictGlobal: [
            .fr: "Verdict global", .en: "Overall verdict", .es: "Veredicto global"
        ],

        .emptyState: [
            .fr: "Aucune analyse pour le moment",
            .en: "No analysis yet",
            .es: "Sin análisis por ahora"
        ],
        .emptyHint: [
            .fr: "Choisissez un profil chaîne, glissez un fichier, puis lancez l'analyse.",
            .en: "Pick a profile, drop a file, then start the analysis.",
            .es: "Elige un perfil, suelta un archivo y empieza el análisis."
        ],
        .analyzing: [
            .fr: "Analyse en cours…",
            .en: "Analysing…",
            .es: "Analizando…"
        ],
        .stageProbe: [
            .fr: "Lecture des métadonnées",
            .en: "Reading metadata",
            .es: "Lectura de metadatos"
        ],
        .stageLoudness: [
            .fr: "Mesure du loudness R128",
            .en: "Measuring R128 loudness",
            .es: "Medición de loudness R128"
        ],
        .stageBlack: [
            .fr: "Détection des noirs vidéo",
            .en: "Detecting black frames",
            .es: "Detección de fotogramas negros"
        ],
        .stageSilence: [
            .fr: "Détection des silences audio",
            .en: "Detecting audio silence",
            .es: "Detección de silencios"
        ],
        .stageFinalize: [
            .fr: "Compilation du rapport",
            .en: "Compiling report",
            .es: "Compilando informe"
        ],

        .errorTitle: [.fr: "Erreur", .en: "Error", .es: "Error"],
        .okButton:   [.fr: "OK", .en: "OK", .es: "OK"],

        .footerCredit: [
            .fr: "MisiQC Pro créé par Matthieu Misiraca —",
            .en: "MisiQC Pro built by Matthieu Misiraca —",
            .es: "MisiQC Pro por Matthieu Misiraca —"
        ],

        // Settings
        .settingsTitle: [
            .fr: "Réglages", .en: "Settings", .es: "Ajustes"
        ],
        .settingsLanguage: [
            .fr: "Langue de l'interface",
            .en: "Interface language",
            .es: "Idioma de la interfaz"
        ],
        .settingsLanguageNote: [
            .fr: "Modifie immédiatement les libellés affichés.",
            .en: "Updates the on-screen labels immediately.",
            .es: "Actualiza los textos al instante."
        ],
        .settingsDefaultProfile: [
            .fr: "Profil chaîne par défaut",
            .en: "Default channel profile",
            .es: "Perfil por defecto"
        ],
        .settingsDefaultVariant: [
            .fr: "Variante audio par défaut",
            .en: "Default audio variant",
            .es: "Variante de audio por defecto"
        ],
        .settingsDetection: [
            .fr: "Détection de contenu",
            .en: "Content detection",
            .es: "Detección de contenido"
        ],
        .settingsBlackThreshold: [
            .fr: "Seuil de noir (secondes)",
            .en: "Black threshold (seconds)",
            .es: "Umbral de negro (segundos)"
        ],
        .settingsSilenceThreshold: [
            .fr: "Seuil de silence (secondes)",
            .en: "Silence threshold (seconds)",
            .es: "Umbral de silencio (segundos)"
        ],
        .settingsAbout: [
            .fr: "À propos", .en: "About", .es: "Acerca de"
        ],
        .settingsAboutBody: [
            .fr: "MisiQC Pro vérifie la conformité d'un master PAD aux cahiers des charges techniques des principales chaînes et plateformes.",
            .en: "MisiQC Pro checks whether a delivery master complies with the technical specs of major broadcasters and streamers.",
            .es: "MisiQC Pro comprueba si un máster de entrega cumple las normas técnicas de las principales emisoras y plataformas."
        ],
        .settingsResetButton: [
            .fr: "Réinitialiser tous les réglages",
            .en: "Reset all settings",
            .es: "Restablecer todos los ajustes"
        ],
        .settingsResetConfirm: [
            .fr: "Tous les réglages reviendront à leurs valeurs par défaut.",
            .en: "All preferences will revert to defaults.",
            .es: "Todos los ajustes volverán a los valores predeterminados."
        ],

        // Menus
        .menuFile: [.fr: "Fichier", .en: "File", .es: "Archivo"],
        .menuAnalysis: [.fr: "Analyse", .en: "Analysis", .es: "Análisis"],
        .menuProfile: [.fr: "Profil chaîne", .en: "Channel profile", .es: "Perfil de canal"],
        .menuVariant: [.fr: "Version audio", .en: "Audio version", .es: "Versión de audio"],
        .menuView: [.fr: "Affichage", .en: "View", .es: "Vista"],
        .menuHelp: [.fr: "Aide", .en: "Help", .es: "Ayuda"],
        .menuOpenFile: [
            .fr: "Ouvrir un fichier…",
            .en: "Open File…",
            .es: "Abrir archivo…"
        ],
        .menuShowReport: [
            .fr: "Afficher le rapport",
            .en: "Show Report",
            .es: "Mostrar informe"
        ],

        .actionShowSpecs: [
            .fr: "Voir normes",
            .en: "View specs",
            .es: "Ver normas"
        ],
        .errorNoProfileSelected: [
            .fr: "Aucun profil sélectionné.",
            .en: "No profile selected.",
            .es: "Ningún perfil seleccionado."
        ],
        .settingsToleranceLevel: [
            .fr: "Niveau de tolérance",
            .en: "Tolerance level",
            .es: "Nivel de tolerancia"
        ],
        .settingsToleranceSection: [
            .fr: "Plage signal vidéo (Y)",
            .en: "Video signal range (Y)",
            .es: "Rango de señal de vídeo (Y)"
        ],
        .settingsToleranceFooter: [
            .fr: "EBU R103 v3.0 est la norme européenne broadcast standard. Strict broadcast s'aligne sur France TV / ARTE / BBC. Permissif OTT convient aux livraisons streaming.",
            .en: "EBU R103 v3.0 is the European broadcast standard. Strict broadcast matches France TV / ARTE / BBC. Permissive OTT suits streaming deliveries.",
            .es: "EBU R103 v3.0 es la norma europea estándar. Strict broadcast se alinea con France TV / ARTE / BBC. Permisivo OTT para streaming."
        ],

        // Categories
        .catContainer: [.fr: "Conteneur", .en: "Container", .es: "Contenedor"],
        .catVideo:     [.fr: "Vidéo", .en: "Video", .es: "Vídeo"],
        .catAudio:     [.fr: "Audio", .en: "Audio", .es: "Audio"],
        .catLoudness:  [.fr: "Loudness", .en: "Loudness", .es: "Loudness"],
        .catStructure: [.fr: "Structure", .en: "Structure", .es: "Estructura"],

        // Stages
        .stageGOP:        [.fr: "Analyse de la structure GOP", .en: "GOP structure analysis", .es: "Análisis estructura GOP"],
        .stageInterlace:  [.fr: "Détection du mode de balayage", .en: "Scan mode detection", .es: "Detección modo de barrido"],
        .stageCrop:       [.fr: "Détection letterbox / pillarbox", .en: "Letterbox / pillarbox detection", .es: "Detección letterbox / pillarbox"],
        .stagePhase:      [.fr: "Mesure de la phase L/R", .en: "L/R phase measurement", .es: "Medición fase L/R"],
        .stageAudioStats: [.fr: "Statistiques audio (DC, crêtes)", .en: "Audio statistics (DC, peaks)", .es: "Estadísticas audio (DC, picos)"],
        .stageFreeze:     [.fr: "Détection des images figées", .en: "Frozen frame detection", .es: "Detección imágenes congeladas"],
        .stageDuplicate:  [.fr: "Détection des images dupliquées", .en: "Duplicate frame detection", .es: "Detección imágenes duplicadas"],
        .stageDeadPixel:  [.fr: "Détection des pixels stuck", .en: "Stuck pixel detection", .es: "Detección píxeles bloqueados"],
        .stagePSE:        [.fr: "Analyse PSE (épilepsie photosensible)", .en: "PSE analysis (photosensitive epilepsy)", .es: "Análisis PSE (epilepsia fotosensible)"],
        .stageSignalRange: [.fr: "Analyse de la plage signal vidéo", .en: "Video signal range analysis", .es: "Análisis rango señal vídeo"],
        .stageLeader: [
            .fr: "Détection mires + tone 1 kHz",
            .en: "Bars + 1 kHz tone detection",
            .es: "Detección barras + tono 1 kHz"
        ],
        .stageAudioPops: [
            .fr: "Détection des pops / clicks audio",
            .en: "Audio pops / clicks detection",
            .es: "Detección de pops / clics audio"
        ],
        .stageMetadataExtras: [
            .fr: "Métadonnées (sous-titres, AFD, HDR)",
            .en: "Metadata (subtitles, AFD, HDR)",
            .es: "Metadatos (subtítulos, AFD, HDR)"
        ],

        // Check labels
        .lblContainer:        [.fr: "Conteneur", .en: "Container", .es: "Contenedor"],
        .lblOP:               [.fr: "Operational Pattern", .en: "Operational Pattern", .es: "Operational Pattern"],
        .lblVideoCodec:       [.fr: "Codec vidéo", .en: "Video codec", .es: "Códec vídeo"],
        .lblVideoProfile:     [.fr: "Profil vidéo", .en: "Video profile", .es: "Perfil vídeo"],
        .lblResolution:       [.fr: "Résolution", .en: "Resolution", .es: "Resolución"],
        .lblFramerate:        [.fr: "Fréquence", .en: "Frame rate", .es: "Velocidad"],
        .lblInterlace:        [.fr: "Entrelacement", .en: "Interlace", .es: "Entrelazado"],
        .lblVideoBitrate:     [.fr: "Débit vidéo", .en: "Video bitrate", .es: "Tasa de bits vídeo"],
        .lblColorSpace:       [.fr: "Espace colorimétrique", .en: "Color space", .es: "Espacio de color"],
        .lblColorPrimaries:   [.fr: "Primaires couleurs", .en: "Color primaries", .es: "Primarios de color"],
        .lblColorTransfer:    [.fr: "Gamma / Transfert", .en: "Gamma / Transfer", .es: "Gamma / Transferencia"],
        .lblColorRange:       [.fr: "Plage de codage", .en: "Color range", .es: "Rango de codificación"],
        .lblAspectRatio:      [.fr: "Aspect Ratio", .en: "Aspect ratio", .es: "Relación de aspecto"],
        .lblGopStructure:     [.fr: "Structure GOP", .en: "GOP structure", .es: "Estructura GOP"],
        .lblScanMode:         [.fr: "Mode de balayage (idet)", .en: "Scan mode (idet)", .es: "Modo barrido (idet)"],
        .lblFraming:          [.fr: "Cadrage (letterbox / pillarbox)", .en: "Framing (letterbox / pillarbox)", .es: "Encuadre (letterbox / pillarbox)"],
        .lblSignalRange:      [.fr: "Plage signal vidéo (Y)", .en: "Video signal range (Y)", .es: "Rango señal vídeo (Y)"],
        .lblFreeze:           [.fr: "Images figées (freeze)", .en: "Frozen frames", .es: "Imágenes congeladas"],
        .lblDuplicateFrames:  [.fr: "Images dupliquées", .en: "Duplicate frames", .es: "Imágenes duplicadas"],
        .lblStuckPixels:      [.fr: "Pixels stuck", .en: "Stuck pixels", .es: "Píxeles bloqueados"],
        .lblPSE:              [.fr: "PSE / Photosensibilité", .en: "PSE / Photosensitivity", .es: "PSE / Fotosensibilidad"],
        .lblAudioChannels:    [.fr: "Nombre de canaux audio", .en: "Audio channel count", .es: "Número de canales"],
        .lblAudioCodec:       [.fr: "Codec audio", .en: "Audio codec", .es: "Códec audio"],
        .lblAudioBitDepth:    [.fr: "Profondeur", .en: "Bit depth", .es: "Profundidad"],
        .lblAudioSampleRate:  [.fr: "Échantillonnage", .en: "Sample rate", .es: "Muestreo"],
        .lblTrueAvg:          [.fr: "True Peak", .en: "True Peak", .es: "True Peak"],
        .lblDCOffset:         [.fr: "Biais DC audio", .en: "Audio DC offset", .es: "Sesgo DC audio"],
        .lblTimecodeStart:    [.fr: "Timecode de départ", .en: "Start timecode", .es: "Timecode inicio"],
        .lblBlackLongest:     [.fr: "Plus long noir", .en: "Longest black segment", .es: "Negro más largo"],
        .lblSilenceLongest:   [.fr: "Plus long silence", .en: "Longest silence", .es: "Silencio más largo"],
        .lblTotalDuration:    [.fr: "Durée totale", .en: "Total duration", .es: "Duración total"],
        .lblBlackDetected:    [.fr: "Noirs détectés", .en: "Black segments detected", .es: "Negros detectados"],
        .lblVideoStream:      [.fr: "Flux vidéo", .en: "Video stream", .es: "Flujo de vídeo"],
        .lblLeaderBars:       [.fr: "Mires d'amorce", .en: "Bars leader", .es: "Barras de amorce"],
        .lblLeaderTone:       [.fr: "Tone 1 kHz d'amorce", .en: "1 kHz tone leader", .es: "Tono 1 kHz de amorce"],
        .lblSubtitles:        [.fr: "Sous-titres embarqués", .en: "Embedded subtitles", .es: "Subtítulos embebidos"],
        .lblAFD:              [.fr: "AFD (Active Format Description)", .en: "AFD (Active Format Description)", .es: "AFD (Active Format Description)"],
        .lblHDR:              [.fr: "Métadonnées HDR", .en: "HDR metadata", .es: "Metadatos HDR"],
        .lblPostRoll:         [.fr: "Post-roll (noir de fin)", .en: "Post-roll (trailing black)", .es: "Post-roll (negro final)"],
        .lblAudioPops:        [.fr: "Pops / clicks audio", .en: "Audio pops / clicks", .es: "Pops / clics audio"],

        .valDetected:    [.fr: "Détecté",     .en: "Detected",     .es: "Detectado"],
        .valNotDetected: [.fr: "Non détecté", .en: "Not detected", .es: "No detectado"],
        .valBarsLine: [
            .fr: "Détectées · durée %@ s · confiance %@%%",
            .en: "Detected · duration %@ s · confidence %@%%",
            .es: "Detectadas · duración %@ s · confianza %@%%"
        ],
        .valToneLine: [
            .fr: "Détecté · niveau %@ dBFS · confiance %@%%",
            .en: "Detected · level %@ dBFS · confidence %@%%",
            .es: "Detectado · nivel %@ dBFS · confianza %@%%"
        ],
        .valTrailingBlack: [
            .fr: "Noir de fin %@ s",
            .en: "Trailing black %@ s",
            .es: "Negro final %@ s"
        ],
        .valHardCut: [
            .fr: "Coupe brutale sur dernière image",
            .en: "Hard cut on last image",
            .es: "Corte brusco en la última imagen"
        ],
        .valNoPops: [
            .fr: "Aucun saut > 6 dB détecté",
            .en: "No jump > 6 dB detected",
            .es: "Ningún salto > 6 dB detectado"
        ],
        .valPopsLine: [
            .fr: "%d saut(s) · pire %@ dB à %@",
            .en: "%d jump(s) · worst %@ dB at %@",
            .es: "%d salto(s) · peor %@ dB en %@"
        ],
        .valPopsSample: [
            .fr: "Échantillons : %@",
            .en: "Samples: %@",
            .es: "Muestras: %@"
        ],
        .valAFDAbsent: [.fr: "Absent",   .en: "Absent",   .es: "Ausente"],
        .valAFDCode:   [.fr: "AFD %d · %@", .en: "AFD %d · %@", .es: "AFD %d · %@"],
        .valNoHDR: [
            .fr: "Aucune métadonnée HDR",
            .en: "No HDR metadata",
            .es: "Sin metadatos HDR"
        ],
        .valHDRMaster:   [.fr: "Mastering Display ✓",
                          .en: "Mastering Display ✓",
                          .es: "Mastering Display ✓"],
        .valHDRCLL:      [.fr: "MaxCLL/FALL ✓",
                          .en: "MaxCLL/FALL ✓",
                          .es: "MaxCLL/FALL ✓"],
        .valHDRPipeline: [.fr: "Pipeline BT.2020 + PQ/HLG",
                          .en: "BT.2020 + PQ/HLG pipeline",
                          .es: "Pipeline BT.2020 + PQ/HLG"],
        .valExpectedHDR: [
            .fr: "Mastering Display + MaxCLL/FALL",
            .en: "Mastering Display + MaxCLL/FALL",
            .es: "Mastering Display + MaxCLL/FALL"
        ],
        .valExpectedTone: [
            .fr: "-18 dBFS ± 3",
            .en: "-18 dBFS ± 3",
            .es: "-18 dBFS ± 3"
        ],
        .valExpectedPostRollRecommend: [
            .fr: "≥ 1 s recommandé",
            .en: "≥ 1 s recommended",
            .es: "≥ 1 s recomendado"
        ],
        .valSubsStreams: [
            .fr: "%d stream(s)",
            .en: "%d stream(s)",
            .es: "%d stream(s)"
        ],

        .afd0:  [.fr: "Indéfini",                  .en: "Undefined",                   .es: "Indefinido"],
        .afd2:  [.fr: "Boîte 16:9 (haut)",         .en: "16:9 box (top)",              .es: "Caja 16:9 (arriba)"],
        .afd3:  [.fr: "Boîte 14:9 (haut)",         .en: "14:9 box (top)",              .es: "Caja 14:9 (arriba)"],
        .afd4:  [.fr: "Boîte > 16:9 (centré)",     .en: "> 16:9 centered box",         .es: "Caja > 16:9 (centrada)"],
        .afd8:  [.fr: "Image plein cadre",         .en: "Full-frame image",            .es: "Imagen a pantalla completa"],
        .afd9:  [.fr: "4:3 plein cadre",           .en: "4:3 full frame",              .es: "4:3 pantalla completa"],
        .afd10: [.fr: "16:9 plein cadre",          .en: "16:9 full frame",             .es: "16:9 pantalla completa"],
        .afd11: [.fr: "14:9 plein cadre",          .en: "14:9 full frame",             .es: "14:9 pantalla completa"],
        .afd13: [.fr: "4:3 protégé 14:9",          .en: "4:3 with 14:9 protect",       .es: "4:3 protegido 14:9"],
        .afd14: [.fr: "16:9 protégé 14:9",         .en: "16:9 with 14:9 protect",      .es: "16:9 protegido 14:9"],
        .afd15: [.fr: "16:9 protégé 4:3",          .en: "16:9 with 4:3 protect",       .es: "16:9 protegido 4:3"],
        .afdCodeFallback: [
            .fr: "AFD code %d", .en: "AFD code %d", .es: "Código AFD %d"
        ],

        .remedPDFTitle: [
            .fr: "MisiQC Pro", .en: "MisiQC Pro", .es: "MisiQC Pro"
        ],
        .remedPDFSubtitle: [
            .fr: "Guide de correction technique",
            .en: "Technical remediation guide",
            .es: "Guía de corrección técnica"
        ],
        .remedFile: [
            .fr: "Fichier", .en: "File", .es: "Archivo"
        ],
        .remedProfile: [
            .fr: "Profil chaîne", .en: "Channel profile", .es: "Perfil de canal"
        ],
        .remedToFix: [
            .fr: "Non-conformités à corriger",
            .en: "Non-conformities to fix",
            .es: "No conformidades a corregir"
        ],
        .remedHowToUseTitle: [
            .fr: "Comment utiliser ce guide",
            .en: "How to use this guide",
            .es: "Cómo usar esta guía"
        ],
        .remedHowToUseBody: [
            .fr: "Pour chaque échec relevé dans le rapport principal, vous trouverez une fiche détaillant la cause technique et la procédure de correction dans les principaux logiciels de mastering (DaVinci Resolve, Adobe Premiere Pro, Avid Media Composer) ainsi que la commande FFmpeg équivalente.\n\nAprès chaque correction, relancez une analyse complète dans MisiQC Pro pour valider la conformité avant livraison à la chaîne.",
            .en: "For every failure raised in the main report, you'll find a card detailing the technical cause and the fix procedure in the major mastering apps (DaVinci Resolve, Adobe Premiere Pro, Avid Media Composer) plus the equivalent FFmpeg command.\n\nAfter each fix, re-run a full analysis in MisiQC Pro to validate compliance before delivering to the channel.",
            .es: "Para cada fallo del informe principal, encontrará una ficha con la causa técnica y el procedimiento de corrección en los principales programas de mastering (DaVinci Resolve, Adobe Premiere Pro, Avid Media Composer) más el comando FFmpeg equivalente.\n\nTras cada corrección, vuelva a lanzar un análisis completo en MisiQC Pro para validar la conformidad antes de entregar al canal."
        ],
        .remedRunningFooter: [
            .fr: "Guide de correction",
            .en: "Remediation guide",
            .es: "Guía de corrección"
        ],
        .remedPageHeader: [
            .fr: "Guide de correction — MisiQC Pro",
            .en: "Remediation guide — MisiQC Pro",
            .es: "Guía de corrección — MisiQC Pro"
        ],
        .remedNothingToFix: [
            .fr: "Aucun échec à corriger dans ce rapport.",
            .en: "No failures to fix in this report.",
            .es: "Sin fallos a corregir en este informe."
        ],

        .rptPDFSubtitle: [
            .fr: "Rapport de contrôle qualité PAD",
            .en: "Broadcast master QC report",
            .es: "Informe de control de calidad PAD"
        ],
        .rptPDFContinued: [
            .fr: "MisiQC Pro — Rapport (suite)",
            .en: "MisiQC Pro — Report (cont.)",
            .es: "MisiQC Pro — Informe (cont.)"
        ],
        .rptInfoFile:       [.fr: "Fichier",    .en: "File",        .es: "Archivo"],
        .rptInfoProfile:    [.fr: "Profil",     .en: "Profile",     .es: "Perfil"],
        .rptInfoDuration:   [.fr: "Durée",      .en: "Duration",    .es: "Duración"],
        .rptInfoAnalyzedAt: [.fr: "Analysé le", .en: "Analyzed on", .es: "Analizado el"],
        .rptVerdictGlobal: [
            .fr: "VERDICT GLOBAL", .en: "OVERALL VERDICT", .es: "VEREDICTO GLOBAL"
        ],
        .rptSignature: [
            .fr: "Rapport généré par MisiQC Pro — Conçu par Matthieu Misiraca · www.misiraca.com",
            .en: "Report generated by MisiQC Pro — Built by Matthieu Misiraca · www.misiraca.com",
            .es: "Informe generado por MisiQC Pro — Creado por Matthieu Misiraca · www.misiraca.com"
        ],
        .rptDateFormat: [
            .fr: "dd/MM/yyyy 'à' HH:mm",
            .en: "yyyy-MM-dd 'at' HH:mm",
            .es: "dd/MM/yyyy 'a las' HH:mm"
        ],

        .valPresent: [.fr: "présent", .en: "present", .es: "presente"],
        .valAbsent:  [.fr: "absent",  .en: "absent",  .es: "ausente"],
        .valNone:    [.fr: "aucun",   .en: "none",    .es: "ninguno"],
        .valInformational: [
            .fr: "informationnel", .en: "informational", .es: "informativo"
        ],
        .errPDFWriteFailed: [
            .fr: "Échec de l'écriture du PDF : %@",
            .en: "PDF write failed: %@",
            .es: "Fallo al escribir el PDF: %@"
        ],

        .valComputedDAR: [
            .fr: " (calculé : %@)",
            .en: " (computed: %@)",
            .es: " (calculado: %@)"
        ],
        .detColorRangeNotSet: [
            .fr: "Non renseignée par le codec — à vérifier.",
            .en: "Not declared by the codec — to verify.",
            .es: "No declarado por el códec — verificar."
        ],

        .fmtSignalActual: [
            .fr: "%@%% en moy. (pic %@%%) · %@ · excursion ±%@%%",
            .en: "%@%% mean (peak %@%%) · %@ · excursion ±%@%%",
            .es: "%@%% media (pico %@%%) · %@ · excursión ±%@%%"
        ],
        .fmtSignalRangeExpected: [
            .fr: "0%%–100%% (Y %d–%d)",
            .en: "0%%–100%% (Y %d–%d)",
            .es: "0%%–100%% (Y %d–%d)"
        ],
        .fmtSignalMeanWarn: [
            .fr: "moyenne %@%% > %@%%",
            .en: "mean %@%% > %@%%",
            .es: "media %@%% > %@%%"
        ],
        .fmtSignalMeanFail: [
            .fr: "moyenne %@%% > %@%%",
            .en: "mean %@%% > %@%%",
            .es: "media %@%% > %@%%"
        ],
        .fmtSignalPeakWarn: [
            .fr: "pic frame %@%% > %@%%",
            .en: "frame peak %@%% > %@%%",
            .es: "pico frame %@%% > %@%%"
        ],
        .fmtSignalPeakFail: [
            .fr: "pic frame %@%% > %@%%",
            .en: "frame peak %@%% > %@%%",
            .es: "pico frame %@%% > %@%%"
        ],
        .fmtSignalYWarn: [
            .fr: "Y dépasse de %@%% la plage",
            .en: "Y exceeds the range by %@%%",
            .es: "Y excede el rango en %@%%"
        ],
        .fmtSignalYFail: [
            .fr: "Y dépasse de %@%% la plage légale",
            .en: "Y exceeds legal range by %@%%",
            .es: "Y excede el rango legal en %@%%"
        ],
        .valInfraBlack:  [.fr: "infra-noir", .en: "infra-black", .es: "infra-negro"],
        .valSuperWhite:  [.fr: "super-blanc", .en: "super-white", .es: "super-blanco"],
        .fmtSignalKindLabel: [
            .fr: "type : %@",
            .en: "type: %@",
            .es: "tipo: %@"
        ],
        .fmtSignalPass: [
            .fr: "Signal conforme broadcast sur %d frames.",
            .en: "Signal compliant with broadcast on %d frames.",
            .es: "Señal conforme con broadcast en %d fotogramas."
        ],
        .detSignalWarn: [
            .fr: "Acceptable pour la plupart des diffuseurs, à surveiller.",
            .en: "Acceptable for most broadcasters, but worth monitoring.",
            .es: "Aceptable para la mayoría de emisores, pero vigilar."
        ],
        .detSignalFail: [
            .fr: "Re-clipper côté grading avant livraison.",
            .en: "Re-clip during grading before delivery.",
            .es: "Recortar en grading antes de entregar."
        ],
        .errSignalUnavailable: [
            .fr: "Mesure indisponible.",
            .en: "Measurement unavailable.",
            .es: "Medición no disponible."
        ],

        .valNoBlackDetected: [
            .fr: "aucun noir détecté",
            .en: "no black detected",
            .es: "sin negro detectado"
        ],
        .fmtBlackActual: [
            .fr: "%@ s (%d segment(s))",
            .en: "%@ s (%d segment(s))",
            .es: "%@ s (%d segmento(s))"
        ],
        .valNoSilenceAnomaly: [
            .fr: "aucun silence anormal",
            .en: "no abnormal silence",
            .es: "sin silencio anormal"
        ],
        .fmtSilenceActual: [
            .fr: "%@ s sur la piste %d",
            .en: "%@ s on track %d",
            .es: "%@ s en la pista %d"
        ],
        .fmtBlackSegmentsCount: [
            .fr: "%d segment(s)",
            .en: "%d segment(s)",
            .es: "%d segmento(s)"
        ],

        .fmtFreezeActual: [
            .fr: "%d segment(s), %@ s figé (~%@%% du programme)",
            .en: "%d segment(s), %@ s frozen (~%@%% of programme)",
            .es: "%d segmento(s), %@ s congelado (~%@%% del programa)"
        ],
        .fmtFreezeDetail: [
            .fr: "Le plus long : %@ s. Premières occurrences : %@.",
            .en: "Longest: %@ s. First occurrences: %@.",
            .es: "El más largo: %@ s. Primeras apariciones: %@."
        ],
        .expFreezeNone: [
            .fr: "aucune > 2 s",
            .en: "none > 2 s",
            .es: "ninguna > 2 s"
        ],

        .fmtDupActual: [
            .fr: "%d / %d frames (%@%%) — durée affectée ≈ %@",
            .en: "%d / %d frames (%@%%) — affected duration ≈ %@",
            .es: "%d / %d frames (%@%%) — duración afectada ≈ %@"
        ],
        .expDupCadence: [
            .fr: "≤ 0.5%% (cadence normale)",
            .en: "≤ 0.5%% (normal cadence)",
            .es: "≤ 0.5%% (cadencia normal)"
        ],
        .detDupUnknown: [
            .fr: "Nombre de frames source indisponible.",
            .en: "Source frame count unavailable.",
            .es: "Número de frames de origen no disponible."
        ],
        .detDupPass: [
            .fr: "Cadence stable, pas de duplication anormale.",
            .en: "Stable cadence, no abnormal duplication.",
            .es: "Cadencia estable, sin duplicación anormal."
        ],
        .detDupWarn: [
            .fr: "Quelques répétitions détectées — peut indiquer une compression à débit serré ou une rare correction de cadence.",
            .en: "A few repeats detected — may indicate a tight-bitrate compression or rare cadence correction.",
            .es: "Algunas repeticiones detectadas — puede indicar compresión con bitrate ajustado o corrección de cadencia rara."
        ],
        .detDupFail: [
            .fr: "Forte proportion de frames dupliquées — symptomatique d'une conversion 29.97→25 ratée, d'un 3:2 pulldown non retiré ou d'une source figée par segments.",
            .en: "High duplicate ratio — typical of a botched 29.97→25 conversion, leftover 3:2 pulldown or a partly-frozen source.",
            .es: "Alta proporción de frames duplicados — típico de una conversión 29.97→25 fallida, 3:2 pulldown no retirado o fuente congelada por segmentos."
        ],

        .expFramingFull: [
            .fr: "image plein cadre",
            .en: "full-frame image",
            .es: "imagen pantalla completa"
        ],
        .fmtFramingActual: [
            .fr: "crop = %dx%d (%d/%d) sur %dx%d",
            .en: "crop = %dx%d (%d/%d) on %dx%d",
            .es: "crop = %dx%d (%d/%d) sobre %dx%d"
        ],
        .detFramingBoth: [
            .fr: "Bandes noires haut/bas et gauche/droite — image non plein cadre.",
            .en: "Black bars top/bottom and left/right — image not full-frame.",
            .es: "Bandas negras arriba/abajo y izquierda/derecha — imagen no full-frame."
        ],
        .detLetterbox: [
            .fr: "Bandes noires horizontales (letterbox) détectées — vérifier l'aspect ratio livré.",
            .en: "Horizontal black bars (letterbox) detected — verify the delivered aspect ratio.",
            .es: "Bandas negras horizontales (letterbox) detectadas — verificar la relación de aspecto entregada."
        ],
        .detPillarbox: [
            .fr: "Bandes noires verticales (pillarbox) détectées — vérifier l'aspect ratio livré.",
            .en: "Vertical black bars (pillarbox) detected — verify the delivered aspect ratio.",
            .es: "Bandas negras verticales (pillarbox) detectadas — verificar la relación de aspecto entregada."
        ],

        .expPhaseMono: [
            .fr: "≥ 0.5 (compatible mono)",
            .en: "≥ 0.5 (mono compatible)",
            .es: "≥ 0.5 (compatible mono)"
        ],
        .fmtPhaseActual: [
            .fr: "moy %@ · min %@ · anti-phase %@%%",
            .en: "mean %@ · min %@ · anti-phase %@%%",
            .es: "media %@ · mín %@ · anti-fase %@%%"
        ],
        .detPhasePass: [
            .fr: "Signal stéréo correctement corrélé, compatible down-mix mono.",
            .en: "Stereo signal correctly correlated, mono down-mix safe.",
            .es: "Señal estéreo correctamente correlada, down-mix mono seguro."
        ],
        .detPhaseWarn: [
            .fr: "Stéréo très large — vérifier que le programme reste audible en mono.",
            .en: "Very wide stereo — confirm the programme remains audible in mono.",
            .es: "Estéreo muy ancho — comprobar que el programa sigue siendo audible en mono."
        ],
        .detPhaseFail: [
            .fr: "Phase moyenne négative — le programme se cancelle en down-mix mono.",
            .en: "Negative mean phase — the programme cancels on mono down-mix.",
            .es: "Fase media negativa — el programa se cancela en down-mix mono."
        ],
        .lblPhasePrefix: [
            .fr: "Phase L/R — %@",
            .en: "L/R phase — %@",
            .es: "Fase L/R — %@"
        ],

        .expDCOffset: [
            .fr: "≤ 1%% de pleine échelle",
            .en: "≤ 1%% of full scale",
            .es: "≤ 1%% de escala completa"
        ],
        .fmtDCActual: [
            .fr: "%@ (%@%% de pleine échelle)",
            .en: "%@ (%@%% of full scale)",
            .es: "%@ (%@%% de escala completa)"
        ],
        .detDCWarn: [
            .fr: "Biais DC modéré — peut indiquer un préampli mal calibré.",
            .en: "Moderate DC bias — may indicate a poorly calibrated preamp.",
            .es: "Sesgo DC moderado — puede indicar un preamplificador mal calibrado."
        ],
        .detDCFail: [
            .fr: "Biais DC élevé — clicks à la coupure, perte de headroom, risque de clipping asymétrique.",
            .en: "High DC bias — clicks on cuts, lost headroom, risk of asymmetric clipping.",
            .es: "Sesgo DC alto — clics en los cortes, pérdida de headroom, riesgo de clipping asimétrico."
        ],

        .expPSE: [
            .fr: "≤ 3 flashes/sec (seuil PSE)",
            .en: "≤ 3 flashes/sec (PSE threshold)",
            .es: "≤ 3 flashes/seg (umbral PSE)"
        ],
        .fmtPSEActual: [
            .fr: "%d flashes détectés · pic %@/sec · %d zones à risque",
            .en: "%d flashes detected · peak %@/sec · %d risky zones",
            .es: "%d flashes detectados · pico %@/seg · %d zonas de riesgo"
        ],
        .detPSEPass: [
            .fr: "Aucune zone n'excède 3 transitions de luminance/sec — pas de risque évident.",
            .en: "No zone exceeds 3 luminance transitions/sec — no obvious risk.",
            .es: "Ninguna zona supera 3 transiciones de luminancia/seg — sin riesgo evidente."
        ],
        .detPSEWarn: [
            .fr: "Zones à risque modéré : %@. À faire vérifier par un test Harding certifié.",
            .en: "Moderate-risk zones: %@. Verify with a certified Harding test.",
            .es: "Zonas de riesgo moderado: %@. Verificar con un test Harding certificado."
        ],
        .detPSEFail: [
            .fr: "Risque PSE élevé — pic à %@ flashes/sec sur %d segment(s) (%@). À retraiter avant diffusion broadcast.",
            .en: "High PSE risk — peak at %@ flashes/sec across %d segment(s) (%@). Rework before broadcast.",
            .es: "Riesgo PSE alto — pico en %@ flashes/seg en %d segmento(s) (%@). Reprocesar antes de emitir."
        ],

        .expDeadPixel: [
            .fr: "≤ 0.05%%",
            .en: "≤ 0.05%%",
            .es: "≤ 0.05%%"
        ],
        .fmtDeadPixelActual: [
            .fr: "%d / %d pixels échantillonnés stuck (%@%%, %d frames testées)",
            .en: "%d / %d sampled pixels stuck (%@%%, %d frames tested)",
            .es: "%d / %d píxeles muestreados bloqueados (%@%%, %d frames probados)"
        ],
        .detDeadPixelPass: [
            .fr: "Aucun pixel persistant détecté sur la grille de test.",
            .en: "No persistent pixel detected on the test grid.",
            .es: "Ningún píxel persistente detectado en la rejilla de prueba."
        ],
        .detDeadPixelWarn: [
            .fr: "Quelques pixels n'ont pas évolué — peut être du contenu (logo, bandeau fixe) ou de vrais stuck pixels. À vérifier visuellement.",
            .en: "A few pixels didn't change — could be content (logo, fixed banner) or real stuck pixels. Verify visually.",
            .es: "Algunos píxeles no cambiaron — puede ser contenido (logo, banda fija) o píxeles realmente bloqueados. Verificar visualmente."
        ],
        .detDeadPixelFail: [
            .fr: "Beaucoup de pixels identiques sur toute la durée — capteur défectueux probable ou grosse zone d'incrustation statique.",
            .en: "Many identical pixels throughout — likely defective sensor or large static overlay area.",
            .es: "Muchos píxeles idénticos durante todo el programa — sensor defectuoso probable o zona estática grande."
        ],

        .tipConfVerified: [
            .fr: "Profil vérifié contre le PDF officiel de la chaîne",
            .en: "Profile verified against the channel's official PDF",
            .es: "Perfil verificado contra el PDF oficial del canal"
        ],
        .tipConfStandard: [
            .fr: "Profil basé sur un standard public (EBU, CST, DPP, ATSC)",
            .en: "Profile based on a public standard (EBU, CST, DPP, ATSC)",
            .es: "Perfil basado en un estándar público (EBU, CST, DPP, ATSC)"
        ],
        .tipConfGeneric: [
            .fr: "Profil générique — à valider avec le diffuseur avant livraison",
            .en: "Generic profile — validate with the broadcaster before delivery",
            .es: "Perfil genérico — validar con el emisor antes de entregar"
        ],

        .lblLoudnessIntegrated: [
            .fr: "Loudness intégré", .en: "Integrated loudness", .es: "Loudness integrado"
        ],
        .lblLoudnessTruePeak: [
            .fr: "True Peak", .en: "True Peak", .es: "True Peak"
        ],
        .lblLoudnessLRA: [
            .fr: "LRA", .en: "LRA", .es: "LRA"
        ],

        .licenseSettingsTab: [.fr: "Licence", .en: "License", .es: "Licencia"],
        .licenseSectionStatus: [
            .fr: "Statut", .en: "Status", .es: "Estado"
        ],
        .licenseSectionActivate: [
            .fr: "Activer une licence",
            .en: "Activate a license",
            .es: "Activar una licencia"
        ],
        .licenseStatusTrial: [
            .fr: "Essai en cours — %d jour(s) restant(s)",
            .en: "Trial — %d day(s) left",
            .es: "Prueba — %d día(s) restante(s)"
        ],
        .licenseStatusLicensed: [
            .fr: "Licence active jusqu'au %@ · Hôte : %@",
            .en: "Licence active until %@ · Host: %@",
            .es: "Licencia activa hasta %@ · Host: %@"
        ],
        .licenseStatusExpired: [
            .fr: "Essai expiré — acheter une licence pour exporter PDF / CSV",
            .en: "Trial expired — buy a license to export PDF / CSV",
            .es: "Prueba expirada — compra una licencia para exportar PDF / CSV"
        ],
        .licenseTrialBanner: [
            .fr: "Essai — %d jour(s) restant(s)",
            .en: "Trial — %d day(s) left",
            .es: "Prueba — %d día(s) restante(s)"
        ],
        .licenseTrialBannerExpired: [
            .fr: "Essai expiré",
            .en: "Trial expired",
            .es: "Prueba expirada"
        ],
        .licenseLastDay: [
            .fr: "Dernier jour",
            .en: "Last day",
            .es: "Último día"
        ],
        .licenseEnterKey: [
            .fr: "Clé reçue par email",
            .en: "Licence key (from email)",
            .es: "Clave de licencia (del email)"
        ],
        .licenseEnterKeyPlaceholder: [
            .fr: "Collez votre clé ici…",
            .en: "Paste your license key here…",
            .es: "Pega tu clave aquí…"
        ],
        .licenseActivateButton: [
            .fr: "Activer", .en: "Activate", .es: "Activar"
        ],
        .licenseDeactivateButton: [
            .fr: "Désactiver la licence",
            .en: "Deactivate license",
            .es: "Desactivar licencia"
        ],
        .licenseBuyButton: [
            .fr: "Acheter une licence",
            .en: "Buy a license",
            .es: "Comprar una licencia"
        ],
        .licenseErrorMalformed: [
            .fr: "Clé incomplète (%d/%d caractères) — recopiez la clé entière depuis l'email.",
            .en: "Incomplete key (%d/%d characters) — copy the entire key from your email.",
            .es: "Clave incompleta (%d/%d caracteres) — copia la clave entera desde el correo."
        ],
        .licenseErrorSignature: [
            .fr: "Signature invalide — cette clé n'est pas valide pour MisiQC Pro.",
            .en: "Invalid signature — this key isn't valid for MisiQC Pro.",
            .es: "Firma inválida — esta clave no es válida para MisiQC Pro."
        ],
        .licenseErrorExpired: [
            .fr: "Cette clé a expiré le %@.",
            .en: "This key expired on %@.",
            .es: "Esta clave expiró el %@."
        ],
        .licenseErrorUnsupported: [
            .fr: "Format de clé non reconnu — mettez à jour MisiQC Pro.",
            .en: "Unsupported key format — please update MisiQC Pro.",
            .es: "Formato de clave no reconocido — actualiza MisiQC Pro."
        ],
        .licenseActivatedTitle: [
            .fr: "Licence activée 🎉",
            .en: "License activated 🎉",
            .es: "Licencia activada 🎉"
        ],
        .licenseActivatedMessage: [
            .fr: "Merci ! Licence valide jusqu'au %@.",
            .en: "Thanks! License valid until %@.",
            .es: "¡Gracias! Licencia válida hasta %@."
        ],
        .licenseExpiredTitle: [
            .fr: "Essai expiré",
            .en: "Trial expired",
            .es: "Prueba expirada"
        ],
        .licenseExpiredMessage: [
            .fr: "Votre période d'essai de 7 jours est terminée. Achetez une licence pour exporter vos rapports.",
            .en: "Your 7-day trial is over. Buy a license to export your reports.",
            .es: "Tu prueba de 7 días ha terminado. Compra una licencia para exportar tus informes."
        ],
        .licenseHost: [
            .fr: "Hôte", .en: "Host", .es: "Host"
        ],
        .licenseWatermark: [
            .fr: "Licence #%@ · Hôte : %@",
            .en: "License #%@ · Host: %@",
            .es: "Licencia #%@ · Host: %@"
        ],
        .licenseWatermarkTrial: [
            .fr: "MisiQC Pro · Essai",
            .en: "MisiQC Pro · Trial",
            .es: "MisiQC Pro · Prueba"
        ],
        .licenseRestrictExports: [
            .fr: "Achetez une licence pour réactiver l'export PDF / CSV.",
            .en: "Buy a license to re-enable PDF / CSV exports.",
            .es: "Compra una licencia para reactivar la exportación PDF / CSV."
        ],
        .licenseStatusLifetime: [
            .fr: "Licence à vie active · Hôte : %@",
            .en: "Lifetime license active · Host: %@",
            .es: "Licencia de por vida activa · Host: %@"
        ],
        .licenseExpiryLifetime: [
            .fr: "à vie", .en: "lifetime", .es: "de por vida"
        ],

        .menuCheckUpdates: [
            .fr: "Vérifier les mises à jour…",
            .en: "Check for Updates…",
            .es: "Buscar actualizaciones…"
        ],

        // SpecDetailView
        .specHeaderContainer: [.fr: "Conteneur", .en: "Container", .es: "Contenedor"],
        .specHeaderVideo:     [.fr: "Vidéo", .en: "Video", .es: "Vídeo"],
        .specHeaderAudio:     [.fr: "Audio", .en: "Audio", .es: "Audio"],
        .specHeaderLoudness:  [.fr: "Loudness EBU R128", .en: "Loudness EBU R128", .es: "Loudness EBU R128"],
        .specHeaderStructure: [.fr: "Structure", .en: "Structure", .es: "Estructura"],
        .specFormat:          [.fr: "Format", .en: "Format", .es: "Formato"],
        .specOperationalPattern: [.fr: "Operational Pattern", .en: "Operational Pattern", .es: "Operational Pattern"],
        .specShim:            [.fr: "Shim / Norme", .en: "Shim / Standard", .es: "Shim / Norma"],
        .specCodec:           [.fr: "Codec", .en: "Codec", .es: "Códec"],
        .specProfile:         [.fr: "Profil", .en: "Profile", .es: "Perfil"],
        .specResolution:      [.fr: "Résolution", .en: "Resolution", .es: "Resolución"],
        .specFramerate:       [.fr: "Fréquence", .en: "Frame rate", .es: "Velocidad"],
        .specInterlace:       [.fr: "Entrelacement", .en: "Interlace", .es: "Entrelazado"],
        .specFieldOrder:      [.fr: "Ordre des trames", .en: "Field order", .es: "Orden de campos"],
        .specBitrate:         [.fr: "Débit", .en: "Bitrate", .es: "Tasa de bits"],
        .specBitrateMode:     [.fr: "Mode débit", .en: "Bitrate mode", .es: "Modo bitrate"],
        .specGOP:             [.fr: "GOP", .en: "GOP", .es: "GOP"],
        .specGOPClosed:       [.fr: "GOP fermé", .en: "Closed GOP", .es: "GOP cerrado"],
        .specColorSpace:      [.fr: "Espace coul.", .en: "Color space", .es: "Espacio color"],
        .specColorPrimaries:  [.fr: "Primaires", .en: "Primaries", .es: "Primarios"],
        .specColorTransfer:   [.fr: "Transfert (γ)", .en: "Transfer (γ)", .es: "Transferencia (γ)"],
        .specColorRange:      [.fr: "Plage de codage", .en: "Color range", .es: "Rango codificación"],
        .specAspectRatio:     [.fr: "Aspect ratio", .en: "Aspect ratio", .es: "Relación aspecto"],
        .specAudioCodec:      [.fr: "Codec", .en: "Codec", .es: "Códec"],
        .specAudioBitDepth:   [.fr: "Profondeur", .en: "Bit depth", .es: "Profundidad"],
        .specAudioSampleRate: [.fr: "Échantillonnage", .en: "Sample rate", .es: "Muestreo"],
        .specAcceptedTracks:  [.fr: "Pistes acceptées", .en: "Accepted tracks", .es: "Pistas aceptadas"],
        .specMappingPrefix:   [.fr: "Mapping —", .en: "Mapping —", .es: "Mapeo —"],
        .specIntegratedLUFS:  [.fr: "Loudness intégré cible", .en: "Target integrated loudness", .es: "Loudness integrado objetivo"],
        .specMaxTruePeak:     [.fr: "True Peak max", .en: "Max True Peak", .es: "True Peak máx"],
        .specMaxLRA:          [.fr: "LRA max", .en: "Max LRA", .es: "LRA máx"],
        .specMaxShortTerm:    [.fr: "Short Term max", .en: "Max Short Term", .es: "Short Term máx"],
        .specTCStart:         [.fr: "Timecode IN", .en: "Start timecode", .es: "Timecode entrada"],
        .specDropFrame:       [.fr: "Drop Frame", .en: "Drop frame", .es: "Drop frame"],
        .specMaxBlack:        [.fr: "Plus long noir toléré", .en: "Longest black tolerated", .es: "Negro máx tolerado"],
        .specMaxSilence:      [.fr: "Plus long silence toléré", .en: "Longest silence tolerated", .es: "Silencio máx tolerado"],
        .specSlate:           [.fr: "Amorce / slate", .en: "Slate / leader", .es: "Pizarra / amorce"],
        .specSlateAllowed:    [.fr: "Tolérée", .en: "Allowed", .es: "Permitida"],
        .specSlateForbidden:  [.fr: "Interdite", .en: "Forbidden", .es: "Prohibida"],
        .specReference:       [.fr: "Référence", .en: "Reference", .es: "Referencia"],

        .yes:                 [.fr: "Oui", .en: "Yes", .es: "Sí"],
        .no:                  [.fr: "Non", .en: "No", .es: "No"],
        .interlaced:          [.fr: "Entrelacé", .en: "Interlaced", .es: "Entrelazado"],
        .progressive:         [.fr: "Progressif", .en: "Progressive", .es: "Progresivo"],

        .scanTFF: [
            .fr: "TFF — Entrelacé haut",
            .en: "TFF — Top Field First",
            .es: "TFF — Campo superior primero"
        ],
        .scanBFF: [
            .fr: "BFF — Entrelacé bas",
            .en: "BFF — Bottom Field First",
            .es: "BFF — Campo inferior primero"
        ],
        .scanProgressive: [
            .fr: "Progressif", .en: "Progressive", .es: "Progresivo"
        ],
        .scanUndetermined: [
            .fr: "Indéterminé", .en: "Undetermined", .es: "Indeterminado"
        ],
        .scanCountTFF: [
            .fr: "Entrelacé haut",
            .en: "Interlaced TFF",
            .es: "Entrelazado TFF"
        ],
        .scanCountBFF: [
            .fr: "Entrelacé bas",
            .en: "Interlaced BFF",
            .es: "Entrelazado BFF"
        ],
        .scanCountProgressive: [
            .fr: "Progressif", .en: "Progressive", .es: "Progresivo"
        ],
        .scanCountUndetermined: [
            .fr: "Indét.", .en: "Undet.", .es: "Indet."
        ],
        .scanPsFDetail: [
            .fr: "Probable PsF (Progressive segmented Frame) — contenu progressif livré dans un conteneur entrelacé, pratique standard en broadcast EU pour la fiction 24p/25p. À valider visuellement : si l'image est nette en mouvement = OK ; si elle peigne = vraie erreur de tag.",
            .en: "Likely PsF (Progressive segmented Frame) — progressive content in an interlaced container, standard EU broadcast practice for 24p/25p fiction. Visual check: sharp in motion = OK; combing = real tag mistake.",
            .es: "Probable PsF (Progressive segmented Frame) — contenido progresivo en contenedor entrelazado, práctica estándar broadcast EU para ficción 24p/25p. Comprobar visualmente: nítido en movimiento = OK; peine = error de tag real."
        ],
        .scanInterlacedOnProgressiveDetail: [
            .fr: "Master entrelacé livré sur une plateforme qui exige du progressif — à désentrelacer avant livraison (yadif, QTGMC, Resolve Deinterlace).",
            .en: "Interlaced master delivered to a platform that requires progressive — deinterlace before delivery (yadif, QTGMC, Resolve Deinterlace).",
            .es: "Máster entrelazado en plataforma que exige progresivo — desentrelazar antes de entregar (yadif, QTGMC, Resolve Deinterlace)."
        ],
        .scanUndeterminedDetail: [
            .fr: "Idet n'a pas pu trancher de façon fiable — typique d'un master cinéma 24p mal cadencé ou d'un contenu animé pauvre en mouvement. Vérification visuelle recommandée.",
            .en: "Idet couldn't reach a confident verdict — typical of badly cadenced 24p cinema masters or low-motion animation. Visual check recommended.",
            .es: "Idet no pudo decidir con fiabilidad — típico de másteres cine 24p mal cadenciados o animación con poco movimiento. Se recomienda verificación visual."
        ],

        // Timeline help
        .timelineTitle: [
            .fr: "Timeline signal",
            .en: "Signal timeline",
            .es: "Línea de tiempo señal"
        ],
        .timelineHelpTitle: [
            .fr: "Lecture du graphique",
            .en: "Reading the chart",
            .es: "Lectura del gráfico"
        ],
        .timelineHelpIntro: [
            .fr: "Chaque ligne suit une métrique image par image sur toute la durée du programme. Les pointillés horizontaux marquent la plage broadcast légale (≈ 64 → 940 sur 1023).",
            .en: "Each line tracks a per-frame metric across the full programme. The dashed horizontal lines mark the legal broadcast range (≈ 64 → 940 over 1023).",
            .es: "Cada línea sigue una métrica por fotograma a lo largo de todo el programa. Las líneas discontinuas marcan el rango broadcast legal (≈ 64 → 940 sobre 1023)."
        ],
        .timelineLegendYAVG: [
            .fr: "YAVG — Luma moyenne. Idéale autour du milieu de plage. Trop bas = image sombre, trop haut = image cramée.",
            .en: "YAVG — Mean luma. Ideal mid-range. Too low = dark image, too high = blown-out image.",
            .es: "YAVG — Luma media. Ideal en mitad de rango. Demasiado baja = imagen oscura, demasiado alta = quemada."
        ],
        .timelineLegendYMIN: [
            .fr: "YMIN — Pixel le plus sombre de la frame. S'il passe sous la guide basse = infra-noir (signal hors plage).",
            .en: "YMIN — Darkest pixel in the frame. If it dips below the lower guide = infra-black (out of range).",
            .es: "YMIN — Píxel más oscuro. Si baja por debajo de la guía inferior = infra-negro (fuera de rango)."
        ],
        .timelineLegendYMAX: [
            .fr: "YMAX — Pixel le plus clair. S'il dépasse la guide haute = super-blanc (clipping vidéo).",
            .en: "YMAX — Brightest pixel. If it crosses the upper guide = super-white (video clipping).",
            .es: "YMAX — Píxel más claro. Si supera la guía superior = super-blanco (clipping)."
        ],
        .timelineLegendBRNG: [
            .fr: "BRNG — Proportion de pixels hors plage broadcast (amplifiée ×10 pour visibilité). Pics oranges = passages à risque.",
            .en: "BRNG — Ratio of out-of-range pixels (×10 amplified). Orange spikes = risky passages.",
            .es: "BRNG — Proporción de píxeles fuera de rango (×10). Picos naranjas = pasajes de riesgo."
        ],
        .timelineLegendTOUT: [
            .fr: "TOUT — Outliers temporels (pixels qui sautent brutalement frame à frame). Indicateur de bruit, dropouts ou compression cassée.",
            .en: "TOUT — Temporal outliers (pixels jumping abruptly frame-to-frame). Indicator of noise, dropouts or broken compression.",
            .es: "TOUT — Outliers temporales (píxeles que saltan bruscamente). Indica ruido, dropouts o compresión rota."
        ],
        .timelineLegendVREP: [
            .fr: "VREP — Lignes répétées verticalement. Trahit head clog, dropouts bande ou perte de signal.",
            .en: "VREP — Vertically repeated lines. Reveals head clog, tape dropouts or signal loss.",
            .es: "VREP — Líneas repetidas verticalmente. Revela head clog, dropouts de cinta o pérdida de señal."
        ],
        .timelineHelpNote: [
            .fr: "BRNG / TOUT / VREP sont amplifiés ×10 dans le graphe : une trace visible = un défaut réel à investiguer.",
            .en: "BRNG / TOUT / VREP are ×10 amplified on the chart: any visible trace = a real defect worth investigating.",
            .es: "BRNG / TOUT / VREP se amplifican ×10: cualquier trazo visible = un defecto real a investigar."
        ]
    ]
}
