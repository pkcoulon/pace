# Pace

Petite app macOS de barre de menu qui affiche, en un coup d'œil et sans clic, ta
consommation **Claude** (abonnement claude.ai) et **OpenAI Codex**.

```
C 54% · 6%   X 63%
```

`C` = Claude, `X` = Codex. Premier pourcentage = fenêtre 5 h, second = fenêtre
hebdo. Vert sous 60 %, orange de 60 à 85 %, rouge au-delà, gris si la donnée est
indisponible ou le token expiré. Un clic ouvre un popover avec le détail par
fenêtre, le compte à rebours jusqu'au reset, les modèles et l'extra usage.

## Prérequis

- macOS 14 (Sonoma) ou plus récent, Apple Silicon.
- Au moins l'un des deux, connecté :
  - **Claude Code** connecté (`claude`), pour lire l'usage Claude sans rien saisir.
  - **Codex CLI** connecté (`codex login`), pour l'usage Codex.
- Xcode 16+ ou une toolchain Swift 6 pour compiler.

Si Claude Code n'est pas installé, tu peux coller une **session key claude.ai**
dans les réglages (mode secours). Rien n'est requis pour Codex à part `codex login`.

## Installation

```sh
make app      # compile et assemble build/Pace.app
make run      # (re)lance l'app
```

`make app` produit `build/Pace.app`. Pour une identité de signature stable
(sinon macOS redemande les autorisations à chaque build) :

```sh
SIGN_IDENTITY="Apple Development: Ton Nom (TEAMID)" make app
```

Installe l'app en la copiant dans `/Applications` :

```sh
cp -R build/Pace.app /Applications/
```

Note Gatekeeper : le certificat de signature n'étant pas notarisé par Apple,
un `.dmg` téléchargé affiche « impossible de vérifier le développeur ». Copier
le `.app` local ne pose pas ce souci ; si tu passes par le `.dmg`, lève la
quarantaine une fois :

```sh
xattr -dr com.apple.quarantine /Applications/Pace.app
```

Active « Lancer au démarrage » dans les réglages pour un démarrage automatique.

Compilation seule, sans bundle :

```sh
swift build            # binaire de debug dans .build/
swift build -c release
```

## Utilisation

- **Barre de menu** : deux blocs compacts. La couleur suit la valeur.
- **Popover** (clic) : une carte par provider, barres 5 h et hebdo, compte à
  rebours, date de reset, lignes par modèle (Opus / Sonnet / Fable…) et extra
  usage / crédits s'ils existent. Un **curseur de rythme** sur chaque barre
  montre le temps écoulé dans la fenêtre : si la barre le dépasse, tu consommes
  plus vite que le temps ne passe, avec une phrase du type « à ce rythme, limite
  atteinte dans ~2 h ». Cliquer une carte ouvre la page d'usage officielle.
- **Réglages** : activer chaque provider, choisir par provider ce que la barre
  affiche (5 h, hebdo, ou les deux), afficher ou non le rythme, intervalle de
  refresh (1 / 3 / 5 min), seuils de notification distincts pour la 5 h et
  l'hebdo, lancer au démarrage, et le champ session key Claude avec bouton Tester.
- **Notifications** : une alerte native aux seuils choisis sur chaque fenêtre,
  réarmée à chaque reset.
- **Démarrage instantané** : le dernier usage connu est mis en cache sur disque
  (pourcentages et dates, jamais de token) et affiché avant le premier appel.
- **Surveillance de panne** : les pages de statut d'Anthropic et d'OpenAI sont
  interrogées toutes les 5 min ; en cas de perturbation ou de panne d'un
  composant Claude ou Codex, un bandeau coloré apparaît sur la carte concernée.

## Comment les comptes sont lus

### Claude

Mode principal : le token OAuth déposé par Claude Code est lu dans le Trousseau
macOS (entrée `Claude Code-credentials`), sans jamais déclencher de fenêtre
d'autorisation. L'usage vient de `GET https://api.anthropic.com/api/oauth/usage`.
Pace ne rafraîchit jamais ce token lui-même : si l'appel renvoie 401, le
popover affiche « relance `claude` ». Le fichier de credentials est surveillé, un
changement déclenche un refresh immédiat.

Mode secours : une session key claude.ai collée dans les réglages, stockée au
Trousseau, qui interroge `claude.ai/api/organizations/{id}/usage`.

### Codex

Le token est lu dans `~/.codex/auth.json`. L'usage vient de
`GET https://chatgpt.com/backend-api/wham/usage`. Si le token a plus de 8 jours,
il est rafraîchi via `https://auth.openai.com/oauth/token`, et `auth.json` est
réécrit de façon atomique avec les permissions `0600`. Si le fichier est absent,
le popover affiche « lance `codex login` ».

Certains plans Codex n'ont pas de fenêtre 5 h : dans ce cas la barre n'affiche
que l'hebdo (`X 63%`), sans tiret.

## Vérifier qu'aucun autre appel réseau n'est fait

Pace ne contacte que les hôtes strictement nécessaires, aucune télémétrie,
aucun analytics. En fonctionnement normal :

| Hôte | Quand |
|---|---|
| `api.anthropic.com` | usage Claude (mode principal) |
| `chatgpt.com` | usage Codex |
| `auth.openai.com` | seulement quand le token Codex a plus de 8 jours |
| `claude.ai` | seulement en mode secours session key |
| `status.claude.com` | surveillance de panne Claude (toutes les 5 min) |
| `status.openai.com` | surveillance de panne Codex (toutes les 5 min) |

Pour le confirmer toi-même, lance l'app puis observe son trafic, par exemple :

```sh
# nécessite les droits admin ; filtre le processus Pace
sudo lsof -i -nP | grep -i pace

# ou, en continu, avec un pare-feu applicatif comme Little Snitch / LuLu,
# vérifie que seuls les hôtes du tableau ci-dessus apparaissent.
```

Aucun token n'est écrit en clair sur disque ni journalisé. Les secrets propres à
l'app (session key) vivent uniquement dans le Trousseau.

## Structure

```
Sources/Pace/
  Models/     modèles d'usage, niveaux de couleur, formats
  Services/   un provider par source derrière le protocole UsageProvider,
              lecture Trousseau, auth Codex, watcher de fichiers, notifications
  Stores/     UsageStore (polling, backoff) et SettingsStore (ObservableObject)
  Views/      barre de menu, popover, réglages
```

Zéro dépendance externe.
