from channels.middleware import BaseMiddleware
from channels.db import database_sync_to_async
from django.contrib.auth.models import AnonymousUser
from urllib.parse import parse_qs


@database_sync_to_async
def get_user_from_token(token):
    """Validate JWT token and return user."""
    try:
        from ninja_jwt.tokens import AccessToken
        validated = AccessToken(token)
        user_id = validated.get('user_id')
        
        from django.contrib.auth import get_user_model
        User = get_user_model()
        return User.objects.get(id=user_id)
    except Exception:
        return AnonymousUser()


class JWTAuthMiddleware(BaseMiddleware):
    """Middleware that authenticates WebSocket connections via JWT query param."""

    async def __call__(self, scope, receive, send):
        query_string = scope.get('query_string', b'').decode()
        params = parse_qs(query_string)
        token = params.get('token', [None])[0]

        if token:
            scope['user'] = await get_user_from_token(token)
        else:
            scope['user'] = AnonymousUser()

        return await super().__call__(scope, receive, send)
