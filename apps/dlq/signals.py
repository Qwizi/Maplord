import logging
import traceback as tb_module

from celery.signals import task_failure

logger = logging.getLogger(__name__)


@task_failure.connect
def handle_task_failure(sender, task_id, exception, args, kwargs, traceback, einfo, **extra):
    """Capture every Celery task failure into the FailedTask dead letter queue."""
    from apps.dlq.models import FailedTask

    exception_type = type(exception).__name__
    exception_message = str(exception)

    # einfo is a Celery ExceptionInfo object; fall back to formatting the live
    # traceback when it is unavailable.
    if einfo is not None:
        traceback_str = str(einfo)
    elif traceback is not None:
        traceback_str = "".join(tb_module.format_tb(traceback))
    else:
        traceback_str = ""

    try:
        FailedTask.objects.create(
            task_name=sender.name,
            task_id=task_id,
            args=list(args) if args else [],
            kwargs=dict(kwargs) if kwargs else {},
            exception_type=exception_type,
            exception_message=exception_message,
            traceback=traceback_str,
        )
        logger.warning(
            "DLQ: recorded failed task %s (id=%s) — %s: %s",
            sender.name,
            task_id,
            exception_type,
            exception_message,
        )
    except Exception as e:
        logger.error("DLQ: failed to persist FailedTask record for task %s: %s", task_id, e)
