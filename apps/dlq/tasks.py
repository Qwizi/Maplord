import logging

from celery import current_app, shared_task

logger = logging.getLogger(__name__)


@shared_task
def retry_dead_letter_tasks():
    """Retry all unresolved FailedTask records that have not yet reached max_retries.

    Runs every 60 seconds via Celery beat. Each eligible record is re-queued
    with its original args/kwargs and its retry_count is incremented. Records
    that have reached max_retries are left in place so they can be inspected
    and resolved manually via the admin.
    """
    from apps.dlq.models import FailedTask

    # Fetch all unresolved records and filter in Python so we can compare the
    # two per-row integer fields without a raw SQL expression.
    pending = FailedTask.objects.filter(resolved=False)
    eligible = [ft for ft in pending if ft.retry_count < ft.max_retries]

    if not eligible:
        return

    retried = 0
    for failed_task in eligible:
        try:
            current_app.send_task(
                failed_task.task_name,
                args=failed_task.args,
                kwargs=failed_task.kwargs,
            )
            failed_task.retry_count += 1
            failed_task.save(update_fields=["retry_count"])
            retried += 1
            logger.info(
                "DLQ: re-queued task %s (id=%s), retry %d/%d",
                failed_task.task_name,
                failed_task.task_id,
                failed_task.retry_count,
                failed_task.max_retries,
            )
        except Exception as e:
            logger.error(
                "DLQ: could not re-queue task %s (id=%s): %s",
                failed_task.task_name,
                failed_task.task_id,
                e,
            )

    if retried:
        logger.info("DLQ: retried %d failed task(s)", retried)
