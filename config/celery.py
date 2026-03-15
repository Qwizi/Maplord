import os
from celery import Celery

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

app = Celery('maplord')
app.config_from_object('django.conf:settings', namespace='CELERY')
app.autodiscover_tasks()

app.conf.beat_schedule = {
    **getattr(app.conf, 'beat_schedule', {}),
    'cleanup-stale-lobbies': {
        'task': 'apps.matchmaking.tasks.cleanup_stale_lobbies',
        'schedule': 60.0,  # every minute
    },
}
