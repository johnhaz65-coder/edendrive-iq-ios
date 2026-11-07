# EdenDrive IQ — application iPhone (prototype v0.4)

**Application iPhone native en code source — pas encore un `.ipa` installé ni testé sur un appareil.**
Aucune connexion ou fonctionnalité Waze. Aucun accès au site EdenDrive, au dépôt du site ou au bot padel.

## Ce que fait le prototype

- **Un bouton « Activer la capture automatique »** ouvre la boîte de consentement Apple pour partager l'écran entier. C'est une session autorisée, que l'on peut arrêter. Le système peut nécessiter plusieurs touches pour confirmer l'autorisation.
- iOS 27 : **ScreenCaptureKit** collecte les images de la session lorsque Uber/Bolt est ouvert, sans qu'il faille déclencher une capture d'écran à chaque offre.
- **Double vérification OCR :** deux images successives doivent afficher exactement la même offre (prix, kilomètres et adresses) avant d'engager une analyse. Cela réduit les erreurs de lecture ponctuelles, sans les éliminer. **Vision OCR** reconnaît localement les textes. Aucun fichier vidéo, capture ou texte OCR n'est enregistré ou envoyé à un serveur de l'application.
- Le parseur cherche tarif, kilomètres et temps d'approche dans la proposition. Il tente de lire les deux adresses de la course.
- **Apple Plans** (`MKLocalSearch`, `MKDirections.calculateETA`) calcule l'approche GPS → client et le temps de trajet client → dépose, avec trafic attendu et départ de la deuxième portion après la première.
- **Une alerte finale plutôt que deux :** pas de verdict favorable diffusé avant le résultat Apple Plans ; si la carte ne répond pas, le seul verdict est « À VÉRIFIER ». Le réseau peut rester trop lent pour analyser une offre avant sa disparition.
- **Chiffre clé en grand : €/minute + prix minimum + montant manquant**, plutôt qu'une note arbitraire sur dix.
- **Seuil personnalisé : 1 € de chiffre d'affaires par minute** (prix Uber/Bolt ÷ [approche + course]). Par exemple : 24,80 € / (6+13) = 1,31 €/min = PRENDRE ; 9 € / (9+6) = 0,60 €/min = REFUSER.
- Affiche les frais estimés séparément, en plus du verdict brut. Notification locale lorsque l'offre change et quand les temps trafic sont confirmés.
- **Sans ETA trafic ni deux durées déjà fiables**, verdict **À VÉRIFIER** : l'application ne prétend jamais disposer d'un calcul de trafic qui a échoué.

## Installation sur le Mac (SDK iOS 27 obligatoire)

1. Décompresser le ZIP.
2. Ouvrir directement **`EdenDriveIQ.xcodeproj`** (il est fourni dans ce paquet).
3. Dans Xcode, choisir l'équipe Apple pour « Signing & Capabilities » (connexion Apple ID via Xcode → Settings → Accounts si nécessaire) et sélectionner son iPhone comme destination.
4. Cliquer sur **Run ▶**. Lors du premier lancement, autoriser les notifications et la localisation, puis activer la capture d'écran complet via le sélecteur officiel iOS.
5. Ouvrir Uber ou Bolt, laisser la session de capture active, et tester sur une offre. Ne pas consulter l'écran au volant.

**Attention :** la compilation sur Xcode, la signature, la continuité de l'OCR en arrière-plan et l'affichage des notifications pendant Uber n'ont pas été testés sur un iPhone réel dans cet environnement. Les systèmes d'exploitation peuvent limiter les captures ou le rendu des notifications. Le trafic Apple Plans nécessite une connexion et des adresses lisibles ; son délai peut dépasser le temps disponible avant expiration d'une offre.

## Confidentialité et limites

La capture autorisée peut contenir l'écran entier, y compris les données qui apparaissent dans d'autres applications. Activez-la seulement pendant vos sessions VTC. L'OCR de Vision est local. Les adresses et la position requises pour les ETA sont envoyées aux services Apple Plans. Il n'y a aucune acceptation/refus automatique de course, ni superposition garantie au-dessus des autres apps. Aucun retour à vide, péage, attente, charge sociale ou impôt n'entre dans le verdict de 1 €/minute.

## Fonctionnement de l'analyse

- Capture : `CaptureManager.swift` avec `SCContentSharingPicker`, `SCStream`.
- Reconnaissance : `FrameOCR.swift` avec Vision.
- Lecture des offres : `OfferParser.swift`.
- ETA : `TrafficETAService.swift`, contrôle les distances remontées par Apple Plans contre celles d'Uber/Bolt.
- Calcul : `Profitability.swift`.
- Alertes : `NotificationService.swift`.

Le projet est **iPhone uniquement, iOS 27 minimum**. Il ne dépend pas de Waze ni d'API Google Maps.

## Tests du moteur de décision

```bash
cd EdenDriveIQ-GitHub
sh Tests/run_smoke.sh
sh Tests/run_decision_cases.sh
```

Les tests couvrent le parseur et les calculs avec des ETA simulées. Les tests ne prouvent pas le fonctionnement de ScreenCaptureKit ni du trafic réel. 

Sources : https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-on-ios et https://developer.apple.com/documentation/mapkit/mkdirections/etaresponse/expectedtraveltime

## Améliorations v0.4 / limites

La version v0.4 privilégie la **fiabilité des données** à un score trompeur : contrôle de cohérence de deux captures successives, attente du calcul Apple Plans pour afficher PRENDRE ou REFUSER, et manque à gagner visible. Elle reste **non compilée/non testée sur iPhone**, sans garantie de notification en surimpression et sans acceptation automatique des courses. Le coût d'un éventuel péage, l'attente après la dépose et les retours à vide ne sont pas calculés en temps réel.


## Publication GitHub

Déposer ce projet dans un **dépôt privé distinct** de `eden-drive` et de `cap7-padel-alertes`.
Le script `publier-sur-github.command` peut créer et pousser le dépôt `edendrive-iq-ios` depuis un Mac **si GitHub CLI est installé et que l’utilisateur s’est connecté avec `gh auth login`**. Le script n’accède à aucun autre dépôt.

Le dépôt GitHub contient seulement du code ; il n’installe pas une app sur un iPhone. Pour cela, utiliser Xcode sur Mac et tester sur un véritable iPhone. Aucune compilation iOS n’a été effectuée ici.
