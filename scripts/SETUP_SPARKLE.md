# MisiQC Pro — Setup Sparkle (mises à jour auto)

## 1. Ajouter le package Sparkle au projet

Dans Xcode :

1. **File → Add Package Dependencies…**
2. URL : `https://github.com/sparkle-project/Sparkle`
3. Range : "Up to Next Major Version" depuis `2.6.4`
4. Add Package
5. Coche la target **MisiQC**, valide

À ce moment-là, la branche `#if canImport(Sparkle)` du fichier `Services/UpdateService.swift` devient active automatiquement.

## 2. Générer la paire de clés EdDSA Sparkle

Sparkle utilise sa propre paire EdDSA (différente de celle des licences). Une fois le package ajouté :

```sh
# Tool fourni par Sparkle après installation du package
~/Library/Developer/Xcode/DerivedData/MisiQC-*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys
```

Le tool stocke la clé privée dans le **Trousseau macOS** (compte "ed25519") et imprime la clé publique en base64.

## 3. Configurer la clé publique dans l'app

Ouvre `Services/UpdateService.swift` et remplis la constante :

```swift
private let publicEDKey = "TaCl\xC3\xA9PubliqueBase64IciCollée=="
```

(En attendant je n'ai pas mis cette constante — c'est le `SPUUpdaterDelegate.publicKey` à implémenter, OU plus simple : ajouter `SUPublicEDKey` dans le Info.plist du target. Préférence : Info.plist, plus standard.)

Pour ajouter via Info.plist :

1. Target **MisiQC** → onglet **Info**
2. + Ajouter une ligne **SUPublicEDKey** (String) → la clé publique base64
3. + Ajouter **SUFeedURL** (String) → l'URL de ton appcast.xml (cf. étape 4) — *optionnel si tu utilises la fonction `feedURLString(for:)` déjà implémentée*

## 4. Choisir l'URL de l'appcast

Recommandation : **GitHub Releases** — gratuit, hébergement statique, CDN inclus.

L'URL configurée dans `UpdateService.swift` est :
```
https://github.com/Misiraca/MisiQCPro/releases/latest/download/appcast.xml
```

Cette URL renvoie toujours vers le dernier appcast.xml uploadé dans une Release "latest". Pratique : tu publies une nouvelle release sur GitHub → l'appcast est servi automatiquement à la bonne URL.

Si tu utilises ton domaine, change cette ligne vers `https://misiraca.com/misiqcpro/appcast.xml`.

## 5. Script de release

Crée `scripts/release.sh` (à adapter) :

```sh
#!/bin/zsh
set -e

VERSION="$1"  # ex: 1.0.0
if [ -z "$VERSION" ]; then echo "Usage: release.sh <version>"; exit 1; fi

# 1. Archive Xcode
xcodebuild archive \
  -project MisiQC.xcodeproj \
  -scheme MisiQC \
  -archivePath build/MisiQC.xcarchive

# 2. Export .app
xcodebuild -exportArchive \
  -archivePath build/MisiQC.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist scripts/exportOptions.plist

APP="build/export/MisiQC Pro.app"
ZIP="build/MisiQC-Pro-$VERSION.zip"

# 3. Notarize
xcrun notarytool submit "$APP" \
  --keychain-profile "AC_NOTARY" \
  --wait

xcrun stapler staple "$APP"

# 4. Zip
ditto -c -k --keepParent "$APP" "$ZIP"

# 5. Sparkle sign
SIGN=$(~/Library/Developer/Xcode/DerivedData/MisiQC-*/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update "$ZIP")
echo "Sparkle signature for appcast.xml:"
echo "$SIGN"

# 6. Manual: edit appcast.xml, then upload to GitHub Releases
echo "→ Edit scripts/appcast.xml with the new <item>, then upload $ZIP + appcast.xml to a GitHub Release."
```

## 6. Format de l'appcast.xml

```xml
<?xml version="1.0" standalone="yes"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>MisiQC Pro</title>
    <item>
      <title>Version 1.0.1</title>
      <pubDate>Mon, 10 Jun 2026 12:00:00 +0200</pubDate>
      <sparkle:version>1.0.1</sparkle:version>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <description><![CDATA[
        <h3>Nouveautés</h3>
        <ul><li>Détection scene change rate ajoutée</li></ul>
      ]]></description>
      <enclosure url="https://github.com/Misiraca/MisiQCPro/releases/download/v1.0.1/MisiQC-Pro-1.0.1.zip"
                 sparkle:edSignature="SIGNATURE_PASTÉE_ICI_DEPUIS_sign_update"
                 length="42365920"
                 type="application/octet-stream" />
    </item>
  </channel>
</rss>
```

## 7. Workflow release complet

```sh
# 1. Bump version dans Xcode
# 2. Lancer le script
./scripts/release.sh 1.0.1

# 3. Récupérer la signature Sparkle affichée
# 4. Éditer scripts/appcast.xml avec :
#    - nouvelle <item> en haut
#    - la signature collée dans sparkle:edSignature
# 5. Créer une release GitHub v1.0.1
# 6. Y attacher MisiQC-Pro-1.0.1.zip + appcast.xml
# 7. Marquer comme "latest"
```

Les utilisateurs auront la notification "Mise à jour disponible" au prochain lancement (ou via le menu **MisiQC Pro → Vérifier les mises à jour…**).

## 8. Hardened Runtime + entitlements

Sparkle nécessite quelques entitlements particuliers pour s'updater :
- `com.apple.security.cs.disable-library-validation` (déjà OK pour ffmpeg)
- `com.apple.security.cs.allow-jit` (si Sparkle 2.x avec auto-installer)

L'entitlement `MisiQC.entitlements` actuel devrait déjà supporter ça.
