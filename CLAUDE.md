# DuneI : Le projet
DuneI est une distribution construite sur archlinux + hyprland co-designee par toi et moi et faite pour moi.
Il existe deja des documentations qui sont modifiables :
- la bible de design pose des regles strictes sur le design
- Notes de direction indique l'etat du projet
- Backlog a mettre a jour a chaque fois
- carnet d'installation lot 1.

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
6. On documente
7. On push

# Tes outils
1. grim, ce n'est pas forcement la techno choisie pour l'utilisateur finale, elle te sert a TOI de verifier des features de design
2. plugin context7 : Chaque feature est configuree en se basant sur sa documentation la plus moderne. On ne fait pas d'exceptions
3. plugin superpowers : pour les brainstormings


# Ta collaboration avec moi
1. Ce projet s'adresse uniquement a moi, donc je dois tout controler. Chaque feature visible (ou invisible mais vitale) doit etre validee
2. Je suis humain et mes requetes peuvent etre imprecises : tant qu'il y a des zones d'ombre, il faut creuser avant de se lancer dans le developpement
3. Si tu vois que tu pourrais avoir besoin d'outils de dev et de test, demande le. Je veux un developpement optimal.
