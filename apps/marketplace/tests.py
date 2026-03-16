"""
Tests for apps/marketplace — MarketListing, MarketTransaction, MarketConfig.
"""
from datetime import timedelta

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone

from apps.inventory.models import Item, ItemCategory, UserInventory, Wallet
from apps.marketplace.models import MarketConfig, MarketListing, MarketTransaction

User = get_user_model()


def make_category():
    return ItemCategory.objects.get_or_create(name='Materials', slug='materials')[0]


def make_item(name='Iron Ore', slug='iron-ore'):
    cat = make_category()
    return Item.objects.get_or_create(
        slug=slug,
        defaults={
            'name': name,
            'category': cat,
            'item_type': Item.ItemType.MATERIAL,
            'rarity': Item.Rarity.COMMON,
            'base_value': 10,
        },
    )[0]


def make_user(email, username):
    return User.objects.create_user(email=email, username=username, password='testpass123')


# ---------------------------------------------------------------------------
# MarketConfig singleton
# ---------------------------------------------------------------------------

class MarketConfigTests(TestCase):

    def test_get_creates_singleton(self):
        config = MarketConfig.get()
        self.assertIsNotNone(config)

    def test_get_returns_same_instance(self):
        c1 = MarketConfig.get()
        c2 = MarketConfig.get()
        # Both calls should return the same singleton row
        self.assertEqual(MarketConfig.objects.count(), 1)
        # PKs should resolve to the same UUID value
        self.assertEqual(
            str(c1.pk).replace('-', '').lower(),
            str(c2.pk).replace('-', '').lower(),
        )

    def test_default_transaction_fee_percent(self):
        config = MarketConfig.get()
        self.assertEqual(config.transaction_fee_percent, 5.0)

    def test_default_max_active_listings(self):
        config = MarketConfig.get()
        self.assertEqual(config.max_active_listings_per_user, 20)

    def test_str_representation(self):
        config = MarketConfig.get()
        self.assertEqual(str(config), 'Marketplace Config')


# ---------------------------------------------------------------------------
# MarketListing tests
# ---------------------------------------------------------------------------

class MarketListingTests(TestCase):

    def setUp(self):
        self.seller = make_user('seller@test.com', 'sellertestuser')
        self.item = make_item()

    def test_sell_order_creation(self):
        listing = MarketListing.objects.create(
            seller=self.seller,
            item=self.item,
            listing_type=MarketListing.ListingType.SELL,
            quantity=10,
            price_per_unit=15,
            quantity_remaining=10,
        )
        self.assertEqual(listing.status, MarketListing.Status.ACTIVE)
        self.assertEqual(listing.quantity, 10)
        self.assertEqual(listing.price_per_unit, 15)

    def test_buy_order_creation(self):
        listing = MarketListing.objects.create(
            seller=self.seller,
            item=self.item,
            listing_type=MarketListing.ListingType.BUY,
            quantity=5,
            price_per_unit=12,
            quantity_remaining=5,
        )
        self.assertEqual(listing.listing_type, MarketListing.ListingType.BUY)

    def test_str_representation_sell_order(self):
        listing = MarketListing.objects.create(
            seller=self.seller,
            item=self.item,
            listing_type=MarketListing.ListingType.SELL,
            quantity=1,
            price_per_unit=20,
            quantity_remaining=1,
        )
        self.assertIn('Sell', str(listing))
        self.assertIn('Iron Ore', str(listing))

    def test_total_price_property(self):
        listing = MarketListing.objects.create(
            seller=self.seller,
            item=self.item,
            listing_type=MarketListing.ListingType.SELL,
            quantity=5,
            price_per_unit=10,
            quantity_remaining=5,
        )
        self.assertEqual(listing.total_price, 50)

    def test_listing_expiry_field(self):
        expires = timezone.now() + timedelta(hours=72)
        listing = MarketListing.objects.create(
            seller=self.seller,
            item=self.item,
            listing_type=MarketListing.ListingType.SELL,
            quantity=1,
            price_per_unit=10,
            quantity_remaining=1,
            expires_at=expires,
        )
        self.assertIsNotNone(listing.expires_at)

    def test_status_transitions(self):
        listing = MarketListing.objects.create(
            seller=self.seller,
            item=self.item,
            listing_type=MarketListing.ListingType.SELL,
            quantity=1,
            price_per_unit=10,
            quantity_remaining=1,
        )
        listing.status = MarketListing.Status.FULFILLED
        listing.save()
        listing.refresh_from_db()
        self.assertEqual(listing.status, MarketListing.Status.FULFILLED)

    def test_is_bot_listing_default_false(self):
        listing = MarketListing.objects.create(
            seller=self.seller,
            item=self.item,
            listing_type=MarketListing.ListingType.SELL,
            quantity=1,
            price_per_unit=10,
            quantity_remaining=1,
        )
        self.assertFalse(listing.is_bot_listing)

    def test_expired_listings_can_be_filtered(self):
        """Items past expires_at can be queried."""
        past = timezone.now() - timedelta(hours=1)
        expired_listing = MarketListing.objects.create(
            seller=self.seller,
            item=self.item,
            listing_type=MarketListing.ListingType.SELL,
            quantity=1,
            price_per_unit=10,
            quantity_remaining=1,
            expires_at=past,
        )
        expired_listing.status = MarketListing.Status.EXPIRED
        expired_listing.save()
        count = MarketListing.objects.filter(status=MarketListing.Status.EXPIRED).count()
        self.assertEqual(count, 1)

    def test_multiple_listings_per_item(self):
        buyer = make_user('buyer@test.com', 'buyertestuser')
        for i in range(3):
            MarketListing.objects.create(
                seller=self.seller,
                item=self.item,
                listing_type=MarketListing.ListingType.SELL,
                quantity=1,
                price_per_unit=10 + i,
                quantity_remaining=1,
            )
        self.assertEqual(
            MarketListing.objects.filter(item=self.item).count(), 3
        )


# ---------------------------------------------------------------------------
# MarketTransaction tests
# ---------------------------------------------------------------------------

class MarketTransactionTests(TestCase):

    def setUp(self):
        self.seller = make_user('tx_seller@test.com', 'txsellertestuser')
        self.buyer = make_user('tx_buyer@test.com', 'txbuyertestuser')
        self.item = make_item('Steel', 'steel')
        self.listing = MarketListing.objects.create(
            seller=self.seller,
            item=self.item,
            listing_type=MarketListing.ListingType.SELL,
            quantity=10,
            price_per_unit=25,
            quantity_remaining=10,
        )

    def test_transaction_creation(self):
        tx = MarketTransaction.objects.create(
            listing=self.listing,
            buyer=self.buyer,
            seller=self.seller,
            item=self.item,
            quantity=5,
            price_per_unit=25,
            total_price=125,
            fee=6,
        )
        self.assertEqual(tx.quantity, 5)
        self.assertEqual(tx.total_price, 125)
        self.assertEqual(tx.fee, 6)

    def test_str_representation(self):
        tx = MarketTransaction.objects.create(
            listing=self.listing,
            buyer=self.buyer,
            seller=self.seller,
            item=self.item,
            quantity=1,
            price_per_unit=25,
            total_price=25,
        )
        self.assertIn('txbuyertestuser', str(tx))
        self.assertIn('Steel', str(tx))

    def test_transaction_linked_to_listing(self):
        tx = MarketTransaction.objects.create(
            listing=self.listing,
            buyer=self.buyer,
            seller=self.seller,
            item=self.item,
            quantity=2,
            price_per_unit=25,
            total_price=50,
        )
        self.assertEqual(tx.listing, self.listing)

    def test_buyer_and_seller_relationships(self):
        tx = MarketTransaction.objects.create(
            listing=self.listing,
            buyer=self.buyer,
            seller=self.seller,
            item=self.item,
            quantity=3,
            price_per_unit=25,
            total_price=75,
        )
        self.assertEqual(self.buyer.market_purchases.count(), 1)
        self.assertEqual(self.seller.market_sales.count(), 1)

    def test_fee_default_zero(self):
        tx = MarketTransaction.objects.create(
            listing=self.listing,
            buyer=self.buyer,
            seller=self.seller,
            item=self.item,
            quantity=1,
            price_per_unit=10,
            total_price=10,
        )
        self.assertEqual(tx.fee, 0)
