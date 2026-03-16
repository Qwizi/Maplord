"""
Tests for apps/inventory — Item, ItemCategory, UserInventory, Wallet, Deck, DeckItem, ItemInstance.
"""
from django.contrib.auth import get_user_model
from django.test import TestCase

from apps.inventory.models import (
    Deck,
    DeckItem,
    Item,
    ItemCategory,
    ItemDrop,
    ItemInstance,
    UserInventory,
    Wallet,
)

User = get_user_model()


def make_category(name='Materials', slug='materials'):
    return ItemCategory.objects.create(name=name, slug=slug)


def make_item(category, name='Iron Ore', slug='iron-ore', item_type=Item.ItemType.MATERIAL):
    return Item.objects.create(
        name=name,
        slug=slug,
        category=category,
        item_type=item_type,
        rarity=Item.Rarity.COMMON,
    )


# ---------------------------------------------------------------------------
# ItemCategory tests
# ---------------------------------------------------------------------------

class ItemCategoryTests(TestCase):

    def test_creation(self):
        cat = make_category('Blueprints', 'blueprints')
        self.assertEqual(cat.name, 'Blueprints')
        self.assertEqual(cat.slug, 'blueprints')

    def test_str_representation(self):
        cat = make_category('Boosts', 'boosts')
        self.assertEqual(str(cat), 'Boosts')

    def test_is_active_default_true(self):
        cat = make_category()
        self.assertTrue(cat.is_active)

    def test_unique_slug(self):
        make_category('Mats', 'unique-slug')
        from django.db import IntegrityError
        with self.assertRaises(IntegrityError):
            make_category('Mats 2', 'unique-slug')


# ---------------------------------------------------------------------------
# Item model tests
# ---------------------------------------------------------------------------

class ItemModelTests(TestCase):

    def setUp(self):
        self.category = make_category()
        self.item = make_item(self.category)

    def test_creation_and_attributes(self):
        self.assertEqual(self.item.name, 'Iron Ore')
        self.assertEqual(self.item.slug, 'iron-ore')
        self.assertEqual(self.item.category, self.category)
        self.assertEqual(self.item.item_type, Item.ItemType.MATERIAL)
        self.assertEqual(self.item.rarity, Item.Rarity.COMMON)

    def test_str_representation(self):
        self.assertIn('Iron Ore', str(self.item))
        self.assertIn('Common', str(self.item))

    def test_is_active_default_true(self):
        self.assertTrue(self.item.is_active)

    def test_is_stackable_default_true(self):
        self.assertTrue(self.item.is_stackable)

    def test_is_tradeable_default_true(self):
        self.assertTrue(self.item.is_tradeable)

    def test_is_consumable_default_false(self):
        self.assertFalse(self.item.is_consumable)

    def test_unique_slug_constraint(self):
        from django.db import IntegrityError
        with self.assertRaises(IntegrityError):
            make_item(self.category, name='Iron Ore 2', slug='iron-ore')

    def test_rarity_choices(self):
        for rarity in [
            Item.Rarity.COMMON, Item.Rarity.UNCOMMON, Item.Rarity.RARE,
            Item.Rarity.EPIC, Item.Rarity.LEGENDARY,
        ]:
            item = Item.objects.create(
                name=f'Item {rarity}', slug=f'item-{rarity}',
                category=self.category, item_type=Item.ItemType.MATERIAL,
                rarity=rarity,
            )
            item.refresh_from_db()
            self.assertEqual(item.rarity, rarity)

    def test_blueprint_item_type(self):
        bp = make_item(
            self.category,
            name='Barracks Blueprint',
            slug='bp-barracks',
            item_type=Item.ItemType.BLUEPRINT_BUILDING,
        )
        self.assertEqual(bp.item_type, Item.ItemType.BLUEPRINT_BUILDING)


# ---------------------------------------------------------------------------
# UserInventory tests
# ---------------------------------------------------------------------------

class UserInventoryTests(TestCase):

    def setUp(self):
        self.user = User.objects.create_user(
            email='inventory@test.com', username='inventoryuser', password='testpass123',
        )
        self.category = make_category()
        self.item = make_item(self.category)

    def test_creation_with_quantity(self):
        inv = UserInventory.objects.create(user=self.user, item=self.item, quantity=5)
        self.assertEqual(inv.quantity, 5)

    def test_str_representation(self):
        inv = UserInventory.objects.create(user=self.user, item=self.item, quantity=3)
        self.assertIn('inventoryuser', str(inv))
        self.assertIn('Iron Ore', str(inv))
        self.assertIn('3', str(inv))

    def test_unique_together_user_item(self):
        UserInventory.objects.create(user=self.user, item=self.item, quantity=1)
        from django.db import IntegrityError
        with self.assertRaises(IntegrityError):
            UserInventory.objects.create(user=self.user, item=self.item, quantity=2)

    def test_quantity_tracking(self):
        inv = UserInventory.objects.create(user=self.user, item=self.item, quantity=10)
        inv.quantity -= 3
        inv.save()
        inv.refresh_from_db()
        self.assertEqual(inv.quantity, 7)

    def test_related_name_on_user(self):
        UserInventory.objects.create(user=self.user, item=self.item, quantity=1)
        self.assertEqual(self.user.inventory.count(), 1)


# ---------------------------------------------------------------------------
# Wallet tests
# ---------------------------------------------------------------------------

class WalletTests(TestCase):

    def setUp(self):
        self.user = User.objects.create_user(
            email='wallet@test.com', username='walletuser', password='testpass123',
        )

    def test_wallet_creation_with_gold(self):
        wallet = Wallet.objects.create(user=self.user, gold=100)
        self.assertEqual(wallet.gold, 100)

    def test_str_representation(self):
        wallet = Wallet.objects.create(user=self.user, gold=250)
        self.assertIn('walletuser', str(wallet))
        self.assertIn('250', str(wallet))

    def test_one_to_one_user_relationship(self):
        wallet = Wallet.objects.create(user=self.user, gold=0)
        self.assertEqual(wallet.user, self.user)

    def test_gold_update(self):
        wallet = Wallet.objects.create(user=self.user, gold=100)
        wallet.gold += 50
        wallet.total_earned += 50
        wallet.save()
        wallet.refresh_from_db()
        self.assertEqual(wallet.gold, 150)
        self.assertEqual(wallet.total_earned, 50)


# ---------------------------------------------------------------------------
# Deck model tests
# ---------------------------------------------------------------------------

class DeckModelTests(TestCase):

    def setUp(self):
        self.user = User.objects.create_user(
            email='deck@test.com', username='deckuser', password='testpass123',
        )
        self.category = make_category()
        self.item = make_item(self.category)

    def test_deck_creation(self):
        deck = Deck.objects.create(user=self.user, name='My Deck')
        self.assertEqual(deck.name, 'My Deck')
        self.assertEqual(deck.user, self.user)

    def test_str_representation(self):
        deck = Deck.objects.create(user=self.user, name='Battle Deck')
        self.assertIn('deckuser', str(deck))
        self.assertIn('Battle Deck', str(deck))

    def test_is_default_false_by_default(self):
        deck = Deck.objects.create(user=self.user, name='Not Default')
        self.assertFalse(deck.is_default)

    def test_default_deck_flag(self):
        deck = Deck.objects.create(user=self.user, name='Default', is_default=True)
        self.assertTrue(deck.is_default)

    def test_only_one_default_deck_per_user(self):
        """Setting a new deck as default should unset the previous default."""
        d1 = Deck.objects.create(user=self.user, name='D1', is_default=True)
        d2 = Deck.objects.create(user=self.user, name='D2', is_default=True)
        d1.refresh_from_db()
        self.assertFalse(d1.is_default)
        self.assertTrue(d2.is_default)

    def test_deck_items_relationship(self):
        deck = Deck.objects.create(user=self.user, name='Deck with Items')
        DeckItem.objects.create(deck=deck, item=self.item, quantity=1)
        self.assertEqual(deck.items.count(), 1)

    def test_deck_item_str(self):
        deck = Deck.objects.create(user=self.user, name='Test Deck')
        di = DeckItem.objects.create(deck=deck, item=self.item, quantity=2)
        self.assertIn('Iron Ore', str(di))
        self.assertIn('2', str(di))


# ---------------------------------------------------------------------------
# ItemInstance tests
# ---------------------------------------------------------------------------

class ItemInstanceTests(TestCase):

    def setUp(self):
        self.user = User.objects.create_user(
            email='instance@test.com', username='instanceuser', password='testpass123',
        )
        self.category = make_category()
        self.item = make_item(
            self.category,
            name='Tactical Package',
            slug='tactical-pkg',
            item_type=Item.ItemType.TACTICAL_PACKAGE,
        )

    def test_creation(self):
        inst = ItemInstance.objects.create(item=self.item, owner=self.user)
        self.assertEqual(inst.item, self.item)
        self.assertEqual(inst.owner, self.user)

    def test_wear_condition_factory_new(self):
        inst = ItemInstance.objects.create(item=self.item, owner=self.user, wear=0.0)
        self.assertEqual(inst.wear_condition, ItemInstance.WearCondition.FACTORY_NEW)

    def test_wear_condition_battle_scarred(self):
        inst = ItemInstance.objects.create(item=self.item, owner=self.user, wear=0.9)
        self.assertEqual(inst.wear_condition, ItemInstance.WearCondition.BATTLE_SCARRED)

    def test_is_rare_pattern_true_for_low_seed(self):
        inst = ItemInstance.objects.create(item=self.item, owner=self.user, pattern_seed=5)
        self.assertTrue(inst.is_rare_pattern)

    def test_is_rare_pattern_false_for_high_seed(self):
        inst = ItemInstance.objects.create(item=self.item, owner=self.user, pattern_seed=100)
        self.assertFalse(inst.is_rare_pattern)

    def test_stattrak_default_false(self):
        inst = ItemInstance.objects.create(item=self.item, owner=self.user)
        self.assertFalse(inst.stattrak)

    def test_nametag_default_empty(self):
        inst = ItemInstance.objects.create(item=self.item, owner=self.user)
        self.assertEqual(inst.nametag, '')
