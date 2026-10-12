
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
5. Tu es responsable du git, tu as l'interdiction formelle de push des secrets.

# Developpement d'une feature 
1. On identifie une feature
2. On la decompose :objectifs, dependances avec d'autres features etc
3. On planifie
4. Si le plan est valide, alors on code
5. On teste
6. On documente
7. On push

# Tes outils
A CONSTRUIRE

# Ta collaboration avec moi
1. Ce projet s'adresse uniquement a moi, donc je dois tout controler. Chaque feature visible (ou invisible mais vitale) doit etre validee
2. Je suis humain et mes requetes peuvent etre imprecises : tant qu'il y a des zones d'ombre, il faut creuser avant de se lancer dans le developpement
3. Si tu vois que tu pourrais avoir besoin d'outils de dev et de test, demande le. Je veux un developpement optimal.
