from django.apps import AppConfig


class DlqConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.dlq"
    verbose_name = "Dead Letter Queue"

    def ready(self):
        import apps.dlq.signals  # noqa: F401
