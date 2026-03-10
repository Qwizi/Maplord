import uuid
from django.db import models


class ShopCategory(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=100, unique=True)
    slug = models.SlugField(max_length=100, unique=True)
    order = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)

    class Meta:
        verbose_name_plural = 'shop categories'
        ordering = ['order', 'name']

    def __str__(self):
        return self.name


class ShopItem(models.Model):
    class ItemType(models.TextChoices):
        COSMETIC = 'cosmetic', 'Cosmetic'
        BOOST = 'boost', 'Boost'
        CURRENCY = 'currency', 'Currency'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    category = models.ForeignKey(ShopCategory, on_delete=models.CASCADE, related_name='items')
    item_type = models.CharField(max_length=20, choices=ItemType.choices, default=ItemType.COSMETIC)
    price = models.PositiveIntegerField(default=0, help_text='Price in game currency')
    icon = models.CharField(max_length=50, blank=True, default='🎁')
    image = models.ImageField(upload_to='shop/', blank=True, null=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['category__order', 'name']

    def __str__(self):
        return self.name
