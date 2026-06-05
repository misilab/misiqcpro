# MisiQC Pro — Setup Payhip + Licence

Ce document explique le workflow vendeur pour distribuer les clés de licence MisiQC Pro via Payhip.

---

## 1. Génération des clés (one-shot par paire de clés)

Les clés sont déjà générées dans `scripts/output/` :

- `keys.csv` — **5000 clés** prêtes pour l'upload Payhip
- `private_key.dat` — clé privée Ed25519 (**SECRÈTE — ne JAMAIS commiter, sauvegarder hors-ligne**)
- `public_key.dat` — clé publique
- `public_key.hex` — version hex de la clé publique, déjà copiée dans `LicenseService.publicKeyHex`

Pour régénérer (par exemple un autre batch de 1000 clés avec la **même** paire de clés) :

```sh
swift scripts/generate_keys.swift 1000
```

Le script détecte automatiquement la paire de clés existante et l'utilise.

> ⚠ Si tu supprimes `private_key.dat`, tu **ne pourras plus émettre de nouvelles clés** valides — la clé publique embarquée dans l'app ne vérifiera que les clés signées avec l'ancienne clé privée. **Sauvegarder `private_key.dat` dans un coffre (1Password, Bitwarden, Keychain dédié)**.

---

## 2. Validité des clés générées

Chaque clé du batch actuel est valide **1 an** à partir de la génération.

Pour étendre/changer la durée par défaut, édite le script `generate_keys.swift`, ligne :

```swift
let oneYearFromNow = Calendar.current.date(byAdding: .day, value: 365, to: Date())!
```

---

## 3. Upload sur Payhip

1. Crée un compte **payhip.com**
2. Crée le produit **MisiQC Pro** (type : Digital Download)
3. Dans les options du produit, active **License Keys**
4. Choisis le mode **"I will provide my own keys"**
5. Upload le fichier `scripts/output/keys.csv` (5000 clés)
6. Configure le **prix** (mon avis : 150-200 € HT)
7. Active la **livraison automatique par email** : Payhip enverra une clé unique de la liste à chaque acheteur

Payhip gère automatiquement :
- la **TVA EU** (Merchant of Record)
- l'**email de livraison** avec la clé
- la **suspension de la clé** si l'achat est remboursé / contesté (rotation depuis la liste restante)

---

## 4. Format des clés (référence technique)

- 74 bytes binaires encodés en **base32 RFC 4648** avec hyphens tous les 5 caractères
- Exemple : `JUYQA-AADOU-LUZYK-QDOA7-WYERA-SK5IZ-7DG3L-FYUHZ-DERJT-M43A7-N7AOY-JAWBG-LO43K-L36IB-RWPJB-NJ5PP-EINWV-YRNEA-2MXEH-TONQ4-VH5EH-CBM3J-PSR7S-QQDI`
- Structure interne :
  - `[0..1]` : Magic `M1` (0x4D 0x31)
  - `[2..5]` : Expiry (UInt32 BE, jours depuis 2025-01-01)
  - `[6..9]` : Nonce aléatoire (UInt32 BE)
  - `[10..73]` : Signature Ed25519 du payload `[0..9]`

L'app vérifie la signature **offline** avec la clé publique embarquée (`LicenseService.publicKeyHex`).

---

## 5. Workflow client

1. Achat sur Payhip → reçoit la clé par email
2. Lance MisiQC Pro → **Trial 7 jours** par défaut
3. Réglages → **Licence** → colle la clé → **Activer**
4. Statut bascule sur "Licence active jusqu'au DD/MM/YYYY · Hôte : Nom-du-Mac"
5. Chaque rapport PDF affiche en footer : *"Licence #XXXXX · Hôte : Nom-du-Mac"* (anti-piratage)

---

## 6. Anti-piratage social

Le footer PDF du rapport affiche les **5 premiers caractères de la clé + le nom du Mac** (`Host.current().localizedName`). Si une clé fuite et est partagée, tu peux identifier le coupable depuis les rapports publics — c'est un fort deterrent.

---

## 7. Quand renouveler le batch

Quand tu approches de 5000 ventes (👏), relance le script avec un nouveau count et upload un nouveau CSV sur Payhip. Garde la **même** paire de clés Ed25519 : toutes les nouvelles clés resteront vérifiables par les utilisateurs déjà installés.
