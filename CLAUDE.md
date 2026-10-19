# DuneI : Le projet
**Au début de chaque session, et après chaque /clear, appliquer la section « Reprise » avant toute autre chose.**

DuneI est une distribution construite sur archlinux + hyprland co-designée par toi et moi et faite pour moi.
Il existe déjà des documentations qui sont modifiables :
- la bible de design pose des règles strictes sur le design
- Notes de direction indique l'état du projet
- Backlog à mettre à jour à chaque fois
- carnet d'installation lot 1.
- journal des décisions (docs/journal-decisions.md) : chaque arbitrage, avec sa raison.

Versionnage des documents : numéro de version en tête + table "Historique des versions" en fin de fichier. Pas de dossier d'archive, git est l'archive. Étiquette git à chaque fin de lot.

# Reprise
1. `git status`, `git log --oneline -5`, `gh pr list` : branche courante, PR en attente de fusion.
2. Notes de direction, « État d'avancement », dernier paragraphe : la prochaine étape.
3. Backlog : la ligne de l'élément visé (L1-xx). Carnet : sa section.
4. Journal : les dernières décisions (Dxx), si la feature touche un sujet déjà arbitré.
Le reste se lit seulement au besoin.

# Repères
- Docs : docs/project_management/ (bible, direction, backlog, carnet), docs/journal-decisions.md,
  docs/superpowers/specs/ et plans/ (AAAA-MM-JJ-<sujet>.md).
- Chaîne : make tokens | motion | generes | test | check | golden | install. generated/ ne s'édite jamais :
  le crochet pre-commit et le contrôle exigé sur main le refusent (D77).
- Une branche feat/<sujet> par feature, partie de main à jour, une PR. Tu la fusionnes toi-même dès
  que la relecture finale est propre et que j'ai validé à l'écran, par `gh pr merge <n> --merge` seul,
  puis tu appliques la procédure après fusion du carnet (D32). Jamais `--delete-branch` : il bascule
  l'arbre local sur l'ancien main avant de le tirer. Jamais `--admin` ni fusion par `gh api` : un contrôle
  rouge se corrige ou se signale (D77) ; `git commit --no-verify` est permis.
- make install refuse les arbres git secondaires : travailler dans ~/DuneI.
- Atelier (L1-26) : ~/dunei-atelier, dépôt privé, porte mes réglages, instructions et mémoire ; tout
  changement y est validé et envoyé aussitôt (D64). rtk est épinglé dans atelier.toml.
- Aperçus : .superpowers/preview/, ouverts dans un Firefox isolé et capturés avec grim ;
  jamais firefox --headless pour juger une police.

# Règles globales de développement
1. Tout changement, installation, nouvelle feature est documenté dans les ressources correspondantes.
2. Chaque fonction est commentée :
- Son titre et son rôle
- ses paramètres d'entrée
- ses paramètres de sortie
- ses éventuels messages d'erreurs
- ses dépendances
3. Le code est minimal, si une ligne suffit alors on écrit une ligne.
4. Le code est modulaire, le projet n'est pas figé dans le marbre donc chaque fonctionnalité doit être facilement extensible, scalable et interchangeable. On fait de l'abstraction dès que possible.
5. Le code est agnostique de la machine et peut être installé sur n'importe quelle autre machine Arch + Hyprland.
6. Tu es responsable du git, tu as l'interdiction formelle de push des secrets. Chaque modèle signe sa propre
   production (ligne `Co-Authored-By`) : un commit écrit par un sous-agent porte le nom de son modèle.
7. Je travaille sur la machine sur laquelle tu développes DuneI. Si des états changent, son, luminosité, etc., c'est très sûrement parce que je l'ai fait et pas un bug.

# Développement d'une feature
1. On identifie une feature et tu m'en expliques l'enjeu avant toute question : ce qu'elle change pour moi, ce qui casse sans elle, ce qu'elle engage pour la suite, ce qu'elle ne couvre pas
2. On la décompose : objectifs, listing des technos possibles, récupération de leur documentation la plus moderne, dépendances avec d'autres features, etc.
2bis. Tu n'imposes jamais une techno directement : on fait un repérage de la meilleure option, mêlant confort, intégrabilité et performance.
3. On planifie
4. Si le plan est validé, alors on code
5. On teste
6. On documente ; le dernier paragraphe des notes de direction nomme toujours la prochaine étape
7. On push, puis tu fusionnes (voir Repères)

# Tes outils
1. grim, ce n'est pas forcément la techno choisie pour l'utilisateur final, elle te sert à TOI de vérifier des features de design
2. plugin context7 : chaque feature est configurée en se basant sur sa documentation la plus moderne. On ne fait pas d'exceptions
3. plugin superpowers : pour les brainstormings
4. Sous-agents : pour accélérer le développement et ne pas remplir ta fenêtre de contexte, lance des sous-agents pour chaque tâche indépendante, propose-moi des astuces pour fluidifier.

# Ta collaboration avec moi
1. Ce projet s'adresse uniquement à moi, donc je dois tout contrôler. Chaque feature visible (ou invisible mais vitale) doit être validée
2. Je suis humain et mes requêtes peuvent être imprécises : tant qu'il y a des zones d'ombre, il faut creuser avant de se lancer dans le développement
3. Si tu vois que tu pourrais avoir besoin d'outils de dev et de test, demande-le. Je veux un développement optimal.
4. Dès que c'est pertinent, indique-moi de compacter ou clear la conversation. N'hésite pas à faire de la doc et modifier tes ressources perso
5. J'écris sans accents parce que mon clavier est en QWERTY : ce n'est pas un choix de style. Tout ce que tu écris (docs, code, commentaires, ce fichier) prend les accents du français correct.
