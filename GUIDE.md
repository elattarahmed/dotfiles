# Guide : personnaliser ta machine

Ce guide est affiché par la commande `dotfiles-guide`. Il est aussi dans le dépôt (`GUIDE.md`).

Chaque partie dit comment **changer un réglage sur cette machine** et, si tu veux, comment **en faire le réglage par défaut du dépôt**. Le réglage par défaut est celui que reçoit chaque nouvelle machine qui clone le dépôt et lance `./install.sh`.

`Super+Espace` ouvre le menu Omarchy. Les chemins du type « Appearance → Background » sont des entrées de ce menu. Tu peux aussi taper le nom de l'entrée pour la chercher.

---

## 1. zsh comme shell

Rien à faire : l'élément `zsh` est coché par défaut, donc chaque clone du dépôt fait de zsh :

- **le shell de connexion** (`chsh -s /usr/bin/zsh`, qui demande ton mot de passe) ;
- **le shell de Ghostty** (`command = /usr/bin/zsh` dans `~/.config/ghostty/dotfiles/shell.conf`). Les nouveaux terminaux s'ouvrent en zsh tout de suite, sans attendre la prochaine connexion.

Vérifier :

```bash
echo $0                                  # → zsh dans le terminal
getent passwd "$USER" | cut -d: -f7      # → /usr/bin/zsh (shell de connexion)
```

Après le premier `chsh`, déconnecte-toi puis reconnecte-toi une fois : les autres applications (scripts, autres terminaux) voient alors zsh elles aussi.

Revenir à bash : `./install.sh --disable zsh`, puis `chsh -s /usr/bin/bash`.

---

## 2. Thème de Neovim

L'élément `neovim-themes` donne à Neovim son propre thème, indépendant du thème Omarchy.

| Action | Comment |
|---|---|
| Choisir avec aperçu en direct | `<leader>uC` (Espace puis `u` puis `C`) ou `:Theme`. Les flèches prévisualisent, **Entrée garde** le thème, Échap annule. |
| Choisir directement | `:Theme tokyonight` (Tab complète le nom) |
| Revenir au thème d'Omarchy | `:Theme omarchy` |

Le choix est enregistré dans `~/.local/state/nvim/theme-choice`. Il est gardé au redémarrage de Neovim et quand tu changes le thème d'Omarchy.

**Ajouter un thème qui n'est pas installé.** Ajoute son plugin dans la liste `return { … }` de `modules/neovim/theme-choice.lua`, dans le dépôt. Exemple :

```lua
{ "scottmckendry/cyberdream.nvim", lazy = true, priority = 1000 },
```

Lance ensuite `./install.sh --yes` puis, dans Neovim, `:Lazy sync`. Le thème apparaît alors dans `:Theme`, sur cette machine comme sur toutes celles qui clonent le dépôt.

**Le même thème par défaut partout.** Le choix fait avec `:Theme` reste propre à chaque machine. Pour qu'il s'applique aussi sur une machine neuve, recopie-le sur cette machine-là avec `echo tokyonight > ~/.local/state/nvim/theme-choice`.

---

## 3. Comptes GitHub et identité des commits

`./install.sh` pose ses questions **dès le début**, juste après le menu. Pour chaque compte, il demande :

1. un **alias**, par exemple `hmd` ou `github-hmd` (c'est le même compte : le préfixe `github-` est ajouté s'il manque) ;
2. le **nom** et l'**email** à mettre dans les commits.

Ensuite, il demande « Ajouter un autre compte GitHub ? ». Réponds oui autant de fois que tu as de comptes.

Pour chaque compte, il crée :

| Fichier | Rôle |
|---|---|
| `~/.ssh/id_ed25519_github-<alias>` | la clé SSH (sa partie publique est affichée et copiée dans le presse-papiers) |
| `Host github-<alias>` dans `~/.ssh/config` | l'alias à utiliser à la place de `github.com` |
| `~/.config/git/github-<alias>` | le nom et l'email des commits |

**Une étape à faire toi-même par compte :** colle la clé publique sur https://github.com/settings/ssh/new, en étant connecté au bon compte. Puis teste :

```bash
ssh -T github-hmd        # → « Hi <ton-compte>! You've successfully authenticated »
```

### Le repo se souvient du compte

```bash
git clone git@github-hmd:<owner>/<repo>.git
cd <repo>
git config user.email    # → l'email du compte hmd, sans rien configurer
```

Le compte est retrouvé à partir de l'adresse du remote (`github-hmd`), qui est enregistrée dans le repo. Le repo garde donc ce compte pour tous ses commits, définitivement. Les formes `github-hmd:<owner>/<repo>` et `ssh://git@github-hmd/<owner>/<repo>` marchent aussi.

**Un repo cloné avec `github.com`** (sans alias) n'a pas d'identité : git refuse de commiter plutôt que de deviner. Pour lui en donner une :

```bash
git remote set-url origin git@github-hmd:<owner>/<repo>.git
```

**Ajouter un compte plus tard :** `./install.sh git-ssh`.

---

## 4. Fond d'écran

| Action | Comment |
|---|---|
| Choisir parmi les fonds du thème en cours | `Super+Ctrl+Espace` (ou `Super+Ctrl+W`), ou menu **Appearance → Background** |
| Passer au fond suivant | `omarchy theme bg next` |
| Mettre une image ou une vidéo à toi | `omarchy theme bg set ~/Images/mon-fond.jpg` |
| Ajouter des images au thème pour les retrouver dans le sélecteur | `omarchy theme bg install` ouvre le dossier où les déposer |
| Voir le fond actuel | `omarchy theme bg current` |

Chaque thème a ses propres fonds d'écran : changer de thème change aussi le fond.

### Fonds d'écran et thèmes HyDE

L'élément `hyde-themes` installe la commande `hyde-theme`. Elle convertit les thèmes de la galerie HyDE (https://github.com/HyDE-Project/hyde-gallery) en thèmes Omarchy, **avec tous leurs fonds d'écran**.

```bash
hyde-theme list                         # les thèmes de la galerie, avec leur description
hyde-theme install "Catppuccin Mocha"   # télécharge et convertit (devient « hyde-catppuccin-mocha »)
hyde-theme install "Catppuccin Mocha" --set   # pareil, et l'applique tout de suite
hyde-theme installed                    # ceux déjà convertis
hyde-theme remove "Catppuccin Mocha"    # supprime la version convertie
```

Pour choisir un fond d'écran HyDE :

1. installe et applique le thème : `hyde-theme install "<Nom>" --set` ;
2. ouvre le sélecteur avec `Super+Ctrl+Espace` : il montre les fonds de ce thème ;
3. clique sur celui que tu veux (ou parcours-les avec `omarchy theme bg next`).

Un fond HyDE avec un autre thème ? Les images sont dans `~/.config/omarchy/themes/hyde-<nom>/backgrounds/`. Applique-en une avec `omarchy theme bg set <chemin>`.

**Par défaut dans le dépôt :** dans `modules/theme/module.sh`,

- `HYDE_THEMES=("Catppuccin Mocha" …)` : les thèmes HyDE installés sur chaque nouvelle machine ;
- `THEME_NAME="…"` : le thème appliqué (`omarchy theme list` pour les noms) ;
- `THEME_BACKGROUND="…"` : le fond appliqué, un nom de fichier du dossier `backgrounds/` de ce thème. Un fond à toi se dépose dans `modules/theme/backgrounds/<thème>/`.

---

## 5. Écran de déverrouillage du disque (Plymouth)

C'est l'écran du démarrage où tu tapes le mot de passe du disque chiffré. Il ne suit pas le thème du bureau : il se règle à part. Chaque changement reconstruit l'image de démarrage : il **demande le mot de passe sudo** et se voit **au prochain démarrage**.

| Action | Comment |
|---|---|
| Choisir avec aperçus | menu **Appearance → Unlock** |
| Voir le thème actuel | `omarchy plymouth current` |
| Lister les thèmes possibles | `omarchy plymouth list` |
| Prendre les couleurs d'un thème | `omarchy plymouth set by theme tokyo-night` |
| Couleurs et logo à toi | `omarchy plymouth set 1a1b26 c0caf5 ~/Images/logo.png` (fond, texte, logo PNG) |
| Prévisualiser sans rien changer | `omarchy plymouth preview 1a1b26 c0caf5 ~/Images/logo.png ~/apercu.png` |
| Revenir à l'écran d'Omarchy | `omarchy plymouth reset` |

**Par défaut dans le dépôt :** `PLYMOUTH_THEME="matte-black"` dans `modules/plymouth/module.sh`. Mets-y un nom de `omarchy plymouth list`.

---

## 6. Économiseur d'écran

Avec l'élément `idle-lock` (coché par défaut) :

| Inactivité | Ce qui se passe |
|---|---|
| **5 min** | l'économiseur démarre. Au moindre mouvement ou touche, il se ferme et **l'écran de verrouillage demande ton mot de passe** : tu ne retombes pas sur le bureau. |
| **15 min** | la session se verrouille et **l'écran s'éteint**. Une touche le rallume sur l'écran de verrouillage. |

L'économiseur ne peut pas s'afficher *par-dessus* l'écran de verrouillage d'Omarchy : le mot de passe est donc demandé juste après, quand tu reviens. C'est le service `screensaver-lock` qui s'en charge (`systemctl --user status screensaver-lock`). Un économiseur lancé à la main (menu **System → Screensaver**) ne verrouille pas en se fermant.

Sans `idle-lock`, ce sont les délais d'Omarchy : économiseur à 2 min 30, verrouillage à 5 min, écran éteint 5 s après le verrouillage.

### Le voir maintenant

```bash
omarchy launch screensaver force
```

Tu peux aussi passer par le menu **System → Screensaver**. N'importe quelle touche ou mouvement de souris l'arrête.

### Changer son texte et ses polices

L'élément `screensaver` montre ton texte en ASCII art, une police différente à chaque effet.

```bash
screensaver-text                            # texte actuel, polices de la rotation et leur taille
screensaver-text set "Bonjour"              # change le texte et redessine tout
screensaver-text preview                    # aperçu de toutes les polices, dans le terminal
screensaver-text preview Doom --text "Essai"    # essayer une police ou un texte sans rien changer
screensaver-text fonts                      # polices disponibles (screensaver-text fonts shadow pour filtrer)
screensaver-text add Doom "ANSI Shadow@grand"   # ajouter des polices à la rotation
screensaver-text remove 3 Basic             # retirer (par numéro ou par nom)
screensaver-text only "DOS Rebel"           # ne garder que celles-là
screensaver-text reset                      # les huit polices par défaut
```

Deux modificateurs s'ajoutent au nom d'une police : `@grand` donne des lettres deux fois plus grandes (pour les polices en blocs) et `@large` empêche figlet de resserrer les lettres.

Les réglages sont dans `~/.config/dotfiles/screensaver.conf`, sur la machine seulement : ton texte n'est jamais dans le dépôt. Avec cet élément, n'utilise pas **Appearance → Branding → Screensaver** d'Omarchy : la rotation remplacerait aussitôt ce texte.

### Changer quand il démarre

Dans `~/.config/omarchy/shell.json`, la partie `"idle"`, en secondes. `lock` est le moment où l'écran devient noir (verrouillage puis extinction 5 s plus tard) :

```json
"idle": {
  "screensaver": 300,
  "lock": 900
}
```

Le fichier est relu dès que tu l'enregistres. Pour que ce soit le réglage de chaque nouvelle machine, change `IDLE_SCREENSAVER` et `IDLE_BLANK` dans `modules/idle/module.sh` : `./install.sh` les remet sinon à 5 et 15 min.

### Le désactiver

| Action | Comment |
|---|---|
| Plus d'économiseur (le verrouillage reste) | menu **Trigger → Toggle → Screensaver Off** (et **Screensaver On** pour le remettre) |
| Ni économiseur ni verrouillage pour un moment (film, présentation) | `Super+Ctrl+I`, ou menu **Trigger → Toggle → Stay Awake** |
| Revenir à l'économiseur d'Omarchy (logo) | `./install.sh --disable screensaver` |

---

## 7. Framework Laptop 13 : Hz adaptatifs et pavé tactile

Des éléments faits pour le Framework Laptop 13 AMD (Ryzen AI 300, écran 2,8K à 120 Hz), décochés par défaut.

**Pour la batterie**, les deux qui comptent le plus : `power-profile` (coché par défaut, profil `balanced` au lieu de `performance`) et `adaptive-refresh` (ci-dessous). `powerprofilesctl get` montre le profil actuel.

### Hz adaptatifs (`adaptive-refresh`)

L'écran tourne à 120 Hz quand quelque chose bouge (souris, défilement) et descend vers 34–48 Hz quand l'image est figée : la fluidité reste, la batterie dure plus. Une vidéo fait tourner l'écran à sa propre cadence (60 Hz pour une vidéo à 30 ou 60 images/s).

```bash
./install.sh adaptive-refresh    # demande le mot de passe sudo
```

Puis **redémarre** : le paramètre noyau `amdgpu.dcdebugmask=0x610` ne s'applique qu'au démarrage. Il coupe le Panel Self Refresh et le Panel Replay de l'écran. Sans lui, le VRR fait tomber la souris et les vidéos sous 1 FPS, jusqu'à figer l'écran. Après le redémarrage, `cat /sys/module/amdgpu/parameters/dcdebugmask` doit afficher `1552`.

| Pour | Comment |
|---|---|
| Voir les Hz réels | `Super+Ctrl+Alt+H` (la même touche le ferme), ou `hz` dans un terminal, `hz --once` pour une mesure. `hz` lit le compteur de rafraîchissements du noyau : il ne dessine rien, donc ne fait pas monter les Hz comme une page de test dans le navigateur |
| VRR en plein écran seulement | dans `~/.config/hypr/dotfiles/adaptive_refresh.lua`, `vrr = 2` au lieu de `1`, puis `hyprctl reload` |
| Tout retirer | `./install.sh --disable adaptive-refresh`, puis redémarrer |
| L'écran fige quand même | `Ctrl+Alt+F3`, connecte-toi, `cd` dans le dépôt puis `./install.sh --disable adaptive-refresh --files-only`, et reviens avec `Ctrl+Alt+F1` (ou `F2`) : le VRR est coupé. Le paramètre noyau reste, sans gêner ; `./install.sh --disable adaptive-refresh` (sans `--files-only`) le retire au prochain démarrage |

Le curseur de la souris passe en logiciel : avec le VRR, le pilote AMD ne met à jour le curseur matériel qu'une image sur plusieurs, et la souris ramerait. N'utilise pas l'overlay de débogage de Hyprland (`debug:overlay`) pour voir les FPS : avec le VRR, il fige l'écran.

### Pavé tactile avec des doigts fantômes (`touchpad-reset`)

Parfois, après une longue pause (souvent une mise en veille), le pavé croit qu'un ou deux doigts sont restés posés : bouger fait défiler, défiler zoome, etc.

```bash
./install.sh touchpad-reset    # demande le mot de passe sudo
```

| Pour | Comment |
|---|---|
| Le débloquer tout de suite | `Super+Ctrl+Alt+P` (ou `touchpad-reset` dans un terminal). Une notification confirme |
| L'éviter | rien à faire : le pavé est aussi réinitialisé à chaque sortie de veille |
| Réinitialisation légère seulement | `touchpad-reset --soft` : Hyprland éteint et rallume le pavé, sans toucher au pilote |

La réinitialisation complète détache puis rattache le pilote `i2c_hid_acpi` du pavé. Le pavé redémarre et revient comme un nouveau périphérique, et libinput oublie les doigts qu'il croyait posés. Elle passe par un script root fixe (`/usr/local/lib/dotfiles/touchpad-rebind`, sans argument), qu'une règle sudoers te laisse lancer sans mot de passe.

**Les causes possibles :**

- Le **micrologiciel du pavé** (PixArt `PIXA3854`) qui perd un contact : il ne signale pas qu'un doigt s'est levé, ou il envoie une position aberrante. libinput le note dans le journal de Hyprland (`kernel bug: Touch jump detected and discarded`).
- La **sortie de veille** : la puce du pavé et son bus I2C se remettent en route dans un état incohérent. C'est le cas le plus souvent signalé sur les Framework, d'où la réinitialisation automatique au réveil.
- Une **paume ou un pouce** posé au bord pendant la frappe, que le pavé continue de compter.
- Des **parasites électriques** : chargeur sans prise de terre, humidité, objet métallique contre le pavé. Si ça arrive surtout sur secteur, essaie une autre prise ou un autre chargeur.

Pour voir ce que le pavé croit sentir : `sudo libinput debug-events --device /dev/input/event8` (le numéro d'`event` est dans `cat /proc/bus/input/devices`, sous « Touchpad »). Une ligne qui annonce plusieurs doigts alors qu'il n'y en a aucun confirme le doigt fantôme.

### Curseur immobile pendant la frappe (`typing-guard`)

Quand tu tapes, une paume qui frôle le pavé ne déplace plus le curseur.

```bash
./install.sh typing-guard
```

libinput a déjà un blocage pendant la frappe, mais il est court (0,2 à 0,5 s après la dernière touche, non réglable) et ne bloque que les contacts qui commencent pendant la frappe. Le pavé du Framework ne mesure ni la pression ni la taille des contacts : une paume ne peut pas être reconnue à sa forme, comme sur un trackpad Apple. Avec `typing-guard`, chaque touche tapée immobilise le curseur jusqu'à 0,8 s après la dernière. Le pavé n'est pas éteint : son accélération passe à zéro, puis revient. (Une première version l'éteignait, et un doigt posé à ce moment revenait mal suivi : clics qui marchent mais curseur bloqué.)

| Pour | Comment |
|---|---|
| Ctrl + clic, Maj + clic juste après avoir tapé | ça marche : les clics passent toujours, et appuyer sur Ctrl ou Maj rend aussi le mouvement tout de suite. Ctrl, Maj, Alt, AltGr et Super ne déclenchent jamais le blocage, ni les raccourcis comme Ctrl+C |
| Changer le délai | `GUARD_MS` en haut de `~/.config/hypr/dotfiles/typing_guard.lua` (en millisecondes), puis `hyprctl reload`. Plus long protège mieux des paumes, plus court rend le mouvement plus vite après la frappe |
| Le désactiver | `./install.sh --disable typing-guard` |

Limites : une paume posée pendant une pause de plus de 0,8 s redevient un doigt. Un tap de paume (pas un clic) reste filtré par libinput seulement. Un clavier externe déclenche aussi le blocage.

---

## 8. Le reste

- Thème complet du bureau (terminal, barre, verrouillage, fond…) : `Super+Ctrl+T`, ou menu **Appearance → Theme**.
- Tous les raccourcis clavier : `Super+K`.
- Activer ou désactiver un élément du dépôt : `./install.sh` (menu), `./install.sh <élément>`, `./install.sh --disable <élément>`. La liste des éléments : `./install.sh --list`.
- Ce guide : `dotfiles-guide`. Ce que fait chaque élément : `README.md`.
