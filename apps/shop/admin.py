from django.contrib import admin
from unfold.admin import ModelAdmin, TabularInline
from unfold.decorators import display
from apps.shop.models import ShopCategory, ShopItem


class ShopItemInline(TabularInline):
    model = ShopItem
    extra = 0
    fields = ('name', 'item_type', 'price', 'icon', 'is_active')


@admin.register(ShopCategory)
class ShopCategoryAdmin(ModelAdmin):
    list_display = ('name', 'slug', 'order', 'display_active')
    list_fullwidth = True
    prepopulated_fields = {'slug': ('name',)}
    inlines = [ShopItemInline]

    @display(description="Active", label=True)
    def display_active(self, obj):
        return "ACTIVE" if obj.is_active else "INACTIVE"


@admin.register(ShopItem)
class ShopItemAdmin(ModelAdmin):
    list_display = ('name', 'category', 'item_type', 'price', 'icon', 'display_active')
    list_filter = ('category', 'item_type', 'is_active')
    list_filter_submit = True
    list_fullwidth = True
    search_fields = ('name',)

    @display(description="Active", label=True)
    def display_active(self, obj):
        return "ACTIVE" if obj.is_active else "INACTIVE"
