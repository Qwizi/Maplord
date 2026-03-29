import logging

from django.contrib import admin
from django.utils import timezone
from unfold.admin import ModelAdmin
from unfold.decorators import display

from apps.dlq.models import FailedTask

logger = logging.getLogger(__name__)


@admin.register(FailedTask)
class FailedTaskAdmin(ModelAdmin):
    list_display = (
        "task_name",
        "task_id",
        "exception_type",
        "retry_count",
        "max_retries",
        "display_resolved",
        "created_at",
        "resolved_at",
    )
    list_filter = (
        "resolved",
        "exception_type",
        "task_name",
    )
    list_filter_submit = True
    list_fullwidth = True
    search_fields = ("task_name", "task_id", "exception_type", "exception_message")
    readonly_fields = (
        "id",
        "task_name",
        "task_id",
        "args",
        "kwargs",
        "exception_type",
        "exception_message",
        "traceback",
        "created_at",
        "retry_count",
        "resolved_at",
    )
    actions = ["retry_selected_tasks", "mark_as_resolved"]

    @display(
        description="Resolved",
        label={
            True: "success",
            False: "danger",
        },
    )
    def display_resolved(self, obj):
        return obj.resolved

    @admin.action(description="Retry selected tasks")
    def retry_selected_tasks(self, request, queryset):
        from celery import current_app

        retried = 0
        for failed_task in queryset.filter(resolved=False):
            if failed_task.retry_count >= failed_task.max_retries:
                continue
            try:
                current_app.send_task(
                    failed_task.task_name,
                    args=failed_task.args,
                    kwargs=failed_task.kwargs,
                )
                failed_task.retry_count += 1
                failed_task.save(update_fields=["retry_count"])
                retried += 1
            except Exception as e:
                logger.error(
                    "DLQ admin: failed to retry task %s (id=%s): %s",
                    failed_task.task_name,
                    failed_task.task_id,
                    e,
                )

        self.message_user(request, f"Re-queued {retried} task(s).")

    @admin.action(description="Mark as resolved")
    def mark_as_resolved(self, request, queryset):
        now = timezone.now()
        updated = queryset.filter(resolved=False).update(resolved=True, resolved_at=now)
        self.message_user(request, f"Marked {updated} task(s) as resolved.")
