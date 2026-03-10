from django.contrib import admin
from apps.matchmaking.models import Match, MatchPlayer, MatchQueue


class MatchPlayerInline(admin.TabularInline):
    model = MatchPlayer
    extra = 0
    readonly_fields = ('user', 'color', 'is_alive', 'capital_region', 'joined_at', 'eliminated_at')


@admin.register(Match)
class MatchAdmin(admin.ModelAdmin):
    list_display = ('id', 'status', 'max_players', 'player_count', 'winner', 'started_at', 'finished_at')
    list_filter = ('status',)
    search_fields = ('id',)
    readonly_fields = ('id', 'settings_snapshot', 'created_at')
    inlines = [MatchPlayerInline]

    def player_count(self, obj):
        return obj.players.count()
    player_count.short_description = 'Players'


@admin.register(MatchPlayer)
class MatchPlayerAdmin(admin.ModelAdmin):
    list_display = ('user', 'match', 'color', 'is_alive', 'joined_at')
    list_filter = ('is_alive',)


@admin.register(MatchQueue)
class MatchQueueAdmin(admin.ModelAdmin):
    list_display = ('user', 'joined_at')
    readonly_fields = ('id',)
