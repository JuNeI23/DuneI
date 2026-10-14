"""Ressort — le simulateur Python retrouve les mesures du banc proto/motion."""

import unittest

from dunei_motion.spring import critical_spring, exit_spring, simulate, spring, zeta

# Durées de stabilisation à ±1 % affichées par le banc pour les réglages validés le 2026-10-13.
BENCH = {
    "state": ((0.50, 1100, 50), 164),
    "reveal": ((1.00, 600, 50), 286),
    "overlay": ((1.00, 400, 44), 402),
    "window": ((0.70, 300, 27), 274),
    "reflow": ((0.80, 500, 40), 269),
    "spectacle": ((1.00, 150, 25), 569),
    "navigate": ((0.30, 600, 30), 186),
}


class SpringTest(unittest.TestCase):
    """Simulation, dérivation de la sortie et ressort réduit."""

    def test_matches_bench(self):
        for name, (params, ms) in BENCH.items():
            with self.subTest(transition=name):
                self.assertEqual(simulate(spring(*params))[0], ms)

    def test_exit_keeps_zeta_and_scales_duration(self):
        s = spring(1, 600, 50)
        e = exit_spring(s, 0.7)
        self.assertEqual(e, {"mass": 1, "stiffness": 1224.5, "dampening": 71.43})
        self.assertAlmostEqual(zeta(e), zeta(s), places=3)
        self.assertAlmostEqual(simulate(e)[0], 0.7 * simulate(s)[0], delta=2)

    def test_critical_spring(self):
        r = critical_spring(100)
        self.assertEqual(r, {"mass": 1, "stiffness": 4406.3, "dampening": 132.76})
        self.assertAlmostEqual(zeta(r), 1, places=3)
        self.assertAlmostEqual(simulate(r)[0], 100, delta=5)

    def test_overshoot_only_below_critical(self):
        self.assertGreater(simulate(spring(0.70, 300, 27))[1], 0)
        self.assertEqual(simulate(spring(1, 600, 50))[1], 0)


if __name__ == "__main__":
    unittest.main()
