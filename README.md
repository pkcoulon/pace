<div align="center">

<img src="docs/img/icon.png" width="110" alt="Logo Pace">

# Pace

**Ta consommation Claude et OpenAI Codex, dans la barre de menu macOS.**

Sans clic, sans télémétrie, sans dépendance.

<img src="docs/img/menubar.png" width="340" alt="Barre de menu Pace">

</div>

---

`C` = Claude, `X` = Codex. Premier pourcentage = fenêtre 5 h, second = hebdo.
Couleur par valeur : vert, orange, rouge. Un clic ouvre le détail.

<div align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/img/popover.png">
  <source media="(prefers-color-scheme: light)" srcset="docs/img/popover-light.png">
  <img src="docs/img/popover.png" width="330" alt="Popover Pace">
</picture>
</div>

## Fonctionnalités

- Claude et Codex côte à côte, fenêtre 5 h et hebdo, détail par modèle.
- **Curseur de rythme** : un repère marque le temps écoulé ; si la barre le
  dépasse, tu vas trop vite (« à ce rythme, limite atteinte dans ~32 min »).
- Notifications aux seuils choisis, distincts 5 h / hebdo.
- Bandeau de panne si un service Claude ou Codex est perturbé.
- Réglages par provider, démarrage instantané via cache local.
- Secrets dans le Trousseau, aucun appel réseau superflu.

## Prérequis

macOS 14+, Apple Silicon. Claude Code (`claude`) et/ou Codex CLI
(`codex login`) connectés. Sinon, une session key claude.ai en secours.

## Installation

Télécharge le `.dmg` de la [dernière release](https://github.com/pkcoulon/pace/releases)
et glisse **Pace** dans Applications. L'app est signée Developer ID et
notarisée : elle s'ouvre sans avertissement.

Depuis les sources :

```sh
git clone https://github.com/pkcoulon/pace.git && cd pace
make app && cp -R build/Pace.app /Applications/
```

## Confidentialité

Aucun token n'est écrit en clair ni journalisé. Seuls ces hôtes sont contactés :

| Hôte | Quand |
|---|---|
| `api.anthropic.com` | usage Claude |
| `chatgpt.com` | usage Codex |
| `auth.openai.com` | refresh du token Codex (> 8 jours) |
| `claude.ai` | mode secours session key |
| `status.claude.com`, `status.openai.com` | surveillance de panne |

## Crédits

Approches d'auth étudiées dans [TokenEater](https://github.com/AThevon/TokenEater),
[Claude-Usage-Tracker](https://github.com/hamed-elfayome/Claude-Usage-Tracker)
(d'après [codexbar](https://github.com/steipete/codexbar)) et
[usage4claude](https://github.com/f-is-h/usage4claude).

## Licence

[MIT](LICENSE).
