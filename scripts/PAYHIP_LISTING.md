# Description produit Payhip — MisiQC Pro

À copier-coller dans les champs Payhip lors de la création du produit.

---

## Nom du produit (Title)

**MisiQC Pro — Contrôle qualité PAD pour Mac**

## Sous-titre (Tagline)

**Vérifiez la conformité broadcast de vos masters vidéo en 30 secondes — France TV, TF1, M6, Canal+, ARTE, BBC, Netflix, Amazon, Disney+ et 60+ profils chaînes.**

## Description longue (à coller dans "Description")

MisiQC Pro est l'outil de contrôle qualité PAD ("Prêt À Diffuser") pour les professionnels du broadcast et de la post-production. En quelques secondes, l'app analyse votre master vidéo et vous dit s'il passe les cahiers des charges techniques des chaînes et plateformes — sans expertise FFmpeg requise, sans envoyer vos fichiers en ligne.

### 🎯 Ce que ça fait pour vous

- **Évite les rejets de livraison** — chaque non-conformité est détectée AVANT que le PAD parte chez le diffuseur
- **Gain de temps massif** — 30 secondes d'analyse au lieu de 2 heures à croiser MediaInfo + DaVinci + listening manuel
- **70+ chaînes & plateformes** couvertes — France TV, TF1, M6, Canal+, ARTE, BBC, RTBF, ARD/ZDF, Rai, Netflix, Amazon, Disney+, Apple TV+, Max, Paramount+, YouTube, Vimeo...

### ✨ Ce qui est vérifié

**Conteneur & vidéo** : MXF OP1a, codec, profil, résolution, framerate, entrelacement, débit, GOP (longueur + closed/open), espace couleur, primaires, transfer, range, aspect ratio, Active Format Description (AFD), métadonnées HDR (MaxCLL / MaxFALL / Mastering Display).

**Audio** : codec, profondeur, sample rate, mapping VF/VO/AD, loudness EBU R128 (LUFS / True Peak / LRA), phase L/R, DC offset, pops/clicks.

**Contenu** : noirs longs, silences, images figées, frames dupliquées, pixels stuck, risque PSE (épilepsie photosensible), plage signal vidéo (BRNG), mires SMPTE / EBU + tone 1 kHz d'amorce, sous-titres embarqués (CC608/708 / DVB / Teletext), timecode de départ, post-roll.

### 📊 Rapport pro

- **Rapport PDF** designé avec verdict global, statistiques, timeline visuelle des métriques signal
- **Export CSV** des données per-frame (compatible Excel / Numbers / pandas)
- **Guide de correction PDF** : pour chaque échec, une fiche détaillée explique comment fixer le problème dans DaVinci Resolve, Adobe Premiere Pro, Avid Media Composer et FFmpeg — 38 recettes pro inclues
- Interface en **français, anglais et espagnol**

### 🔒 Confidentialité

- 100% **offline** — aucun fichier n'est envoyé sur internet
- Pas de compte, pas d'inscription, pas de tracking
- Vos masters restent sur votre Mac

### 💎 Licence à vie + mises à jour gratuites

- Achat unique, licence **valable à vie**
- **Mises à jour gratuites** automatiques (Sparkle)
- Utilisable sur **tous vos Macs personnels** (poste fixe + portable)

### 🖥 Configuration requise

- macOS 14 Sonoma ou plus récent
- Apple Silicon (M1, M2, M3, M4) ou Intel
- 500 Mo d'espace disque
- FFmpeg + FFprobe **inclus** dans l'app — rien à installer

---

## Bullets courts (à mettre dans la sidebar Payhip si dispo)

- ✓ 70+ profils chaînes (France TV, BBC, Netflix, Amazon, Disney+, …)
- ✓ 30+ contrôles techniques automatisés
- ✓ Rapport PDF + CSV + guide de correction
- ✓ EBU R128 / signal range / PSE / cadrage
- ✓ Licence à vie, mises à jour gratuites
- ✓ 100% offline, vos fichiers restent privés
- ✓ macOS 14+, Apple Silicon + Intel
- ✓ Interface FR / EN / ES

---

## Prix suggéré

- **149 €** → positionnement "outil pro indépendant" accessible
- **199 €** → si tu vises plutôt des post houses / agences (le prix paraît plus "broadcast pro")
- **99 €** → prix d'appel / promo de lancement (premières 50 ventes)

Recommandation : **149 € + promo lancement à 99 €** pendant le premier mois pour amorcer.

---

## Catégorie / Tag Payhip

- Category : **Software**
- Tags : `mac`, `video`, `broadcast`, `quality-control`, `qc`, `pad`, `master`, `ffmpeg`, `ebu-r128`, `post-production`

---

## Fichiers à uploader sur Payhip

1. **MisiQC-Pro.zip** — l'app notarisée (à produire après build + `xcrun notarytool` + `stapler`)
2. **MisiQC-Pro-Guide-Installation.pdf** — le guide client (déjà généré dans `scripts/output/`)
3. Dans le panneau "License Keys" du produit : uploader **keys.csv** (4999 clés perpétuelles)

---

## Email de confirmation (modèle à personnaliser dans les paramètres Payhip)

> Sujet : **Bienvenue dans MisiQC Pro — votre clé de licence**
>
> Bonjour,
>
> Merci pour votre achat de **MisiQC Pro** !
>
> **Votre clé de licence à vie :**
>
> `{{license_key}}`
>
> **Téléchargement** : `{{download_link}}`
>
> Suivez le **Guide d'installation** (PDF inclus dans le téléchargement) pour installer et activer votre licence en 2 minutes.
>
> Une question ? Répondez simplement à cet email ou écrivez à **contact@misiraca.com**.
>
> Bonne diffusion !
>
> — Matthieu Misiraca
> MisiQC Pro · [www.misiraca.com](https://www.misiraca.com)
