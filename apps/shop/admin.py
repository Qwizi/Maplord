from django.contrib import admin
from apps.shop.models import ShopCategory, ShopItem


class ShopItemInline(admin.TabularInline):
    model = ShopItem
    extra = 0
    fields = ('name', 'item_type', 'price', 'icon', 'is_active')


@admin.register(ShopCategory)
class ShopCategoryAdmin(admin.ModelAdmin):
    list_display = ('name', 'slug', 'order', 'is_active')
    prepopulated_fields = {'slug': ('name',)}
    inlines = [ShopItemInline]


@admin.register(ShopItem)
class ShopItemAdmin(admin.ModelAdmin):
    list_display = ('name', 'category', 'item_type', 'price', 'icon', 'is_active')
    list_filter = ('category', 'item_type', 'is_active')
    search_fields = ('name',)
