.pragma library

// unites.js — vocabulaire du calcul du lanceur (L2-82), données seules.
// Rôle : liste tout ce que le lanceur sait lire. Un mot absent d'ici fait taire le calcul, parce que qalc invente un
// sens aux mots qu'il ne connaît pas (« 5 asdfg » y vaut 432 qg·s²). Ajouter un mot ou une unité tient en une ligne.
// Entrées, sorties, erreurs : aucune. Dépendances : aucune ; chaque nom qalc est éprouvé par tests/test_lanceur.py.

// Unités : [nom qalc, grandeur, symboles, noms, préfixes].
// Grandeur : puissances de L (longueur), M (masse), T (durée), I (courant), K (température), A (angle), D (donnée) et
// E (monnaie), par exemple « L T-1 ». Symboles et noms se séparent par « | ». Un symbole garde sa casse ; un nom
// s'écrit ici en minuscules, sans accent et au singulier. Préfixes : "" aucun, "si" tous les décimaux,
// "k" les décimaux à partir de kilo, "bi" ceux-là et les binaires.
const UNITES = [
    ["m", "L", "m", "metre|meter", "si"],
    ["in", "L", "in", "pouce|inch|inches", ""],
    ["ft", "L", "ft", "pied|foot|feet", ""],
    ["yd", "L", "yd", "yard|verge", ""],
    ["mi", "L", "mi", "mile", ""],
    ["nmi", "L", "nmi|NM", "mille marin|mille nautique|nautical mile", ""],
    ["ly", "L", "ly|al", "annee lumiere|lightyear", ""],
    ["au", "L", "au|ua", "unite astronomique", ""],
    ["pc", "L", "pc", "parsec", ""],

    ["ha", "L2", "ha", "hectare", ""],
    ["acre", "L2", "", "acre", ""],

    ["L", "L3", "L|l", "litre|liter", "si"],
    ["gal", "L3", "gal", "gallon", ""],
    ["cup", "L3", "", "cup", ""],
    ["fl_oz", "L3", "", "once liquide|fluid ounce", ""],

    ["g", "M", "g", "gramme|gram", "si"],
    ["t", "M", "t", "tonne", "k"],
    ["lb", "M", "lb|lbs", "livre|pound", ""],
    ["oz", "M", "oz", "once|ounce", ""],
    ["stone", "M", "st", "stone", ""],

    ["s", "T", "s", "seconde|second|sec", "si"],
    ["min", "T", "min|mn", "minute", ""],
    ["h", "T", "h", "heure|hour", ""],
    ["d", "T", "j|d", "jour|journee|day", ""],
    ["week", "T", "", "semaine|week", ""],
    ["month", "T", "", "mois|month", ""],
    ["year", "T", "yr", "an|annee|year", ""],

    ["km/h", "L T-1", "kmh|kph", "", ""],
    ["mi/h", "L T-1", "mph", "", ""],
    ["knot", "L T-1", "kn|kt", "noeud|knot", ""],

    ["°C", "K", "°C", "celsius|degre celsius", ""],
    ["°F", "K", "°F", "fahrenheit|degre fahrenheit", ""],
    ["K", "K", "K", "kelvin|degre kelvin", ""],

    ["deg", "A", "°|deg", "degre|degree", ""],
    ["rad", "A", "rad", "radian", "si"],
    ["gon", "A", "gon", "grade", ""],
    ["turn", "A", "tr", "tour", ""],

    ["Hz", "T-1", "Hz", "hertz", "si"],
    ["N", "M L T-2", "N", "newton", "si"],

    ["J", "M L2 T-2", "J", "joule", "si"],
    ["Wh", "M L2 T-2", "Wh", "wattheure|watt heure", "si"],
    ["cal", "M L2 T-2", "cal", "calorie", "si"],
    ["eV", "M L2 T-2", "eV", "electronvolt", "si"],

    ["W", "M L2 T-3", "W", "watt", "si"],
    ["hp", "M L2 T-3", "hp", "horsepower", ""],

    ["Pa", "M L-1 T-2", "Pa", "pascal", "si"],
    ["bar", "M L-1 T-2", "bar", "bar", ""],
    ["mbar", "M L-1 T-2", "mbar", "millibar", ""],
    ["kbar", "M L-1 T-2", "kbar", "kilobar", ""],
    ["atm", "M L-1 T-2", "atm", "atmosphere", ""],
    ["psi", "M L-1 T-2", "psi", "", ""],
    ["mmHg", "M L-1 T-2", "mmHg", "", ""],

    ["A", "I", "A", "ampere", "si"],
    ["Ah", "I T", "Ah", "amperheure|ampere heure", "si"],
    ["V", "M L2 T-3 I-1", "V", "volt", "si"],
    ["ohm", "M L2 T-3 I-2", "\u03a9|\u2126", "ohm", "si"],

    ["B", "D", "o|B", "octet|byte", "bi"],
    ["kB", "D", "Ko|KB", "", ""],
    ["bit", "D", "bit|b", "bit", "bi"],
    ["bit/s", "D T-1", "bps", "", "bi"],

    ["€", "E", "€", "", "k"],
    ["$", "E", "$", "", "k"],
    ["£", "E", "£", "", "k"],
    ["EUR", "E", "", "eur|euro", ""],
    ["USD", "E", "", "usd|dollar", ""],
    ["GBP", "E", "", "gbp|livre sterling", ""],
    ["CHF", "E", "", "chf|franc suisse", ""],
    ["JPY", "E", "¥", "jpy|yen", ""],
    ["CNY", "E", "", "cny|yuan", ""],
    ["CAD", "E", "", "cad|dollar canadien", ""],
    ["AUD", "E", "", "aud|dollar australien", ""],
    ["NZD", "E", "", "nzd", ""],
    ["SEK", "E", "", "sek|couronne suedoise", ""],
    ["NOK", "E", "", "nok|couronne norvegienne", ""],
    ["DKK", "E", "", "dkk|couronne danoise", ""],
    ["PLN", "E", "", "pln|zloty", ""],
    ["CZK", "E", "", "czk|couronne tcheque", ""],
    ["HUF", "E", "", "huf|forint", ""],
    ["RON", "E", "", "ron", ""],
    ["TRY", "E", "", "try", ""],
    ["INR", "E", "", "inr|roupie", ""],
    ["BRL", "E", "", "brl", ""],
    ["MXN", "E", "", "mxn", ""],
    ["KRW", "E", "", "krw|won", ""],
    ["SGD", "E", "", "sgd", ""],
    ["HKD", "E", "", "hkd", ""],
    ["THB", "E", "", "thb|baht", ""],
    ["ZAR", "E", "", "zar|rand", ""],
    ["ILS", "E", "", "ils|shekel", ""],
    ["BTC", "E", "", "btc|bitcoin", ""],
]

// Préfixes : [symbole qalc, autres symboles, nom]. Les petits n'ont de sens ni pour une donnée ni pour une tonne.
const PETITS = [
    ["p", "", "pico"], ["n", "", "nano"], ["µ", "μ", "micro"], ["m", "", "milli"], ["c", "", "centi"],
    ["d", "", "deci"], ["da", "", "deca"], ["h", "", "hecto"],
]
const GRANDS = [["k", "", "kilo"], ["M", "", "mega"], ["G", "", "giga"], ["T", "", "tera"], ["P", "", "peta"]]
const BINAIRES = [["Ki", "", "kibi"], ["Mi", "", "mebi"], ["Gi", "", "gibi"], ["Ti", "", "tebi"]]
const PREFIXES = { "": [], si: PETITS.concat(GRANDS), k: GRANDS, bi: GRANDS.concat(BINAIRES) }

// Constantes : mot saisi, à la casse près (« 5 E » n'est pas 5 e), nom qalc.
const CONSTANTES = [["pi", "pi"], ["Pi", "pi"], ["π", "pi"], ["e", "e"]]

// Bases de numération admises comme cible d'une conversion : mot saisi, nom qalc.
const BASES = [["hex", "hex"], ["hexa", "hex"], ["hexadecimal", "hex"], ["bin", "bin"], ["binaire", "bin"],
               ["oct", "oct"], ["octal", "oct"]]

// Fonctions à un argument. « racine » divise la grandeur par deux, « garde » la conserve, « nombre » exige un nombre
// ou un angle et rend un nombre.
const FONCTIONS = [
    ["sqrt", "racine"], ["abs", "garde"], ["round", "nombre"], ["floor", "nombre"], ["ceil", "nombre"],
    ["sin", "nombre"], ["cos", "nombre"], ["tan", "nombre"], ["asin", "nombre"], ["acos", "nombre"], ["atan", "nombre"],
    ["ln", "nombre"],
    ["log", "nombre"], ["log2", "nombre"], ["log10", "nombre"], ["exp", "nombre"],
]

// Mots qui valent un opérateur, et mots qui introduisent une conversion (« in » après une unité, sinon c'est le pouce).
const OPERATEURS = [["x", "×"], ["fois", "×"], ["par", "/"], ["plus", "+"], ["moins", "-"], ["mod", "mod"]]
const CONVERSIONS = ["en", "vers", "to", "in"]

// Exposants écrits en mots.
const EXPOSANTS = [["carre", 2], ["cube", 3]]

// Noms qalc des durées dont une conversion garde la forme composée (« 1 h + 40 min »), sans unité unique forcée.
const DUREES = ["h", "min", "s", "d"]
