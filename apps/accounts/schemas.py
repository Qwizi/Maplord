import uuid
from datetime import datetime
from ninja import Schema
from pydantic import EmailStr


class RegisterSchema(Schema):
    email: EmailStr
    username: str
    password: str


class UserOutSchema(Schema):
    id: uuid.UUID
    email: str
    username: str
    role: str
    elo_rating: int
    date_joined: datetime

    class Config:
        from_attributes = True
