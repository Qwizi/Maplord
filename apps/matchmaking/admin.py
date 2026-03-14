from django.contrib import admin
from django.db.models import Count
from apps.matchmaking.models import Match, MatchPlayer, MatchQueue


@admin.action(description="Anuluj wybrane mecze (powiadom graczy)")
def cancel_matches(modeladmin, request, queryset):
    import redis
    from django.conf import settings

    r = redis.Redis.from_url(settings.REDIS_URL)
    count = 0
    for match in queryset.filter(status__in=['selecting', 'in_progress']):
        r.set(f"game:{match.id}:cancel_requested", "1", ex=300)
        match.status = 'cancelled'
        match.save(update_fields=['status'])
        count += 1
    modeladmin.message_user(request, f"Anulowano {count} meczy.")


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
    actions = [cancel_matches]

    def get_queryset(self, request):
        return super().get_queryset(request).annotate(player_count=Count('players'))

    def player_count(self, obj):
        return obj.player_count
    player_count.short_description = 'Players'


@admin.register(MatchPlayer)
class MatchPlayerAdmin(admin.ModelAdmin):
    list_display = ('user', 'match', 'color', 'is_alive', 'joined_at')
    list_filter = ('is_alive',)


@admin.register(MatchQueue)
class MatchQueueAdmin(admin.ModelAdmin):
    list_display = ('user', 'joined_at')
    readonly_fields = ('id',)
