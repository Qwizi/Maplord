from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand

from apps.inventory.models import Item, UserInventory, Wallet

User = get_user_model()

STARTER_ITEMS = [
    'pkg-shield-1',   # Pakiet: Tarcza Lvl 1 (free ability)
    'bp-barracks-1',  # Blueprint: Koszary Lvl 1
    'bp-radar-1',     # Blueprint: Elektrownia Lvl 1
]
STARTER_GOLD = 100


class Command(BaseCommand):
    help = "Give all non-bot players default starter items and gold"

    def handle(self, *args, **options):
        users = User.objects.filter(is_bot=False)
        items = {slug: Item.objects.filter(slug=slug).first() for slug in STARTER_ITEMS}

        # Filter out items that don't exist yet (seed might not have run)
        items = {slug: item for slug, item in items.items() if item is not None}

        if not items:
            self.stdout.write("No starter items found — run seed_economy_data first")
            return

        provisioned = 0
        for user in users:
            changed = False

            # Wallet
            wallet, created = Wallet.objects.get_or_create(user=user, defaults={'gold': STARTER_GOLD})
            if created:
                changed = True
            elif wallet.gold < STARTER_GOLD:
                wallet.gold = STARTER_GOLD
                wallet.save(update_fields=['gold'])
                changed = True

            # Starter items
            for slug, item in items.items():
                inv, created = UserInventory.objects.get_or_create(
                    user=user, item=item,
                    defaults={'quantity': 1},
                )
                if created:
                    changed = True

            if changed:
                provisioned += 1

        self.stdout.write(
            f"Provisioned {provisioned} player(s) with default items "
            f"({len(items)} items, {STARTER_GOLD} gold)"
        )
