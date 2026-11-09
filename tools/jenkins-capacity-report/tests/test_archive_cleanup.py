#!/usr/bin/env python3
"""Tests for archiving completed months of metrics history."""

import json
import os
import tempfile
import unittest
from datetime import datetime
from unittest import mock

from src.metrics_tracker import MetricsTracker


class TestArchiveAndCleanup(unittest.TestCase):
    """Test cases for MetricsTracker.archive_and_cleanup."""

    def setUp(self):
        """Set up a metrics history file with a past and a current month."""
        self.temp_file = tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.json')
        self.past_snapshot = {'timestamp': '2000-01-15T12:00:00', 'total_nodes': 1}
        self.current_snapshot = {'timestamp': datetime.now().isoformat(), 'total_nodes': 2}
        json.dump([self.past_snapshot, self.current_snapshot], self.temp_file)
        self.temp_file.close()
        self.tracker = MetricsTracker(data_file=self.temp_file.name)
        self.archive_manager = mock.Mock()

    def tearDown(self):
        """Remove the metrics history file."""
        if os.path.exists(self.temp_file.name):
            os.unlink(self.temp_file.name)

    def _read_history(self):
        with open(self.temp_file.name, 'r') as f:
            return json.load(f)

    def _archive_and_cleanup(self):
        with mock.patch('src.archive_manager.get_archive_manager',
                        return_value=self.archive_manager):
            return self.tracker.archive_and_cleanup()

    def test_archived_month_is_removed_from_history(self):
        """A month that is archived is removed from the history file."""
        result = self._archive_and_cleanup()

        self.archive_manager.archive_month.assert_called_once_with('2000-01', [self.past_snapshot])
        self.assertEqual(result['archived_months'], ['2000-01'])
        self.assertEqual(self._read_history(), [self.current_snapshot])

    def test_failed_archive_keeps_month_in_history(self):
        """A month that fails to archive stays in the history file."""
        self.archive_manager.archive_month.side_effect = OSError('disk full')

        result = self._archive_and_cleanup()

        self.assertEqual(result['archived_months'], [])
        self.assertEqual(result['snapshots_archived'], 0)
        self.assertEqual(self._read_history(), [self.past_snapshot, self.current_snapshot])


if __name__ == '__main__':
    unittest.main()
