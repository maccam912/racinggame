"""A failed acceptance-input push cannot be hidden by the next cosmetic push."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from acceptance_changes import detect


class AcceptanceChanges(unittest.TestCase):
    def test_failed_push_then_cosmetic_push_still_requires_the_soak(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)/'checkout'; root.mkdir()
            remote = Path(temp)/'remote.git'
            def git(*args):
                return subprocess.check_output(['git',*args],cwd=root,stderr=subprocess.DEVNULL,text=True).strip()
            subprocess.run(['git','init','--bare',str(remote)],check=True,capture_output=True)
            git('init','-b','main'); git('config','user.name','Acceptance Fixture'); git('config','user.email','fixture@example.invalid')
            git('remote','add','origin',str(remote))
            def commit(path,value):
                target = root/path; target.parent.mkdir(parents=True,exist_ok=True); target.write_text(value)
                git('add',path); git('commit','-m','fixture')
            commit('game/content/compatibility.json','baseline')
            git('tag','v0.0.1-dev'); git('tag','unrelated-9999'); git('push','--tags','origin','main')
            self.assertFalse(detect(root)['gameplay_changed'])
            commit('tests/soak_network_client.gd','new fixture in failed build')
            commit('game/ui/menu.gd','subsequent cosmetic change')
            value = detect(root)
            self.assertTrue(value['soak_changed']); self.assertFalse(value['gameplay_changed'])
            self.assertEqual(value['baseline_tag'],'v0.0.1-dev')
            git('tag','v0.0.2-dev'); git('push','origin','refs/tags/v0.0.2-dev')
            self.assertFalse(detect(root)['soak_changed'])
            commit('game/content/compatibility.json','new physics identity')
            value = detect(root)
            self.assertTrue(value['soak_changed']); self.assertTrue(value['gameplay_changed'])


if __name__=='__main__': unittest.main()
