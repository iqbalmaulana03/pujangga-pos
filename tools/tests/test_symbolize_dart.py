import unittest

from tools.symbolize_dart import normalize_trace


class NormalizeTraceTest(unittest.TestCase):
    def test_legacy_trace_is_unchanged(self):
        trace = "isolate_instructions: 7000, vm_instructions: 0\n#00 abs 7080 _kDartIsolateSnapshotInstructions+0x80\n"
        self.assertEqual(normalize_trace(trace), trace)

    def test_unified_trace_preserves_virtual_pc_and_build_identity(self):
        trace = (
            "os: android arch: arm64 comp: yes sim: no\n"
            "build_id: 'abc123'\n"
            "isolate_dso_base: 7000, vm_dso_base: 0\n"
            "isolate_instructions: 8000, vm_instructions: 0\n"
            "#00 abs 8080 virt 1080 _kDartSnapshotText+0x80\n"
        )
        result = normalize_trace(trace)
        self.assertNotIn("isolate_dso_base:", result)
        self.assertNotIn("isolate_instructions:", result)
        self.assertIn("os: android arch: arm64", result)
        self.assertIn("build_id: 'abc123'", result)
        self.assertIn("#00 abs 8080 virt 1080 _kDartSnapshotText+0x80", result)

    def test_missing_virtual_pc_is_rejected(self):
        with self.assertRaises(ValueError):
            normalize_trace("#00 abs 8080 _kDartSnapshotText+0x80\n")

    def test_deferred_unit_is_not_decoded_with_root_symbols(self):
        with self.assertRaises(ValueError):
            normalize_trace("#00 abs 8080 unit 2 virt 1080 _kDartSnapshotText+0x80\n")


if __name__ == "__main__":
    unittest.main()
