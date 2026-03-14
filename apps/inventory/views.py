import logging
import random
from ninja_extra import api_controller, route
from ninja_jwt.authentication import JWTAuth
from django.db import transaction
from django.shortcuts import get_object_or_404
from apps.pagination import paginate_qs

from apps.inventory.models import Deck, DeckItem, EquippedCosmetic, Item, ItemCategory, ItemDrop, UserInventory, Wallet
from apps.inventory.schemas import (
    DeckCreateSchema,
    DeckOutSchema,
    DeckUpdateSchema,
    EquipCosmeticInSchema,
    EquippedCosmeticOutSchema,
    InventoryItemOutSchema,
    ItemCategoryOutSchema,
    ItemDropOutSchema,
    OpenCrateInSchema,
    UnequipCosmeticInSchema,
    WalletOutSchema,
)

logger = logging.getLogger(__name__)


def get_or_create_wallet(user):
    wallet, _ = Wallet.objects.get_or_create(user=user)
    return wallet


def add_item_to_inventory(user, item, quantity=1):
    """Add items to user inventory, respecting stack limits."""
    inv, created = UserInventory.objects.get_or_create(
        user=user, item=item,
        defaults={'quantity': quantity},
    )
    if not created:
        inv.quantity = min(inv.quantity + quantity, item.max_stack)
        inv.save(update_fields=['quantity'])
    return inv


def remove_item_from_inventory(user, item, quantity=1):
    """Remove items from inventory. Returns True if successful."""
    try:
        inv = UserInventory.objects.get(user=user, item=item)
    except UserInventory.DoesNotExist:
        return False
    if inv.quantity < quantity:
        return False
    inv.quantity -= quantity
    if inv.quantity == 0:
        inv.delete()
    else:
        inv.save(update_fields=['quantity'])
    return True


@api_controller('/inventory', tags=['Inventory'])
class InventoryController:

    @route.get('/items/', response=list[ItemCategoryOutSchema], auth=None)
    def list_items(self):
        """List all available item types grouped by category."""
        return list(
            ItemCategory.objects.filter(is_active=True)
            .prefetch_related('items')
        )

    @route.get('/my/', response=dict, auth=JWTAuth())
    def my_inventory(self, request, limit: int = 50, offset: int = 0):
        """Get current user's inventory."""
        qs = (
            UserInventory.objects.filter(user=request.user)
            .select_related('item', 'item__category')
        )
        return paginate_qs(qs, limit, offset, schema=InventoryItemOutSchema)

    @route.get('/wallet/', response=WalletOutSchema, auth=JWTAuth())
    def my_wallet(self, request):
        """Get current user's gold wallet."""
        return get_or_create_wallet(request.user)

    @route.get('/drops/', response=dict, auth=JWTAuth())
    def my_drops(self, request, limit: int = 50, offset: int = 0):
        """Get recent item drops for current user."""
        qs = (
            ItemDrop.objects.filter(user=request.user)
            .select_related('item', 'item__category')
        )
        return paginate_qs(qs, limit, offset, schema=ItemDropOutSchema)

    @route.post('/open-crate/', auth=JWTAuth())
    def open_crate(self, request, payload: OpenCrateInSchema):
        """Open a crate using a key. Returns dropped items."""
        crate = get_object_or_404(Item, slug=payload.crate_item_slug, item_type=Item.ItemType.CRATE)
        key = get_object_or_404(Item, slug=payload.key_item_slug, item_type=Item.ItemType.KEY)

        if key.opens_crate_id != crate.id:
            return self.create_response({'error': 'This key does not open this crate'}, status_code=400)

        with transaction.atomic():
            if not remove_item_from_inventory(request.user, crate, 1):
                return self.create_response({'error': 'You do not have this crate'}, status_code=400)
            if not remove_item_from_inventory(request.user, key, 1):
                # Return the crate
                add_item_to_inventory(request.user, crate, 1)
                return self.create_response({'error': 'You do not have this key'}, status_code=400)

            # Roll loot from crate_loot_table
            loot_table = crate.crate_loot_table or []
            if not loot_table:
                return self.create_response({'error': 'Crate has no loot table'}, status_code=400)

            drops = _roll_crate_loot(loot_table)
            result_drops = []
            for item_slug, qty in drops:
                try:
                    drop_item = Item.objects.get(slug=item_slug)
                except Item.DoesNotExist:
                    continue
                add_item_to_inventory(request.user, drop_item, qty)
                drop_record = ItemDrop.objects.create(
                    user=request.user, item=drop_item, quantity=qty,
                    source=ItemDrop.DropSource.CRATE_OPEN,
                )
                result_drops.append({
                    'item_name': drop_item.name,
                    'item_slug': drop_item.slug,
                    'rarity': drop_item.rarity,
                    'quantity': qty,
                })

        return {'drops': result_drops}

    @route.get('/cosmetics/equipped/', response=list[EquippedCosmeticOutSchema], auth=JWTAuth())
    def equipped_cosmetics(self, request):
        """List currently equipped cosmetics."""
        return EquippedCosmetic.objects.filter(user=request.user).select_related('item', 'item__cosmetic_asset')

    @route.post('/cosmetics/equip/', response={200: EquippedCosmeticOutSchema, 400: dict, 404: dict}, auth=JWTAuth())
    def equip_cosmetic(self, request, payload: EquipCosmeticInSchema):
        """Equip a cosmetic item."""
        inv = UserInventory.objects.filter(user=request.user, item__slug=payload.item_slug).select_related('item', 'item__cosmetic_asset').first()
        if not inv:
            return 404, {'detail': 'Item not found in inventory.'}

        item = inv.item
        if item.item_type != Item.ItemType.COSMETIC:
            return 400, {'detail': 'Item is not a cosmetic.'}

        if not item.asset_key:
            return 400, {'detail': 'Item has no asset_key configured.'}

        equipped, _ = EquippedCosmetic.objects.update_or_create(
            user=request.user,
            slot=item.asset_key,
            defaults={'item': item},
        )
        return 200, equipped

    @route.post('/cosmetics/unequip/', response={200: dict, 404: dict}, auth=JWTAuth())
    def unequip_cosmetic(self, request, payload: UnequipCosmeticInSchema):
        """Unequip a cosmetic from a slot."""
        deleted, _ = EquippedCosmetic.objects.filter(user=request.user, slot=payload.slot).delete()
        if not deleted:
            return 404, {'detail': 'No cosmetic equipped in this slot.'}
        return 200, {'detail': 'Unequipped.'}


def _roll_crate_loot(loot_table, num_rolls=3):
    """Roll items from a crate loot table. Returns list of (item_slug, quantity)."""
    if not loot_table:
        return []

    items = []
    weights = []
    for entry in loot_table:
        items.append(entry)
        weights.append(entry.get('weight', 1))

    results = []
    for _ in range(num_rolls):
        chosen = random.choices(items, weights=weights, k=1)[0]
        min_qty = chosen.get('min_qty', 1)
        max_qty = chosen.get('max_qty', 1)
        qty = random.randint(min_qty, max_qty)
        results.append((chosen['item_slug'], qty))

    # Merge duplicates
    merged = {}
    for slug, qty in results:
        merged[slug] = merged.get(slug, 0) + qty
    return list(merged.items())


# Item types permitted inside a deck
_DECK_ALLOWED_TYPES = {
    Item.ItemType.BLUEPRINT_BUILDING,
    Item.ItemType.BLUEPRINT_UNIT,
    Item.ItemType.TACTICAL_PACKAGE,
    Item.ItemType.BOOST,
}


@api_controller('/inventory/decks', tags=['Decks'])
class DeckController:

    @route.get('/', response=dict, auth=JWTAuth())
    def list_decks(self, request, limit: int = 50, offset: int = 0):
        """List current user's decks with their items."""
        qs = (
            Deck.objects.filter(user=request.user)
            .prefetch_related('items__item', 'items__item__category')
        )
        return paginate_qs(qs, limit, offset, schema=DeckOutSchema)

    @route.post('/', response=DeckOutSchema, auth=JWTAuth())
    def create_deck(self, request, payload: DeckCreateSchema):
        """Create a new deck for the current user."""
        deck = Deck.objects.create(user=request.user, name=payload.name)
        return deck

    @route.get('/{deck_id}/', response=DeckOutSchema, auth=JWTAuth())
    def get_deck(self, request, deck_id: str):
        """Retrieve a single deck with its items."""
        deck = get_object_or_404(
            Deck.objects.prefetch_related('items__item', 'items__item__category'),
            id=deck_id, user=request.user,
        )
        return deck

    @route.put('/{deck_id}/', response=DeckOutSchema, auth=JWTAuth())
    def update_deck(self, request, deck_id: str, payload: DeckUpdateSchema):
        """Update a deck's name and/or item list.

        Validation:
        - Each item_slug must exist and be of type blueprint_building,
          blueprint_unit, ability_scroll, or boost.
        - User must have enough items in inventory to cover ALL decks combined
          (not just this one).
        """
        deck = get_object_or_404(Deck, id=deck_id, user=request.user)

        with transaction.atomic():
            if payload.name is not None:
                deck.name = payload.name
                deck.save(update_fields=['name', 'updated_at'])

            if payload.items is not None:
                # Validate each slot
                validated_items: list[tuple] = []
                for slot in payload.items:
                    try:
                        item = Item.objects.get(slug=slot.item_slug, is_active=True)
                    except Item.DoesNotExist:
                        return self.create_response(
                            {'error': f'Item not found: {slot.item_slug}'},
                            status_code=400,
                        )
                    if item.item_type not in _DECK_ALLOWED_TYPES:
                        return self.create_response(
                            {'error': f'Item type "{item.item_type}" is not allowed in a deck: {slot.item_slug}'},
                            status_code=400,
                        )
                    validated_items.append((item, slot.quantity))

                # Check inventory coverage across all decks
                # For each item, sum quantities required by ALL decks (replacing this deck's old requirement)
                new_deck_requirements: dict = {}
                for item, qty in validated_items:
                    new_deck_requirements[item.id] = new_deck_requirements.get(item.id, 0) + qty

                # Sum requirements from OTHER decks for the same user
                other_requirements: dict = {}
                for di in DeckItem.objects.filter(
                    deck__user=request.user
                ).exclude(deck_id=deck_id).select_related('item'):
                    other_requirements[di.item_id] = other_requirements.get(di.item_id, 0) + di.quantity

                # Build combined requirement and validate against inventory
                all_item_ids = set(new_deck_requirements) | set(other_requirements)
                for item_id in all_item_ids:
                    total_required = (
                        new_deck_requirements.get(item_id, 0)
                        + other_requirements.get(item_id, 0)
                    )
                    owned = UserInventory.objects.filter(
                        user=request.user, item_id=item_id
                    ).values_list('quantity', flat=True).first() or 0
                    if owned < total_required:
                        try:
                            item_name = Item.objects.get(id=item_id).name
                        except Item.DoesNotExist:
                            item_name = str(item_id)
                        return self.create_response(
                            {
                                'error': (
                                    f'Insufficient inventory for "{item_name}": '
                                    f'need {total_required} across all decks, have {owned}'
                                )
                            },
                            status_code=400,
                        )

                # Replace deck items
                DeckItem.objects.filter(deck=deck).delete()
                for item, qty in validated_items:
                    DeckItem.objects.create(deck=deck, item=item, quantity=qty)

        return (
            Deck.objects.prefetch_related('items__item', 'items__item__category')
            .get(id=deck.id)
        )

    @route.delete('/{deck_id}/', auth=JWTAuth())
    def delete_deck(self, request, deck_id: str):
        """Delete a deck."""
        deck = get_object_or_404(Deck, id=deck_id, user=request.user)
        deck.delete()
        return {'ok': True}

    @route.post('/{deck_id}/set-default/', response=DeckOutSchema, auth=JWTAuth())
    def set_default_deck(self, request, deck_id: str):
        """Set this deck as the user's default deck."""
        deck = get_object_or_404(
            Deck.objects.prefetch_related('items__item', 'items__item__category'),
            id=deck_id, user=request.user,
        )
        deck.is_default = True
        deck.save()  # triggers the unique-default enforcement in Deck.save()
        return deck
