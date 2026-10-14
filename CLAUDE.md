# DuneI : Le projet
**Au debut de chaque session, et apres chaque /clear, appliquer la section « Reprise » avant toute autre chose.**

DuneI est une distribution construite sur archlinux + hyprland co-designee par toi et moi et faite pour moi.
Il existe deja des documentations qui sont modifiables :
- la bible de design pose des regles strictes sur le design
- Notes de direction indique l'etat du projet
- Backlog a mettre a jour a chaque fois
- carnet d'installation lot 1.
- journal des decisions (docs/journal-decisions.md) : chaque arbitrage, avec sa raison.

Versionnage des documents : numero de version en tete + table "Historique des versions" en fin de fichier. Pas de dossier d'archive, git est l'archive. Etiquette git a chaque fin de lot.

# Reprise
1. `git status`, `git log --oneline -5`, `gh pr list` : branche courante, PR en attente de fusion.
2. Notes de direction, « Etat d'avancement », dernier paragraphe : la prochaine etape.
3. Backlog : la ligne de l'element vise (L1-xx). Carnet : sa section.
4. Journal : les dernieres decisions (Dxx), si la feature touche un sujet deja arbitre.
Le reste se lit seulement au besoin.

# Reperes
- Docs : docs/project_management/ (bible, direction, backlog, carnet), docs/journal-decisions.md,
  docs/superpowers/specs/ et plans/ (AAAA-MM-JJ-<sujet>.md).
- Chaine : make tokens | motion | test | check | golden | install. generated/ ne s'edite jamais.
- Une branche feat/<sujet> par feature, partie de main a jour, une PR, je fusionne.
- make install refuse les arbres git secondaires : travailler dans ~/DuneI.
- Apercus : .superpowers/preview/, ouverts dans un Firefox isole et captures avec grim ;
  jamais firefox --headless pour juger une police.

# Regles globales de developpement
1. Tout changement, installation, nouvelle feature est documente dans les ressources correspondantes.
2. Chaque fonction est commentee : 
- Son titre et son role
- ses parametres d'entree
- ses parametres de sortie
- ses eventuels messages d'erreurs
- ses dependances
3. Le code est minimal, si une ligne suffit alors on ecrit une ligne. 
4. Le code est modulaire, le projet n'est pas fige dans le marbre donc chaque fonctionnalite doit etre facilement etendable, scalable et intercheangable. On fait de l'abstraction des que possible.
5. Le code est agnostique de la machine et peut etre installe sur n'importe quelle autre machine Arch + Hyprland.
6. Tu es responsable du git, tu as l'interdiction formelle de push des secrets.
7. Je travaille sur la machine surlaquelle tu developpes dunei. Si des etats changent, son, luminosite etc ect c'est tres surement parce que je l'ai fait et pas un bug.

# Developpement d'une feature 
1. On identifie une feature
2. On la decompose :objectifs, listing des technos possibles, recuperation de leur documentation la plus moderne, dependances avec d'autres features etc
3. On planifie
4. Si le plan est valide, alors on code
5. On teste
6. On documente ; le dernier paragraphe des notes de direction nomme toujours la prochaine etape
7. On push

# Tes outils
1. grim, ce n'est pas forcement la techno choisie pour l'utilisateur finale, elle te sert a TOI de verifier des features de design
2. plugin context7 : Chaque feature est configuree en se basant sur sa documentation la plus moderne. On ne fait pas d'exceptions
3. plugin superpowers : pour les brainstormings
4. Sous-agents : pour accelerer le developpement et ne pas remplir ta fenetre de contexte, lance des sous-agents pour chaque tache independante, propose moi des astuces pour fluidifier.

# Ta collaboration avec moi
1. Ce projet s'adresse uniquement a moi, donc je dois tout controler. Chaque feature visible (ou invisible mais vitale) doit etre validee
2. Je suis humain et mes requetes peuvent etre imprecises : tant qu'il y a des zones d'ombre, il faut creuser avant de se lancer dans le developpement
3. Si tu vois que tu pourrais avoir besoin d'outils de dev et de test, demande le. Je veux un developpement optimal.
4. Des que c'est pertinent, indique moi de compacter ou clear la conversation. N'hesite pas a faire de la doc et modifier tes ressources perso
