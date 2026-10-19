"""Contrôle GitHub et règle de main — le workflow et le ruleset versionnés se répondent (L1-21)."""

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORKFLOW = ROOT / ".github/workflows/controle.yml"
REGLE = ROOT / "setup/github/regle-main.json"


class ControleTest(unittest.TestCase):
    """Le nom du contrôle exigé est celui de la tâche du workflow ; les actions sont épinglées."""

    def test_tache_controle(self):
        texte = WORKFLOW.read_text(encoding="utf-8")
        self.assertRegex(texte, r"(?m)^jobs:\n  controle:$")
        self.assertIn("pull_request", texte)

    def test_actions_epinglees(self):
        uses = re.findall(r"uses:\s*(\S+)", WORKFLOW.read_text(encoding="utf-8"))
        self.assertTrue(uses)
        for u in uses:
            self.assertRegex(u, r"@[0-9a-f]{40}$")

    def test_ruleset(self):
        regle = json.loads(REGLE.read_text(encoding="utf-8"))
        self.assertEqual(len(regle["rules"]), 1)
        rule = regle["rules"][0]
        self.assertEqual(rule["type"], "required_status_checks")
        self.assertEqual([c["context"] for c in rule["parameters"]["required_status_checks"]], ["controle"])
        self.assertFalse(rule["parameters"]["strict_required_status_checks_policy"])
        self.assertEqual(regle["bypass_actors"], [{"actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "pull_request"}])
        self.assertEqual(regle["conditions"]["ref_name"]["include"], ["~DEFAULT_BRANCH"])


if __name__ == "__main__":
    unittest.main()
