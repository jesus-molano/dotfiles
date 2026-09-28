"""Synthetic catalogs only; no credentials, project tests or network required."""
import copy
import json
import os
import shutil
import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'ai/skills/tessera/scripts'))
import tessera
import tessera_batches as batches
import test_tessera as fixtures


def context(count=241, size=100):
    entries = [dict(id=f'item-{i:04d}', kind='utility', summary='Synthetic operation',
                    contract='Contract ' + 'x' * size, constraints=['No side effects'],
                    source=f'src/{i}.ts', usages=[], usage_gap='Synthetic unused utility') for i in range(count)]
    return tessera.build_context(dict(schema=1, project='synthetic', scope=['src'], entries=entries),
                                dict(revision='0' * 40, curation=dict(status='current')),
                                dict(id='example', requirement='Find the required operation', acceptance=['Exact contract']))


def response(request, choice):
    return tessera.encoded(dict(model=request['model'], answers=dict(decision=dict(
        type='choice', choice=choice, confidence=1.0,
        probabilities={key: float(key == choice) for key in request['questions']['decision']['criteria']})),
        usage=dict(input_tokens=10, output_tokens=1)))


class BatchPlanTest(unittest.TestCase):
    def test_every_card_and_all_three_actions_appear_exactly_once(self):
        c = context()
        plan = batches.plan(c, tessera.tessera_typesafe, tessera.encoded)
        ids, choices = [], []
        for request in plan['requests']:
            self.assertLessEqual(len(tessera.encoded(request)), batches.REQUEST_BYTES)
            criteria = request['questions']['decision']['criteria']
            self.assertLessEqual(len(criteria), 255)
            choices.extend(key for key in criteria if key not in batches.GLOBAL)
            ids.extend(entry['id'] for entry in request['state']['catalog']['entries'])
            for entry in request['state']['catalog']['entries']:
                self.assertTrue(all(f"{action}:{entry['id']}" in criteria for action in ('reuse', 'modify', 'wrap')))
        self.assertEqual(sorted(ids), plan['entry_ids'])
        self.assertEqual(len(ids), len(set(ids)))
        self.assertEqual(set(choices), set(c['options']) - set(batches.GLOBAL))

    def test_small_context_keeps_original_wire_protocol(self):
        c = context(1)
        self.assertEqual(batches.plan(c, tessera.tessera_typesafe, tessera.encoded),
                         tessera.tessera_typesafe.build_request(c))

    def test_supporting_references_survive_every_partition(self):
        c = context()
        c['catalog']['supporting_files'] = ['theme/config.ts']
        plan = batches.plan(c, tessera.tessera_typesafe, tessera.encoded)
        for request in plan['requests']:
            self.assertEqual(request['state']['catalog']['supporting_files'], ['theme/config.ts'])

    def test_plan_is_stable_across_catalog_order(self):
        c = context()
        original = batches.plan(c, tessera.tessera_typesafe, tessera.encoded)
        c['catalog']['entries'].reverse()
        # Each partition keeps the canonical ID order, independent of source order.
        other = batches.plan(c, tessera.tessera_typesafe, tessera.encoded)
        self.assertEqual(original, other)

    def test_oversize_card_fails_without_truncation(self):
        c = context(1, batches.REQUEST_BYTES)
        before = copy.deepcopy(c)
        with self.assertRaisesRegex(ValueError, 'exceeds'):
            batches.plan(c, tessera.tessera_typesafe, tessera.encoded)
        self.assertEqual(c, before)

    def test_winner_reduction_is_bounded_and_keeps_action(self):
        c = context()
        plan = batches.plan(c, tessera.tessera_typesafe, tessera.encoded)
        seen = []
        def invoke(request, index):
            seen.append(request)
            keys = request['questions']['decision']['criteria']
            choice = 'wrap:item-0240' if 'wrap:item-0240' in keys else next(k for k in keys if k not in batches.GLOBAL)
            raw = response(request, choice)
            return raw, tessera.tessera_typesafe.validate_response(request, json.loads(raw))
        _, answer, count = batches.run(c, plan, tessera.tessera_typesafe, tessera.encoded, invoke)
        self.assertEqual(answer['choice'], 'wrap:item-0240')
        self.assertLessEqual(count, plan['max_calls'])
        self.assertGreater(count, len(plan['requests']))
        self.assertTrue(all(len(tessera.encoded(r)) <= batches.REQUEST_BYTES for r in seen))

    def test_unknown_partition_without_proposals_abstains_without_empty_call(self):
        c = context()
        plan = batches.plan(c, tessera.tessera_typesafe, tessera.encoded)
        seen = []
        def invoke(request, index):
            seen.append(len(request['state']['catalog']['entries']))
            raw = response(request, 'insufficient_evidence' if index == 0 else 'create')
            return raw, tessera.tessera_typesafe.validate_response(request, json.loads(raw))
        raw, answer, count = batches.run(c, plan, tessera.tessera_typesafe, tessera.encoded, invoke)
        self.assertIsNone(raw)
        self.assertEqual((answer['choice'], answer['decided_by']), ('insufficient_evidence', 'coordinator'))
        self.assertEqual(count, len(plan['requests']))
        self.assertNotIn(0, seen, 'The provider must never receive an empty comparison')

    def test_unanimous_create_is_resolved_by_rule_not_by_an_empty_call(self):
        c = context()
        plan = batches.plan(c, tessera.tessera_typesafe, tessera.encoded)
        def invoke(request, index):
            self.assertTrue(request['state']['catalog']['entries'], 'Empty comparison sent to the provider')
            # A real provider shown no cards tends to abstain; this mock would expose that call.
            raw = response(request, 'create')
            return raw, tessera.tessera_typesafe.validate_response(request, json.loads(raw))
        raw, answer, count = batches.run(c, plan, tessera.tessera_typesafe, tessera.encoded, invoke)
        self.assertIsNone(raw)
        self.assertEqual((answer['choice'], answer['decided_by'], answer['usage']['input_tokens']),
                         ('create', 'coordinator', 0))
        self.assertEqual(count, len(plan['requests']))

    def test_uncertain_final_create_still_fails(self):
        c = context()
        plan = batches.plan(c, tessera.tessera_typesafe, tessera.encoded)
        def invoke(request, index):
            options = [key for key in request['questions']['decision']['criteria'] if key not in batches.GLOBAL]
            if index == 0:
                choice = 'insufficient_evidence'
            elif index == 1:
                choice = options[0]
            else:
                choice = 'create'
            raw = response(request, choice)
            return raw, tessera.tessera_typesafe.validate_response(request, json.loads(raw))
        with self.assertRaisesRegex(ValueError, 'Global create'):
            batches.run(c, plan, tessera.tessera_typesafe, tessera.encoded, invoke)


class BatchIntegrationTest(unittest.TestCase):
    def setUp(self):
        consent = patch.object(tessera, "require_provider_consent")
        consent.start()
        self.addCleanup(consent.stop)
        self.fixture = fixtures.TesseraTest()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        f = self.fixture
        f.data['entries'] = []
        for i in range(85):
            source = f'src/ui/Item{i}.tsx'
            (f.repo / source).write_text('export const value = 1;\n')
            f.data['entries'].append(dict(id=f'item-{i:04d}', source=source, kind='utility',
                summary='Synthetic factory', contract='Returns a constant', constraints=[],
                usages=[], usage_gap='Synthetic unused fixture'))
        f.data['scope'] = [entry['source'] for entry in f.data['entries']]
        tessera.git(f.repo, 'add', '.')
        tessera.git(f.repo, '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'fixture')
        result = f.prepare()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_evaluate_records_all_calls_and_never_replays(self):
        f = self.fixture
        def invoke(payload):
            request = json.loads(payload)
            choice = next(key for key in request['questions']['decision']['criteria'] if key not in batches.GLOBAL)
            return response(request, choice)
        with patch.object(tessera.tessera_typesafe, 'check_credentials'), \
                patch.object(tessera.tessera_typesafe, 'invoke', side_effect=invoke) as send:
            result = tessera.evaluate(f.run_dir)
            self.assertEqual(result['decided_by'], 'provider')
            self.assertTrue(result['batch_proposals'])
            self.assertTrue(all(set(p) == {'option', 'action', 'primary'} for p in result['batch_proposals']))
            self.assertEqual(len(result['evaluated_entry_ids']), 85)
            self.assertEqual(result['usage']['input_tokens'], send.call_count * 10)
            self.assertEqual(len(result['calls']), send.call_count)
            with self.assertRaises(FileExistsError):
                tessera.evaluate(f.run_dir)
        for call in result['calls']:
            directory = f.run_dir / 'calls' / f"{call['index']:04d}"
            self.assertEqual(tessera.digest((directory / 'response.json').read_bytes()), call['response_sha256'])

    def test_failed_second_batch_stops_without_decision_or_retry(self):
        f = self.fixture
        calls = 0
        def invoke(payload):
            nonlocal calls
            calls += 1
            if calls == 2: raise ValueError('synthetic provider failure')
            request = json.loads(payload)
            return response(request, next(iter(request['questions']['decision']['criteria'])))
        with patch.object(tessera.tessera_typesafe, 'check_credentials'), \
                patch.object(tessera.tessera_typesafe, 'invoke', side_effect=invoke):
            with self.assertRaisesRegex(ValueError, 'synthetic provider failure'):
                tessera.evaluate(f.run_dir)
            with self.assertRaises(FileExistsError):
                tessera.evaluate(f.run_dir)
        self.assertEqual(calls, 2)
        self.assertFalse((f.run_dir / 'decision.json').exists())
        self.assertEqual(tessera.load(f.run_dir / 'failure.json')['completed_calls'], 1)

    def test_tampered_plan_is_rejected_before_network(self):
        f = self.fixture
        path = f.run_dir / 'request.json'
        value = tessera.load(path)
        value['requests'].pop()
        path.write_bytes(tessera.encoded(value))
        with patch.object(tessera.tessera_typesafe, 'invoke') as invoke:
            with self.assertRaises(ValueError): tessera.evaluate(f.run_dir)
            invoke.assert_not_called()

    def test_existing_calls_directory_is_rejected_before_network(self):
        f = self.fixture
        (f.run_dir / 'calls').mkdir()
        with patch.object(tessera.tessera_typesafe, 'invoke') as invoke:
            with self.assertRaises(FileExistsError): tessera.evaluate(f.run_dir)
            invoke.assert_not_called()

    def test_checkout_change_between_batches_stops(self):
        f = self.fixture
        def invoke(payload):
            (f.repo / 'src/ui/Item0.tsx').write_text('changed\n')
            request = json.loads(payload)
            return response(request, 'create')
        with patch.object(tessera.tessera_typesafe, 'check_credentials'), \
                patch.object(tessera.tessera_typesafe, 'invoke', side_effect=invoke) as send:
            with self.assertRaisesRegex(ValueError, 'checkout changed'): tessera.evaluate(f.run_dir)
        self.assertEqual(send.call_count, 1)
        self.assertEqual(tessera.load(f.run_dir / 'failure.json')['completed_calls'], 1)
        self.assertFalse((f.run_dir / 'decision.json').exists())

    def test_calls_symlink_is_rejected_before_network(self):
        f = self.fixture
        try:
            (f.run_dir / 'calls').symlink_to(f.repo, target_is_directory=True)
        except OSError:
            self.skipTest('Host does not permit unprivileged directory symlinks')
        with patch.object(tessera.tessera_typesafe, 'invoke') as invoke:
            with self.assertRaises(FileExistsError): tessera.evaluate(f.run_dir)
            invoke.assert_not_called()
        self.assertFalse((f.repo / '0000').exists())

    def test_git_failure_after_a_call_is_recorded(self):
        f = self.fixture
        def invoke(payload):
            request = json.loads(payload)
            return response(request, 'create')
        with patch.object(tessera.tessera_typesafe, 'check_credentials'), \
                patch.object(tessera.tessera_typesafe, 'invoke', side_effect=invoke) as send, \
                patch.object(tessera, 'project_snapshot', side_effect=[
                    dict(revision=tessera.load(f.run_dir / 'manifest.json')['revision'], checkout_changes=[]),
                    subprocess.CalledProcessError(128, 'git')]):
            with self.assertRaises(subprocess.CalledProcessError): tessera.evaluate(f.run_dir)
        self.assertEqual(send.call_count, 1)
        self.assertEqual(tessera.load(f.run_dir / 'failure.json')['error'], 'CalledProcessError')

    @unittest.skipUnless(os.name == 'nt', 'Windows long-path regression')
    def test_long_windows_run_writes_nested_call_artifacts(self):
        f = self.fixture
        long_run = f.run_dir / ('x' * (240 - len(str(f.run_dir)) - 1))
        io_run = tessera.storage_io_path(long_run)
        io_run.mkdir()
        self.addCleanup(shutil.rmtree, io_run)
        for name in ('manifest.json', 'context.json', 'derived.json', 'request.json'):
            (io_run / name).write_bytes((f.run_dir / name).read_bytes())
        def invoke(payload):
            request = json.loads(payload)
            return response(request, 'create')
        with patch.object(tessera.tessera_typesafe, 'check_credentials'), \
                patch.object(tessera.tessera_typesafe, 'invoke', side_effect=invoke):
            result = tessera.evaluate(long_run)
        self.assertEqual(result['action'], 'create')
        self.assertTrue((io_run / 'calls/0000/response.json').exists())


if __name__ == '__main__':
    unittest.main()
