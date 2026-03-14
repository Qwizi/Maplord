from django.contrib import admin
from unfold.admin import ModelAdmin
from unfold.decorators import display
from unfold.contrib.filters.admin import RangeNumericFilter
from apps.inventory.models import ItemCategory, Item, UserInventory, ItemDrop, Wallet


@admin.register(ItemCategory)
class ItemCategoryAdmin(ModelAdmin):
    list_display = ('name', 'slug', 'order', 'display_active')
    list_fullwidth = True
    prepopulated_fields = {'slug': ('name',)}
    list_editable = ('order',)

    @display(description="Active", label=True)
    def display_active(self, obj):
        return "ACTIVE" if obj.is_active else "INACTIVE"


@admin.register(Item)
class ItemAdmin(ModelAdmin):
    list_display = ('icon', 'name', 'slug', 'category', 'item_type', 'display_rarity', 'base_value', 'is_tradeable', 'display_active')
    list_filter = (
        'category',
        'item_type',
        'rarity',
        'is_active',
        'is_tradeable',
        ('base_value', RangeNumericFilter),
    )
    list_filter_submit = True
    list_fullwidth = True
    search_fields = ('name', 'slug')
    prepopulated_fields = {'slug': ('name',)}
    fieldsets = (
        (None, {'fields': ('name', 'slug', 'description', 'category', 'item_type', 'rarity', 'icon', 'asset_key')}),
        ('Properties', {'fields': ('is_stackable', 'is_tradeable', 'is_consumable', 'max_stack', 'base_value')}),
        ('Crate / Key', {'classes': ('collapse',), 'fields': ('crate_loot_table', 'opens_crate')}),
        ('Boost / Blueprint', {'classes': ('collapse',), 'fields': ('boost_params', 'blueprint_ref')}),
        ('Status', {'fields': ('is_active',)}),
    )

    @display(description="Rarity", label={
        "common": "info",
        "uncommon": "success",
        "rare": "primary",
        "epic": "warning",
        "legendary": "danger",
    })
    def display_rarity(self, obj):
        return obj.rarity

    @display(description="Active", label=True)
    def display_active(self, obj):
        return "ACTIVE" if obj.is_active else "INACTIVE"


@admin.register(UserInventory)
class UserInventoryAdmin(ModelAdmin):
    list_display = ('user', 'item', 'quantity', 'acquired_at')
    list_filter = ('item__category', 'item__rarity')
    list_filter_submit = True
    list_fullwidth = True
    search_fields = ('user__username', 'item__name')
    raw_id_fields = ('user', 'item')


@admin.register(ItemDrop)
class ItemDropAdmin(ModelAdmin):
    list_display = ('user', 'item', 'quantity', 'display_source', 'match', 'created_at')
    list_filter = ('source', 'item__rarity')
    list_filter_submit = True
    list_fullwidth = True
    search_fields = ('user__username', 'item__name')
    raw_id_fields = ('user', 'item', 'match')

    @display(description="Source", label={
        "match_reward": "success",
        "crate_open": "warning",
        "crafting": "info",
    })
    def display_source(self, obj):
        return obj.source


@admin.register(Wallet)
class WalletAdmin(ModelAdmin):
    list_display = ('user', 'gold', 'total_earned', 'total_spent', 'updated_at')
    list_filter = (
        ('gold', RangeNumericFilter),
    )
    list_filter_submit = True
    list_fullwidth = True
    search_fields = ('user__username',)
    raw_id_fields = ('user',)
