from django.contrib import admin
from apps.game.models import GameStateSnapshot, MatchResult, PlayerResult


class PlayerResultInline(admin.TabularInline):
    model = PlayerResult
    extra = 0
    readonly_fields = ('user', 'placement', 'regions_conquered', 'units_produced', 'units_lost', 'buildings_built', 'elo_change')


@admin.register(GameStateSnapshot)
class GameStateSnapshotAdmin(admin.ModelAdmin):
    list_display = ('match', 'tick', 'created_at')
    list_filter = ('match',)
    readonly_fields = ('id', 'state_data', 'created_at')


@admin.register(MatchResult)
class MatchResultAdmin(admin.ModelAdmin):
    list_display = ('match', 'duration_seconds', 'total_ticks')
    readonly_fields = ('id',)
    inlines = [PlayerResultInline]


@admin.register(PlayerResult)
class PlayerResultAdmin(admin.ModelAdmin):
    list_display = ('user', 'match_result', 'placement', 'regions_conquered', 'elo_change')
    list_filter = ('placement',)
