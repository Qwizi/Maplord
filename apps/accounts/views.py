from django.contrib.auth import get_user_model
from ninja_extra import api_controller, route
from ninja_extra.permissions import IsAuthenticated
from ninja_jwt.authentication import JWTAuth

from apps.accounts.schemas import RegisterSchema, UserOutSchema

User = get_user_model()


@api_controller('/auth', tags=['Auth'])
class AuthController:

    @route.post('/register', response=UserOutSchema, auth=None)
    def register(self, payload: RegisterSchema):
        user = User.objects.create_user(
            email=payload.email,
            username=payload.username,
            password=payload.password,
        )
        return user

    @route.get('/me', response=UserOutSchema, auth=JWTAuth(), permissions=[IsAuthenticated])
    def me(self, request):
        return request.auth
