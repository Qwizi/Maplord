import uuid

from django.db import models


class FailedTask(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    task_name = models.CharField(max_length=255, db_index=True)
    task_id = models.CharField(max_length=255, unique=True)
    args = models.JSONField(default=list)
    kwargs = models.JSONField(default=dict)
    exception_type = models.CharField(max_length=255)
    exception_message = models.TextField()
    traceback = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    retry_count = models.IntegerField(default=0)
    max_retries = models.IntegerField(default=3)
    resolved = models.BooleanField(default=False, db_index=True)
    resolved_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.task_name} ({self.task_id}) - {'resolved' if self.resolved else 'pending'}"
