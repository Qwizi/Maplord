import json
import logging
import os
import tempfile

from django.conf import settings
from pywebpush import webpush, WebPushException

logger = logging.getLogger(__name__)

# Write VAPID private key PEM to a temp file once at module load
# (pywebpush expects a file path, not a PEM string)
_vapid_key_path = None
if settings.VAPID_PRIVATE_KEY:
    _f = tempfile.NamedTemporaryFile(mode="w", suffix=".pem", delete=False)
    _f.write(settings.VAPID_PRIVATE_KEY)
    _f.close()
    _vapid_key_path = _f.name


def send_push(user_id: str, title: str, body: str, url: str = "/dashboard", tag: str = ""):
    """Send push notification to all subscriptions for a user."""
    from apps.accounts.models import PushSubscription

    if not _vapid_key_path:
        return

    payload = json.dumps({
        "title": title,
        "body": body,
        "url": url,
        "tag": tag,
    })

    subs = PushSubscription.objects.filter(user_id=user_id)
    stale_ids = []

    for sub in subs:
        try:
            webpush(
                subscription_info=sub.to_webpush_dict(),
                data=payload,
                vapid_private_key=_vapid_key_path,
                vapid_claims={"sub": settings.VAPID_MAILTO},
            )
        except WebPushException as e:
            if e.response and e.response.status_code in (404, 410):
                stale_ids.append(sub.id)
            else:
                logger.warning(f"Push failed for user {user_id}: {e}")
        except Exception as e:
            logger.warning(f"Push error for user {user_id}: {e}")

    if stale_ids:
        PushSubscription.objects.filter(id__in=stale_ids).delete()


def send_push_to_users(user_ids: list[str], title: str, body: str, url: str = "/dashboard", tag: str = ""):
    """Send push notification to multiple users."""
    for uid in user_ids:
        send_push(uid, title, body, url, tag)
