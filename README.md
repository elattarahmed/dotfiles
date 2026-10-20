# dotfiles

Ma config [Omarchy](https://omarchy.org/) (Arch Linux + Hyprland), réinstallable sur une autre machine avec un seul script. Chaque élément s'active ou se désactive séparément, raccourcis clavier compris.

## Installation

Sur une machine où Omarchy est déjà installé :

```bash
git clone https://github.com/elattarahmed/dotfiles.git ~/Documents/GIT/dotfiles
cd ~/Documents/GIT/dotfiles
./install.sh
```

Un menu liste tous les éléments. Ceux par défaut sont déjà cochés : **Espace** coche ou décoche, **Entrée** valide. Le script demande ton mot de passe sudo quand il installe des paquets. À la fin, il affiche ce qui reste à faire de ton côté, par exemple se déconnecter pour passer à zsh, ou ajouter une clé SSH sur GitHub.

Chaque fichier remplacé est d'abord sauvegardé dans `~/.local/state/dotfiles/backups/<date>/`. Relancer le script ne change que ce qui a changé dans le dépôt.

## Ce que ça contient

| Élément | Par défaut | Ce que ça fait |
|---|---|---|
| `theme` | ✓ | thème Omarchy Hackerman (terminal, barre, écran de verrouillage, fond d'écran) |
| `zsh` | ✓ | zsh comme shell par défaut, suggestions grisées (→ pour accepter), coloration syntaxique, alias et fonctions d'Omarchy |
| `zsh-p10k` | ✓ | prompt Powerlevel10k. Au premier lancement, son assistant teste les icônes que ton terminal sait afficher et te fait choisir ton style (`p10k configure` pour le refaire). Décoché : le prompt starship d'Omarchy |
| `zsh-p10k-mine` | | reprend exactement mon style de prompt (`modules/zsh/p10k.zsh`) au lieu de l'assistant ; il faut une police Nerd Font |
| `zsh-line-keys` | ✓ | Ctrl/Alt + Effacer/Suppr, Alt + ←/→/↑/↓ |
| `zsh-selection` | ✓ | sélection au clavier dans zsh, comme dans un éditeur |
| `zsh-root` | | même shell et même config pour root |
| `ghostty` | ✓ | Ghostty comme terminal par défaut |
| `ghostty-font` | ✓ | texte du terminal en taille 11 au lieu de 9 (Ctrl+= / Ctrl+- / Ctrl+0 changent la taille d'une fenêtre) |
| `ghostty-tabs` | ✓ | onglets avec Alt+T / Alt+W |
| `resize-mode` | ✓ | Super+R puis flèches : redimensionne la fenêtre active comme en tirant son coin bas-droit (Maj = plus vite), Échap pour finir. Dans la barre, « RESIZE » s'allume pendant le mode ; un clic l'active ou le quitte, la molette élargit ou rétrécit la fenêtre |
| `workspace-keys` | ✓ | Super+Ctrl+←/→ pour changer de workspace |
| `macos-keys` | ✓ | Alt joue le rôle de Cmd sur Mac |
| `natural-scroll` | ✓ | défilement naturel au pavé tactile, comme sur Mac (le contenu suit les doigts), et plus lent (0.25 au lieu de 0.4) |
| `touchscreen-off` | ✓ | écran tactile désactivé (son nom est détecté avec `hyprctl devices`) |
| `caps-lock` | ✓ | Verr. Maj redevient un vrai Verr. Maj (é → É, ç → Ç…) ; la touche Compose passe sur Ctrl droit |
| `gestures` | ✓ | glisser à 3 doigts ←/→ pour changer de workspace |
| `zoom` | ✓ | zoom de l'écran façon macOS au pavé tactile. Pendant le verrouillage et l'économiseur d'écran, le zoom revient à la normale, puis se remet au retour (service `zoom-lock-guard`) |
| `workspace-animation` | ✓ | les workspaces glissent au lieu d'apparaître d'un coup |
| `no-middle-paste` | ✓ | le tap à 3 doigts (clic du milieu) ne colle plus la dernière sélection |
| `clipboard` | ✓ | historique du presse-papiers avec épingles, façon Maccy, et son bouton dans la barre |
| `emojis` | ✓ | sélecteur d'émojis (Ctrl+Alt+Espace) où l'émoji sélectionné a une bordure claire, bien visible sur un thème sombre |
| `scale-button` | ✓ | bouton dans la barre avec l'échelle de l'écran (125 %…) : molette vers le haut ou clic gauche pour agrandir, vers le bas ou clic droit pour réduire. La valeur est gardée après un redémarrage |
| `sysstats` | ✓ | RAM, CPU ou température dans la barre |
| `whichport` | ✓ | [whichport](https://github.com/elattarahmed/whichport) : les serveurs de dev qui tournent, dans la barre |
| `bar-layout` | ✓ | langue du clavier avant l'horloge, icônes d'applis après le réseau |
| `no-fcitx` | ✓ | désactive fcitx5 : sinon, dans Ghostty, Maj+flèches affiche un C ou un D au lieu de sélectionner. Les accents à touche morte (^ ¨) et la touche Compose sont gérés par les applis elles-mêmes |
| `lockscreen-layout` | ✓ | avec fcitx5 seulement : le mot de passe de l'écran de verrouillage se tape dans la même disposition que la session (sinon c'est du QWERTY). Ignoré avec `no-fcitx` |
| `neovim-spell` | ✓ | correcteur orthographique de Neovim en français et en anglais |
| `git-ssh` | ✓ | plusieurs comptes GitHub sur la même machine (voir plus bas) |
| `ssh-server` | | serveur SSH pour te connecter depuis un autre ordinateur (ton Mac) ; le pare-feu n'ouvre le port 22 qu'au réseau local |
| `display-scale` | | échelle de l'écran (le script demande la valeur ; 1.25 sur ce portable). Le bouton `scale-button` permet ensuite de la changer depuis la barre |

`./install.sh --list` affiche la même liste.

## Les raccourcis

**Partout (`macos-keys`)** : Alt est à la place de Cmd sur un clavier Mac.

| Raccourci | Action |
|---|---|
| Alt+C / V / X | copier / coller / couper (marche aussi dans le terminal) |
| Alt+A | tout sélectionner |
| Alt+Z / Alt+Maj+Z | annuler / rétablir |
| Alt+S / Alt+F | enregistrer / rechercher |
| Alt+T / Alt+W / Alt+Maj+T | nouvel onglet / fermer l'onglet / rouvrir le dernier onglet fermé |
| Alt+L / Alt+R | barre d'adresse / recharger |
| Alt+1…9 | aller à l'onglet n° (rangée des chiffres, marche en AZERTY) |
| Alt+← / → | début / fin de ligne |
| Alt+↑ / ↓ | début / fin du document |
| Alt+Effacer / Alt+Suppr | effacer jusqu'au début / à la fin de la ligne |
| Super+Q | fermer la fenêtre (Super+W marche toujours) |
| Ctrl+Alt+Espace | menu des émojis, comme Ctrl+Cmd+Espace sur Mac (Super+Ctrl+E marche toujours). La touche Fn seule n'est pas utilisable : sur la plupart des PC, le système ne la voit pas |

Dans un terminal, ces touches Alt arrivent telles quelles à zsh, qui a ses propres équivalents (ci-dessous). Ctrl+C y garde son rôle : arrêter la commande en cours.

**Workspaces et pavé tactile**

| Raccourci | Action |
|---|---|
| Super+Ctrl+← / → | workspace précédent / suivant (`workspace-keys`) |
| 3 doigts ← / → | workspace précédent / suivant (`gestures`) |
| Clic à 3 doigts, puis glisser à 3 doigts ↑ / ↓ | zoomer / dézoomer, lever les doigts termine (`zoom`) |
| Clic à 3 doigts maintenu, puis glisser ↑ / ↓ | pareil, relâcher termine |
| Double clic à 3 doigts | vue normale ↔ dernier zoom |

**Presse-papiers (`clipboard`)**

| Raccourci | Action |
|---|---|
| Alt+Maj+V (ou Super+Ctrl+V) | ouvrir l'historique |
| Entrée ou clic | remettre l'élément dans le presse-papiers (tu colles ensuite toi-même) |
| Maj+Entrée | remettre l'élément dans le presse-papiers et le coller tout de suite |
| Alt+P | épingler / désépingler l'élément choisi |
| Alt+A, Alt+B… | remettre dans le presse-papiers l'élément épinglé à cette lettre |
| Alt+1…9 | remettre dans le presse-papiers l'un des 9 derniers éléments |

Les éléments épinglés restent en haut de la liste et gardent leur lettre. Ils ne sont jamais effacés automatiquement, même quand on vide l'historique (Suppr les supprime un par un).

**zsh et Ghostty**

| Raccourci | Action |
|---|---|
| → ou Fin | accepter la suggestion grisée (Ctrl+→ : seulement le mot suivant) |
| Ctrl+Effacer / Ctrl+Suppr | effacer le mot avant / après (`zsh-line-keys`) |
| Alt+Effacer / Alt+Suppr | effacer jusqu'au début / à la fin de la ligne |
| Alt+← / → · Alt+↑ / ↓ | début / fin de la ligne · de toute la commande |
| Maj (+Ctrl ou +Alt) + flèches | sélectionner par caractère, mot ou ligne (`zsh-selection`) |
| Alt+A · Alt+C · Alt+X | tout sélectionner · copier · couper la sélection |
| Alt+T / Alt+W | nouvel onglet / fermer l'onglet dans Ghostty (`ghostty-tabs`) |

## Activer, désactiver

```bash
./install.sh                         # le menu, avec tes choix actuels cochés
./install.sh zoom sysstats           # ajouter des éléments
./install.sh --disable macos-keys    # en retirer
./install.sh --yes                   # tout réappliquer sans question
./install.sh --files-only            # copier les fichiers seulement : ni paquets, ni sudo, ni session
```

Tes choix sont enregistrés dans `~/.config/dotfiles/selection`. Pour couper un réglage à la main, sans relancer le script :

- **Hyprland :** passer la ligne à `false` dans `~/.config/hypr/dotfiles.lua`, puis `hyprctl reload`.
- **zsh :** mettre `0` dans `~/.config/zsh/dotfiles.zsh`, puis `exec zsh`.
- **Ghostty :** commenter la ligne `config-file` concernée à la fin de `~/.config/ghostty/config`.

Le prochain `./install.sh` réécrit ces fichiers d'après tes choix enregistrés. Pour qu'un changement dure, passe par `--disable`.

## Où vont les fichiers

| Dans le dépôt | Sur la machine |
|---|---|
| `modules/zsh/zshrc`, `p10k.zsh` | `~/.zshrc`, et `~/.p10k.zsh` seulement avec `zsh-p10k-mine` (sinon un `~/.p10k.zsh` existant est gardé). Tes ajouts perso vont dans `~/.zshrc.local`, que le script ne touche jamais |
| `modules/ghostty/*.conf` | `~/.config/ghostty/dotfiles/`, inclus depuis `~/.config/ghostty/config` |
| `modules/hyprland/features/*.lua` | `~/.config/hypr/dotfiles/`, chargés par `~/.config/hypr/dotfiles.lua` |
| `modules/omarchy-plugins/*`, `modules/whichport/plugin` | `~/.config/omarchy/plugins/` |
| *(généré)* | `~/.config/fcitx5/profile`, une ligne dans `~/.config/nvim/lua/config/options.lua` |

Les fichiers Hyprland d'Omarchy (`bindings.lua`, `input.lua`, `looknfeel.lua`…) ne sont pas modifiés, à une ligne près : `require("hypr.dotfiles")` dans `hyprland.lua`. La config de Ghostty et les options de Neovim reçoivent seulement quelques lignes à la fin. Les mises à jour d'Omarchy continuent donc de s'appliquer.

## Plusieurs comptes GitHub (`git-ssh`)

Le script demande un alias par compte (par défaut `hmd` et `oc`), puis pour chacun un nom et un email. Il crée ensuite :

- une clé SSH par compte, `~/.ssh/id_ed25519_<alias>` ;
- un hôte `github-<alias>` dans `~/.ssh/config` ;
- l'identité git du compte, choisie d'après l'URL du dépôt.

Il ne te reste qu'à coller chaque clé publique (`cat ~/.ssh/id_ed25519_<alias>.pub`) dans le bon compte GitHub : **Settings → SSH and GPG keys**. Ensuite :

```bash
ssh -T github-hmd                                  # → « Hi <compte> ! »
git clone git@github-hmd:elattarahmed/whichport.git
git remote set-url origin git@github-oc:<org>/<repo>.git   # pour un repo déjà cloné
```

Un repo cloné sans alias n'a pas d'identité : git refuse de commiter plutôt que d'en deviner une.

## Ce qui n'est pas dans le dépôt

- **Les clés SSH privées**, jamais. Le script en génère de nouvelles sur chaque machine.
- **L'historique du presse-papiers**, l'historique zsh, les réglages de Chromium.
- **Le thème** : c'est celui par défaut d'Omarchy (Tokyo Night).

## Migrer une machine déjà configurée

Sur la machine où tout a été fait à la main, les mêmes réglages sont déjà écrits dans les fichiers d'Omarchy. Les installer une deuxième fois les ferait tourner en double, par exemple un Alt+V qui colle deux fois. Le script le détecte et prévient. Pour passer cette machine sur le dépôt :

```bash
omarchy refresh config hypr/bindings.lua      # chaque refresh sauvegarde l'ancien fichier
omarchy refresh config hypr/input.lua
omarchy refresh config hypr/looknfeel.lua
omarchy refresh config hypr/hyprland.lua
omarchy refresh config ghostty/config
rm ~/.config/hypr/zoom.lua
./install.sh --yes
```

L'échelle de l'écran reste dans `hypr/monitors.lua`, qu'il n'y a pas besoin de toucher.

## Garder le dépôt à jour

Quand tu changes quelque chose sur ta machine, mets le changement dans le dépôt, relance `./install.sh --yes`, puis commite. Pour un nouveau réglage :

- **Hyprland :** un fichier dans `modules/hyprland/features/` qui renvoie `function(settings) … end`, plus une ligne dans `HYPR_FEATURES` (`modules/hyprland/module.sh`) et dans `ITEMS` (`install.sh`).
- **Autre chose :** une fonction `module_<nom>` dans `modules/<nom>/module.sh`, ajoutée à `MODULES` dans `install.sh`.

Les plugins `verybad.clipboard` et `verybad.emojis` sont des copies modifiées du gestionnaire de presse-papiers et du sélecteur d'émojis d'Omarchy (licence MIT). Ils ne suivent donc pas les mises à jour des originaux.
