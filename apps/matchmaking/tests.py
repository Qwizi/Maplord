"""
Tests for apps/matchmaking — Match, MatchPlayer, MatchQueue models.
"""
from datetime import timedelta

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone

from apps.matchmaking.models import Match, MatchPlayer, MatchQueue
from apps.game_config.models import GameSettings

User = get_user_model()


# ---------------------------------------------------------------------------
# Match model
# ---------------------------------------------------------------------------

class MatchModelTests(TestCase):
    """Tests for the Match model."""

    def test_default_status_is_waiting(self):
        match = Match.objects.create(max_players=2)
        self.assertEqual(match.status, Match.Status.WAITING)

    def test_str_representation_includes_status(self):
        match = Match.objects.create(max_players=2, status=Match.Status.IN_PROGRESS)
        self.assertIn('In Progress', str(match))
        self.assertIn(str(match.id), str(match))

    def test_status_transitions_selecting(self):
        match = Match.objects.create(max_players=2)
        match.status = Match.Status.SELECTING
        match.save()
        match.refresh_from_db()
        self.assertEqual(match.status, Match.Status.SELECTING)

    def test_status_transitions_in_progress(self):
        match = Match.objects.create(max_players=2)
        match.status = Match.Status.IN_PROGRESS
        match.started_at = timezone.now()
        match.save()
        match.refresh_from_db()
        self.assertEqual(match.status, Match.Status.IN_PROGRESS)
        self.assertIsNotNone(match.started_at)

    def test_status_transitions_finished(self):
        match = Match.objects.create(max_players=2, status=Match.Status.IN_PROGRESS)
        match.status = Match.Status.FINISHED
        match.finished_at = timezone.now()
        match.save()
        match.refresh_from_db()
        self.assertEqual(match.status, Match.Status.FINISHED)

    def test_status_transitions_cancelled(self):
        match = Match.objects.create(max_players=2)
        match.status = Match.Status.CANCELLED
        match.save()
        match.refresh_from_db()
        self.assertEqual(match.status, Match.Status.CANCELLED)

    def test_winner_field_nullable(self):
        match = Match.objects.create(max_players=2)
        self.assertIsNone(match.winner)

    def test_settings_snapshot_default_is_empty_dict(self):
        match = Match.objects.create(max_players=2)
        self.assertEqual(match.settings_snapshot, {})

    def test_is_tutorial_default_false(self):
        match = Match.objects.create(max_players=2)
        self.assertFalse(match.is_tutorial)

    def test_tutorial_match_creation(self):
        match = Match.objects.create(max_players=1, is_tutorial=True)
        self.assertTrue(match.is_tutorial)

    def test_ordering_newest_first(self):
        m1 = Match.objects.create(max_players=2)
        m2 = Match.objects.create(max_players=2)
        matches = list(Match.objects.all())
        # Newest first
        self.assertEqual(matches[0].pk, m2.pk)

    def test_all_status_choices_valid(self):
        valid_statuses = [
            Match.Status.WAITING,
            Match.Status.SELECTING,
            Match.Status.IN_PROGRESS,
            Match.Status.FINISHED,
            Match.Status.CANCELLED,
        ]
        for status in valid_statuses:
            match = Match.objects.create(max_players=2, status=status)
            match.refresh_from_db()
            self.assertEqual(match.status, status)


# ---------------------------------------------------------------------------
# MatchPlayer model
# ---------------------------------------------------------------------------

class MatchPlayerModelTests(TestCase):
    """Tests for the MatchPlayer model."""

    def setUp(self):
        self.user1 = User.objects.create_user(
            email='mp1@test.com', username='mpplayer1', password='testpass123',
        )
        self.user2 = User.objects.create_user(
            email='mp2@test.com', username='mpplayer2', password='testpass123',
        )
        self.match = Match.objects.create(max_players=2)

    def test_creation_and_relationships(self):
        mp = MatchPlayer.objects.create(match=self.match, user=self.user1, color='#FF0000')
        self.assertEqual(mp.match, self.match)
        self.assertEqual(mp.user, self.user1)
        self.assertEqual(mp.color, '#FF0000')

    def test_default_is_alive_true(self):
        mp = MatchPlayer.objects.create(match=self.match, user=self.user1)
        self.assertTrue(mp.is_alive)

    def test_str_representation(self):
        mp = MatchPlayer.objects.create(match=self.match, user=self.user1)
        self.assertIn('mpplayer1', str(mp))

    def test_unique_together_match_user(self):
        MatchPlayer.objects.create(match=self.match, user=self.user1)
        from django.db import IntegrityError
        with self.assertRaises(IntegrityError):
            MatchPlayer.objects.create(match=self.match, user=self.user1)

    def test_multiple_players_in_same_match(self):
        MatchPlayer.objects.create(match=self.match, user=self.user1, color='#FF0000')
        MatchPlayer.objects.create(match=self.match, user=self.user2, color='#0000FF')
        self.assertEqual(self.match.players.count(), 2)

    def test_eliminated_at_null_by_default(self):
        mp = MatchPlayer.objects.create(match=self.match, user=self.user1)
        self.assertIsNone(mp.eliminated_at)

    def test_deck_snapshot_default_empty_dict(self):
        mp = MatchPlayer.objects.create(match=self.match, user=self.user1)
        self.assertEqual(mp.deck_snapshot, {})

    def test_cosmetic_snapshot_default_empty_dict(self):
        mp = MatchPlayer.objects.create(match=self.match, user=self.user1)
        self.assertEqual(mp.cosmetic_snapshot, {})

    def test_player_related_name_on_match(self):
        MatchPlayer.objects.create(match=self.match, user=self.user1)
        self.assertEqual(self.match.players.count(), 1)

    def test_match_related_name_on_user(self):
        MatchPlayer.objects.create(match=self.match, user=self.user1)
        self.assertEqual(self.user1.match_players.count(), 1)


# ---------------------------------------------------------------------------
# MatchQueue model
# ---------------------------------------------------------------------------

class MatchQueueTests(TestCase):
    """Tests for the MatchQueue model."""

    def setUp(self):
        self.user = User.objects.create_user(
            email='queue@test.com', username='queueuser', password='testpass123',
        )

    def test_queue_creation(self):
        entry = MatchQueue.objects.create(user=self.user)
        self.assertEqual(entry.user, self.user)

    def test_str_representation(self):
        entry = MatchQueue.objects.create(user=self.user)
        self.assertIn('queueuser', str(entry))

    def test_one_entry_per_user(self):
        MatchQueue.objects.create(user=self.user)
        from django.db import IntegrityError
        with self.assertRaises(IntegrityError):
            MatchQueue.objects.create(user=self.user)

    def test_joined_at_auto_set(self):
        entry = MatchQueue.objects.create(user=self.user)
        self.assertIsNotNone(entry.joined_at)
